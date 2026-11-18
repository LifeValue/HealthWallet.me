import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart'
    show QueryExecutor, TableInfo, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/data/local/app_database.dart';
import 'package:health_wallet/core/services/attachment_references.dart';
import 'package:health_wallet/core/services/folder_access_service.dart';
import 'package:health_wallet/core/services/path_resolver.dart';
import 'package:health_wallet/features/desktop/backup/data/services/backup_service.dart';
import 'package:health_wallet/features/desktop/backup/domain/entity/backup_entry.dart';
import 'package:health_wallet/features/desktop/lww_sync/data/services/attachment_sync_service.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../../helpers/log_capture.dart';

/// Failures of the file system and the database around backups, faked with
/// [IOOverrides] and a database subclass; the happy paths are in
/// backup_service_test.dart.

class _NoFolderAccess extends Fake implements FolderAccessService {
  @override
  Future<String?> bookmarkFor(String path) async => null;

  @override
  Future<String?> restore(String bookmark) async => bookmark;
}

class _DocsPathResolver extends PathResolver {
  _DocsPathResolver(this.documentsPath);

  final String documentsPath;

  @override
  Future<String> getDocumentsPath() async => documentsPath;
}

class _BrokenPathResolver extends PathResolver {
  @override
  Future<String> getDocumentsPath() async =>
      throw const FileSystemException('documents unavailable');
}

class _NoLegacyFolders extends LegacyAttachmentFolders {
  _NoLegacyFolders() : super(_DocsPathResolver(''));

  @override
  Future<List<String>> roots() async => const [];
}

/// The app database, except that the next detach or the change notice after
/// a restore can be made to fail.
class _FlakyDatabase extends AppDatabase {
  _FlakyDatabase(QueryExecutor super.e);

  bool failNextDetach = false;
  bool failNotify = false;

  @override
  Future<void> customStatement(String statement, [List<dynamic>? args]) {
    if (failNextDetach && statement.startsWith('DETACH')) {
      failNextDetach = false;
      return Future.error(StateError('database backup_db is locked'));
    }
    return super.customStatement(statement, args);
  }

  @override
  void markTablesUpdated(Iterable<TableInfo> tables) {
    if (failNotify) throw StateError('a listener failed');
    super.markTablesUpdated(tables);
  }
}

/// A directory that exists as far as the service can tell.
class _ExistingDirectory extends Fake implements Directory {
  _ExistingDirectory(this.path);

  @override
  final String path;

  @override
  Future<bool> exists() async => true;
}

/// A directory that can't be removed (another app holds a file in it).
class _UndeletableDirectory extends Fake implements Directory {
  _UndeletableDirectory(this.path, [this._real]);

  @override
  final String path;
  final Directory? _real;

  @override
  Future<bool> exists() async => _real == null || await _real.exists();

  @override
  Future<Directory> create({bool recursive = false}) async {
    await _real?.create(recursive: recursive);
    return this;
  }

  @override
  Future<FileSystemEntity> delete({bool recursive = false}) async =>
      throw FileSystemException('in use', path);
}

/// A documents folder holding only [entries].
class _ListedDirectory extends Fake implements Directory {
  _ListedDirectory(this.path, this.entries);

  @override
  final String path;
  final List<FileSystemEntity> entries;

  @override
  Future<bool> exists() async => true;

  @override
  Stream<FileSystemEntity> list({
    bool recursive = false,
    bool followLinks = true,
  }) => Stream.fromIterable(entries);
}

/// A real file with one operation replaced by a failure.
class _FailingFile extends Fake implements File {
  _FailingFile(this._file, {this.failCopy = false, this.failDelete = false});

  final File _file;
  final bool failCopy;
  final bool failDelete;

  @override
  String get path => _file.path;

  @override
  Future<bool> exists() => _file.exists();

  @override
  Future<String> resolveSymbolicLinks() => _file.resolveSymbolicLinks();

  @override
  Stream<List<int>> openRead([int? start, int? end]) =>
      _file.openRead(start, end);

  @override
  Future<File> copy(String newPath) async {
    if (failCopy) throw FileSystemException('locked', path);
    return _file.copy(newPath);
  }

  @override
  Future<FileSystemEntity> delete({bool recursive = false}) async {
    if (failDelete) throw FileSystemException('in use', path);
    return _file.delete(recursive: recursive);
  }

  @override
  Future<File> setLastModified(DateTime time) async =>
      throw FileSystemException('read-only volume', path);
}

/// Hands out a [_FailingFile] for every path [matches] accepts.
final class _FailingFiles extends IOOverrides {
  _FailingFiles(this.matches, {this.failCopy = false, this.failDelete = false});

  final bool Function(String path) matches;
  final bool failCopy;
  final bool failDelete;

  @override
  File createFile(String path) {
    final file = super.createFile(path);
    return matches(path)
        ? _FailingFile(file, failCopy: failCopy, failDelete: failDelete)
        : file;
  }
}

/// A restore staging folder that can't be removed afterwards.
final class _StuckStaging extends IOOverrides {
  @override
  Directory createDirectory(String path) {
    final directory = super.createDirectory(path);
    return p.basename(path).startsWith('.restore-')
        ? _UndeletableDirectory(path, directory)
        : directory;
  }
}

/// Reports the first `.db` name a backup tries as taken.
final class _FirstNameTaken extends IOOverrides {
  String? taken;

  @override
  Future<FileSystemEntityType> fseGetType(String path, bool followLinks) {
    if (taken == null && path.endsWith('.db')) {
      taken = path;
      return Future.value(FileSystemEntityType.file);
    }
    return super.fseGetType(path, followLinks);
  }
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  final logs = captureLogs();

  late Directory root;
  late Directory dir;
  late Directory docs;
  late _FlakyDatabase db;
  late BackupService service;

  BackupService serviceFor({PathResolver? paths}) {
    final resolver = paths ?? _DocsPathResolver(docs.path);
    return BackupService(
      db,
      _NoFolderAccess(),
      resolver,
      AttachmentReferences(db),
      AttachmentSyncService(resolver),
      _NoLegacyFolders(),
    );
  }

  setUp(() async {
    root = await Directory.systemTemp.createTemp('backup_failures_test');
    dir = Directory(p.join(root.path, 'backups'))..createSync();
    docs = Directory(p.join(root.path, 'docs'))..createSync();
    SharedPreferences.setMockInitialValues({'backupDirectory': dir.path});
    db = _FlakyDatabase(
      NativeDatabase.memory(
        setup: (raw) => raw.execute('PRAGMA foreign_keys = ON'),
      ),
    );
    service = serviceFor();
  });

  tearDown(() async {
    await db.close();
    await root.delete(recursive: true);
  });

  Future<void> insertResource(String id) => db.customStatement(
    'INSERT INTO fhir_resource (id, resource_raw) VALUES (?, ?)',
    [id, '{}'],
  );

  Future<List<String>> resourceIds() async {
    final rows = await db
        .customSelect(
          'SELECT id FROM fhir_resource WHERE deleted_at IS NULL ORDER BY id',
        )
        .get();
    return rows.map((r) => r.data['id'] as String).toList();
  }

  Future<void> insertDocument(String id, List<String> urls) =>
      db.customStatement(
        'INSERT INTO fhir_resource (id, resource_type, resource_raw) '
        'VALUES (?, ?, ?)',
        [
          id,
          'DocumentReference',
          jsonEncode({
            'resourceType': 'DocumentReference',
            'content': [
              for (final url in urls)
                {
                  'attachment': {'url': url, 'title': 't'},
                },
            ],
          }),
        ],
      );

  Future<List<String>> urlsOf(String id) async {
    final row = await db
        .customSelect(
          "SELECT resource_raw FROM fhir_resource WHERE id = '$id'",
        )
        .getSingle();
    return [
      for (final item
          in (jsonDecode(row.data['resource_raw'] as String)['content']
              as List))
        item['attachment']['url'] as String,
    ];
  }

  File docFile(String name, String content) => File(p.join(docs.path, name))
    ..parent.createSync(recursive: true)
    ..writeAsStringSync(content);

  String filesDirOf(BackupEntry entry) =>
      '${entry.filePath.substring(0, entry.filePath.length - 3)}.files';

  bool hasStaging() =>
      docs.listSync().any((e) => p.basename(e.path).startsWith('.restore-'));

  group('backup folder', () {
    test('without a chosen folder, backups go to the default one', () async {
      await service.resetBackupDirectory();

      final backups = await IOOverrides.runZoned(
        service.getBackupDirectory,
        createDirectory: _ExistingDirectory.new,
      );

      expect(backups.path, await service.getBackupPath());
      expect(
        backups.path,
        endsWith(p.join('Documents', 'HealthWallet', 'Backups')),
      );
    });

    test('a backup never takes a name already in the folder', () async {
      final overrides = _FirstNameTaken();

      final entry = await IOOverrides.runWithIOOverrides(
        () => service.createSnapshot(name: 'mine'),
        overrides,
      );

      final taken = overrides.taken!;
      expect(entry.filePath, isNot(taken));
      expect(File(taken).existsSync(), isFalse);
      final takenMs = int.parse(
        RegExp(r'_(\d+)\.db$').firstMatch(taken)!.group(1)!,
      );
      expect(p.basename(entry.filePath), 'mine_${takenMs + 1}.db');
    });
  });

  group('restore', () {
    test('a failure after the commit is logged and the restore '
        'stands', () async {
      await insertResource('then');
      final entry = await service.createSnapshot();
      await insertResource('since');
      // Anything after the commit, here the log line announcing it.
      void failingSink(LogEvent event) {
        if ('${event.message}'.startsWith('[Backup] restored')) {
          throw StateError('log sink failed');
        }
      }

      Logger.addLogListener(failingSink);
      addTearDown(() => Logger.removeLogListener(failingSink));

      await service.restoreFromFile(entry.filePath);

      expect(await resourceIds(), ['then']);
      expect(logs, loggedWarning('error after the restore committed'));
    });

    test('a backup left attached by a failed detach is detached by the next '
        'restore', () async {
      await insertResource('then');
      final entry = await service.createSnapshot();
      await insertResource('since');
      db.failNextDetach = true;

      await service.restoreFromFile(entry.filePath);

      expect(await resourceIds(), ['then']);
      expect(logs, loggedWarning('could not detach the backup'));

      await insertResource('again');
      await service.restoreFromFile(entry.filePath);

      expect(logs, loggedWarning('backup_db was still attached'));
      expect(await resourceIds(), ['then']);
    });

    test('screens failing to hear of the restore do not undo it', () async {
      await insertResource('then');
      final entry = await service.createSnapshot();
      await insertResource('since');
      db.failNotify = true;

      await service.restoreFromFile(entry.filePath);

      expect(await resourceIds(), ['then']);
      expect(logs, loggedWarning('could not notify listeners'));
    });

    test(
      'a file already in Documents under its backup name is reused',
      () async {
        docFile('a/scan.pdf', 'first');
        docFile('b/scan.pdf', 'second');
        await insertDocument('d1', ['file://a/scan.pdf']);
        await insertDocument('d2', ['file://b/scan.pdf']);
        final entry = await service.createSnapshot();
        Directory(p.join(docs.path, 'a')).deleteSync(recursive: true);
        Directory(p.join(docs.path, 'b')).deleteSync(recursive: true);
        // The second file was backed up under another name; a copy of it
        // under that name is already here.
        final second = entry.files.singleWhere((f) => f.name != 'scan.pdf');
        docFile(second.name, 'second');

        final result = await service.restoreFromFile(entry.filePath);

        expect(result.filesAdded, 1);
        expect(result.filesAlreadyPresent, 1);
        expect(await urlsOf('d2'), [
          'file://${Uri.encodeComponent(second.name)}',
        ]);
        expect(
          File(p.join(docs.path, second.name)).readAsStringSync(),
          'second',
        );
      },
    );

    test('a restored file that cannot be re-dated is kept', () async {
      docFile('scan.pdf', 'scan');
      await insertDocument('d1', ['file://scan.pdf']);
      final entry = await service.createSnapshot();
      File(p.join(docs.path, 'scan.pdf')).deleteSync();

      final result = await IOOverrides.runWithIOOverrides(
        () => service.restoreFromFile(entry.filePath),
        _FailingFiles((path) => p.dirname(path) == docs.path),
      );

      expect(result.filesAdded, 1);
      expect(File(p.join(docs.path, 'scan.pdf')).readAsStringSync(), 'scan');
      expect(logs, loggedWarning('could not touch'));
    });

    test('a backup file with a path for a name is not restored', () async {
      docFile('scan.pdf', 'scan');
      await insertDocument('d1', ['file://scan.pdf']);
      final entry = await service.createSnapshot();
      await service.saveBackupMetadata(
        entry.copyWith(
          files: [entry.files.single.copyWith(name: '../escape.pdf')],
        ),
      );

      final result = await service.restoreFromFile(entry.filePath);

      expect(result.filesNotRestored, 1);
      expect(result.filesAdded, 0);
      expect(File(p.join(root.path, 'escape.pdf')).existsSync(), isFalse);
      expect(logs, loggedWarning('ignored a backup file named ../escape.pdf'));
    });

    test('a backup file that cannot be read is counted and the rest '
        'restores', () async {
      docFile('scan.pdf', 'scan');
      await insertDocument('d1', ['file://scan.pdf']);
      final entry = await service.createSnapshot();
      File(p.join(docs.path, 'scan.pdf')).deleteSync();
      final filesDir = filesDirOf(entry);

      final result = await IOOverrides.runWithIOOverrides(
        () => service.restoreFromFile(entry.filePath),
        _FailingFiles((path) => p.dirname(path) == filesDir, failCopy: true),
      );

      expect(result.filesNotRestored, 1);
      expect(result.filesAdded, 0);
      expect(File(p.join(docs.path, 'scan.pdf')).existsSync(), isFalse);
      expect(logs, loggedWarning('scan.pdf could not be read'));
      expect(hasStaging(), isFalse);
    });

    test('a staging folder that cannot be removed is logged and removed by '
        'the next clean-up', () async {
      docFile('scan.pdf', 'scan');
      await insertDocument('d1', ['file://scan.pdf']);
      final entry = await service.createSnapshot();
      File(p.join(docs.path, 'scan.pdf')).deleteSync();

      final result = await IOOverrides.runWithIOOverrides(
        () => service.restoreFromFile(entry.filePath),
        _StuckStaging(),
      );

      expect(result.filesAdded, 1);
      expect(logs, loggedWarning('could not remove'));
      expect(hasStaging(), isTrue);

      expect(await service.removeRestoreLeftovers(), 1);
      expect(hasStaging(), isFalse);
    });
  });

  group('deleting and clean-up', () {
    test('a database file that cannot be deleted fails the delete after the '
        'rest is gone', () async {
      docFile('scan.pdf', 'scan');
      await insertDocument('d1', ['file://scan.pdf']);
      final entry = await service.createSnapshot();

      await IOOverrides.runWithIOOverrides(
        () => expectLater(
          service.deleteBackup(entry.id),
          throwsA(isA<FileSystemException>()),
        ),
        _FailingFiles((path) => path == entry.filePath, failDelete: true),
      );

      expect(logs, loggedWarning('could not delete ${entry.filePath}'));
      expect(File(entry.filePath).existsSync(), isTrue);
      expect(Directory(filesDirOf(entry)).existsSync(), isFalse);
      expect(await service.listBackups(), isEmpty);
    });

    test('an expired safety copy that cannot be deleted is logged and '
        'kept', () async {
      final safety = await service.createSnapshot(isSafetyCopy: true);
      await service.saveBackupMetadata(
        safety.copyWith(
          timestamp: DateTime.now().subtract(const Duration(days: 31)),
        ),
      );

      final deleted = await IOOverrides.runWithIOOverrides(
        service.deleteExpiredSafetyCopies,
        _FailingFiles(
          (path) => path.endsWith('.db.meta.json'),
          failDelete: true,
        ),
      );

      expect(deleted, 0);
      expect(logs, loggedWarning('could not delete safety copy ${safety.id}'));
      expect((await service.listBackups()).map((e) => e.id), [safety.id]);
    });

    test('a backup folder that cannot be opened expires nothing', () async {
      final plain = File(p.join(root.path, 'plain'))..writeAsStringSync('x');
      await service.setBackupDirectory(p.join(plain.path, 'backups'));

      expect(await service.deleteExpiredSafetyCopies(), 0);
      expect(logs, loggedWarning('could not look for expired safety copies'));
    });

    test('a leftover staging folder that cannot be removed is logged and '
        'the others still go', () async {
      final stuck = _UndeletableDirectory(p.join(docs.path, '.restore-1'));
      final gone = Directory(p.join(docs.path, '.restore-2'))..createSync();

      final removed = await IOOverrides.runZoned(
        service.removeRestoreLeftovers,
        createDirectory: (path) =>
            _ListedDirectory(path, [stuck, gone, File('x')]),
      );

      expect(removed, 1);
      expect(gone.existsSync(), isFalse);
      expect(logs, loggedWarning('could not remove ${stuck.path}'));
    });

    test('documents that cannot be found leave nothing to clean up', () async {
      final broken = serviceFor(paths: _BrokenPathResolver());

      expect(await broken.removeRestoreLeftovers(), 0);
      expect(logs, loggedWarning('could not look for restore leftovers'));
    });
  });

  test('legacyWindowsRoot reads the path with this platform\'s rules by '
      'default', () {
    final documents = p.join(p.separator, 'Users', 'ana', 'Documents');

    expect(
      LegacyAttachmentFolders.legacyWindowsRoot(
        p.join(documents, 'HealthWallet', 'Documents'),
      ),
      documents,
    );
  });
}
