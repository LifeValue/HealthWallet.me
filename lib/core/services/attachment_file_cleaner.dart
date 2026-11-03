import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:health_wallet/core/data/local/app_database.dart';
import 'package:health_wallet/core/services/attachment_references.dart';
import 'package:health_wallet/core/services/path_resolver.dart';
import 'package:health_wallet/core/utils/logger.dart';
import 'package:health_wallet/features/desktop/backup/data/services/backup_service.dart'
    show LegacyAttachmentFolders;
import 'package:injectable/injectable.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

/// Deletes attachment files that no row refers to any more. The only code
/// that deletes record attachment files: record and attachment deletes only
/// tombstone rows, so a deleted record keeps its files until its tombstone
/// is purged after 30 days ([deleteUnreferenced]), and files nothing refers
/// to are moved by the start-up [sweep] into the hidden quarantine folder
/// [trashDirName], where they are deleted after [trashRetention]. (Scan
/// sessions delete their own
/// working files in `imports/`.) Files of purged records inside a subfolder
/// are never deleted; that limit is accepted.
///
/// A file is deleted (or, by the sweep, quarantined) only when all of these
/// hold:
/// - it is a top-level regular file in [PathResolver.getDocumentsPath]: not
///   a symbolic link, not a dot-file, not the database (`db.sqlite*`), not a
///   `*.log` or `*.db` file, nothing in a subfolder;
/// - no `fhir_resource` row (live or deleted) and no scan session refers to
///   it, as [AttachmentReferences.isReferenced] finds (basenames raw and
///   decoded, ignoring case; an unreadable row is matched as raw text, so
///   the file is kept);
/// - it is more than [sweepMinAge] old for the [sweep], [purgeMinAge] for
///   [deleteUnreferenced], by the later of its modified and changed times
///   (every copy into Documents sets its modified time, so a file whose row
///   isn't written yet is fresh).
///
/// [deleteUnreferenced] also deletes, by the same rules, a purged record's
/// file that is top-level in a [LegacyAttachmentFolders] root (the Windows
/// Documents folder older versions saved attachments to). The sweep never
/// enters those folders.
///
/// Each file is checked and deleted inside one [AppDatabase.transaction], so
/// a sync write can't add a reference between the check and the delete.
/// Nothing is deleted on Linux, where the documents directory is the user's
/// own, or when the documents directory itself is a symbolic link.
@lazySingleton
class AttachmentFileCleaner {
  AttachmentFileCleaner(
    this._db,
    this._paths,
    this._references,
    this._legacyFolders,
  ) : _operatingSystem = Platform.operatingSystem,
      _now = DateTime.now,
      _legacyRoots = const [];

  /// A cleaner that acts as on [operatingSystem], reads the time from [now]
  /// and takes `legacyRoots` as the [LegacyAttachmentFolders] roots.
  @visibleForTesting
  AttachmentFileCleaner.forTesting(
    this._db,
    this._paths,
    this._references, {
    String? operatingSystem,
    DateTime Function()? now,
    this._legacyRoots = const [],
  }) : _operatingSystem = operatingSystem ?? Platform.operatingSystem,
       _now = now ?? DateTime.now,
       _legacyFolders = null;

  final AppDatabase _db;
  final PathResolver _paths;
  final AttachmentReferences _references;
  final String _operatingSystem;
  final DateTime Function() _now;
  final LegacyAttachmentFolders? _legacyFolders;
  final List<String> _legacyRoots;

  /// The platforms whose documents directory belongs to the app alone.
  static const supportedPlatforms = {'android', 'ios', 'macos', 'windows'};

  /// How old an unreferenced file must be before the [sweep] deletes it.
  static const sweepMinAge = Duration(days: 7);

  /// The hidden folder in Documents the [sweep] moves unreferenced files to.
  /// A dot-folder, so the sweep, the purge, backups and sync never take a
  /// file from it.
  static const trashDirName = '.trash';

  /// How long a quarantined file stays in [trashDirName], counted from the
  /// move.
  static const trashRetention = Duration(days: 30);

  /// How old a purged record's file must be before it is deleted: a file
  /// just written under the same name may not have its row yet. Younger
  /// files are left to the [sweep].
  static const purgeMinAge = Duration(hours: 1);

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
        lower.endsWith('.db') ||
        // Backup metadata (`<name>.db.meta.json` and its `.tmp`): a backup
        // folder can be the Documents root itself.
        lower.endsWith('.db.meta.json') ||
        lower.endsWith('.db.meta.json.tmp');
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
      final matched = <String>{};
      for (final entry in await _topLevelEntries(root)) {
        final name = p.basename(entry.path);
        if (wanted.contains(name.toLowerCase())) matched.add(name);
      }
      for (final name in matched) {
        if (isProtectedName(name)) continue;
        if (await _deleteIfUnreferenced(root, name, purgeMinAge)) deleted++;
      }
      deleted += await _deleteInLegacyRoots(urls);
      if (deleted > 0) {
        logger.i('$_tag deleted $deleted files of purged records');
      }
    } catch (e, s) {
      logger.e('$_tag cleaning up the files of purged records failed', e, s);
    }
    return deleted;
  }

  /// Moves every top-level file in Documents that no row refers to and is
  /// older than [sweepMinAge] into [trashDirName] (under a free name, its
  /// modified time set to now), then deletes the files there older than
  /// [trashRetention]. Runs at start-up, in the background; a call while a
  /// sweep runs joins it. Returns how many files were moved; never throws.
  Future<int> sweep() =>
      _sweeping ??= _sweep().whenComplete(() => _sweeping = null);

  Future<int> _sweep() async {
    var moved = 0;
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
        if (!await _isOldEnough(entry.path, sweepMinAge)) continue;
        if (await _quarantineIfUnreferenced(root, name)) moved++;
      }
      final expired = await _emptyTrash(root);
      logger.i(
        '$_tag sweep moved $moved unreferenced files to $trashDirName '
        'and deleted $expired expired ones',
      );
    } catch (e, s) {
      logger.e('$_tag sweep failed', e, s);
    }
    return moved;
  }

  /// Checks `root/name` and moves it into [trashDirName] in one transaction.
  Future<bool> _quarantineIfUnreferenced(String root, String name) async {
    final path = p.join(root, name);
    final label = _label(name);
    try {
      return await _db.transaction(() async {
        final type = await FileSystemEntity.type(path, followLinks: false);
        if (type != FileSystemEntityType.file) return false;
        if (!await _isOldEnough(path, sweepMinAge)) return false;
        if (await _references.isReferenced(name)) return false;
        final trash = await _trashDir(root, create: true);
        if (trash == null) return false;
        final moved = await File(path).rename(await _freeName(trash, name));
        await moved.setLastModified(_now());
        logger.d('$_tag moved file $label to $trashDirName');
        return true;
      });
    } catch (e, s) {
      logger.e('$_tag moving file $label to $trashDirName failed', e, s);
      return false;
    }
  }

  /// Deletes the top-level regular files in [trashDirName] older than
  /// [trashRetention]. Returns how many were deleted.
  Future<int> _emptyTrash(String root) async {
    final trash = await _trashDir(root, create: false);
    if (trash == null) return 0;
    var deleted = 0;
    for (final entry in await _topLevelEntries(trash)) {
      if (entry is! File) continue;
      final label = _label(p.basename(entry.path));
      try {
        final type = await FileSystemEntity.type(
          entry.path,
          followLinks: false,
        );
        if (type != FileSystemEntityType.file) continue;
        if (!await _isOldEnough(entry.path, trashRetention)) continue;
        await entry.delete();
        deleted++;
        logger.d('$_tag deleted expired file $label from $trashDirName');
      } catch (e, s) {
        logger.e('$_tag deleting expired file $label failed', e, s);
      }
    }
    return deleted;
  }

  /// `root/.trash` when it is a real directory (created when [create]), or
  /// null.
  Future<String?> _trashDir(String root, {required bool create}) async {
    final path = p.join(root, trashDirName);
    final type = await FileSystemEntity.type(path, followLinks: false);
    if (type == FileSystemEntityType.notFound && create) {
      await Directory(path).create();
      return path;
    }
    if (type == FileSystemEntityType.directory) return path;
    if (type != FileSystemEntityType.notFound) {
      logger.w('$_tag $trashDirName is not a folder, nothing quarantined');
    }
    return null;
  }

  /// A path in [dir] for [name] that no entry takes: [name], or the same name
  /// with a unique suffix.
  static Future<String> _freeName(String dir, String name) async {
    var candidate = p.join(dir, name);
    while (await FileSystemEntity.type(candidate, followLinks: false) !=
        FileSystemEntityType.notFound) {
      final dot = name.lastIndexOf('.');
      final stem = dot > 0 ? name.substring(0, dot) : name;
      final ext = dot > 0 ? name.substring(dot) : '';
      candidate = p.join(dir, '${stem}_${const Uuid().v4()}$ext');
    }
    return candidate;
  }

  /// Deletes the purged records' files that are top-level in a legacy
  /// attachment folder, by the same rules as in Documents.
  Future<int> _deleteInLegacyRoots(Set<String> urls) async {
    var deleted = 0;
    final roots = _legacyFolders == null
        ? _legacyRoots
        : await _legacyFolders.roots();
    for (final root in roots.map(p.normalize)) {
      final type = await FileSystemEntity.type(root, followLinks: false);
      if (type != FileSystemEntityType.directory) continue;
      final wanted = {
        for (final url in urls)
          for (final name in _namesInFolder(url, root)) name.toLowerCase(),
      };
      if (wanted.isEmpty) continue;
      for (final entry in await _topLevelEntries(root)) {
        final name = p.basename(entry.path);
        if (!wanted.contains(name.toLowerCase())) continue;
        if (isProtectedName(name)) continue;
        if (await _deleteIfUnreferenced(root, name, purgeMinAge)) deleted++;
      }
    }
    return deleted;
  }

  /// Checks and deletes `dir/name` in one transaction.
  Future<bool> _deleteIfUnreferenced(
    String dir,
    String name,
    Duration minAge,
  ) async {
    final path = p.join(dir, name);
    final label = _label(name);
    try {
      return await _db.transaction(() async {
        final type = await FileSystemEntity.type(path, followLinks: false);
        if (type != FileSystemEntityType.file) return false;
        if (!await _isOldEnough(path, minAge)) return false;
        if (await _references.isReferenced(name)) return false;
        await File(path).delete();
        logger.d('$_tag deleted file $label');
        return true;
      });
    } catch (e, s) {
      logger.e('$_tag deleting file $label failed', e, s);
      return false;
    }
  }

  /// A short hash standing for [name] in logs: file names often hold a
  /// diagnosis or a person's name.
  static String _label(String name) =>
      sha256.convert(utf8.encode(name)).toString().substring(0, 8);

  Future<bool> _isOldEnough(String path, Duration minAge) async {
    final stat = await FileStat.stat(path);
    final newest = stat.modified.isAfter(stat.changed)
        ? stat.modified
        : stat.changed;
    return _now().difference(newest) > minAge;
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

  /// The names [url] stands for when it is an absolute path directly in
  /// [folder], raw and decoded.
  static Set<String> _namesInFolder(String url, String folder) {
    const scheme = AttachmentReferences.scheme;
    if (!url.startsWith(scheme)) return const {};
    final raw = url.substring(scheme.length);
    final prefix = '${folder.replaceAll(r'\', '/')}/'.toLowerCase();
    return {
      for (final path in {raw, AttachmentRef(url).path})
        if (path.replaceAll(r'\', '/') case final unified
            when unified.toLowerCase().startsWith(prefix) &&
                unified.length > prefix.length &&
                !unified.substring(prefix.length).contains('/'))
          unified.substring(prefix.length),
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
