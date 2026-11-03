import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:drift/drift.dart' show Variable, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/data/local/app_database.dart';
import 'package:health_wallet/core/services/attachment_references.dart';
import 'package:health_wallet/core/services/folder_access_service.dart';
import 'package:health_wallet/core/services/path_resolver.dart';
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
      .customSelect(
        'SELECT id FROM fhir_resource WHERE deleted_at IS NULL ORDER BY id',
      )
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

/// The real [PathResolver] with a fixed documents directory.
class _DocsPathResolver extends PathResolver {
  _DocsPathResolver(this.documentsPath);

  final String documentsPath;

  @override
  Future<String> getDocumentsPath() async => documentsPath;
}

/// A documents folder that can't be read, to make a backup fail midway.
class _BrokenPathResolver extends PathResolver {
  @override
  Future<String> getDocumentsPath() async =>
      throw const FileSystemException('documents unavailable');
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  /// The backup folder.
  late Directory dir;

  /// The app's documents folder, where attachments live.
  late Directory docs;
  late Directory root;
  late AppDatabase db;
  late _FakeFolderAccess folderAccess;
  late BackupService service;

  BackupService serviceFor(AppDatabase db, {PathResolver? paths}) =>
      BackupService(
        db,
        folderAccess,
        paths ?? _DocsPathResolver(docs.path),
        AttachmentReferences(db),
      );

  setUp(() async {
    root = await Directory.systemTemp.createTemp('backup_service_test');
    dir = Directory(p.join(root.path, 'backups'))..createSync();
    docs = Directory(p.join(root.path, 'docs'))..createSync();
    SharedPreferences.setMockInitialValues({'backupDirectory': dir.path});
    // Foreign keys on, as the app opens its database.
    db = AppDatabase(
      NativeDatabase.memory(
        setup: (raw) => raw.execute('PRAGMA foreign_keys = ON'),
      ),
    );
    folderAccess = _FakeFolderAccess();
    service = serviceFor(db);
  });

  tearDown(() async {
    await db.close();
    await root.delete(recursive: true);
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

    test('keeps the name as typed and sanitises only the file name', () async {
      final entry = await service.createSnapshot(
        name: '  Before trip/2026: v1!  ',
      );

      expect(entry.name, 'Before trip/2026: v1!');
      expect(
        p.basename(entry.filePath),
        'Before trip_2026. v1__${entry.id}.db',
      );
    });

    test('a name in another script and a dated name stay readable', () async {
      final entry = await service.createSnapshot(
        name: 'Înainte de restaurare 3 nov. 2026, 14:05',
      );

      expect(entry.name, 'Înainte de restaurare 3 nov. 2026, 14:05');
      expect(
        p.basename(entry.filePath),
        'Înainte de restaurare 3 nov. 2026, 14.05_${entry.id}.db',
      );
      expect(await service.listBackups(), [entry]);
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

        // A damaged backup: a note whose source isn't in it.
        final damaged = AppDatabase(NativeDatabase(File(entry.filePath)));
        await damaged.customStatement(
          'INSERT INTO record_notes (resource_id, source_id, content, timestamp) '
          "VALUES ('r1', 'ghost', 'note', 0)",
        );
        await damaged.close();

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
          .customSelect(
            'SELECT content FROM record_notes WHERE deleted_at IS NULL ORDER BY id',
          )
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
      final sources = await db
          .customSelect('SELECT id FROM sources WHERE deleted_at IS NULL')
          .get();
      expect(sources.map((r) => r.data['id']), ['s1']);
      expect(await attachedSchemas(), isNot(contains('backup_db')));
    });

    test('restores notes that refer to their source', () async {
      await db.customStatement(
        "INSERT INTO sources (id, platform_name) VALUES ('s1', 'Clinic')",
      );
      await db.customStatement(
        'INSERT INTO record_notes (resource_id, source_id, content, timestamp) '
        "VALUES ('r1', 's1', 'note', 0)",
      );
      final entry = await service.createSnapshot();

      await service.restoreFromFile(entry.filePath);

      expect(await notes(db), ['note']);
    });

    test('restores a backup from an older schema, one column fewer', () async {
      await insertResource(db, 'from-backup');
      final entry = await service.createSnapshot();
      await editBackup(
        entry,
        (b) => b.customStatement(
          'ALTER TABLE fhir_resource DROP COLUMN specialty_override',
        ),
      );
      await db.customStatement('DELETE FROM fhir_resource');

      await service.restoreFromFile(entry.filePath);

      expect(await resourceIds(db), ['from-backup']);
    });

    test(
      'restores a backup made before notes had a key of their own',
      () async {
        await insertNote(db, 'old note');
        final entry = await service.createSnapshot();
        await editBackup(entry, (b) async {
          await b.customStatement('DROP TRIGGER record_notes_insert_uuid');
          await b.customStatement('DROP TRIGGER record_notes_insert_outbox');
          await b.customStatement('DROP TRIGGER record_notes_update_outbox');
          await b.customStatement(
            'DROP TRIGGER record_notes_update_updated_at',
          );
          await b.customStatement('DROP INDEX record_notes_uuid');
          await b.customStatement('ALTER TABLE record_notes DROP COLUMN uuid');
        });
        await db.customStatement('DELETE FROM record_notes');

        await service.restoreFromFile(entry.filePath);

        final row = await db
            .customSelect('SELECT id, content, uuid FROM record_notes')
            .getSingle();
        expect(row.data['content'], 'old note');
        expect(row.data['uuid'], 'legacy-${row.data['id']}');
      },
    );

    group('with foreign keys on, as in the app', () {
      late AppDatabase fkDb;
      late BackupService fkService;

      setUp(() {
        fkDb = AppDatabase(
          NativeDatabase.memory(
            setup: (raw) => raw.execute('PRAGMA foreign_keys = ON'),
          ),
        );
        fkService = serviceFor(fkDb);
      });

      tearDown(() => fkDb.close());

      Future<void> insertSourceWithNote(AppDatabase db, String id) async {
        await db.customStatement(
          'INSERT INTO sources (id, platform_name) VALUES (?, ?)',
          [id, 'Clinic'],
        );
        await db.customStatement(
          'INSERT INTO record_notes (resource_id, source_id, content, '
          'timestamp) VALUES (?, ?, ?, ?)',
          ['r1', id, 'note of $id', 0],
        );
      }

      test('restores notes that point at a source', () async {
        await insertSourceWithNote(fkDb, 's1');
        final entry = await fkService.createSnapshot();
        await insertSourceWithNote(fkDb, 's2');

        await fkService.restoreFromFile(entry.filePath);

        expect(await notes(fkDb), ['note of s1']);
        final sources = await fkDb
            .customSelect('SELECT id FROM sources WHERE deleted_at IS NULL')
            .get();
        expect(sources.map((r) => r.data['id']), ['s1']);
      });

      test('a backup whose note points at a missing source fails and leaves '
          'the data alone', () async {
        await insertSourceWithNote(fkDb, 's1');
        final entry = await fkService.createSnapshot();
        await editBackup(
          entry,
          (backup) => backup.customStatement(
            "UPDATE record_notes SET source_id = 'ghost'",
          ),
        );

        await expectLater(
          fkService.restoreFromFile(entry.filePath),
          throwsA(isA<SqliteException>()),
        );

        expect(await notes(fkDb), ['note of s1']);
        final sources = await fkDb
            .customSelect('SELECT id FROM sources WHERE deleted_at IS NULL')
            .get();
        expect(sources.map((r) => r.data['id']), ['s1']);
        expect(await attachedSchemas(), isNot(contains('backup_db')));
      });

      test('a backup note whose source was deleted since keeps it as a '
          'tombstone', () async {
        await insertSourceWithNote(fkDb, 's1');
        final entry = await fkService.createSnapshot();
        await editBackup(
          entry,
          (backup) => backup.customStatement('DELETE FROM sources'),
        );

        await fkService.restoreFromFile(entry.filePath);

        expect(await notes(fkDb), ['note of s1']);
        final source = await fkDb
            .customSelect("SELECT deleted_at FROM sources WHERE id = 's1'")
            .getSingle();
        expect(source.data['deleted_at'], isNotNull);
      });
    });

    test(
      'stamps restored rows later than any row, so they win on sync',
      () async {
        await db.customStatement(
          'INSERT INTO fhir_resource (id, resource_raw, updated_at) '
          "VALUES ('r', '{}', 1234)",
        );
        final entry = await service.createSnapshot();
        await db.customStatement(
          "UPDATE fhir_resource SET updated_at = 9999 WHERE id = 'r'",
        );
        final before = DateTime.now().millisecondsSinceEpoch;

        await service.restoreFromFile(entry.filePath);

        final row = await db
            .customSelect("SELECT updated_at FROM fhir_resource WHERE id = 'r'")
            .getSingle();
        expect(row.data['updated_at'], greaterThanOrEqualTo(before));
      },
    );

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

  // ---------------------------------------------------------------------------
  // Attachment files and point-in-time restore

  String docRaw(List<String> urls) => jsonEncode({
    'resourceType': 'DocumentReference',
    'content': [
      for (final url in urls)
        {
          'attachment': {'url': url, 'title': 't'},
        },
    ],
  });

  Future<void> insertDocument(
    AppDatabase db,
    String id,
    List<String> urls, {
    int? updatedAt,
    int? deletedAt,
  }) => db.customStatement(
    'INSERT INTO fhir_resource (id, resource_type, resource_raw, updated_at, '
    'deleted_at) VALUES (?, ?, ?, ?, ?)',
    [id, 'DocumentReference', docRaw(urls), updatedAt, deletedAt],
  );

  File docFile(String name, [String? content]) => File(p.join(docs.path, name))
    ..parent.createSync(recursive: true)
    ..writeAsStringSync(content ?? 'content of $name');

  Future<Map<String, dynamic>> rowOf(String table, String id) => db
      .customSelect(
        'SELECT * FROM $table WHERE id = ?',
        variables: [
          Variable.withString(id),
        ],
      )
      .getSingle()
      .then((r) => r.data);

  Future<List<String>> urlsOf(String id) async {
    final raw = (await rowOf('fhir_resource', id))['resource_raw'] as String;
    return [
      for (final item in (jsonDecode(raw)['content'] as List))
        item['attachment']['url'] as String,
    ];
  }

  String filesDirOf(BackupEntry entry) =>
      '${entry.filePath.substring(0, entry.filePath.length - 3)}.files';

  List<String> docNames() => [
    for (final e in docs.listSync())
      if (e is File) p.basename(e.path),
  ]..sort();

  bool hasStaging() => docs.listSync().any(
    (e) => p.basename(e.path).startsWith('.restore-'),
  );

  group('backups with files', () {
    test('copies each file the records refer to once, metadata last', () async {
      final scan = docFile('scan.pdf');
      docFile('photo.jpg');
      docFile('old.pdf');
      docFile('unrelated.pdf');
      docFile('db.sqlite', 'the database');
      final absolute = 'file://${Uri.encodeComponent(scan.path)}';
      await insertDocument(db, 'd1', [
        'file://scan.pdf',
        'https://example.org/remote.pdf',
      ]);
      await insertDocument(db, 'd2', [absolute, 'file://gone.pdf']);
      await insertDocument(db, 'd3', ['file://old.pdf'], deletedAt: 5);
      await insertDocument(db, 'd4', ['file://db.sqlite']);
      await db.customStatement(
        'INSERT INTO fhir_resource (id, resource_type, resource_raw) '
        "VALUES ('m1', 'Media', ?)",
        [
          jsonEncode({
            'resourceType': 'Media',
            'content': {'url': 'file://photo.jpg'},
          }),
        ],
      );

      final entry = await service.createSnapshot();

      expect(entry.formatVersion, 2);
      expect(entry.hasFiles, isTrue);
      expect(entry.files.map((f) => f.name).toSet(), {
        'scan.pdf',
        'photo.jpg',
        'old.pdf',
      });
      final scanEntry = entry.files.firstWhere((f) => f.name == 'scan.pdf');
      expect(scanEntry.sourcePaths.toSet(), {'scan.pdf', scan.path});
      expect(scanEntry.sha256, hexSha(scan.readAsBytesSync()));
      expect(scanEntry.size, scan.lengthSync());
      expect(entry.missing.toSet(), {'file://gone.pdf', 'file://db.sqlite'});

      final copied = Directory(filesDirOf(entry))
          .listSync()
          .map((e) => p.basename(e.path))
          .toSet();
      expect(copied, {'scan.pdf', 'photo.jpg', 'old.pdf'});
      for (final file in entry.files) {
        final copy = File(p.join(filesDirOf(entry), file.name));
        expect(hexSha(copy.readAsBytesSync()), file.sha256);
      }
      expect(entry.totalBytes, entry.sizeBytes + 19 + 20 + 18);

      final meta = jsonDecode(
        File('${entry.filePath}.meta.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      expect(meta['formatVersion'], 2);
      expect(BackupEntry.fromJson(meta), entry);
      expect(File('${entry.filePath}.meta.json.tmp').existsSync(), isFalse);
    });

    test('a backup without metadata is not listed', () async {
      final entry = await service.createSnapshot();
      File('${entry.filePath}.meta.json').renameSync(
        '${entry.filePath}.meta.json.tmp',
      );

      expect(await service.listBackups(), isEmpty);
    });

    test('two files with the same name get two names', () async {
      docFile('a/scan.pdf', 'first');
      docFile('b/scan.pdf', 'second');
      await insertDocument(db, 'd1', [
        'file://a/scan.pdf',
        'file://b/scan.pdf',
      ]);

      final entry = await service.createSnapshot();

      expect(entry.files, hasLength(2));
      final names = entry.files.map((f) => f.name).toSet();
      expect(names, hasLength(2));
      expect(names, contains('scan.pdf'));
      expect(
        names.every((n) => n.startsWith('scan') && n.endsWith('.pdf')),
        isTrue,
      );
    });

    test('backs up a Windows attachment in the Documents root, and only '
        'top-level files there', () async {
      final winRoot = Directory(p.join(root.path, 'Documents'))..createSync();
      service.debugExtraAttachmentRoots = [winRoot.path];
      final old = File(p.join(winRoot.path, 'old_attach.pdf'))
        ..writeAsStringSync('windows file');
      final nested = File(p.join(winRoot.path, 'private', 'deep.pdf'))
        ..parent.createSync()
        ..writeAsStringSync('nested');
      final outside = File(p.join(root.path, 'elsewhere', 'secret.pdf'))
        ..parent.createSync()
        ..writeAsStringSync('secret');
      String url(File f) => 'file://${Uri.encodeComponent(f.path)}';
      await insertDocument(db, 'd1', [url(old), url(nested), url(outside)]);

      final entry = await service.createSnapshot();

      expect(entry.files.single.name, 'old_attach.pdf');
      expect(entry.files.single.sourcePaths, [old.path]);
      expect(entry.missing.toSet(), {url(nested), url(outside)});
    });

    test('a failed backup leaves nothing behind', () async {
      await insertDocument(db, 'd1', ['file://scan.pdf']);
      final broken = serviceFor(db, paths: _BrokenPathResolver());

      await expectLater(broken.createSnapshot(), throwsA(anything));

      expect(dir.listSync(), isEmpty);
      expect(await broken.listBackups(), isEmpty);
    });

    test('keeps file names in any script', () async {
      final name = 'Rezultate înregistrări 日本.pdf';
      docFile(name, 'unicode');
      await insertDocument(db, 'd1', ['file://${Uri.encodeComponent(name)}']);
      final entry = await service.createSnapshot(name: 'Ünïcödé');
      File(p.join(docs.path, name)).deleteSync();

      final result = await service.restoreFromFile(entry.filePath);

      expect(entry.files.single.name, name);
      expect(result.filesAdded, 1);
      expect(File(p.join(docs.path, name)).readAsStringSync(), 'unicode');
      expect(await urlsOf('d1'), ['file://${Uri.encodeComponent(name)}']);
    });
  });

  group('restoring files', () {
    test('brings back every deleted file, freshly dated', () async {
      docFile('scan.pdf');
      docFile('sub/photo.jpg');
      await insertDocument(db, 'd1', [
        'file://scan.pdf',
        'file://sub/photo.jpg',
      ]);
      final entry = await service.createSnapshot();
      for (final f in entry.files) {
        File(p.join(filesDirOf(entry), f.name)).setLastModifiedSync(
          DateTime(2020),
        );
      }
      File(p.join(docs.path, 'scan.pdf')).deleteSync();
      Directory(p.join(docs.path, 'sub')).deleteSync(recursive: true);
      final before = DateTime.now().subtract(const Duration(minutes: 1));

      final result = await service.restoreFromFile(entry.filePath);

      expect(result.hadFiles, isTrue);
      expect(result.filesAdded, 2);
      expect(result.filesNotRestored, 0);
      expect(docNames(), ['photo.jpg', 'scan.pdf']);
      final scan = File(p.join(docs.path, 'scan.pdf'));
      expect(scan.readAsStringSync(), 'content of scan.pdf');
      expect(scan.lastModifiedSync().isAfter(before), isTrue);
      // `sub/photo.jpg` finds `photo.jpg` in Documents by name.
      expect(await urlsOf('d1'), ['file://scan.pdf', 'file://sub/photo.jpg']);
      expect(hasStaging(), isFalse);
    });

    test('reuses a file with the same name and content', () async {
      docFile('scan.pdf');
      await insertDocument(db, 'd1', ['file://scan.pdf']);
      final entry = await service.createSnapshot();

      final result = await service.restoreFromFile(entry.filePath);

      expect(result.filesAlreadyPresent, 1);
      expect(result.filesAdded, 0);
      expect(docNames(), ['scan.pdf']);
    });

    test('keeps a current file with the same name and other content, and '
        'points the record at the restored copy, keeping the stamp', () async {
      docFile('scan.pdf', 'backed up');
      await insertDocument(db, 'd1', ['file://scan.pdf']);
      await insertDocument(db, 'd2', []);
      final entry = await service.createSnapshot();
      docFile('scan.pdf', 'changed since');

      final result = await service.restoreFromFile(entry.filePath);

      expect(result.filesAdded, 1);
      expect(
        File(p.join(docs.path, 'scan.pdf')).readAsStringSync(),
        'changed since',
      );
      final restored = docNames().singleWhere((n) => n != 'scan.pdf');
      expect(restored, matches(RegExp(r'^scan_[0-9a-f]{8}\.pdf$')));
      expect(
        File(p.join(docs.path, restored)).readAsStringSync(),
        'backed up',
      );
      expect(await urlsOf('d1'), ['file://$restored']);
      final repointed = await rowOf('fhir_resource', 'd1');
      final untouched = await rowOf('fhir_resource', 'd2');
      expect(repointed['updated_at'], untouched['updated_at']);
    });

    test('counts missing and damaged files and restores the rest', () async {
      docFile('a.pdf');
      docFile('b.pdf');
      docFile('c.pdf');
      await insertDocument(db, 'd1', [
        'file://a.pdf',
        'file://b.pdf',
        'file://c.pdf',
      ]);
      final entry = await service.createSnapshot();
      File(p.join(filesDirOf(entry), 'a.pdf')).deleteSync();
      File(p.join(filesDirOf(entry), 'b.pdf')).writeAsStringSync('damaged');
      for (final name in ['a.pdf', 'b.pdf', 'c.pdf']) {
        File(p.join(docs.path, name)).deleteSync();
      }
      await db.customStatement('DELETE FROM fhir_resource');

      final result = await service.restoreFromFile(entry.filePath);

      expect(result.filesNotRestored, 2);
      expect(result.filesAdded, 1);
      expect(docNames(), ['c.pdf']);
      expect(await resourceIds(db), ['d1']);
      expect(hasStaging(), isFalse);
    });

    test('reports attachments that were already missing at backup', () async {
      await insertDocument(db, 'd1', ['file://never-here.pdf']);
      final entry = await service.createSnapshot();

      final result = await service.restoreFromFile(entry.filePath);

      expect(result.filesMissingFromBackup, 1);
      expect(result.filesNotRestored, 0);
    });

    test('an old database-only backup restores rows and keeps every current '
        'file', () async {
      await insertDocument(db, 'd1', []);
      final entry = await service.createSnapshot();
      // Metadata as 1.2.x wrote it.
      final meta = File('${entry.filePath}.meta.json');
      final json = jsonDecode(meta.readAsStringSync()) as Map<String, dynamic>
        ..remove('formatVersion')
        ..remove('files')
        ..remove('missing')
        ..remove('isSafetyCopy');
      meta.writeAsStringSync(jsonEncode(json));
      docFile('current.pdf');
      await insertDocument(db, 'd2', ['file://current.pdf']);

      final result = await service.restoreFromFile(entry.filePath);

      expect(result.hadFiles, isFalse);
      expect(docNames(), ['current.pdf']);
      expect(await resourceIds(db), ['d1']);
      expect((await rowOf('fhir_resource', 'd2'))['deleted_at'], isNotNull);
      expect((await service.listBackups()).single.hasFiles, isFalse);
    });

    test('a restore that fails removes the files it added and changes '
        'nothing', () async {
      docFile('scan.pdf');
      await db.customStatement(
        "INSERT INTO sources (id, platform_name) VALUES ('s1', 'Clinic')",
      );
      await db.customStatement(
        'INSERT INTO record_notes (resource_id, source_id, content, timestamp) '
        "VALUES ('d1', 's1', 'note', 0)",
      );
      await insertDocument(db, 'd1', ['file://scan.pdf']);
      final entry = await service.createSnapshot();
      // A damaged backup whose checksum still matches: its note points at a
      // source that exists nowhere.
      final backup = AppDatabase(NativeDatabase(File(entry.filePath)));
      await backup.customStatement(
        "UPDATE record_notes SET source_id = 'ghost'",
      );
      await backup.close();
      await service.saveBackupMetadata(
        entry.copyWith(
          checksum: hexSha(File(entry.filePath).readAsBytesSync()),
        ),
      );
      File(p.join(docs.path, 'scan.pdf')).deleteSync();
      await insertResource(db, 'later');

      await expectLater(
        service.restoreFromFile(entry.filePath),
        throwsA(isA<SqliteException>()),
      );

      expect(docNames(), isEmpty);
      expect(hasStaging(), isFalse);
      expect(await resourceIds(db), ['d1', 'later']);
    });

    test(
      'removes .restore-* leftovers at start-up and before a restore',
      () async {
        Directory(p.join(docs.path, '.restore-1', 'x'))
            .createSync(recursive: true);
        docFile('.restore-not-a-folder', 'kept');

        await service.cleanUpOnStartup();

        expect(hasStaging(), isTrue); // only the plain file is left
        expect(
          Directory(p.join(docs.path, '.restore-1')).existsSync(),
          isFalse,
        );

        Directory(p.join(docs.path, '.restore-2')).createSync();
        final entry = await service.createSnapshot();
        await service.restoreFromFile(entry.filePath);

        expect(
          Directory(p.join(docs.path, '.restore-2')).existsSync(),
          isFalse,
        );
        expect(
          File(p.join(docs.path, '.restore-not-a-folder')).existsSync(),
          isTrue,
        );
      },
    );

    test('works from the default macOS folder inside Documents', () async {
      final inDocs = Directory(p.join(docs.path, 'HealthWallet', 'Backups'));
      await service.setBackupDirectory(inDocs.path);
      docFile('scan.pdf');
      await insertDocument(db, 'd1', ['file://scan.pdf']);
      final entry = await service.createSnapshot();
      File(p.join(docs.path, 'scan.pdf')).deleteSync();

      final result = await service.restoreFromFile(
        (await service.listBackups()).single.filePath,
      );

      expect(p.dirname(entry.filePath), inDocs.path);
      expect(result.filesAdded, 1);
      expect(docNames(), ['scan.pdf']);
      expect(File(p.join(filesDirOf(entry), 'scan.pdf')).existsSync(), isTrue);
    });

    test(
      'a moved backup folder still lists and restores, files included',
      () async {
        docFile('scan.pdf');
        await insertDocument(db, 'd1', ['file://scan.pdf']);
        final entry = await service.createSnapshot();
        final moved = dir.renameSync(p.join(root.path, 'moved'));
        await service.setBackupDirectory(moved.path);
        File(p.join(docs.path, 'scan.pdf')).deleteSync();

        final listed = (await service.listBackups()).single;
        final result = await service.restoreFromFile(listed.filePath);

        expect(listed.filePath, p.join(moved.path, p.basename(entry.filePath)));
        expect(result.filesAdded, 1);
        expect(docNames(), ['scan.pdf']);
      },
    );
  });

  group('point in time', () {
    test('rows added since the backup become tombstones stamped after the '
        'restore', () async {
      await insertDocument(db, 'kept', [], updatedAt: 100);
      final entry = await service.createSnapshot();
      await insertDocument(db, 'added', ['file://x.pdf'], updatedAt: 200);
      final before = DateTime.now().millisecondsSinceEpoch;

      await service.restoreFromFile(entry.filePath);

      final kept = await rowOf('fhir_resource', 'kept');
      final added = await rowOf('fhir_resource', 'added');
      final stamp = kept['updated_at'] as int;
      expect(stamp, greaterThanOrEqualTo(before));
      expect(kept['deleted_at'], isNull);
      expect(added['deleted_at'], added['updated_at']);
      expect(added['updated_at'] as int, greaterThanOrEqualTo(stamp));
      expect(added['resource_raw'], docRaw(['file://x.pdf']));
    });

    test('tombstones in the backup get the restore stamp', () async {
      await insertDocument(db, 'gone', [], updatedAt: 5, deletedAt: 5);
      await insertDocument(db, 'live', []);
      final entry = await service.createSnapshot();

      await service.restoreFromFile(entry.filePath);

      final gone = await rowOf('fhir_resource', 'gone');
      final live = await rowOf('fhir_resource', 'live');
      expect(gone['deleted_at'], live['updated_at']);
      expect(gone['updated_at'], live['updated_at']);
    });

    test('a row from a clock that runs ahead still loses', () async {
      await insertDocument(db, 'r', []);
      final entry = await service.createSnapshot();
      final ahead = DateTime.now()
          .add(const Duration(days: 1))
          .millisecondsSinceEpoch;
      await db.customStatement(
        'UPDATE fhir_resource SET resource_raw = ?, updated_at = ?',
        ['{"edited":true}', ahead],
      );
      await insertDocument(db, 'phone', [], updatedAt: ahead + 5);

      await service.restoreFromFile(entry.filePath);

      final r = await rowOf('fhir_resource', 'r');
      final phone = await rowOf('fhir_resource', 'phone');
      expect(r['updated_at'] as int, greaterThan(ahead + 5));
      expect(r['resource_raw'], docRaw([]));
      expect(phone['deleted_at'], isNotNull);
      expect(phone['updated_at'] as int, greaterThan(ahead + 5));
    });

    test('notes with the same id on both sides stay apart', () async {
      await db.customStatement(
        'INSERT INTO record_notes (id, uuid, resource_id, content, timestamp) '
        "VALUES (1, 'from-backup', 'r', 'old', 0)",
      );
      final entry = await service.createSnapshot();
      await db.customStatement('DELETE FROM record_notes');
      await db.customStatement(
        'INSERT INTO record_notes (id, uuid, resource_id, content, timestamp) '
        "VALUES (1, 'added-since', 'r', 'new', 0)",
      );

      await service.restoreFromFile(entry.filePath);

      final rows = await db
          .customSelect(
            'SELECT id, uuid, deleted_at FROM record_notes ORDER BY uuid',
          )
          .get();
      final byUuid = {for (final r in rows) r.data['uuid']: r.data};
      expect(byUuid.keys, ['added-since', 'from-backup']);
      expect(byUuid['from-backup']!['id'], 1);
      expect(byUuid['from-backup']!['deleted_at'], isNull);
      expect(byUuid['added-since']!['id'], isNot(1));
      expect(byUuid['added-since']!['deleted_at'], isNotNull);
    });

    test('an old backup without sync columns gets the restore stamp', () async {
      await insertDocument(db, 'r', [], updatedAt: 1, deletedAt: 1);
      final entry = await service.createSnapshot();
      final backup = AppDatabase(NativeDatabase(File(entry.filePath)));
      await backup.customStatement(
        'DROP TRIGGER fhir_resource_insert_updated_at',
      );
      await backup.customStatement(
        'DROP TRIGGER fhir_resource_update_updated_at',
      );
      await backup.customStatement(
        'ALTER TABLE fhir_resource DROP COLUMN updated_at',
      );
      await backup.customStatement(
        'ALTER TABLE fhir_resource DROP COLUMN deleted_at',
      );
      await backup.close();
      File('${entry.filePath}.meta.json').deleteSync();
      final before = DateTime.now().millisecondsSinceEpoch;

      await service.restoreFromFile(entry.filePath);

      final r = await rowOf('fhir_resource', 'r');
      expect(r['updated_at'] as int, greaterThanOrEqualTo(before));
      expect(r['deleted_at'], isNull);
    });

    test('the outbox is never restored, and keeps its entries', () async {
      await insertDocument(db, 'kept', []);
      final entry = await service.createSnapshot();
      final backup = AppDatabase(NativeDatabase(File(entry.filePath)));
      await backup.customStatement(
        "INSERT INTO sync_outbox (synced_table, row_key) VALUES ('x', 'ghost')",
      );
      await backup.close();
      File('${entry.filePath}.meta.json').deleteSync();
      await insertDocument(db, 'added', []);
      final before = await db
          .customSelect('SELECT seq, row_key FROM sync_outbox ORDER BY seq')
          .get();

      await service.restoreFromFile(entry.filePath);

      final after = await db
          .customSelect('SELECT seq, row_key FROM sync_outbox ORDER BY seq')
          .get();
      final keys = after.map((r) => r.data['row_key']).toList();
      expect(keys, isNot(contains('ghost')));
      expect(
        after.take(before.length).map((r) => r.data),
        before.map((r) => r.data),
      );
      final queued = after.skip(before.length).map((r) => r.data['row_key']);
      expect(queued, containsAll(['kept', 'added']));
    });

    test('scan sessions are replaced by the backup\'s', () async {
      await db.customStatement(
        "INSERT INTO processing_sessions (id, status) VALUES ('s1', 'done')",
      );
      final entry = await service.createSnapshot();
      await db.customStatement(
        "INSERT INTO processing_sessions (id, status) VALUES ('s2', 'new')",
      );

      await service.restoreFromFile(entry.filePath);

      final ids = await db
          .customSelect('SELECT id FROM processing_sessions')
          .get();
      expect(ids.map((r) => r.data['id']), ['s1']);
    });

    test('restoring the safety copy brings everything back, files '
        'included', () async {
      await insertDocument(db, 'early', []);
      final older = await service.createSnapshot(name: 'older');
      docFile('scan.pdf');
      await insertDocument(db, 'later', ['file://scan.pdf']);
      final safety = await service.createSnapshot(
        name: 'Before restore',
        isSafetyCopy: true,
      );

      await service.restoreFromFile(older.filePath);
      expect(await resourceIds(db), ['early']);
      // The file stays; a cleaner may remove it later.
      File(p.join(docs.path, 'scan.pdf')).deleteSync();

      final result = await service.restoreFromFile(safety.filePath);

      expect(safety.isSafetyCopy, isTrue);
      expect(await resourceIds(db), ['early', 'later']);
      expect(result.filesAdded, 1);
      expect(docNames(), ['scan.pdf']);
    });
  });

  group('deleting and expiring backups', () {
    test(
      'deleting a backup removes its database, metadata and files',
      () async {
        docFile('scan.pdf');
        await insertDocument(db, 'd1', ['file://scan.pdf']);
        final entry = await service.createSnapshot();

        await service.deleteBackup(entry.id);

        expect(File(entry.filePath).existsSync(), isFalse);
        expect(File('${entry.filePath}.meta.json').existsSync(), isFalse);
        expect(Directory(filesDirOf(entry)).existsSync(), isFalse);
        expect(dir.listSync(), isEmpty);
        expect(docNames(), ['scan.pdf']);
      },
    );

    test('safety copies older than 30 days go after the next backup; user '
        'backups never', () async {
      final now = DateTime.now();
      final oldSafety = await service.createSnapshot(isSafetyCopy: true);
      await service.saveBackupMetadata(
        oldSafety.copyWith(timestamp: now.subtract(const Duration(days: 31))),
      );
      final recentSafety = await service.createSnapshot(isSafetyCopy: true);
      await service.saveBackupMetadata(
        recentSafety.copyWith(
          timestamp: now.subtract(const Duration(days: 29)),
        ),
      );
      final oldUser = await service.createSnapshot(name: 'mine');
      await service.saveBackupMetadata(
        oldUser.copyWith(timestamp: now.subtract(const Duration(days: 400))),
      );

      final latest = await service.createSnapshot();

      final ids = (await service.listBackups()).map((e) => e.id).toSet();
      expect(ids, {recentSafety.id, oldUser.id, latest.id});
      expect(File(oldSafety.filePath).existsSync(), isFalse);
    });

    test('expired safety copies are deleted at start-up', () async {
      final safety = await service.createSnapshot(isSafetyCopy: true);

      expect(
        await service.deleteExpiredSafetyCopies(
          now: DateTime.now().add(const Duration(days: 29)),
        ),
        0,
      );
      await service.saveBackupMetadata(
        safety.copyWith(
          timestamp: DateTime.now().subtract(const Duration(days: 31)),
        ),
      );
      await service.cleanUpOnStartup();

      expect(await service.listBackups(), isEmpty);
    });
  });
}
