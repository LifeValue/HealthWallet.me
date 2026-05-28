import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:injectable/injectable.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pointycastle/export.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:health_wallet/core/config/constants/shared_prefs_constants.dart';
import 'package:health_wallet/core/data/local/app_database.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/features/desktop/backup/domain/entity/backup_entry.dart';

@lazySingleton
class BackupService {
  final AppDatabase _database;

  BackupService(this._database);

  Future<String> _defaultBackupPath() async {
    final home = Platform.environment['HOME'] ??
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

  Future<void> setBackupDirectory(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(SharedPrefsConstants.backupDirectory, path);
  }

  Future<void> resetBackupDirectory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(SharedPrefsConstants.backupDirectory);
  }

  Future<BackupEntry> createSnapshot({String? name}) async {
    final backupDir = await getBackupDirectory();
    final timestamp = DateTime.now();
    final id = timestamp.millisecondsSinceEpoch.toString();
    final safeName = (name != null && name.trim().isNotEmpty)
        ? name.trim().replaceAll(RegExp(r'[^\w\s\-.]'), '_')
        : '';
    final prefix = safeName.isNotEmpty ? '${safeName}_' : 'healthwallet_backup_';
    final fileName = '$prefix$id.db';
    final snapshotPath = p.join(backupDir.path, fileName);

    await _database.customStatement("VACUUM INTO ?", [snapshotPath]);

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

    final tables = await _database.customSelect(
      "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'",
    ).get();

    for (final row in tables) {
      final name = row.data['name'] as String;
      await _database.customStatement('DELETE FROM "$name"');
    }

    final escaped = backupPath.replaceAll("'", "''");
    await _database.customStatement("ATTACH DATABASE '$escaped' AS backup_db");

    final backupTables = await _database.customSelect(
      "SELECT name FROM backup_db.sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'",
    ).get();

    for (final row in backupTables) {
      final name = row.data['name'] as String;
      await _database.customStatement(
        'INSERT OR REPLACE INTO main."$name" SELECT * FROM backup_db."$name"',
      );
    }

    await _database.customStatement('DETACH DATABASE backup_db');
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
    final result = await _database.customSelect(
      'SELECT COUNT(*) as count FROM fhir_resource',
      readsFrom: {_database.fhirResource},
    ).getSingle();
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

  Future<void> _deleteWithRetry(File file, {int attempts = 5}) async {
    for (var i = 0; i < attempts; i++) {
      try {
        await file.delete();
        return;
      } on FileSystemException {
        if (i == attempts - 1) rethrow;
        await Future<void>.delayed(Duration(milliseconds: 200 * (i + 1)));
      }
    }
  }

  String _metadataPathFor(String dbPath) => '$dbPath.meta.json';
}
