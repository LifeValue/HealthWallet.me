import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/data/local/app_database.dart';
import 'package:health_wallet/core/services/attachment_file_cleaner.dart';
import 'package:health_wallet/core/services/attachment_files_lock.dart';
import 'package:health_wallet/core/services/attachment_references.dart';
import 'package:health_wallet/features/desktop/backup/data/services/backup_service.dart';
import 'package:health_wallet/features/desktop/lww_sync/data/services/attachment_sync_service.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'backup_test_support.dart';

/// The app's database, running [beforeRestoreCommit] when a restore starts
/// writing its rows: after it has placed its files, before its commit.
class _HookedDatabase extends AppDatabase {
  _HookedDatabase()
    : super(
        NativeDatabase.memory(
          setup: (raw) => raw.execute('PRAGMA foreign_keys = ON'),
        ),
      );

  Future<void> Function()? beforeRestoreCommit;

  @override
  Future<void> customStatement(String statement, [List<dynamic>? args]) async {
    final hook = beforeRestoreCommit;
    if (hook != null && statement.startsWith('PRAGMA wal_checkpoint')) {
      beforeRestoreCommit = null;
      await hook();
    }
    return super.customStatement(statement, args);
  }
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late Directory root;
  late Directory docs;
  late _HookedDatabase db;
  late AttachmentFilesLock lock;
  late BackupService service;
  late AttachmentFileCleaner cleaner;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('restore_cleaner_test');
    final backups = Directory(p.join(root.path, 'backups'))..createSync();
    docs = Directory(p.join(root.path, 'docs'))..createSync();
    SharedPreferences.setMockInitialValues({'backupDirectory': backups.path});
    db = _HookedDatabase();
    lock = AttachmentFilesLock();
    final paths = DocsPathResolver(docs.path);
    service = BackupService(
      db,
      FakeFolderAccess(),
      paths,
      AttachmentReferences(db),
      AttachmentSyncService(paths),
      FixedLegacyFolders(),
      filesLock: lock,
    );
    // Every file counts as old: the purge and the sweep may take it.
    cleaner = AttachmentFileCleaner.forTesting(
      db,
      paths,
      AttachmentReferences(db),
      operatingSystem: 'macos',
      now: () => DateTime.now().add(const Duration(days: 60)),
      filesLock: lock,
    );
  });

  tearDown(() async {
    await db.close();
    await root.delete(recursive: true);
  });

  /// A backup whose record refers to `scan.pdf`, then the record purged on
  /// this device, so the file it reuses looks unreferenced until the
  /// restore commits.
  Future<String> backupThenPurge() async {
    File(p.join(docs.path, 'scan.pdf')).writeAsStringSync('scan');
    await db.customStatement(
      'INSERT INTO fhir_resource (id, resource_type, resource_raw) '
      "VALUES ('d1', 'DocumentReference', ?)",
      [
        BackupFixture.docRaw(['file://scan.pdf']),
      ],
    );
    final entry = await service.createSnapshot();
    await db.customStatement("DELETE FROM fhir_resource WHERE id = 'd1'");
    return entry.filePath;
  }

  test('the purge deletes nothing while a restore reuses a file', () async {
    final backup = await backupThenPurge();
    int? deleted;
    db.beforeRestoreCommit = () async {
      deleted = await cleaner.deleteUnreferenced(['file://scan.pdf']);
    };

    final result = await service.restoreFromFile(backup);

    expect(result.filesAlreadyPresent, 1);
    expect(deleted, 0);
    expect(File(p.join(docs.path, 'scan.pdf')).existsSync(), isTrue);
  });

  test('the sweep moves nothing while a restore reuses a file', () async {
    final backup = await backupThenPurge();
    int? moved;
    db.beforeRestoreCommit = () async {
      moved = await cleaner.sweep();
    };

    await service.restoreFromFile(backup);

    expect(moved, 0);
    expect(File(p.join(docs.path, 'scan.pdf')).existsSync(), isTrue);
  });

  test('after the restore the cleaner runs again and keeps the file', () async {
    final backup = await backupThenPurge();

    await service.restoreFromFile(backup);

    expect(lock.isHeld, isFalse);
    expect(await cleaner.deleteUnreferenced(['file://scan.pdf']), 0);
    expect(await cleaner.sweep(), 0);
    expect(File(p.join(docs.path, 'scan.pdf')).existsSync(), isTrue);
  });

  group('AttachmentFilesLock', () {
    test(
      'ifFree skips while the lock is held and runs once it is free',
      () async {
        final release = Completer<void>();
        final holder = lock.exclusive(() => release.future);

        expect(await lock.ifFree(() async => 1), isNull);
        release.complete();
        await holder;
        expect(await lock.ifFree(() async => 2), 2);
      },
    );

    test('exclusive waits for the holder, one at a time', () async {
      final order = <String>[];
      final release = Completer<void>();
      final first = lock.exclusive(() async {
        order.add('first start');
        await release.future;
        order.add('first end');
      });
      final second = lock.exclusive(() async => order.add('second'));
      final third = lock.exclusive(() async => order.add('third'));

      release.complete();
      await Future.wait([first, second, third]);

      expect(order, ['first start', 'first end', 'second', 'third']);
      expect(lock.isHeld, isFalse);
    });

    test('a failing holder releases the lock', () async {
      await expectLater(
        lock.exclusive<void>(() async => throw StateError('boom')),
        throwsStateError,
      );

      expect(lock.isHeld, isFalse);
      expect(await lock.ifFree(() async => 1), 1);
    });
  });
}
