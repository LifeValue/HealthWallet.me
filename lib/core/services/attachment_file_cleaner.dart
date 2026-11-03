import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:health_wallet/core/data/local/app_database.dart';
import 'package:health_wallet/core/services/attachment_references.dart';
import 'package:health_wallet/core/services/path_resolver.dart';
import 'package:health_wallet/core/utils/logger.dart';
import 'package:injectable/injectable.dart';
import 'package:path/path.dart' as p;

/// Deletes attachment files that no row refers to any more. The only code
/// that deletes attachment files: record, attachment and session deletes
/// only tombstone rows, so a deleted record keeps its files until its
/// tombstone is purged after 30 days ([deleteUnreferenced]), and files
/// nothing refers to are removed by the start-up [sweep].
///
/// A file is deleted only when all of these hold:
/// - it is a top-level regular file in [PathResolver.getDocumentsPath]: not
///   a symbolic link, not a dot-file, not the database (`db.sqlite*`), not a
///   `*.log` or `*.db` file, nothing in a subfolder;
/// - no `fhir_resource` row (live or deleted) and no scan session refers to
///   it, as [AttachmentReferences.isReferenced] finds (basenames raw and
///   decoded, ignoring case; an unreadable row is matched as raw text, so
///   the file is kept);
/// - for the [sweep], it is more than [sweepMinAge] old by the later of its
///   modified and changed times (every copy into Documents sets its modified
///   time, so a file whose row isn't written yet is fresh).
///
/// Each file is checked and deleted inside one [AppDatabase.transaction], so
/// a sync write can't add a reference between the check and the delete.
/// Nothing is deleted on Linux, where the documents directory is the user's
/// own, or when the documents directory itself is a symbolic link.
@lazySingleton
class AttachmentFileCleaner {
  AttachmentFileCleaner(this._db, this._paths, this._references)
    : _operatingSystem = Platform.operatingSystem,
      _now = DateTime.now;

  /// A cleaner that acts as on [operatingSystem] and reads the time from
  /// [now].
  @visibleForTesting
  AttachmentFileCleaner.forTesting(
    this._db,
    this._paths,
    this._references, {
    String? operatingSystem,
    DateTime Function()? now,
  }) : _operatingSystem = operatingSystem ?? Platform.operatingSystem,
       _now = now ?? DateTime.now;

  final AppDatabase _db;
  final PathResolver _paths;
  final AttachmentReferences _references;
  final String _operatingSystem;
  final DateTime Function() _now;

  /// The platforms whose documents directory belongs to the app alone.
  static const supportedPlatforms = {'android', 'ios', 'macos', 'windows'};

  /// How old an unreferenced file must be before the [sweep] deletes it.
  static const sweepMinAge = Duration(days: 7);

  static const _tag = '[AttachmentCleaner]';

  static final _windowsDrive = RegExp(r'^[a-zA-Z]:/');
  static final _containerPattern = RegExp(
    r'/Containers/Data/Application/[^/]+/Documents/(.+)$',
  );

  Future<int>? _sweeping;

  /// Whether [name] can never be deleted, whatever refers to it: a dot-file,
  /// the database, a log, a `.db` file, or not a plain file name.
  static bool isProtectedName(String name) {
    final lower = name.toLowerCase();
    return name.isEmpty ||
        name.startsWith('.') ||
        name.contains('/') ||
        name.contains(r'\') ||
        AttachmentReferences.isDatabase(name) ||
        lower.endsWith('.log') ||
        lower.endsWith('.db');
  }

  /// The `file://` urls in a record's [resourceRaw], for collecting the
  /// files of rows about to be purged. An unreadable record names none: its
  /// files are left to the [sweep].
  Future<List<String>> fileUrlsOf(String resourceRaw) async => [
    for (final ref in await _references.fromResourceRaw(
      resourceRaw,
      mode: OnUnparseable.skip,
    ))
      ref.url,
  ];

  /// Deletes the files named by [candidateUrls] (the attachments of purged
  /// rows) that no remaining row refers to. A url into a subfolder names no
  /// candidate. Returns how many files were deleted; never throws.
  Future<int> deleteUnreferenced(Iterable<String> candidateUrls) async {
    var deleted = 0;
    try {
      final urls = candidateUrls.toSet();
      if (urls.isEmpty) return 0;
      final root = await _usableRoot('purge');
      if (root == null) return 0;

      final wanted = {
        for (final url in urls)
          for (final name in _topLevelNames(url, root)) name.toLowerCase(),
      };
      if (wanted.isEmpty) return 0;

      final matched = <String>{};
      for (final entry in await _topLevelEntries(root)) {
        final name = p.basename(entry.path);
        if (wanted.contains(name.toLowerCase())) matched.add(name);
      }
      for (final name in matched) {
        if (isProtectedName(name)) continue;
        if (await _deleteIfUnreferenced(root, name, checkAge: false)) {
          deleted++;
        }
      }
      if (deleted > 0) {
        logger.i('$_tag deleted $deleted files of purged records');
      }
    } catch (e, s) {
      logger.e('$_tag cleaning up the files of purged records failed', e, s);
    }
    return deleted;
  }

  /// Deletes every top-level file in Documents that no row refers to and is
  /// older than [sweepMinAge]. Runs at start-up, in the background; a call
  /// while a sweep runs joins it. Returns how many files were deleted; never
  /// throws.
  Future<int> sweep() =>
      _sweeping ??= _sweep().whenComplete(() => _sweeping = null);

  Future<int> _sweep() async {
    var deleted = 0;
    try {
      final root = await _usableRoot('sweep');
      if (root == null) return 0;
      // Only a shortcut: a referenced file is skipped without a
      // transaction. Whether a file goes is decided again inside one.
      final referenced = await _references.referencedBasenames();
      for (final entry in await _topLevelEntries(root)) {
        if (entry is! File) continue;
        final name = p.basename(entry.path);
        if (isProtectedName(name)) continue;
        if (referenced.contains(name.toLowerCase())) continue;
        if (!await _isOldEnough(entry.path)) continue;
        if (await _deleteIfUnreferenced(root, name, checkAge: true)) {
          deleted++;
        }
      }
      logger.i('$_tag sweep deleted $deleted unreferenced files');
    } catch (e, s) {
      logger.e('$_tag sweep failed', e, s);
    }
    return deleted;
  }

  /// Checks and deletes `root/name` in one transaction.
  Future<bool> _deleteIfUnreferenced(
    String root,
    String name, {
    required bool checkAge,
  }) async {
    final path = p.join(root, name);
    try {
      return await _db.transaction(() async {
        final type = await FileSystemEntity.type(path, followLinks: false);
        if (type != FileSystemEntityType.file) return false;
        if (checkAge && !await _isOldEnough(path)) return false;
        if (await _references.isReferenced(name)) return false;
        await File(path).delete();
        logger.i('$_tag deleted $name');
        return true;
      });
    } catch (e, s) {
      logger.e('$_tag deleting $name failed', e, s);
      return false;
    }
  }

  Future<bool> _isOldEnough(String path) async {
    final stat = await FileStat.stat(path);
    final newest = stat.modified.isAfter(stat.changed)
        ? stat.modified
        : stat.changed;
    return _now().difference(newest) > sweepMinAge;
  }

  /// The documents directory, or null when nothing may be deleted there.
  Future<String?> _usableRoot(String what) async {
    if (!supportedPlatforms.contains(_operatingSystem)) {
      logger.i('$_tag no $what on $_operatingSystem');
      return null;
    }
    final root = p.normalize(await _paths.getDocumentsPath());
    final type = await FileSystemEntity.type(root, followLinks: false);
    if (type == FileSystemEntityType.link) {
      logger.w('$_tag no $what: the documents directory is a link');
      return null;
    }
    if (type != FileSystemEntityType.directory) {
      logger.w('$_tag no $what: the documents directory is missing');
      return null;
    }
    return root;
  }

  static Future<List<FileSystemEntity>> _topLevelEntries(String root) =>
      Directory(root).list(followLinks: false).toList();

  /// The top-level file names [url] can stand for, raw and decoded: its name
  /// when it is a bare name, a path directly in [root] or under an iOS
  /// container's Documents, or another device's absolute path (which this
  /// device resolves by name). A relative path into a subfolder names none.
  static Set<String> _topLevelNames(String url, String root) {
    const scheme = AttachmentReferences.scheme;
    if (!url.startsWith(scheme) && url.contains('://')) return const {};
    final raw = url.startsWith(scheme) ? url.substring(scheme.length) : url;
    final decoded = AttachmentRef(url).path;
    return {
      for (final path in {raw, decoded}) ?_topLevelName(path, root),
    };
  }

  static String? _topLevelName(String path, String root) {
    final unified = path.replaceAll(r'\', '/');
    if (!unified.contains('/')) return unified.isEmpty ? null : unified;
    final absolute = unified.startsWith('/') || _windowsDrive.hasMatch(unified);
    if (!absolute) return null;

    final rootPrefix = '${root.replaceAll(r'\', '/')}/'.toLowerCase();
    final String relative;
    if (unified.toLowerCase().startsWith(rootPrefix)) {
      relative = unified.substring(rootPrefix.length);
    } else if (_containerPattern.firstMatch(unified) case final match?) {
      relative = match.group(1)!;
    } else {
      relative = unified.split('/').last;
    }
    if (relative.isEmpty || relative.contains('/')) return null;
    return relative;
  }
}
