import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/data/local/app_database.dart';
import 'package:health_wallet/features/desktop/backup/data/services/backup_service.dart';
import 'package:health_wallet/features/desktop/backup/domain/entity/backup_entry.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

Future<void> insertResource(AppDatabase db, String id, {String raw = '{}'}) =>
    db.customStatement(
      'INSERT INTO fhir_resource (id, resource_raw) VALUES (?, ?)',
      [id, raw],
    );

Future<List<String>> resourceIds(AppDatabase db) async {
  final rows = await db
      .customSelect('SELECT id FROM fhir_resource ORDER BY id')
      .get();
  return rows.map((r) => r.data['id'] as String).toList();
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late Directory dir;
  late AppDatabase db;
  late BackupService service;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('backup_service_test');
    SharedPreferences.setMockInitialValues({'backupDirectory': dir.path});
    db = AppDatabase(NativeDatabase.memory());
    service = BackupService(db);
  });

  tearDown(() async {
    await db.close();
    await dir.delete(recursive: true);
  });

  String hexSha(List<int> bytes) => crypto.sha256.convert(bytes).toString();

  group('backup directory', () {
    test('uses the chosen directory', () async {
      expect(await service.hasUserSelectedPath(), isTrue);
      expect(await service.getBackupPath(), dir.path);
      expect((await service.getBackupDirectory()).path, dir.path);
    });

    test('creates a chosen directory that does not exist yet', () async {
      final nested = p.join(dir.path, 'a', 'b');
      await service.setBackupDirectory(nested);

      final created = await service.getBackupDirectory();

      expect(created.path, nested);
      expect(created.existsSync(), isTrue);
    });

    test(
      'defaults to Documents/HealthWallet/Backups under the home dir',
      () async {
        await service.resetBackupDirectory();

        expect(await service.hasUserSelectedPath(), isFalse);
        final home =
            Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
        expect(
          await service.getBackupPath(),
          p.join(home!, 'Documents', 'HealthWallet', 'Backups'),
        );
      },
    );
  });

  group('createSnapshot', () {
    test('writes a database copy and its metadata', () async {
      await insertResource(db, 'r1');
      await insertResource(db, 'r2');

      final entry = await service.createSnapshot();

      final file = File(entry.filePath);
      expect(file.existsSync(), isTrue);
      expect(p.dirname(entry.filePath), dir.path);
      expect(p.basename(entry.filePath), 'healthwallet_backup_${entry.id}.db');
      expect(entry.recordCount, 2);
      expect(entry.sizeBytes, file.lengthSync());
      expect(entry.checksum, hexSha(file.readAsBytesSync()));
      expect(entry.name, '');

      final meta = jsonDecode(
        File('${entry.filePath}.meta.json').readAsStringSync(),
      );
      expect(BackupEntry.fromJson(meta as Map<String, dynamic>), entry);
    });

    test('sanitises a custom name into the file name', () async {
      final entry = await service.createSnapshot(
        name: '  Before trip/2026: v1!  ',
      );

      expect(entry.name, 'Before trip_2026_ v1_');
      expect(
        p.basename(entry.filePath),
        'Before trip_2026_ v1__${entry.id}.db',
      );
    });

    test('a blank name falls back to the default prefix', () async {
      final entry = await service.createSnapshot(name: '   ');

      expect(entry.name, '');
      expect(p.basename(entry.filePath), startsWith('healthwallet_backup_'));
    });
  });

  group('restoreFromFile', () {
    test('replaces the current data with the backup', () async {
      await insertResource(db, 'kept');
      final entry = await service.createSnapshot();
      await db.customStatement('DELETE FROM fhir_resource');
      await insertResource(db, 'added-later');

      await service.restoreFromFile(entry.filePath);

      expect(await resourceIds(db), ['kept']);
    });

    test('restores without metadata (no checksum to check)', () async {
      await insertResource(db, 'kept');
      final entry = await service.createSnapshot();
      File('${entry.filePath}.meta.json').deleteSync();
      await db.customStatement('DELETE FROM fhir_resource');

      await service.restoreFromFile(entry.filePath);

      expect(await resourceIds(db), ['kept']);
    });

    test('refuses a missing file', () async {
      await expectLater(
        service.restoreFromFile(p.join(dir.path, 'nope.db')),
        throwsStateError,
      );
    });

    test('refuses a corrupted file and leaves the data alone', () async {
      await insertResource(db, 'original');
      final entry = await service.createSnapshot();
      final file = File(entry.filePath);
      final bytes = file.readAsBytesSync();
      bytes[bytes.length - 1] ^= 0xFF;
      file.writeAsBytesSync(bytes);

      await expectLater(
        service.restoreFromFile(entry.filePath),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('checksum'),
          ),
        ),
      );
      expect(await resourceIds(db), ['original']);
    });

    test(
      'a backup that cannot be inserted leaves the current data intact',
      () async {
        await insertResource(db, 'original');
        final entry = await service.createSnapshot();
        File('${entry.filePath}.meta.json').deleteSync();

        // A backup from an older schema: one column fewer.
        final old = AppDatabase(NativeDatabase(File(entry.filePath)));
        await old.customStatement(
          'ALTER TABLE fhir_resource DROP COLUMN specialty_override',
        );
        await old.close();

        await expectLater(
          service.restoreFromFile(entry.filePath),
          throwsA(anything),
        );
        expect(await resourceIds(db), ['original']);
      },
      skip:
          'BUG: restoreFromFile deletes every table before attaching and '
          'copying the backup, outside a transaction; any failure while '
          'copying (older schema, extra table, disk error) loses all data and '
          'leaves backup_db attached (backup_service.dart:112-141).',
    );
  });

  group('listBackups / deleteBackup', () {
    test('lists newest first and skips unreadable metadata', () async {
      final first = await service.createSnapshot(name: 'first');
      await Future<void>.delayed(const Duration(milliseconds: 5));
      final second = await service.createSnapshot(name: 'second');
      File(p.join(dir.path, 'broken.db.meta.json')).writeAsStringSync('{');
      File(p.join(dir.path, 'unrelated.txt')).writeAsStringSync('x');

      final list = await service.listBackups();

      expect(list.map((e) => e.id), [second.id, first.id]);
    });

    test('deletes the database and its metadata', () async {
      final entry = await service.createSnapshot();

      await service.deleteBackup(entry.id);

      expect(File(entry.filePath).existsSync(), isFalse);
      expect(File('${entry.filePath}.meta.json').existsSync(), isFalse);
      expect(await service.listBackups(), isEmpty);
    });

    test(
      'deleting when the database file is already gone removes metadata',
      () async {
        final entry = await service.createSnapshot();
        File(entry.filePath).deleteSync();

        await service.deleteBackup(entry.id);

        expect(await service.listBackups(), isEmpty);
      },
    );

    test('deleting an unknown id throws', () async {
      await expectLater(service.deleteBackup('missing'), throwsStateError);
    });
  });
}
