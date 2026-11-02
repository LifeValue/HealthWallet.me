import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/data/local/app_database.dart'
    show AppDatabase;
import 'package:health_wallet/features/desktop/lww_sync/data/services/attachment_sync_service.dart';
import 'package:health_wallet/features/desktop/lww_sync/data/services/lww_sync_service.dart';
import 'package:health_wallet/features/desktop/lww_sync/domain/entity/sync_batch.dart';
import 'package:health_wallet/features/records/data/data_source/shared_notes_datasource.dart';
import 'package:health_wallet/features/records/data/repository/records_repository_impl.dart';
import 'package:health_wallet/features/sync/data/data_source/local/sync_local_data_source.dart';
import 'package:health_wallet/features/sync/data/dto/fhir_resource_dto.dart';
import 'package:health_wallet/features/sync/domain/entities/source.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'lww_sync_test_helpers.dart';

/// One device: its database, its LWW service and the repositories the app
/// deletes and reads through.
class _Device {
  _Device(this.db, this.sync, this.syncLocal, this.records);

  final AppDatabase db;
  final LwwSyncService sync;
  final SyncLocalDataSourceImpl syncLocal;
  final RecordsRepositoryImpl records;

  /// The outbox position the other device acknowledged.
  int acked = 0;

  Future<List<String>> recordIds() async =>
      (await records.getResources(limit: 100)).map((r) => r.id).toList()
        ..sort();

  Future<List<String>> noteContents(String resourceId) async =>
      (await records.getRecordNotes(resourceId)).map((n) => n.content).toList();

  Future<List<String>> sourceIds() async =>
      (await syncLocal.getSources()).map((s) => s.id).toList()..sort();
}

void main() {
  late TestDirs dirs;
  late _Device phone;
  late _Device desktop;

  Future<_Device> device(String name) async {
    final db = openTestDatabase();
    final docs = Directory('${dirs.root.path}/$name')..createSync();
    final prefs = await SharedPreferences.getInstance();
    final syncLocal = SyncLocalDataSourceImpl(db, prefs);
    return _Device(
      db,
      LwwSyncService(
        db,
        prefs,
        AttachmentSyncService(FakePathResolver(docs.path)),
      ),
      syncLocal,
      RecordsRepositoryImpl(
        db,
        syncLocal,
        SharedNotesDatasource(),
        FakePathResolver(docs.path),
      ),
    );
  }

  setUp(() async {
    dirs = await TestDirs.create();
    SharedPreferences.setMockInitialValues({
      'lww_local_device_id': 'device-local',
    });
    phone = await device('phone');
    desktop = await device('desktop');
  });

  tearDown(() async {
    await phone.db.close();
    await desktop.db.close();
    await dirs.dispose();
  });

  /// Sends what [from] has waiting in its outbox to [to] through the JSON
  /// wire format, one acknowledged batch at a time, as `sync.batch` does.
  /// With [reconcile], [from] first queues every row [to] lacks or holds an
  /// older copy of, as a digest mismatch on connecting makes it do.
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
  /// in the past so every later change is newer, and syncs it to the
  /// desktop.
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
      await phone.db.customStatement(
        'UPDATE $table SET updated_at = ?',
        [ms(at(0))],
      );
    }
    await send(phone, desktop, reconcile: true);
    expect(await desktop.recordIds(), ['lab-1', 'obs-1', 'obs-2']);
  }

  test('a record, note and source deleted on the phone stay deleted on the '
      'desktop, also after a full-table resend', () async {
    await seedAndSync();
    final drop = (await phone.records.getRecordNotes(
      'obs-2',
    )).firstWhere((n) => n.content == 'drop');

    await phone.records.deleteResource('obs-1');
    await phone.records.deleteRecordNote(drop);
    await phone.syncLocal.deleteSource('lab');
    await send(phone, desktop);

    for (final d in [phone, desktop]) {
      expect(await d.recordIds(), ['obs-2']);
      expect(await d.noteContents('obs-2'), ['keep']);
      expect(await d.sourceIds(), ['clinic']);
    }
    expect(
      await desktop.sync.computeDigest(),
      await phone.sync.computeDigest(),
    );

    // Both reconcile everything, as on the next connection.
    await send(desktop, phone, reconcile: true);
    await send(phone, desktop, reconcile: true);

    for (final d in [phone, desktop]) {
      expect(await d.recordIds(), ['obs-2']);
      expect(await d.noteContents('obs-2'), ['keep']);
      expect(await d.sourceIds(), ['clinic']);
    }
  });

  test('after the 30-day purge nothing reappears, whichever device purges '
      'first', () async {
    await seedAndSync();
    await phone.records.deleteResource('obs-2');
    await send(phone, desktop);

    /// Moves every delete on [d] 31 days into the past, as if that device
    /// had not been opened for a month.
    Future<void> ageDeletes(_Device d) async {
      final old = ms(DateTime.now().subtract(const Duration(days: 31)));
      for (final table in LwwSyncService.syncedTables) {
        await d.db.customStatement(
          'UPDATE $table SET deleted_at = ?, updated_at = ? '
          'WHERE deleted_at IS NOT NULL',
          [old, old],
        );
      }
    }

    Future<int> rowsIn(_Device d, String table) async =>
        (await d.db
                    .customSelect('SELECT COUNT(*) AS c FROM $table')
                    .getSingle())
                .data['c']
            as int;

    // The desktop is restarted a month later and purges; the phone still
    // holds its tombstones.
    await ageDeletes(desktop);
    expect(await desktop.sync.cleanupTombstones(), greaterThan(0));
    expect(await rowsIn(desktop, 'record_notes'), 0);

    // Reconciling both ways: the phone's tombstones come back to the
    // desktop as tombstones, never as live records.
    await send(phone, desktop, reconcile: true);
    await send(desktop, phone, reconcile: true);
    for (final d in [phone, desktop]) {
      expect(await d.recordIds(), ['lab-1', 'obs-1']);
      expect(await d.noteContents('obs-2'), isEmpty);
    }

    // Then both have purged: the deleted rows are gone for good, and another
    // exchange brings nothing back.
    await ageDeletes(phone);
    await ageDeletes(desktop);
    await phone.sync.cleanupTombstones();
    await desktop.sync.cleanupTombstones();
    await send(phone, desktop, reconcile: true);
    await send(desktop, phone, reconcile: true);

    for (final d in [phone, desktop]) {
      expect(await d.recordIds(), ['lab-1', 'obs-1']);
      expect(await d.noteContents('obs-2'), isEmpty);
      expect(await d.sourceIds(), ['clinic', 'lab']);
      expect(await rowsIn(d, 'record_notes'), 0);
      expect(
        await d.db
            .customSelect(
              'SELECT id FROM fhir_resource WHERE deleted_at IS NOT NULL',
            )
            .get(),
        isEmpty,
      );
    }
    expect(
      await desktop.sync.computeDigest(),
      await phone.sync.computeDigest(),
    );
  });

  test('a record deleted on the desktop stays deleted on the phone', () async {
    await seedAndSync();

    await desktop.records.deleteResourcesByIds(['obs-2']);
    await send(desktop, phone);
    await send(phone, desktop, reconcile: true);

    expect(await phone.recordIds(), ['lab-1', 'obs-1']);
    expect(await phone.noteContents('obs-2'), isEmpty);
    expect(await desktop.recordIds(), ['lab-1', 'obs-1']);
  });

  test('an edit on the desktop made after the delete resurrects the record '
      'on both', () async {
    await seedAndSync();
    await phone.records.deleteResource('obs-1');
    final tombstone =
        (await fetchRow(phone.db, 'fhir_resource', 'obs-1'))!['updated_at']
            as int;

    // The desktop had not received the delete and edits the record later.
    await desktop.db.customStatement(
      "UPDATE fhir_resource SET title = 'edited', updated_at = ? "
      "WHERE id = 'obs-1'",
      [tombstone + 1],
    );
    await send(phone, desktop);
    await send(desktop, phone);

    for (final d in [phone, desktop]) {
      expect(await d.recordIds(), ['lab-1', 'obs-1', 'obs-2']);
      expect(
        (await fetchRow(d.db, 'fhir_resource', 'obs-1'))!['title'],
        'edited',
      );
    }
  });

  test('re-adding a deleted record on the phone brings it back on the '
      'desktop', () async {
    await seedAndSync();
    await phone.records.deleteResource('obs-1');
    await send(phone, desktop);

    // A re-added row is stamped when it is inserted; in the same
    // millisecond as the delete it would tie with the tombstone.
    await Future<void>.delayed(const Duration(milliseconds: 2));
    await phone.syncLocal.cacheFhirResources([observation('obs-1')]);
    await send(phone, desktop);

    expect(await desktop.recordIds(), ['lab-1', 'obs-1', 'obs-2']);
  });

  test('a row hard-deleted on one device comes back from the other', () async {
    await seedAndSync();

    // A local wipe, which is not a delete the other device learns of.
    await desktop.db.customStatement(
      "DELETE FROM fhir_resource WHERE id = 'obs-1'",
    );
    await send(phone, desktop, reconcile: true);

    expect(await desktop.recordIds(), ['lab-1', 'obs-1', 'obs-2']);
  });

  test('deleting a note leaves a different note with the same id on the '
      'other device', () async {
    // Each device numbers its notes with its own autoincrement; they sync on
    // their uuid, so the desktop's note #1 and the phone's note #1 stay two
    // notes.
    await phone.records.addRecordNote(resourceId: 'obs-1', content: 'phone');
    await desktop.records.addRecordNote(
      resourceId: 'obs-9',
      content: 'desktop',
    );
    final phoneNote = (await phone.records.getRecordNotes('obs-1')).single;

    await phone.records.deleteRecordNote(phoneNote);
    await send(phone, desktop, reconcile: true);

    expect(await desktop.noteContents('obs-9'), ['desktop']);
  });
}
