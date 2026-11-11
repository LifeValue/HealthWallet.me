import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:health_wallet/core/config/constants/shared_prefs_constants.dart';
import 'package:health_wallet/core/data/local/app_database.dart';
import 'package:health_wallet/core/services/attachment_files_lock.dart';
import 'package:health_wallet/core/services/attachment_references.dart';
import 'package:health_wallet/core/services/folder_access_service.dart';
import 'package:health_wallet/core/services/path_resolver.dart';
import 'package:health_wallet/core/utils/logger.dart';
import 'package:health_wallet/features/desktop/backup/data/services/scan_file_sweeper.dart';
import 'package:health_wallet/features/desktop/backup/domain/entity/backup_entry.dart';
import 'package:health_wallet/features/desktop/backup/domain/entity/restore_result.dart';
import 'package:health_wallet/features/desktop/backup/domain/utils/safety_copy_retention.dart';
import 'package:health_wallet/features/desktop/lww_sync/data/services/attachment_sync_service.dart';
import 'package:injectable/injectable.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Desktop backups: `<name>.db` (a `VACUUM INTO` copy of the database),
/// `<name>.files/` (every attachment file its records refer to) and
/// `<name>.db.meta.json`, written last as the commit marker. A restore makes
/// the backup the current state on this device and, through sync, on the
/// paired phone (see `restoreFromFile`).
@lazySingleton
class BackupService {
  final AppDatabase _database;
  final FolderAccessService _folderAccess;
  final PathResolver _pathResolver;
  final AttachmentReferences _references;
  final AttachmentSyncService _attachments;
  final LegacyAttachmentFolders _legacyFolders;

  BackupService(
    this._database,
    this._folderAccess,
    this._pathResolver,
    this._references,
    this._attachments,
    this._legacyFolders, {
    AttachmentFilesLock? filesLock,
    ScanFileSweeper? scanFiles,
  }) : _filesLock = filesLock ?? AttachmentFilesLock(),
       _scanFiles = scanFiles ?? ScanFileSweeper(_database, _pathResolver);

  /// Held from placing a restore's files to its commit, so the attachment
  /// cleaner never deletes a file the restore decided to reuse.
  final AttachmentFilesLock _filesLock;

  /// Deletes the files of the scans a restore removed (see
  /// [removeDroppedScanFiles]).
  final ScanFileSweeper _scanFiles;

  /// The tables that sync with the phone, parents first. A restore makes
  /// them the backup's state at a fresh stamp (see [restoreFromFile]).
  static const _syncedTables = ['fhir_resource', 'sources', 'record_notes'];

  /// Never restored: its entries describe this device's own writes.
  static const _localOnlyTables = {'sync_outbox'};

  static const _stagingPrefix = '.restore-';
  static const _metaSuffix = '.meta.json';

  /// How long the parts of a backup without metadata must have been left
  /// alone before [removeBackupLeftovers] takes them for an interrupted one.
  static const leftoverMinAge = Duration(minutes: 10);

  /// A part of a backup as [createSnapshot] names it: `<prefix><ms>` and
  /// `.db`, `.files` or the metadata's `.tmp`. Group 1 is the base name.
  static final _backupPart = RegExp(
    r'^(.*_\d{13})(\.db|\.files|\.db\.meta\.json\.tmp)$',
  );

  /// The base names of the backups this run is writing.
  final _writing = <String>{};

  final _changes = StreamController<void>.broadcast();

  /// The last [deleteExpiredSafetyCopies] run queued, so runs never overlap.
  Future<void> _expiryQueue = Future.value();

  /// Fires after anything that can move the next safety copy expiry: a
  /// backup written, a backup deleted (expired copies included), the folder
  /// or the retention changed. `SafetyCopyExpiryScheduler` listens.
  Stream<void> get changes => _changes.stream;

  void _changed() {
    if (!_changes.isClosed) _changes.add(null);
  }

  /// Whether this run has already reopened the chosen folder from its
  /// bookmark (macOS only; see [FolderAccessService]).
  bool _folderAccessRestored = false;

  /// Reopens the chosen folder after a restart, once per run, so the
  /// sandboxed macOS app can list and write backups there again.
  Future<void> _restoreFolderAccess(SharedPreferences prefs) async {
    if (_folderAccessRestored) return;
    _folderAccessRestored = true;
    final bookmark = prefs.getString(
      SharedPrefsConstants.backupDirectoryBookmark,
    );
    if (bookmark == null) return;
    final current = await _folderAccess.restore(bookmark);
    if (current != null && current != bookmark) {
      await prefs.setString(
        SharedPrefsConstants.backupDirectoryBookmark,
        current,
      );
    }
  }

  Future<String> _defaultBackupPath() async {
    final home =
        Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '';
    return p.join(home, 'Documents', 'HealthWallet', 'Backups');
  }

  Future<bool> hasUserSelectedPath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(SharedPrefsConstants.backupDirectory);
  }

  Future<Directory> getBackupDirectory() async {
    final prefs = await SharedPreferences.getInstance();
    await _restoreFolderAccess(prefs);
    final customPath = prefs.getString(SharedPrefsConstants.backupDirectory);
    final dirPath = customPath ?? await _defaultBackupPath();
    final backupDir = Directory(dirPath);
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }
    return backupDir;
  }

  Future<String> getBackupPath() async {
    final prefs = await SharedPreferences.getInstance();
    final customPath = prefs.getString(SharedPrefsConstants.backupDirectory);
    return customPath ?? await _defaultBackupPath();
  }

  /// Saves the folder the user chose, with a bookmark on macOS so it stays
  /// accessible after a restart. Call it right after the user picks it.
  Future<void> setBackupDirectory(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(SharedPrefsConstants.backupDirectory, path);
    final bookmark = await _folderAccess.bookmarkFor(path);
    if (bookmark != null) {
      await prefs.setString(
        SharedPrefsConstants.backupDirectoryBookmark,
        bookmark,
      );
    } else {
      await prefs.remove(SharedPrefsConstants.backupDirectoryBookmark);
    }
    _folderAccessRestored = true;
    _changed();
  }

  Future<void> resetBackupDirectory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(SharedPrefsConstants.backupDirectory);
    await prefs.remove(SharedPrefsConstants.backupDirectoryBookmark);
    _changed();
  }

  /// The whole days a "Before restore" copy is kept, as set on this desktop:
  /// [SafetyCopyRetention.defaultDays] when nothing is stored or the stored
  /// value isn't a valid number of days.
  Future<int> getSafetyCopyRetentionDays() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.get(SharedPrefsConstants.safetyCopyRetentionDays);
    if (stored is int && SafetyCopyRetention.isValid(stored)) return stored;
    if (stored != null) {
      logger.w(
        '[Backup] ignored the invalid safety copy retention $stored; '
        'keeping copies ${SafetyCopyRetention.defaultDays} days',
      );
    }
    return SafetyCopyRetention.defaultDays;
  }

  /// Saves how many whole days "Before restore" copies are kept on this
  /// desktop. It deletes nothing itself: [changes] fires, and the scheduler
  /// then deletes the copies older than that at once. Throws an
  /// [ArgumentError] for a value outside [SafetyCopyRetention.minDays] to
  /// [SafetyCopyRetention.maxDays], and a [StateError] when it isn't saved.
  Future<void> setSafetyCopyRetentionDays(int days) async {
    if (!SafetyCopyRetention.isValid(days)) {
      throw ArgumentError.value(
        days,
        'days',
        'must be from ${SafetyCopyRetention.minDays} to '
            '${SafetyCopyRetention.maxDays}',
      );
    }
    final prefs = await SharedPreferences.getInstance();
    final saved = await prefs.setInt(
      SharedPrefsConstants.safetyCopyRetentionDays,
      days,
    );
    if (!saved) throw StateError('The safety copy retention was not saved');
    _changed();
  }

  // ---------------------------------------------------------------------------
  // Create

  /// Writes a backup of the database and every attachment file its records
  /// (live and deleted) refer to: the `.db`, then `.files/`, then the
  /// metadata. A failure removes what was written and rethrows. [name] is
  /// shown as given; the file name keeps its letters (any script), digits
  /// and the date's punctuation. With [isSafetyCopy] it is the automatic
  /// "Before restore" copy, deleted after [getSafetyCopyRetentionDays] days.
  /// Nothing is sent to the phone. The expired safety copies it deletes
  /// afterwards never include [keepId]: the backup about to be restored,
  /// which may be an old safety copy itself.
  Future<BackupEntry> createSnapshot({
    String? name,
    bool isSafetyCopy = false,
    String? keepId,
  }) async {
    final backupDir = await getBackupDirectory();
    final displayName = name?.trim() ?? '';
    final stem = _fileStem(displayName);
    final prefix = stem.isNotEmpty ? '${stem}_' : 'healthwallet_backup_';

    // A fresh id, so a failure never removes another backup's files.
    var timestamp = DateTime.now();
    late String base;
    while (true) {
      base = p.join(
        backupDir.path,
        '$prefix${timestamp.millisecondsSinceEpoch}',
      );
      if (!await _exists('$base.db') &&
          !await _exists('$base.files') &&
          !await _exists('$base.db$_metaSuffix')) {
        break;
      }
      timestamp = timestamp.add(const Duration(milliseconds: 1));
    }
    final dbPath = '$base.db';
    final filesDir = Directory(_filesPathFor(dbPath));

    final BackupEntry entry;
    _writing.add(p.basename(base));
    try {
      await _database.customStatement('VACUUM INTO ?', [dbPath]);
      final snapshot = await _readSnapshot(dbPath);
      final (files, missing) = await _copyAttachments(snapshot.raws, filesDir);
      final dbFile = File(dbPath);
      entry = BackupEntry(
        id: timestamp.millisecondsSinceEpoch.toString(),
        timestamp: timestamp,
        sizeBytes: await dbFile.length(),
        recordCount: snapshot.recordCount,
        checksum: await _sha256(dbFile),
        filePath: dbPath,
        name: displayName,
        formatVersion: BackupEntry.filesFormat,
        files: files,
        missing: missing,
        isSafetyCopy: isSafetyCopy,
      );
      await saveBackupMetadata(entry);
    } catch (e, s) {
      logger.e('[Backup] creating $dbPath failed; removing it', e, s);
      await _deleteQuietly(File('$dbPath$_metaSuffix.tmp'));
      await _deleteQuietly(File('$dbPath$_metaSuffix'));
      await _deleteQuietly(File(dbPath));
      await _deleteQuietly(filesDir);
      rethrow;
    } finally {
      _writing.remove(p.basename(base));
    }

    if (entry.missing.isNotEmpty) {
      logger.w(
        '[Backup] ${entry.missing.length} attachments were not on this '
        'device and are not in the backup',
      );
    }
    await deleteExpiredSafetyCopies(keep: {?keepId});
    _changed();
    return entry;
  }

  /// The records' raw JSON and the live record count, read from the copy so
  /// they match it exactly.
  Future<({List<String> raws, int recordCount})> _readSnapshot(
    String dbPath,
  ) async {
    await _detachIfAttached('backup_snapshot');
    await _database.customStatement('ATTACH DATABASE ? AS backup_snapshot', [
      dbPath,
    ]);
    try {
      final rows = await _database
          .customSelect(
            'SELECT resource_raw FROM backup_snapshot.fhir_resource',
          )
          .get();
      final count = await _database
          .customSelect(
            'SELECT COUNT(*) AS c FROM backup_snapshot.fhir_resource '
            'WHERE deleted_at IS NULL',
          )
          .getSingle();
      return (
        raws: [
          for (final r in rows)
            if (r.data['resource_raw'] is String)
              r.data['resource_raw'] as String,
        ],
        recordCount: count.data['c'] as int,
      );
    } finally {
      await _database.customStatement('DETACH DATABASE backup_snapshot');
    }
  }

  /// Copies each file the records refer to into [filesDir] once, under a
  /// free name, and lists the urls whose file isn't on this device.
  Future<(List<BackupFile>, List<String>)> _copyAttachments(
    List<String> raws,
    Directory filesDir,
  ) async {
    final sources = <String, ({File file, Set<String> paths})>{};
    final missing = <String>{};
    for (final raw in raws) {
      final refs = await _references.fromResourceRaw(
        raw,
        mode: OnUnparseable.skip,
      );
      for (final ref in refs) {
        final file = await _resolveAttachment(ref.path);
        if (file == null) {
          missing.add(ref.url);
          continue;
        }
        (sources[file.path] ??= (file: file, paths: <String>{})).paths.add(
          ref.path,
        );
      }
    }

    final files = <BackupFile>[];
    final taken = <String>{};
    for (final source in sources.values) {
      if (files.isEmpty) await filesDir.create(recursive: true);
      final name = await _freeName(
        filesDir.path,
        _safeFileName(p.basename(source.file.path)),
        taken,
      );
      final copy = File(p.join(filesDir.path, name));
      try {
        await source.file.copy(copy.path);
      } on FileSystemException catch (e) {
        // Removed, locked or unreadable: one file must not stop the backup
        // (or the safety copy a restore needs).
        logger.w('[Backup] ${source.file.path} could not be backed up', e);
        await _deleteQuietly(copy);
        missing.addAll(source.paths.map((path) => 'file://$path'));
        continue;
      }
      taken.add(name.toLowerCase());
      files.add(
        BackupFile(
          name: name,
          sourcePaths: source.paths.toList(),
          sha256: await _sha256(copy),
          size: await copy.length(),
        ),
      );
    }
    return (files, missing.toList());
  }

  // ---------------------------------------------------------------------------
  // Restore

  /// Makes the backup at [backupPath] (its `.db`) the current state, and
  /// returns what happened to its files. It throws only when nothing was
  /// committed: the database is then unchanged and every file it added is
  /// removed again. Errors after the commit are logged.
  ///
  /// Point in time, for the synced tables, in one transaction with a stamp
  /// `S` later than every row on either side (and the clock):
  /// 1. Current rows whose key isn't in the backup are kept aside.
  /// 2. Every table is emptied, children first.
  /// 3. The backup's rows are copied in with `updated_at = S`; its
  ///    tombstones also get `deleted_at = S`, so they reach the phone
  ///    before the 30-day purge.
  /// 4. The rows kept aside go back as tombstones stamped at least `S`
  ///    (notes without their per-device `id`).
  ///
  /// Every write lands in the outbox, so the next sync makes the phone the
  /// same; the caller sends `LwwSyncEvent.localChanged()` and must not reset
  /// the peer state, which would prune the outbox. `sync_outbox` itself is
  /// never restored; other local tables are replaced by the backup's.
  ///
  /// Files (format 2): each is copied into `Documents/.restore-<id>/`,
  /// checked against its SHA-256, and moved into Documents. Nothing current
  /// is deleted or overwritten: a file already there with the same content
  /// is reused, one with other content keeps its name and the backup's goes
  /// under a free name, with the restored records repointed to it. A
  /// missing or damaged file is counted in [RestoreResult.filesNotRestored]
  /// and the rest is restored. A database-only backup keeps every current
  /// file.
  Future<RestoreResult> restoreFromFile(String backupPath) async {
    final backupFile = File(backupPath);
    if (!await backupFile.exists()) {
      throw StateError('Backup file not found: $backupPath');
    }
    await removeRestoreLeftovers();

    final entry = await _readMetadata(backupPath);
    if (entry != null && entry.checksum != await _sha256(backupFile)) {
      throw StateError('Backup checksum mismatch — file may be corrupted');
    }

    // A file already in Documents may be reused, and only the commit makes
    // the restored rows refer to it: the cleaner must not run until then.
    return _filesLock.exclusive(() => _restore(backupPath, entry));
  }

  Future<RestoreResult> _restore(String backupPath, BackupEntry? entry) async {
    final docs = await _pathResolver.getDocumentsPath();
    final staging = Directory(
      p.join(
        docs,
        '$_stagingPrefix${DateTime.now().millisecondsSinceEpoch}'
        '_${const Uuid().v4().substring(0, 8)}',
      ),
    );
    final added = <File>[];
    var plan = _FilePlan.none;
    var committed = false;
    try {
      if (entry != null && entry.hasFiles) {
        plan = await _placeFiles(entry, backupPath, staging, docs, added);
      }
      await _restoreRows(backupPath, plan, onCommitted: () => committed = true);
    } catch (e, s) {
      if (!committed) {
        logger.e('[Backup] restore failed; the data was not changed', e, s);
        for (final file in added) {
          await _deleteQuietly(file);
        }
        rethrow;
      }
      // The restore stands; what failed after it is only logged.
      logger.e('[Backup] error after the restore committed', e, s);
    } finally {
      await _deleteQuietly(staging);
    }
    return RestoreResult(
      hadFiles: entry?.hasFiles ?? false,
      filesAdded: plan.added,
      filesAlreadyPresent: plan.alreadyPresent,
      filesNotRestored: plan.notRestored,
      filesMissingFromBackup: entry?.missing.length ?? 0,
    );
  }

  /// The scans on this device not saved yet, which a restore removes (it
  /// replaces `processing_sessions` with the backup's): every session,
  /// whatever its status, since saving one deletes it.
  Future<int> countUnsavedScans() async {
    final row = await _database
        .customSelect(
          'SELECT COUNT(*) AS c FROM processing_sessions',
          readsFrom: {_database.processingSessions},
        )
        .getSingle();
    return row.data['c'] as int;
  }

  /// Stages, checks and moves the backup's files into [docs], and works out
  /// which restored attachment urls must point at another name.
  Future<_FilePlan> _placeFiles(
    BackupEntry entry,
    String backupPath,
    Directory staging,
    String docs,
    List<File> added,
  ) async {
    final filesDir = _filesPathFor(backupPath);
    final hashes = <String, String>{};
    Future<String> hashOf(File file) async =>
        hashes[file.path] ??= await _sha256(file);

    var notRestored = 0;
    var addedCount = 0;
    var alreadyPresent = 0;
    final destinations = <BackupFile, String?>{};

    await staging.create(recursive: true);
    for (final file in entry.files) {
      final staged = await _stage(file, filesDir, staging);
      if (staged == null) {
        notRestored++;
        continue;
      }

      // Where the restored records already find the same content.
      var present = false;
      for (final path in file.sourcePaths) {
        final current = await _resolveAttachment(path);
        if (current != null && await hashOf(current) == file.sha256) {
          present = true;
          break;
        }
      }
      if (present) {
        alreadyPresent++;
        destinations[file] = null;
        continue;
      }

      final named = File(p.join(docs, file.name));
      final type = await FileSystemEntity.type(named.path, followLinks: false);
      if (type == FileSystemEntityType.file &&
          await hashOf(named) == file.sha256) {
        alreadyPresent++;
        destinations[file] = file.name;
        continue;
      }
      final name = type == FileSystemEntityType.notFound
          ? file.name
          : await _freeName(docs, file.name, const {});
      final target = await staged.rename(p.join(docs, name));
      added.add(target);
      try {
        await target.setLastModified(DateTime.now());
      } on FileSystemException catch (e) {
        logger.w('[Backup] could not touch ${target.path}', e);
      }
      hashes[target.path] = file.sha256;
      addedCount++;
      destinations[file] = name;
    }

    return _FilePlan(
      files: entry.files,
      missing: {for (final url in entry.missing) AttachmentRef(url).path},
      destinations: destinations,
      added: addedCount,
      alreadyPresent: alreadyPresent,
      notRestored: notRestored,
      resolvesTo: (path) async {
        final current = await _resolveAttachment(path);
        return current == null ? null : await hashOf(current);
      },
    );
  }

  /// [file] copied from the backup into [staging] and checked, or null when
  /// it is missing or damaged.
  Future<File?> _stage(
    BackupFile file,
    String filesDir,
    Directory staging,
  ) async {
    if (!_isPlainName(file.name)) {
      logger.w('[Backup] ignored a backup file named ${file.name}');
      return null;
    }
    final source = File(p.join(filesDir, file.name));
    final type = await FileSystemEntity.type(source.path, followLinks: false);
    if (type != FileSystemEntityType.file) {
      logger.w('[Backup] ${file.name} is missing from the backup');
      return null;
    }
    final staged = File(p.join(staging.path, file.name));
    try {
      await source.copy(staged.path);
      if (await _sha256(staged) != file.sha256) {
        logger.w('[Backup] ${file.name} is damaged (checksum mismatch)');
        await _deleteQuietly(staged);
        return null;
      }
      return staged;
    } on FileSystemException catch (e) {
      logger.w('[Backup] ${file.name} could not be read', e);
      await _deleteQuietly(staged);
      return null;
    }
  }

  Future<void> _restoreRows(
    String backupPath,
    _FilePlan plan, {
    required void Function() onCommitted,
  }) async {
    await _database.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');

    // SQLite refuses ATTACH inside a transaction, so attach first, copy in
    // one transaction (all or nothing), and always detach afterwards.
    await _detachIfAttached('backup_db');
    await _database.customStatement('ATTACH DATABASE ? AS backup_db', [
      backupPath,
    ]);
    try {
      final mainTables = await _tableNames('main');
      final backupTables = await _tableNames('backup_db');
      final tables = _database.allTables
          .map((t) => t.actualTableName)
          .where((t) => !_localOnlyTables.contains(t))
          .where((t) => mainTables.contains(t) && backupTables.contains(t))
          .toList();
      final columns = {
        for (final t in tables)
          t: (
            main: await _columnNames('main', t),
            backup: (await _columnNames('backup_db', t)).toSet(),
          ),
      };
      final synced = tables.where(_syncedTables.contains).toList();
      final rewrites = await _attachmentRewrites(plan, tables);

      await _database.transaction(() async {
        // Foreign keys are checked once, at commit, against the restored
        // data, in case a backup holds a row whose parent comes later.
        await _database.customStatement('PRAGMA defer_foreign_keys = ON');
        final stamp = await _restoreStamp(synced, columns);

        for (final t in synced) {
          await _database.customStatement(
            'DROP TABLE IF EXISTS temp."${_keep(t)}"',
          );
          await _database.customStatement(
            'CREATE TEMP TABLE "${_keep(t)}" AS SELECT * FROM main."$t" '
            'WHERE ${_key(t, hasUuid: true)} NOT IN ('
            'SELECT ${_key(t, hasUuid: columns[t]!.backup.contains('uuid'))} '
            'FROM backup_db."$t")',
          );
        }

        // Tables are declared parents first: delete in reverse so no row is
        // left pointing at a deleted one.
        for (final t in tables.reversed) {
          await _database.customStatement('DELETE FROM main."$t"');
        }

        for (final t in tables) {
          final (:main, :backup) = columns[t]!;
          final isSynced = synced.contains(t);
          final insert = <String>[];
          final select = <String>[];
          for (final c in main) {
            final expr = isSynced
                ? _restoredColumn(t, c, backup, stamp)
                : (backup.contains(c) ? '"$c"' : null);
            if (expr == null) continue;
            insert.add('"$c"');
            select.add(expr);
          }
          await _database.customStatement(
            'INSERT INTO main."$t" (${insert.join(', ')}) '
            'SELECT ${select.join(', ')} FROM backup_db."$t"',
          );
        }

        for (final t in synced) {
          final insert = <String>[];
          final select = <String>[];
          for (final c in columns[t]!.main) {
            final expr = _tombstoneColumn(t, c, stamp);
            if (expr == null) continue;
            insert.add('"$c"');
            select.add(expr);
          }
          await _database.customStatement(
            'INSERT INTO main."$t" (${insert.join(', ')}) '
            'SELECT ${select.join(', ')} FROM temp."${_keep(t)}"',
          );
          await _database.customStatement('DROP TABLE temp."${_keep(t)}"');
        }

        // The url is device-local: the row keeps the restore stamp, which
        // the update trigger would otherwise move.
        for (final MapEntry(key: id, value: raw) in rewrites.entries) {
          await _database.customStatement(
            'UPDATE main.fhir_resource SET resource_raw = ? WHERE id = ?',
            [raw, id],
          );
          await _database.customStatement(
            'UPDATE main.fhir_resource SET updated_at = ? '
            'WHERE id = ? AND (updated_at IS NULL OR updated_at != ?)',
            [stamp, id, stamp],
          );
        }
      });
      onCommitted();
      logger.i(
        '[Backup] restored ${p.basename(backupPath)}; '
        '${rewrites.length} records repointed to restored files',
      );
    } finally {
      // Never thrown: after a commit the restore stands, and before it the
      // first error is the one that matters. The next restore detaches it.
      try {
        await _database.customStatement('DETACH DATABASE backup_db');
      } catch (e, s) {
        logger.e('[Backup] could not detach the backup', e, s);
      }
    }
    try {
      _database.markTablesUpdated(_database.allTables);
    } catch (e, s) {
      logger.w('[Backup] could not notify listeners of the restore', e, s);
    }
  }

  /// `S`: later than the clock and than every stamp on either side, so the
  /// restored rows win on the phone even when its clock runs ahead.
  Future<int> _restoreStamp(
    List<String> synced,
    Map<String, ({List<String> main, Set<String> backup})> columns,
  ) async {
    var latest = 0;
    for (final t in synced) {
      for (final schema in ['main', 'backup_db']) {
        final has = schema == 'main'
            ? columns[t]!.main.contains('updated_at')
            : columns[t]!.backup.contains('updated_at');
        if (!has) continue;
        final row = await _database
            .customSelect(
              "SELECT MAX(CASE WHEN typeof(updated_at) IN ('integer', 'real') "
              'THEN updated_at END) AS m FROM $schema."$t"',
            )
            .getSingle();
        final value = (row.data['m'] as num?)?.toInt() ?? 0;
        if (value > latest) latest = value;
      }
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    return now > latest + 1 ? now : latest + 1;
  }

  /// The SELECT expression for column [c] of a synced backup row.
  static String? _restoredColumn(
    String table,
    String c,
    Set<String> backup,
    int stamp,
  ) {
    if (c == 'updated_at') return '$stamp';
    if (c == 'deleted_at') {
      return backup.contains('deleted_at')
          ? 'CASE WHEN deleted_at IS NULL THEN NULL ELSE $stamp END'
          : 'NULL';
    }
    if (table == 'record_notes' && c == 'uuid') {
      return _key(table, hasUuid: backup.contains('uuid'));
    }
    return backup.contains(c) ? '"$c"' : null;
  }

  /// The SELECT expression for column [c] of a current row that goes back
  /// as a tombstone.
  static String? _tombstoneColumn(String table, String c, int stamp) {
    final isNote = table == 'record_notes';
    // A note's id counts per device; the backup's notes may use it.
    if (isNote && c == 'id') return null;
    if (c == 'updated_at' || c == 'deleted_at') {
      return 'MAX($stamp, COALESCE(CASE WHEN typeof(updated_at) IN '
          "('integer', 'real') THEN updated_at END, 0) + 1)";
    }
    if (isNote && c == 'uuid') return _key(table, hasUuid: true);
    return '"$c"';
  }

  /// A row's sync key, as `LwwSyncService.keyColumn`, with the legacy key of
  /// a note that has no uuid.
  static String _key(String table, {required bool hasUuid}) {
    if (table != 'record_notes') return 'id';
    return hasUuid ? "COALESCE(uuid, 'legacy-' || id)" : "'legacy-' || id";
  }

  static String _keep(String table) => 'restore_keep_$table';

  /// The restored records whose attachment urls must point at a restored
  /// file's name: urls the backup listed for a file that went under another
  /// name, or that don't find that file's content where they point now.
  Future<Map<String, String>> _attachmentRewrites(
    _FilePlan plan,
    List<String> tables,
  ) async {
    if (!tables.contains('fhir_resource')) return const {};
    if (plan.destinations.values.every((d) => d == null)) return const {};

    // Only by the paths the backup's own rows store: the metadata comes from
    // the same snapshot (its checksum covers the `.db`), so every url the
    // backup copied a file for is listed there. Never by name: a url whose
    // file wasn't on the device (`missing`), or one the metadata doesn't
    // list, would take another record's file of the same name.
    final byPath = <String, BackupFile>{
      for (final file in plan.files)
        for (final path in file.sourcePaths) path: file,
    };
    BackupFile? fileFor(AttachmentRef ref) =>
        plan.missing.contains(ref.path) ? null : byPath[ref.path];

    final rows = await _database
        .customSelect('SELECT id, resource_raw FROM backup_db.fhir_resource')
        .get();
    final rewrites = <String, String>{};
    for (final row in rows) {
      final raw = row.data['resource_raw'];
      if (raw is! String) continue;
      final replacements = <String, String>{};
      for (final ref in await _references.fromResourceRaw(
        raw,
        mode: OnUnparseable.skip,
      )) {
        final file = fileFor(ref);
        final destination = file == null ? null : plan.destinations[file];
        if (file == null || destination == null) continue;
        if (await plan.resolvesTo(ref.path) == file.sha256) continue;
        replacements[ref.url] = 'file://${Uri.encodeComponent(destination)}';
      }
      if (replacements.isEmpty) continue;
      final rewritten = _references.rewriteUrls(
        raw,
        (ref) => replacements[ref.url],
      );
      if (rewritten != null) rewrites['${row.data['id']}'] = rewritten;
    }
    return rewrites;
  }

  /// Detaches [schema] when an earlier run left it attached.
  Future<void> _detachIfAttached(String schema) async {
    final attached = await _database.customSelect('PRAGMA database_list').get();
    if (attached.any((r) => r.data['name'] == schema)) {
      logger.w('[Backup] $schema was still attached; detaching it');
      await _database.customStatement('DETACH DATABASE $schema');
    }
  }

  /// The metadata next to [dbPath], or null when there is none (a backup
  /// copied without it restores its rows only).
  Future<BackupEntry?> _readMetadata(String dbPath) async {
    final file = File('$dbPath$_metaSuffix');
    if (!await file.exists()) return null;
    final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    return BackupEntry.fromJson(json).copyWith(filePath: dbPath);
  }

  Future<List<String>> _columnNames(String schema, String table) async {
    final rows = await _database
        .customSelect('PRAGMA $schema.table_info("$table")')
        .get();
    return [for (final r in rows) r.data['name'] as String];
  }

  Future<Set<String>> _tableNames(String schema) async {
    final rows = await _database
        .customSelect(
          "SELECT name FROM $schema.sqlite_master WHERE type='table' "
          "AND name NOT LIKE 'sqlite_%'",
        )
        .get();
    return rows.map((r) => r.data['name'] as String).toSet();
  }

  // ---------------------------------------------------------------------------
  // List, delete, housekeeping

  /// Every backup in the folder, newest first, with [BackupEntry.filePath]
  /// taken from where its metadata is. Unreadable metadata is logged and
  /// skipped.
  Future<List<BackupEntry>> listBackups() async {
    final backupDir = await getBackupDirectory();
    final entries = <BackupEntry>[];

    if (!await backupDir.exists()) return entries;

    await for (final entity in backupDir.list()) {
      if (entity is File && entity.path.endsWith('.db$_metaSuffix')) {
        try {
          final content = await entity.readAsString();
          final json = jsonDecode(content) as Map<String, dynamic>;
          final dbPath = entity.path.substring(
            0,
            entity.path.length - _metaSuffix.length,
          );
          entries.add(BackupEntry.fromJson(json).copyWith(filePath: dbPath));
        } catch (e) {
          logger.w('[Backup] skipped unreadable metadata ${entity.path}', e);
        }
      }
    }

    entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return entries;
  }

  /// Writes [entry]'s metadata next to its `.db`, through a temporary file
  /// so a listed backup is always complete.
  Future<void> saveBackupMetadata(BackupEntry entry) async {
    final metadataPath = '${entry.filePath}$_metaSuffix';
    final temporary = File('$metadataPath.tmp');
    await temporary.writeAsString(jsonEncode(entry.toJson()), flush: true);
    await temporary.rename(metadataPath);
  }

  Future<void> deleteBackup(String backupId) async {
    final backups = await listBackups();
    final target = backups.firstWhere(
      (b) => b.id == backupId,
      orElse: () => throw StateError('Backup not found: $backupId'),
    );
    try {
      await _deleteEntry(target);
    } finally {
      // Even a delete that failed half-way may have unlisted it.
      _changed();
    }
  }

  /// Removes the metadata first, so a backup is never listed half deleted,
  /// then the `.db` and `.files/`. When the metadata can't be removed the
  /// backup is left whole, still listed and restorable.
  Future<void> _deleteEntry(BackupEntry entry) async {
    final dbPath = entry.filePath;
    final meta = File('$dbPath$_metaSuffix');
    try {
      if (await meta.exists()) await meta.delete();
    } on FileSystemException catch (e) {
      logger.e('[Backup] could not delete ${meta.path}; backup kept', e);
      rethrow;
    }
    FileSystemException? firstError;
    for (final entity in <FileSystemEntity>[
      File(dbPath),
      Directory(_filesPathFor(dbPath)),
    ]) {
      try {
        if (await entity.exists()) await entity.delete(recursive: true);
      } on FileSystemException catch (e) {
        logger.e('[Backup] could not delete ${entity.path}', e);
        firstError ??= e;
      }
    }
    if (firstError != null) throw firstError;
    logger.i('[Backup] deleted ${p.basename(dbPath)}');
  }

  /// Deletes the "Before restore" copies expired at [now] (default: the
  /// current time), existing ones included, and returns how many. A copy
  /// expires [getSafetyCopyRetentionDays] days after it was made, at that
  /// very moment. User backups and the ids in [keep] are never deleted.
  /// Runs one at a time: a call made while one runs waits for it. Failures
  /// are logged; when the setting can't be read nothing is deleted.
  Future<int> deleteExpiredSafetyCopies({
    DateTime? now,
    Set<String> keep = const {},
  }) {
    final run = _expiryQueue.then((_) => _deleteExpired(now, keep));
    _expiryQueue = run;
    return run;
  }

  Future<int> _deleteExpired(DateTime? now, Set<String> keep) async {
    var deleted = 0;
    try {
      final retention = Duration(days: await getSafetyCopyRetentionDays());
      final at = now ?? DateTime.now();
      for (final entry in await listBackups()) {
        if (!entry.isSafetyCopy ||
            entry.timestamp.add(retention).isAfter(at) ||
            keep.contains(entry.id)) {
          continue;
        }
        try {
          await _deleteEntry(entry);
          deleted++;
          logger.i('[Backup] deleted the expired safety copy ${entry.id}');
        } catch (e) {
          logger.e('[Backup] could not delete safety copy ${entry.id}', e);
        }
      }
    } catch (e, s) {
      logger.e('[Backup] could not look for expired safety copies', e, s);
    }
    if (deleted > 0) _changed();
    return deleted;
  }

  /// When each safety copy in the folder expires (made plus
  /// [getSafetyCopyRetentionDays] days), leaving out the ids in [keep].
  /// Throws when the folder can't be listed.
  Future<List<DateTime>> safetyCopyExpiries({
    Set<String> keep = const {},
  }) async {
    final retention = Duration(days: await getSafetyCopyRetentionDays());
    return [
      for (final entry in await listBackups())
        if (entry.isSafetyCopy && !keep.contains(entry.id))
          entry.timestamp.add(retention),
    ];
  }

  /// Removes `Documents/.restore-*` staging folders a crashed restore left
  /// behind and returns how many. Failures are logged.
  Future<int> removeRestoreLeftovers() async {
    var removed = 0;
    try {
      final docs = Directory(await _pathResolver.getDocumentsPath());
      if (!await docs.exists()) return 0;
      await for (final entity in docs.list(followLinks: false)) {
        if (entity is! Directory ||
            !p.basename(entity.path).startsWith(_stagingPrefix)) {
          continue;
        }
        try {
          await entity.delete(recursive: true);
          removed++;
          logger.i('[Backup] removed the leftover ${entity.path}');
        } on FileSystemException catch (e) {
          logger.e('[Backup] could not remove ${entity.path}', e);
        }
      }
    } catch (e, s) {
      logger.e('[Backup] could not look for restore leftovers', e, s);
    }
    return removed;
  }

  /// Removes what an interrupted backup (the app killed while writing it)
  /// left in the backup folder, and returns how many backups. A backup's
  /// `.db`, `.files/` and metadata `.tmp` are removed together, only when it
  /// has no metadata (it was never complete, so never listed), this run
  /// isn't writing it, and none of its parts (nor a file in `.files/`) was
  /// modified in the last [leftoverMinAge]. Names that aren't a backup's
  /// parts are never touched. Failures are logged.
  Future<int> removeBackupLeftovers({DateTime? now}) async {
    final cutoff = (now ?? DateTime.now()).subtract(leftoverMinAge);
    var removed = 0;
    try {
      final backupDir = await getBackupDirectory();
      final parts = <String, List<FileSystemEntity>>{};
      await for (final entity in backupDir.list(followLinks: false)) {
        final match = _backupPart.firstMatch(p.basename(entity.path));
        if (match == null) continue;
        final isDir = match[2] == '.files';
        if (isDir ? entity is! Directory : entity is! File) continue;
        (parts[match[1]!] ??= []).add(entity);
      }
      for (final MapEntry(key: base, value: entities) in parts.entries) {
        if (_writing.contains(base)) continue;
        final meta = p.join(backupDir.path, '$base.db$_metaSuffix');
        if (await _exists(meta)) continue;
        if (!await _untouchedSince(entities, cutoff)) continue;
        for (final entity in entities) {
          await _deleteQuietly(entity);
        }
        removed++;
        logger.i('[Backup] removed the interrupted backup $base');
      }
    } catch (e, s) {
      logger.e('[Backup] could not look for interrupted backups', e, s);
    }
    return removed;
  }

  /// Whether [entities], and the entries directly in those that are folders,
  /// were last modified before [cutoff]. A folder's own time moves with each
  /// file added to it, which matters because a copy may keep its source's
  /// modified time.
  static Future<bool> _untouchedSince(
    List<FileSystemEntity> entities,
    DateTime cutoff,
  ) async {
    for (final entity in entities) {
      final inside = entity is Directory
          ? await entity.list(followLinks: false).toList()
          : const <FileSystemEntity>[];
      for (final e in [entity, ...inside]) {
        final stat = await e.stat();
        if (!stat.modified.isBefore(cutoff)) return false;
      }
    }
    return true;
  }

  /// Deletes the working files (in `imports/` and the page cache) of the
  /// scans a restore removed, once neither this database nor a kept safety
  /// copy holds them, so restoring that safety copy still finds them. See
  /// [ScanFileSweeper]. Returns how many files went; never throws.
  Future<int> removeDroppedScanFiles({DateTime? now}) async {
    final List<BackupEntry> backups;
    try {
      backups = await listBackups();
    } catch (e, s) {
      logger.e(
        '[Backup] could not list the safety copies; no scan file '
        'deleted',
        e,
        s,
      );
      return 0;
    }
    return _scanFiles.sweep(
      keepSessionsOf: [
        for (final backup in backups)
          if (backup.isSafetyCopy) backup.filePath,
      ],
      now: now,
    );
  }

  /// Start-up housekeeping: restore and backup leftovers, expired safety
  /// copies, then the files of the scans no kept data holds. Never throws.
  Future<void> cleanUpOnStartup() async {
    await removeRestoreLeftovers();
    await removeBackupLeftovers();
    await deleteExpiredSafetyCopies();
    await removeDroppedScanFiles();
  }

  // ---------------------------------------------------------------------------
  // Files

  /// The local file behind a stored attachment path: inside Documents (see
  /// `AttachmentSyncService.resolveFile`), or a top-level file of an extra
  /// attachment folder (Windows attachments in the Documents root).
  Future<File?> _resolveAttachment(String path) async {
    if (path.isEmpty) return null;
    final normalized = p.normalize(path);
    if (p.isAbsolute(normalized) &&
        !AttachmentReferences.isDatabase(normalized)) {
      for (final root in await _legacyFolders.roots()) {
        if (!p.equals(p.dirname(normalized), p.normalize(root))) continue;
        final type = await FileSystemEntity.type(
          normalized,
          followLinks: false,
        );
        if (type == FileSystemEntityType.file) return File(normalized);
      }
    }
    return _attachments.resolveFile(path);
  }

  /// [wanted], or the same name with a unique suffix when [dir] (or
  /// [taken], lower-case names) already has it.
  static Future<String> _freeName(
    String dir,
    String wanted,
    Set<String> taken,
  ) async {
    if (!taken.contains(wanted.toLowerCase()) &&
        !await _exists(p.join(dir, wanted))) {
      return wanted;
    }
    final dot = wanted.lastIndexOf('.');
    final stem = dot > 0 ? wanted.substring(0, dot) : wanted;
    final ext = dot > 0 ? wanted.substring(dot) : '';
    while (true) {
      final name = '${stem}_${const Uuid().v4().substring(0, 8)}$ext';
      if (!taken.contains(name.toLowerCase()) &&
          !await _exists(p.join(dir, name))) {
        return name;
      }
    }
  }

  /// A file's name made safe on every desktop: separators and characters
  /// Windows refuses become `_`; no leading dot (hidden), no trailing dot or
  /// space, never the database's name. Letters of any script stay.
  static String _safeFileName(String basename) {
    var name = basename
        .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_')
        .replaceFirst(RegExp(r'^[.\s]+'), '')
        .replaceFirst(RegExp(r'[.\s]+$'), '');
    if (name.replaceAll('.', '').isEmpty) name = 'file';
    if (AttachmentReferences.isDatabase(name)) name = 'file_$name';
    return name;
  }

  /// A name from the metadata that stays inside `.files/`.
  static bool _isPlainName(String name) =>
      name.isNotEmpty &&
      name != '.' &&
      name != '..' &&
      !name.contains('/') &&
      !name.contains(r'\') &&
      _safeFileName(name) == name;

  /// The backup's display name as a file name: letters of any script,
  /// digits, spaces and `-._,`; a time's `:` becomes `.`, anything else `_`.
  static String _fileStem(String name) {
    final stem = name
        .replaceAll(':', '.')
        .replaceAll(RegExp(r'[^\p{L}\p{M}\p{N} \-._,]', unicode: true), '_')
        .replaceFirst(RegExp(r'^[.\s]+'), '')
        .trim();
    final runes = stem.runes;
    return runes.length > 80 ? String.fromCharCodes(runes.take(80)) : stem;
  }

  static String _filesPathFor(String dbPath) {
    final base = dbPath.endsWith('.db')
        ? dbPath.substring(0, dbPath.length - 3)
        : dbPath;
    return '$base.files';
  }

  static Future<String> _sha256(File file) async =>
      (await sha256.bind(file.openRead()).first).toString();

  static Future<bool> _exists(String path) async =>
      await FileSystemEntity.type(path, followLinks: false) !=
      FileSystemEntityType.notFound;

  static Future<void> _deleteQuietly(FileSystemEntity entity) async {
    try {
      if (await entity.exists()) await entity.delete(recursive: true);
    } on FileSystemException catch (e) {
      logger.w('[Backup] could not remove ${entity.path}', e);
    }
  }
}

/// Where a restore put the backup's files.
class _FilePlan {
  const _FilePlan({
    required this.files,
    required this.missing,
    required this.destinations,
    required this.added,
    required this.alreadyPresent,
    required this.notRestored,
    required this.resolvesTo,
  });

  static final none = _FilePlan(
    files: const [],
    missing: const {},
    destinations: const {},
    added: 0,
    alreadyPresent: 0,
    notRestored: 0,
    resolvesTo: (_) async => null,
  );

  /// Every file the backup lists, restored or not.
  final List<BackupFile> files;

  /// The paths of the urls whose file wasn't on the device at backup time;
  /// they are never pointed at a restored file.
  final Set<String> missing;

  /// Each restored file's name in Documents; null when the records already
  /// find its content where they point. Files that couldn't be restored
  /// are absent.
  final Map<BackupFile, String?> destinations;
  final int added;
  final int alreadyPresent;
  final int notRestored;

  /// The SHA-256 of the file a stored path opens now, or null.
  final Future<String?> Function(String path) resolvesTo;
}

/// Folders outside [PathResolver.getDocumentsPath] whose top-level files
/// also count as attachments: on Windows, the Documents folder that older
/// versions saved attachments to. None elsewhere.
@lazySingleton
class LegacyAttachmentFolders {
  LegacyAttachmentFolders(this._pathResolver);

  final PathResolver _pathResolver;

  Future<List<String>> roots() async {
    if (!Platform.isWindows) return const [];
    final root = legacyWindowsRoot(await _pathResolver.getDocumentsPath());
    return root == null ? const [] : [root];
  }

  /// The Documents folder above [documentsPath] when it has the Windows
  /// layout `<Documents>\HealthWallet\Documents`, else null.
  static String? legacyWindowsRoot(String documentsPath, [p.Context? context]) {
    final ctx = context ?? p.context;
    final docs = ctx.normalize(documentsPath);
    final app = ctx.dirname(docs);
    if (ctx.basename(docs) != 'Documents' ||
        ctx.basename(app) != 'HealthWallet') {
      return null;
    }
    final root = ctx.dirname(app);
    return root == app ? null : root;
  }
}
