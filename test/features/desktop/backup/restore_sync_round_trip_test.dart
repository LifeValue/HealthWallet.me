import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/config/constants/shared_prefs_constants.dart';
import 'package:health_wallet/core/data/local/app_database.dart'
    show AppDatabase;
import 'package:health_wallet/core/services/attachment_file_cleaner.dart';
import 'package:health_wallet/core/services/attachment_references.dart';
import 'package:health_wallet/core/services/folder_access_service.dart';
import 'package:health_wallet/core/services/path_resolver.dart';
import 'package:health_wallet/features/desktop/backup/data/services/backup_service.dart';
import 'package:health_wallet/features/desktop/backup/domain/entity/backup_entry.dart';
import 'package:health_wallet/features/desktop/lww_sync/data/services/attachment_sync_service.dart';
import 'package:health_wallet/features/desktop/lww_sync/data/services/lww_sync_service.dart';
import 'package:health_wallet/features/desktop/lww_sync/domain/entity/sync_batch.dart';
import 'package:health_wallet/features/records/data/data_source/shared_notes_datasource.dart';
import 'package:health_wallet/features/records/data/repository/records_repository_impl.dart';
import 'package:health_wallet/features/sync/data/data_source/local/sync_local_data_source.dart';
import 'package:health_wallet/features/sync/data/dto/fhir_resource_dto.dart';
import 'package:health_wallet/features/sync/domain/entities/source.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../lww_sync/lww_sync_test_helpers.dart';

/// The real [PathResolver] with a fixed documents folder.
class _DocsPathResolver extends PathResolver {
  _DocsPathResolver(this.documentsPath);

  final String documentsPath;

  @override
  Future<String> getDocumentsPath() async => documentsPath;
}

/// No macOS bookmarks in tests.
class _NoFolderAccess extends Fake implements FolderAccessService {
  @override
  Future<String?> bookmarkFor(String path) async => null;

  @override
  Future<String?> restore(String bookmark) async => null;
}

/// One device: its database, documents folder, LWW service and the
/// repositories the app writes and reads through. The desktop also backs up.
class _Device {
  _Device(this.db, this.docs, this.sync, this.syncLocal, this.records);

  final AppDatabase db;
  final Directory docs;
  final LwwSyncService sync;
  final SyncLocalDataSourceImpl syncLocal;
  final RecordsRepositoryImpl records;
  late final BackupService backups;

  /// The outbox position the other device acknowledged.
  int acked = 0;

  Future<List<String>> recordIds() async =>
      (await records.getResources(limit: 100)).map((r) => r.id).toList()
        ..sort();

  Future<List<String>> noteContents(String resourceId) async =>
      (await records.getRecordNotes(resourceId)).map((n) => n.content).toList()
        ..sort();

  Future<List<String>> sourceIds() async =>
      (await syncLocal.getSources()).map((s) => s.id).toList()..sort();

  Future<bool> isTombstone(String table, String id) async =>
      (await fetchRow(db, table, id))?['deleted_at'] != null;
}

void main() {
  late TestDirs dirs;
  late Directory backupDir;
  late _Device phone;
  late _Device desktop;

  Future<_Device> device(String name) async {
    final db = openTestDatabase();
    final docs = Directory('${dirs.root.path}/$name')..createSync();
    final prefs = await SharedPreferences.getInstance();
    final paths = _DocsPathResolver(docs.path);
    final syncLocal = SyncLocalDataSourceImpl(db, prefs);
    return _Device(
      db,
      docs,
      LwwSyncService(
        db,
        prefs,
        AttachmentSyncService(paths),
        AttachmentFileCleaner(
          db,
          paths,
          AttachmentReferences(db),
          LegacyAttachmentFolders(paths),
        ),
      ),
      syncLocal,
      RecordsRepositoryImpl(db, syncLocal, SharedNotesDatasource()),
    );
  }

  setUp(() async {
    dirs = await TestDirs.create();
    backupDir = Directory('${dirs.root.path}/backups')..createSync();
    SharedPreferences.setMockInitialValues({
      'lww_local_device_id': 'device-local',
      SharedPrefsConstants.backupDirectory: backupDir.path,
    });
    phone = await device('phone');
    desktop = await device('desktop');
    final desktopPaths = _DocsPathResolver(desktop.docs.path);
    desktop.backups = BackupService(
      desktop.db,
      _NoFolderAccess(),
      desktopPaths,
      AttachmentReferences(desktop.db),
      AttachmentSyncService(desktopPaths),
      // Its docs folder isn't a Windows Documents\HealthWallet\Documents.
      LegacyAttachmentFolders(desktopPaths),
    );
  });

  tearDown(() async {
    await phone.db.close();
    await desktop.db.close();
    await dirs.dispose();
  });

  /// Sends what [from] has waiting in its outbox to [to] through the JSON
  /// wire format, one acknowledged batch at a time, as `sync.batch` does.
  /// With [reconcile], [from] first queues every row [to] lacks or holds an
  /// older copy of, as the digest mismatch on connecting makes it do.
  Future<int> send(_Device from, _Device to, {bool reconcile = false}) async {
    if (reconcile) {
      for (final table in LwwSyncService.syncedTables) {
        await from.sync.queueRowsNewerThan(
          table,
          await to.sync.manifest(table),
        );
      }
    }
    var applied = 0;
    while (true) {
      final batch = await from.sync.nextBatch(from.acked);
      if (batch == null) break;
      final wire = jsonDecode(jsonEncode(batch.toJson()));
      applied += (await to.sync.applyBatch(
        SyncBatch.fromJson(wire as Map<String, dynamic>),
      )).count;
      from.acked = batch.id;
    }
    return applied;
  }

  /// The phone reconnects: both sides compare everything and send what the
  /// other lacks, as the digest on every connect does.
  Future<void> reconnect() async {
    await send(desktop, phone, reconcile: true);
    await send(phone, desktop, reconcile: true);
  }

  Future<void> expectSameOnBoth() async {
    expect(
      await phone.sync.computeDigest(),
      await desktop.sync.computeDigest(),
    );
  }

  FhirResourceDto observation(String id, {String sourceId = 'clinic'}) =>
      FhirResourceDto(
        resourceId: id,
        sourceId: sourceId,
        resourceType: 'Observation',
        title: id,
        resourceRaw: {
          'resourceType': 'Observation',
          'id': id,
          'status': 'final',
          'code': {'text': id},
        },
      );

  /// Seeds the phone with two sources, three records and two notes, stamped
  /// in the past, and syncs it to the desktop.
  Future<void> seedAndSync() async {
    await phone.syncLocal.cacheSources(const [
      Source(id: 'clinic', labelSource: 'Clinic'),
      Source(id: 'lab', labelSource: 'Lab'),
    ]);
    await phone.syncLocal.cacheFhirResources([
      observation('obs-1'),
      observation('obs-2'),
      observation('lab-1', sourceId: 'lab'),
    ]);
    await phone.records.addRecordNote(resourceId: 'obs-2', content: 'keep');
    await phone.records.addRecordNote(resourceId: 'obs-2', content: 'drop');
    for (final table in LwwSyncService.syncedTables) {
      await phone.db.customStatement('UPDATE $table SET updated_at = ?', [
        ms(at(0)),
      ]);
    }
    await send(phone, desktop, reconcile: true);
    expect(await desktop.recordIds(), ['lab-1', 'obs-1', 'obs-2']);
  }

  /// What the backup bloc does: a "Before restore" copy, then the restore.
  Future<BackupEntry> restore(BackupEntry backup) async {
    final safety = await desktop.backups.createSnapshot(
      name: 'Before restore',
      isSafetyCopy: true,
    );
    await desktop.backups.restoreFromFile(backup.filePath);
    return safety;
  }

  test('after a restore and a sync the phone matches the backup, and what '
      'was added since is deleted on both', () async {
    await seedAndSync();
    final backup = await desktop.backups.createSnapshot(name: 'October');

    await phone.syncLocal.cacheSources(const [
      Source(id: 'gp', labelSource: 'GP'),
    ]);
    await phone.syncLocal.cacheFhirResources([observation('obs-3')]);
    await phone.records.addRecordNote(resourceId: 'obs-1', content: 'later');
    await phone.records.deleteResource('obs-2');
    await send(phone, desktop);
    expect(await desktop.recordIds(), ['lab-1', 'obs-1', 'obs-3']);

    await restore(backup);
    await send(desktop, phone);

    for (final d in [phone, desktop]) {
      expect(await d.recordIds(), ['lab-1', 'obs-1', 'obs-2']);
      expect(await d.noteContents('obs-2'), ['drop', 'keep']);
      expect(await d.noteContents('obs-1'), isEmpty);
      expect(await d.sourceIds(), ['clinic', 'lab']);
      // Moved to deleted, not wiped.
      expect(await d.isTombstone('fhir_resource', 'obs-3'), isTrue);
      expect(await d.isTombstone('sources', 'gp'), isTrue);
    }
    await expectSameOnBoth();

    // The next connection's full comparison changes nothing.
    await reconnect();
    expect(await phone.recordIds(), ['lab-1', 'obs-1', 'obs-2']);
    await expectSameOnBoth();
  });

  test(
    'a phone whose clock runs ahead does not win over the restore',
    () async {
      await seedAndSync();
      final backup = await desktop.backups.createSnapshot(name: 'October');

      final ahead = ms(DateTime.now().add(const Duration(days: 2)));
      await phone.db.customStatement(
        "UPDATE fhir_resource SET title = 'edited', updated_at = ? "
        "WHERE id = 'obs-1'",
        [ahead],
      );
      await send(phone, desktop);
      expect(
        (await fetchRow(desktop.db, 'fhir_resource', 'obs-1'))!['title'],
        'edited',
      );

      await restore(backup);
      await send(desktop, phone);
      await reconnect();

      for (final d in [phone, desktop]) {
        final row = (await fetchRow(d.db, 'fhir_resource', 'obs-1'))!;
        expect(row['title'], 'obs-1');
        expect(row['updated_at'] as int, greaterThan(ahead));
      }
      await expectSameOnBoth();
    },
  );

  test(
    'a tombstone in the backup survives a restart before the sync',
    () async {
      await seedAndSync();
      // Deleted on the desktop long ago, and never sent: the phone still has
      // the record.
      await desktop.records.deleteResource('obs-2');
      final old = ms(DateTime.now().subtract(const Duration(days: 40)));
      await desktop.db.customStatement(
        'UPDATE fhir_resource SET deleted_at = ?, updated_at = ? '
        "WHERE id = 'obs-2'",
        [old, old],
      );
      desktop.acked = await desktop.sync.currentOutboxSeq();
      final backup = await desktop.backups.createSnapshot(name: 'October');

      await restore(backup);
      // The app restarts and purges old tombstones before the phone connects.
      await desktop.sync.cleanupTombstones();
      await send(desktop, phone);

      expect(await desktop.isTombstone('fhir_resource', 'obs-2'), isTrue);
      expect(await phone.recordIds(), ['lab-1', 'obs-1']);
      expect(await phone.isTombstone('fhir_resource', 'obs-2'), isTrue);
    },
  );

  test(
    'a current note with the id of a backed-up note is kept apart',
    () async {
      await seedAndSync();
      final backup = await desktop.backups.createSnapshot(name: 'October');
      final dropId =
          (await desktop.db
                      .customSelect(
                        "SELECT id FROM record_notes WHERE content = 'drop'",
                      )
                      .getSingle())
                  .data['id']
              as int;

      // The id now belongs to another note, as after a purge and a counter
      // that went back.
      await desktop.db.customStatement(
        'DELETE FROM record_notes WHERE id = ?',
        [
          dropId,
        ],
      );
      await desktop.db.customStatement(
        'INSERT INTO record_notes (id, uuid, resource_id, content, timestamp) '
        "VALUES (?, 'note-new', 'obs-2', 'new', ?)",
        [dropId, ms(t0) ~/ 1000],
      );
      await send(desktop, phone);
      expect(await phone.noteContents('obs-2'), ['drop', 'keep', 'new']);

      await restore(backup);
      await send(desktop, phone);

      for (final d in [phone, desktop]) {
        expect(await d.noteContents('obs-2'), ['drop', 'keep']);
      }
      final rows = await desktop.db
          .customSelect(
            'SELECT id, uuid, content, deleted_at FROM record_notes',
          )
          .get();
      final byContent = {for (final r in rows) r.data['content']: r.data};
      expect(byContent['drop']!['id'], dropId);
      expect(byContent['drop']!['deleted_at'], isNull);
      expect(byContent['new']!['id'], isNot(dropId));
      expect(byContent['new']!['uuid'], 'note-new');
      expect(byContent['new']!['deleted_at'], isNotNull);
      await expectSameOnBoth();
    },
  );

  test('an offline phone\'s unsynced records come back when it '
      'reconnects', () async {
    await seedAndSync();
    final backup = await desktop.backups.createSnapshot(name: 'October');

    // Added on the phone while it isn't connected.
    await phone.syncLocal.cacheFhirResources([observation('obs-4')]);

    await restore(backup);
    await reconnect();

    for (final d in [phone, desktop]) {
      expect(await d.recordIds(), ['lab-1', 'obs-1', 'obs-2', 'obs-4']);
    }
    await expectSameOnBoth();
  });

  test('restoring the safety copy brings everything back on both devices, '
      'files included', () async {
    await seedAndSync();
    final backup = await desktop.backups.createSnapshot(name: 'October');

    // Added on the desktop after the backup: a document and its file.
    await File('${desktop.docs.path}/report.pdf').writeAsBytes([1, 2, 3, 4]);
    await desktop.syncLocal.cacheFhirResources([
      FhirResourceDto(
        resourceId: 'doc-1',
        sourceId: 'clinic',
        resourceType: 'DocumentReference',
        title: 'Report',
        resourceRaw: jsonDecode(
          documentReferenceRaw([
            {
              'url': 'file://report.pdf',
              'contentType': 'application/pdf',
              'title': 'Report',
            },
          ]),
        ) as Map<String, dynamic>,
      ),
    ]);
    await phone.records.addRecordNote(resourceId: 'obs-1', content: 'later');
    await send(desktop, phone);
    await send(phone, desktop);

    final safety = await restore(backup);
    await send(desktop, phone);
    for (final d in [phone, desktop]) {
      expect(await d.isTombstone('fhir_resource', 'doc-1'), isTrue);
      expect(await d.noteContents('obs-1'), isEmpty);
    }
    // The restore keeps every current file.
    expect(File('${desktop.docs.path}/report.pdf').existsSync(), isTrue);

    // The record is deleted on the desktop. Its file stays until the 30-day
    // purge; remove it as the purge would, so only the backup still has it.
    await desktop.records.deleteResource('doc-1');
    expect(File('${desktop.docs.path}/report.pdf').existsSync(), isTrue);
    await File('${desktop.docs.path}/report.pdf').delete();

    // Undo: restore the "Before restore" copy.
    await restore(safety);
    await send(desktop, phone);

    for (final d in [phone, desktop]) {
      expect(await d.recordIds(), ['lab-1', 'obs-1', 'obs-2']);
      // Documents aren't listed as records; the row is live again.
      expect(await fetchRow(d.db, 'fhir_resource', 'doc-1'), isNotNull);
      expect(await d.isTombstone('fhir_resource', 'doc-1'), isFalse);
      expect(await d.noteContents('obs-1'), ['later']);
    }
    expect(
      await File('${desktop.docs.path}/report.pdf').readAsBytes(),
      [1, 2, 3, 4],
    );
    // The phone asks for the file it lacks, and the desktop has it to send.
    final wanted = await phone.sync.missingAttachmentPaths();
    expect(wanted, isNotEmpty);
    for (final path in wanted) {
      expect(await desktop.sync.fileForRequest(path), isNotNull, reason: path);
    }
    await expectSameOnBoth();
  });
}
