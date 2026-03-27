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
import 'package:health_wallet/features/desktop/backup/domain/entity/backup_entry.dart';

@lazySingleton
class BackupService {
  final AppDatabase _database;

  BackupService(this._database);

  Future<String> _defaultBackupPath() async {
    final home = Platform.environment['HOME'] ?? '';
    return p.join(home, 'Documents', 'HealthWallet', 'Backups');
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
    final dir = await getBackupDirectory();
    return dir.path;
  }

  Future<void> setBackupDirectory(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(SharedPrefsConstants.backupDirectory, path);
  }

  Future<void> resetBackupDirectory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(SharedPrefsConstants.backupDirectory);
  }

  Future<BackupEntry> createSnapshot() async {
    final backupDir = await getBackupDirectory();
    final timestamp = DateTime.now();
    final id = timestamp.millisecondsSinceEpoch.toString();
    final fileName = 'healthwallet_backup_$id.db';
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

    final dbFolder = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dbFolder.path, 'db.sqlite');

    await _database.close();

    final dbFile = File(dbPath);
    if (await dbFile.exists()) {
      await dbFile.delete();
    }

    final walFile = File('$dbPath-wal');
    if (await walFile.exists()) {
      await walFile.delete();
    }

    final shmFile = File('$dbPath-shm');
    if (await shmFile.exists()) {
      await shmFile.delete();
    }

    await backupFile.copy(dbPath);
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

  String _metadataPathFor(String dbPath) => '$dbPath.meta.json';
}
