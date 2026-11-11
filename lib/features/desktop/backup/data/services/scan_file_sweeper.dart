import 'dart:convert';
import 'dart:io';

import 'package:health_wallet/core/data/local/app_database.dart';
import 'package:health_wallet/core/services/path_resolver.dart';
import 'package:health_wallet/core/services/temp_file_sweeper.dart';
import 'package:health_wallet/core/utils/logger.dart';
import 'package:injectable/injectable.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Deletes the working files of scan sessions that no longer exist: the
/// imported files in `imports/` and the page images and page maps in
/// [TempFileSweeper.ocrCacheDirName].
///
/// Deleting a session deletes its files (`ProcessingRepositoryImpl
/// .deleteProcessingSession`), but a backup restore replaces
/// `processing_sessions` with the backup's in SQL and leaves the files of the
/// sessions it drops. This sweep, at start-up, deletes them once nothing
/// needs them:
/// - no session of this database nor of a kept safety copy ([sweep]'s
///   `keepSessionsOf`) refers to them, through its file paths or its page
///   map (whose original files and page images it keeps), so restoring a
///   safety copy still finds its scans;
/// - they were last modified more than [minAge] ago, so a file whose session
///   isn't written yet is kept.
///
/// Only top-level regular files of `imports/`, `<session id>.pages.json`
/// page maps, and the page images and cache metadata of the PDFs those
/// sessions rendered are deleted. A page map of a kept session that can't be
/// read, or a safety copy that can't be read, stops the sweep: nothing is
/// deleted then.
@lazySingleton
class ScanFileSweeper {
  ScanFileSweeper(this._database, this._pathResolver);

  final AppDatabase _database;
  final PathResolver _pathResolver;

  /// The folder in the app's documents directory where imported files go.
  static const importsDirName = 'imports';

  /// How long a file must have been left alone before it can go.
  static const minAge = Duration(days: 1);

  /// The resolutions the PDF pages are rendered at: the preview's and OCR's.
  static const _renderDpis = [72.0, 200.0];

  /// Deletes the files of the sessions neither this database nor the
  /// databases at [keepSessionsOf] (kept safety copies) hold, and returns how
  /// many imported files and page maps it deleted. Never throws.
  Future<int> sweep({
    Iterable<String> keepSessionsOf = const [],
    DateTime? now,
  }) async {
    final cutoff = (now ?? DateTime.now()).subtract(minAge);
    try {
      final appDocs = (await getApplicationDocumentsDirectory()).path;
      final cache = Directory(p.join(appDocs, TempFileSweeper.ocrCacheDirName));

      final sessions = await _sessionsOf(keepSessionsOf);
      if (sessions == null) return 0;
      final kept = await _keptBy(sessions, cache);
      if (kept == null) return 0;

      final dropKeys = <String>{};
      var deleted = 0;

      final imports = Directory(p.join(appDocs, importsDirName));
      for (final file in await _topLevelFiles(imports)) {
        final path = p.normalize(file.path);
        if (kept.paths.contains(path)) continue;
        final stat = await file.stat();
        if (!stat.modified.isBefore(cutoff)) continue;
        // The page images rendered from it, as the converter names them.
        final stored = '${imports.path}/${p.basename(file.path)}';
        for (final dpi in _renderDpis) {
          dropKeys.add(
            TempFileSweeper.pdfPageCacheKey(
              stored,
              stat.size,
              stat.modified,
              dpi,
            ),
          );
        }
        if (await _delete(file)) deleted++;
      }

      for (final file in await _topLevelFiles(cache)) {
        final id = TempFileSweeper.sessionIdOfPageMap(p.basename(file.path));
        if (id == null || kept.ids.contains(id)) continue;
        if (!(await file.stat()).modified.isBefore(cutoff)) continue;
        final map = await _readPageMap(file);
        if (map != null) dropKeys.addAll(map.keys);
        if (await _delete(file)) deleted++;
      }

      dropKeys.removeAll(kept.keys);
      await _deleteCacheEntries(cache, dropKeys);
      if (deleted > 0) {
        logger.i('[ScanFiles] deleted $deleted files of removed scans');
      }
      return deleted;
    } catch (e, s) {
      logger.e('[ScanFiles] sweeping the files of removed scans failed', e, s);
      return 0;
    }
  }

  /// Every session (id and stored file paths) of this database and of the
  /// databases at [others], or null when one can't be read.
  Future<List<({String id, List<String> files})>?> _sessionsOf(
    Iterable<String> others,
  ) async {
    final sessions = <({String id, List<String> files})>[];
    Future<void> read(String schema) async {
      final rows = await _database
          .customSelect(
            'SELECT id, file_paths FROM $schema.processing_sessions',
          )
          .get();
      for (final row in rows) {
        final raw = row.data['file_paths'];
        final files = raw is String && raw.isNotEmpty
            ? (jsonDecode(raw) as List).cast<String>()
            : const <String>[];
        sessions.add((id: row.data['id'] as String, files: files));
      }
    }

    try {
      await read('main');
      for (final path in others) {
        // ATTACH would create a missing one; without its `.db` a backup
        // can't be restored anyway.
        if (!await File(path).exists()) continue;
        await _database.customStatement('ATTACH DATABASE ? AS scan_keep', [
          path,
        ]);
        try {
          await read('scan_keep');
        } finally {
          await _database.customStatement('DETACH DATABASE scan_keep');
        }
      }
      return sessions;
    } catch (e, s) {
      logger.w(
        '[ScanFiles] could not read the scans to keep; none deleted',
        e,
        s,
      );
      return null;
    }
  }

  /// What [sessions] still use: their ids, their files and the originals
  /// their page maps name (absolute, normalised), and the cache keys of
  /// their page images. Null when a page map can't be read.
  Future<({Set<String> ids, Set<String> paths, Set<String> keys})?> _keptBy(
    List<({String id, List<String> files})> sessions,
    Directory cache,
  ) async {
    final ids = <String>{};
    final paths = <String>{};
    final keys = <String>{};
    for (final session in sessions) {
      ids.add(session.id);
      final stored = [...session.files];
      final mapFile = File(
        p.join(cache.path, TempFileSweeper.sessionPageMapName(session.id)),
      );
      if (await mapFile.exists()) {
        final map = await _readPageMap(mapFile);
        if (map == null) {
          logger.w('[ScanFiles] a kept scan\'s page map is unreadable');
          return null;
        }
        stored.addAll(map.originals);
        keys.addAll(map.keys);
      }
      for (final path in stored) {
        paths.add(p.normalize(await _pathResolver.toAbsolute(path)));
        final key = _keyOf(p.basename(path));
        if (key != null) keys.add(key);
      }
    }
    return (ids: ids, paths: paths, keys: keys);
  }

  /// The original files and the page-image cache keys a page map records,
  /// or null when it can't be read.
  Future<({List<String> originals, Set<String> keys})?> _readPageMap(
    File file,
  ) async {
    try {
      final json = jsonDecode(await file.readAsString()) as Map;
      final pages = (json['pages'] as Map?) ?? const {};
      return (
        originals: [
          for (final source in pages.values) (source as Map)['file'] as String,
        ],
        keys: {
          ...((json['previewKeys'] as List?) ?? const []).cast<String>(),
          ...((json['ocrKeys'] as List?) ?? const []).cast<String>(),
          for (final name in pages.keys) ?_keyOf(name as String),
        },
      );
    } catch (e) {
      logger.w('[ScanFiles] unreadable page map', e);
      return null;
    }
  }

  static String? _keyOf(String name) =>
      TempFileSweeper.ocrCachePagePattern.firstMatch(name)?.group(1);

  /// Deletes the page images and cache metadata of [keys] in [cache].
  Future<void> _deleteCacheEntries(Directory cache, Set<String> keys) async {
    if (keys.isEmpty) return;
    for (final file in await _topLevelFiles(cache)) {
      final name = p.basename(file.path);
      final key =
          _keyOf(name) ??
          (name.endsWith('.json') ? name.substring(0, name.length - 5) : null);
      if (key != null && keys.contains(key)) await _delete(file);
    }
  }

  static Future<List<File>> _topLevelFiles(Directory dir) async {
    if (await FileSystemEntity.type(dir.path, followLinks: false) !=
        FileSystemEntityType.directory) {
      return const [];
    }
    return [
      await for (final entity in dir.list(followLinks: false))
        if (entity is File) entity,
    ];
  }

  static Future<bool> _delete(File file) async {
    try {
      await file.delete();
      return true;
    } on FileSystemException catch (e) {
      logger.w('[ScanFiles] could not delete a file of a removed scan', e);
      return false;
    }
  }
}
