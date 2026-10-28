import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/data/local/app_database.dart';
import 'package:health_wallet/core/services/folder_access_service.dart';
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

/// Stands in for the macOS bookmark channel.
class _FakeFolderAccess extends Fake implements FolderAccessService {
  String? Function(String path) bookmark = (_) => null;
  String? Function(String bookmark) restored = (b) => b;
  final restores = <String>[];

  @override
  Future<String?> bookmarkFor(String path) async => bookmark(path);

  @override
  Future<String?> restore(String bookmark) async {
    restores.add(bookmark);
    return restored(bookmark);
  }
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late Directory dir;
  late AppDatabase db;
  late _FakeFolderAccess folderAccess;
  late BackupService service;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('backup_service_test');
    SharedPreferences.setMockInitialValues({'backupDirectory': dir.path});
    db = AppDatabase(NativeDatabase.memory());
    folderAccess = _FakeFolderAccess();
    service = BackupService(db, folderAccess);
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

    test('counts only records that are not deleted', () async {
      await insertResource(db, 'r1');
      await insertResource(db, 'r2');
      await db.customStatement(
        "UPDATE fhir_resource SET deleted_at = 1, updated_at = 1 WHERE id = 'r2'",
      );

      final entry = await service.createSnapshot();

      expect(entry.recordCount, 1);
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
        final attached = await db.customSelect('PRAGMA database_list').get();
        expect(
          attached.map((r) => r.data['name']),
          isNot(contains('backup_db')),
        );

        // The database is usable for the next restore.
        final good = await service.createSnapshot();
        await insertResource(db, 'later');
        await service.restoreFromFile(good.filePath);
        expect(await resourceIds(db), ['original']);
      },
    );

    test('ignores tables in the backup that are not the app\'s own', () async {
      await insertResource(db, 'kept');
      final entry = await service.createSnapshot();
      File('${entry.filePath}.meta.json').deleteSync();
      final backup = AppDatabase(NativeDatabase(File(entry.filePath)));
      await backup.customStatement('CREATE TABLE intruder (x TEXT)');
      await backup.customStatement("INSERT INTO intruder VALUES ('evil')");
      await backup.close();

      await service.restoreFromFile(entry.filePath);

      expect(await resourceIds(db), ['kept']);
      final tables = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE name = 'intruder'",
          )
          .get();
      expect(tables, isEmpty);
    });
  });

  group('restoreFromFile edge cases', () {
    Future<void> insertNote(AppDatabase db, String content) =>
        db.customStatement(
          'INSERT INTO record_notes (resource_id, content, timestamp) '
          'VALUES (?, ?, ?)',
          ['r1', content, 0],
        );

    Future<List<String>> notes(AppDatabase db) async {
      final rows = await db
          .customSelect('SELECT content FROM record_notes ORDER BY id')
          .get();
      return rows.map((r) => r.data['content'] as String).toList();
    }

    /// Opens the snapshot file directly so a test can change it.
    Future<void> editBackup(
      BackupEntry entry,
      Future<void> Function(AppDatabase backup) change,
    ) async {
      File('${entry.filePath}.meta.json').deleteSync();
      final backup = AppDatabase(NativeDatabase(File(entry.filePath)));
      await change(backup);
      await backup.close();
    }

    Future<List<String>> attachedSchemas() async => [
      for (final r in await db.customSelect('PRAGMA database_list').get())
        r.data['name'] as String,
    ];

    test('restores every app table', () async {
      await insertResource(db, 'res');
      await insertNote(db, 'note');
      await db.customStatement(
        "INSERT INTO sources (id, platform_name) VALUES ('s1', 'Clinic')",
      );
      final entry = await service.createSnapshot();
      await db.customStatement('DELETE FROM fhir_resource');
      await db.customStatement('DELETE FROM record_notes');
      await db.customStatement('DELETE FROM sources');
      await insertNote(db, 'later');

      await service.restoreFromFile(entry.filePath);

      expect(await resourceIds(db), ['res']);
      expect(await notes(db), ['note']);
      final sources = await db.customSelect('SELECT id FROM sources').get();
      expect(sources.map((r) => r.data['id']), ['s1']);
      expect(await attachedSchemas(), isNot(contains('backup_db')));
    });

    test('keeps the backed-up updated_at, so sync sees no new edits', () async {
      await db.customStatement(
        'INSERT INTO fhir_resource (id, resource_raw, updated_at) '
        "VALUES ('r', '{}', 1234)",
      );
      final entry = await service.createSnapshot();
      await db.customStatement(
        "UPDATE fhir_resource SET updated_at = 9999 WHERE id = 'r'",
      );

      await service.restoreFromFile(entry.filePath);

      final row = await db
          .customSelect("SELECT updated_at FROM fhir_resource WHERE id = 'r'")
          .getSingle();
      expect(row.data['updated_at'], 1234);
    });

    test('a table missing from the backup keeps its current rows', () async {
      await insertResource(db, 'from-backup');
      await insertNote(db, 'old note');
      final entry = await service.createSnapshot();
      await editBackup(
        entry,
        (b) => b.customStatement('DROP TABLE record_notes'),
      );
      await db.customStatement('DELETE FROM fhir_resource');
      await insertNote(db, 'current note');

      await service.restoreFromFile(entry.filePath);

      expect(await resourceIds(db), ['from-backup']);
      expect(await notes(db), ['old note', 'current note']);
    });

    test('a file that is not a database throws and changes nothing', () async {
      await insertResource(db, 'original');
      final junk = File(p.join(dir.path, 'junk.db'))
        ..writeAsBytesSync(List.generate(8192, (i) => i % 251));

      await expectLater(service.restoreFromFile(junk.path), throwsA(anything));

      expect(await resourceIds(db), ['original']);
      expect(await attachedSchemas(), isNot(contains('backup_db')));
    });

    test('a backup path with a quote in it restores', () async {
      await insertResource(db, 'kept');
      final quoted = Directory(p.join(dir.path, "it's here"))..createSync();
      await service.setBackupDirectory(quoted.path);
      final entry = await service.createSnapshot();
      await db.customStatement('DELETE FROM fhir_resource');

      await service.restoreFromFile(entry.filePath);

      expect(await resourceIds(db), ['kept']);
    });

    test('metadata without a matching checksum is refused even if the file '
        'is a valid database', () async {
      await insertResource(db, 'original');
      final entry = await service.createSnapshot();
      await service.saveBackupMetadata(entry.copyWith(checksum: '00'));
      await db.customStatement('DELETE FROM fhir_resource');

      await expectLater(
        service.restoreFromFile(entry.filePath),
        throwsStateError,
      );
      expect(await resourceIds(db), isEmpty);
    });
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

  group('folder access after a restart (macOS sandbox)', () {
    Future<SharedPreferences> prefs() => SharedPreferences.getInstance();

    test('choosing a folder saves its bookmark', () async {
      folderAccess.bookmark = (path) => 'bookmark:$path';

      await service.setBackupDirectory(dir.path);

      expect(
        (await prefs()).getString('backupDirectoryBookmark'),
        'bookmark:${dir.path}',
      );
    });

    test('a platform without bookmarks stores none', () async {
      SharedPreferences.setMockInitialValues({
        'backupDirectory': dir.path,
        'backupDirectoryBookmark': 'old',
      });

      await service.setBackupDirectory(dir.path);

      expect((await prefs()).containsKey('backupDirectoryBookmark'), isFalse);
    });

    test('reopens the saved folder once, before the first use', () async {
      SharedPreferences.setMockInitialValues({
        'backupDirectory': dir.path,
        'backupDirectoryBookmark': 'saved',
      });

      await service.listBackups();
      await service.listBackups();
      await service.createSnapshot(name: 'after restart');

      expect(folderAccess.restores, ['saved']);
    });

    test('keeps the refreshed bookmark macOS gives for a stale one', () async {
      SharedPreferences.setMockInitialValues({
        'backupDirectory': dir.path,
        'backupDirectoryBookmark': 'stale',
      });
      folderAccess.restored = (_) => 'fresh';

      await service.listBackups();

      expect((await prefs()).getString('backupDirectoryBookmark'), 'fresh');
    });

    test('keeps the bookmark when access could not be restored', () async {
      SharedPreferences.setMockInitialValues({
        'backupDirectory': dir.path,
        'backupDirectoryBookmark': 'saved',
      });
      folderAccess.restored = (_) => null;

      await service.listBackups();

      expect((await prefs()).getString('backupDirectoryBookmark'), 'saved');
    });

    test('without a saved bookmark nothing is restored', () async {
      await service.listBackups();

      expect(folderAccess.restores, isEmpty);
    });

    test(
      'a folder chosen in this run is not reopened from a bookmark',
      () async {
        SharedPreferences.setMockInitialValues({
          'backupDirectory': dir.path,
          'backupDirectoryBookmark': 'old',
        });
        folderAccess.bookmark = (path) => 'new';

        await service.setBackupDirectory(dir.path);
        await service.listBackups();

        expect(folderAccess.restores, isEmpty);
      },
    );

    test('going back to the default folder forgets the bookmark', () async {
      SharedPreferences.setMockInitialValues({
        'backupDirectory': dir.path,
        'backupDirectoryBookmark': 'saved',
      });

      await service.resetBackupDirectory();

      expect((await prefs()).containsKey('backupDirectoryBookmark'), isFalse);
      expect((await prefs()).containsKey('backupDirectory'), isFalse);
    });
  });
}
