import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:health_wallet/core/config/constants/shared_prefs_constants.dart';
import 'package:health_wallet/core/data/local/app_database.dart';
import 'package:health_wallet/core/services/folder_access_service.dart';
import 'package:health_wallet/features/desktop/backup/domain/entity/backup_entry.dart';
import 'package:injectable/injectable.dart';
import 'package:path/path.dart' as p;
import 'package:pointycastle/export.dart';
import 'package:shared_preferences/shared_preferences.dart';

@lazySingleton
class BackupService {
  final AppDatabase _database;
  final FolderAccessService _folderAccess;

  BackupService(this._database, this._folderAccess);

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
  }

  Future<void> resetBackupDirectory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(SharedPrefsConstants.backupDirectory);
    await prefs.remove(SharedPrefsConstants.backupDirectoryBookmark);
  }

  Future<BackupEntry> createSnapshot({String? name}) async {
    final backupDir = await getBackupDirectory();
    final timestamp = DateTime.now();
    final id = timestamp.millisecondsSinceEpoch.toString();
    final safeName = (name != null && name.trim().isNotEmpty)
        ? name.trim().replaceAll(RegExp(r'[^\w\s\-.]'), '_')
        : '';
    final prefix = safeName.isNotEmpty
        ? '${safeName}_'
        : 'healthwallet_backup_';
    final fileName = '$prefix$id.db';
    final snapshotPath = p.join(backupDir.path, fileName);

    await _database.customStatement('VACUUM INTO ?', [snapshotPath]);

    final snapshotFile = File(snapshotPath);
    final sizeBytes = await snapshotFile.length();
    final checksum = await _computeChecksum(snapshotFile);
    final recordCount = await _getRecordCount();

    final entry = BackupEntry(
      id: id,
      timestamp: timestamp,
      sizeBytes: sizeBytes,
      recordCount: recordCount,
      checksum: checksum,
      filePath: snapshotPath,
      name: safeName,
    );

    await saveBackupMetadata(entry);

    return entry;
  }

  Future<void> restoreFromFile(String backupPath) async {
    final backupFile = File(backupPath);
    if (!await backupFile.exists()) {
      throw StateError('Backup file not found: $backupPath');
    }

    final metadataPath = _metadataPathFor(backupPath);
    final metadataFile = File(metadataPath);
    if (await metadataFile.exists()) {
      final metadataJson = jsonDecode(await metadataFile.readAsString());
      final savedChecksum = metadataJson['checksum'] as String;
      final currentChecksum = await _computeChecksum(backupFile);

      if (savedChecksum != currentChecksum) {
        throw StateError('Backup checksum mismatch — file may be corrupted');
      }
    }

    await _database.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');

    // SQLite refuses ATTACH inside a transaction, so attach first, copy in
    // one transaction (all or nothing), and always detach afterwards.
    final escaped = backupPath.replaceAll("'", "''");
    await _database.customStatement("ATTACH DATABASE '$escaped' AS backup_db");
    try {
      final mainTables = await _tableNames('main');
      final backupTables = await _tableNames('backup_db');
      final tables = _database.allTables
          .map((t) => t.actualTableName)
          .where((t) => mainTables.contains(t) && backupTables.contains(t))
          .toList();

      await _database.transaction(() async {
        for (final name in tables) {
          await _database.customStatement('DELETE FROM main."$name"');
          await _database.customStatement(
            'INSERT INTO main."$name" SELECT * FROM backup_db."$name"',
          );
        }
      });
    } finally {
      await _database.customStatement('DETACH DATABASE backup_db');
    }
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

  Future<List<BackupEntry>> listBackups() async {
    final backupDir = await getBackupDirectory();
    final entries = <BackupEntry>[];

    if (!await backupDir.exists()) return entries;

    await for (final entity in backupDir.list()) {
      if (entity is File && entity.path.endsWith('.db.meta.json')) {
        try {
          final content = await entity.readAsString();
          final json = jsonDecode(content) as Map<String, dynamic>;
          entries.add(BackupEntry.fromJson(json));
        } catch (_) {}
      }
    }

    entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return entries;
  }

  Future<void> saveBackupMetadata(BackupEntry entry) async {
    final metadataPath = _metadataPathFor(entry.filePath);
    final metadataFile = File(metadataPath);
    final json = jsonEncode(entry.toJson());
    await metadataFile.writeAsString(json);
  }

  Future<String> _computeChecksum(File file) async {
    final bytes = await file.readAsBytes();
    final digest = SHA256Digest();
    final hash = digest.process(Uint8List.fromList(bytes));
    return hash.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  Future<int> _getRecordCount() async {
    final result = await _database
        .customSelect(
          'SELECT COUNT(*) as count FROM fhir_resource WHERE deleted_at IS NULL',
          readsFrom: {_database.fhirResource},
        )
        .getSingle();
    return result.data['count'] as int;
  }

  Future<void> deleteBackup(String backupId) async {
    final backups = await listBackups();
    final target = backups.firstWhere(
      (b) => b.id == backupId,
      orElse: () => throw StateError('Backup not found: $backupId'),
    );

    final dbFile = File(target.filePath);
    if (await dbFile.exists()) await dbFile.delete();

    final metaFile = File(_metadataPathFor(target.filePath));
    if (await metaFile.exists()) await metaFile.delete();
  }

  String _metadataPathFor(String dbPath) => '$dbPath.meta.json';
}
