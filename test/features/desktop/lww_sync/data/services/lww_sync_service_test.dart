import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/data/local/app_database.dart';
import 'package:health_wallet/features/desktop/lww_sync/data/services/attachment_sync_service.dart';
import 'package:health_wallet/features/desktop/lww_sync/data/services/lww_sync_service.dart';
import 'package:health_wallet/features/desktop/lww_sync/domain/entity/sync_batch.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../lww_sync_test_helpers.dart';

void main() {
  late TestDirs dirs;
  late AppDatabase db;
  late SharedPreferences prefs;
  late LwwSyncService service;

  final pdfBytes = utf8.encode('%PDF-1.7 fake');

  SyncBatch incoming(
    String table,
    List<Map<String, dynamic>> rows, {
    String deviceId = 'device-m',
    int id = 1,
  }) => SyncBatch(id: id, deviceId: deviceId, tables: {table: rows});

  Map<String, dynamic> fhirRow(
    String id, {
    required int updatedAt,
    String title = 'remote',
    String resourceType = 'Observation',
    String? raw,
    int? deletedAt,
  }) => {
    'id': id,
    'resource_type': resourceType,
    'resource_raw': raw ?? jsonEncode({'resourceType': resourceType}),
    'title': title,
    'updated_at': updatedAt,
    'deleted_at': deletedAt,
  };

  Future<String?> titleOf(String id) async =>
      (await fetchRow(db, 'fhir_resource', id))?['title'] as String?;

  Future<int?> stampOf(String id) async =>
      (await fetchRow(db, 'fhir_resource', id))?['updated_at'] as int?;

  Future<int> outboxSize() => countRows(db, 'sync_outbox');

  setUp(() async {
    dirs = await TestDirs.create();
    db = openTestDatabase();
    SharedPreferences.setMockInitialValues({
      'lww_local_device_id': 'device-local',
    });
    prefs = await SharedPreferences.getInstance();
    service = LwwSyncService(
      db,
      prefs,
      AttachmentSyncService(FakePathResolver(dirs.docs.path)),
    );
  });

  tearDown(() async {
    await db.close();
    await dirs.dispose();
  });

  test('syncs exactly sources, fhir_resource and record_notes, in that '
      'order', () {
    expect(LwwSyncService.syncedTables, [
      'sources',
      'fhir_resource',
      'record_notes',
    ]);
  });

  group('the outbox', () {
    test('every local write is waiting until acknowledged', () async {
      expect(await service.nextBatch(0), isNull);

      await insertFhir(db, id: 'a', title: 'first');
      await insertSource(db, id: 's');
      await db.customStatement(
        "UPDATE fhir_resource SET title = 'again' WHERE id = 'a'",
      );

      expect(await service.pendingCount(0), 2);
      final batch = (await service.nextBatch(0))!;
      expect(batch.deviceId, 'device-local');
      expect(batch.tables['fhir_resource']!.single['title'], 'again');
      expect(batch.tables['sources']!.single['id'], 's');

      // Nothing moves without an acknowledgement: the same rows come again.
      expect((await service.nextBatch(0))!.id, batch.id);

      await service.pruneOutbox(batch.id);
      expect(await service.nextBatch(batch.id), isNull);
      expect(await service.pendingCount(batch.id), 0);
    });

    test(
      'an edit made in the same second after a send is still sent',
      () async {
        await insertFhir(db, id: 'a', title: 'one');
        final first = (await service.nextBatch(0))!;
        await service.pruneOutbox(first.id);

        await db.customStatement(
          "UPDATE fhir_resource SET title = 'two' WHERE id = 'a'",
        );
        final second = (await service.nextBatch(first.id))!;
        expect(second.tables['fhir_resource']!.single['title'], 'two');
      },
    );

    test('a batch stops at the row limit and continues from there', () async {
      for (var i = 0; i < LwwSyncService.maxBatchRows + 5; i++) {
        await insertFhir(db, id: 'r$i');
      }
      final first = (await service.nextBatch(0))!;
      expect(
        first.tables['fhir_resource'],
        hasLength(LwwSyncService.maxBatchRows),
      );
      final second = (await service.nextBatch(first.id))!;
      expect(second.tables['fhir_resource'], hasLength(5));
    });

    test('rows deleted since they were logged make an empty batch', () async {
      await insertFhir(db, id: 'gone');
      await db.customStatement("DELETE FROM fhir_resource WHERE id = 'gone'");
      final batch = (await service.nextBatch(0))!;
      expect(batch.tables, isEmpty);
      expect(batch.id, greaterThan(0));
    });

    test('a note is logged under its uuid', () async {
      await insertNote(db, id: 4, content: 'hi');
      final batch = (await service.nextBatch(0))!;
      expect(batch.tables['record_notes']!.single['uuid'], 'legacy-4');
    });
  });

  group('applying a batch', () {
    test('inserts a missing row, keeping its updated_at', () async {
      await service.applyBatch(
        incoming('fhir_resource', [fhirRow('a', updatedAt: ms(at(1)))]),
      );
      expect(await titleOf('a'), 'remote');
      expect(await stampOf('a'), ms(at(1)));
    });

    test('newer wins, older loses, by the millisecond', () async {
      await insertFhir(db, id: 'a', updatedAt: ms(at(1)), title: 'local');
      await service.applyBatch(
        incoming('fhir_resource', [
          fhirRow('a', updatedAt: ms(at(1)) - 1, title: 'older'),
        ]),
      );
      expect(await titleOf('a'), 'local');

      await service.applyBatch(
        incoming('fhir_resource', [
          fhirRow('a', updatedAt: ms(at(1)) + 1, title: 'newer'),
        ]),
      );
      expect(await titleOf('a'), 'newer');
      expect(await stampOf('a'), ms(at(1)) + 1);
    });

    test('a tie goes to the larger device id, the same answer on both '
        'sides, and keeps the stamp', () async {
      await insertFhir(db, id: 'a', updatedAt: ms(at(1)), title: 'local');
      await service.applyBatch(
        incoming('fhir_resource', [
          fhirRow('a', updatedAt: ms(at(1)), title: 'smaller'),
        ], deviceId: 'device-a'),
      );
      expect(await titleOf('a'), 'local');

      await service.applyBatch(
        incoming('fhir_resource', [
          fhirRow('a', updatedAt: ms(at(1)), title: 'larger'),
        ], deviceId: 'device-z'),
      );
      expect(await titleOf('a'), 'larger');
      expect(await stampOf('a'), ms(at(1)), reason: 'not re-stamped');
    });

    test('a row delivered again is not written again', () async {
      final row = fhirRow('a', updatedAt: ms(at(1)), title: 'same');
      final first = await service.applyBatch(incoming('fhir_resource', [row]));
      final again = await service.applyBatch(incoming('fhir_resource', [row]));
      expect(first.count, 1);
      expect(again.count, 0);
      expect(await stampOf('a'), ms(at(1)));
    });

    test("the peer's rows don't go back into the outbox", () async {
      await service.applyBatch(
        incoming('fhir_resource', [fhirRow('a', updatedAt: ms(at(1)))]),
      );
      await service.applyBatch(
        incoming('fhir_resource', [
          fhirRow('a', updatedAt: ms(at(2)), title: 'edited'),
        ]),
      );
      expect(await outboxSize(), 0);
      expect(await service.nextBatch(0), isNull);
    });

    test('unknown columns are dropped, so a newer peer and a hostile key '
        'neither abort nor run SQL', () async {
      await db.customStatement(
        "INSERT INTO processing_sessions (id, status) VALUES ('p', 'secret')",
      );
      const injected =
          'resource_raw, updated_at) SELECT ?, (SELECT group_concat(status) '
          'FROM processing_sessions), 9999999999999 WHERE ? IS NOT NULL --';
      final applied = await service.applyBatch(
        incoming('fhir_resource', [
          {
            ...fhirRow('a', updatedAt: ms(at(1)), title: 'kept'),
            'column_from_v14': 'x',
            injected: 'x',
          },
        ]),
      );
      expect(applied.count, 1);
      expect(await titleOf('a'), 'kept');
      final raw = (await fetchRow(db, 'fhir_resource', 'a'))!['resource_raw'];
      expect(raw, isNot(contains('secret')));
    });

    test('rows of tables outside the synced set are ignored', () async {
      final applied = await service.applyBatch(
        SyncBatch(
          id: 1,
          deviceId: 'device-m',
          tables: {
            'processing_sessions': [
              {'id': 'p', 'status': 'x', 'updated_at': ms(at(1))},
            ],
          },
        ),
      );
      expect(applied.count, 0);
      expect(await countRows(db, 'processing_sessions'), 0);
    });

    test(
      'one row that fails a constraint does not hold back the others',
      () async {
        final applied = await service.applyBatch(
          SyncBatch(
            id: 1,
            deviceId: 'device-m',
            tables: {
              'fhir_resource': [fhirRow('ok', updatedAt: ms(at(1)))],
              'record_notes': [
                {
                  'id': 1,
                  'uuid': 'n1',
                  'resource_id': 'ok',
                  'source_id': 'no-such-source',
                  'content': 'orphan',
                  'timestamp': 0,
                  'updated_at': ms(at(1)),
                },
              ],
            },
          ),
        );
        expect(applied.rows['fhir_resource'], ['ok']);
        expect(applied.rows['record_notes'], isNull);
        expect(await outboxSize(), 0);
      },
    );

    test('a note matches on its uuid and keeps its local id when the '
        "peer's id is taken", () async {
      await insertNote(db, id: 7, content: 'local note');
      await service.applyBatch(
        incoming('record_notes', [
          {
            'id': 7,
            'uuid': 'from-peer',
            'resource_id': 'obs-1',
            'content': 'peer note',
            'timestamp': 0,
            'updated_at': ms(at(1)),
          },
        ]),
      );
      final notes = await db
          .customSelect(
            'SELECT id, uuid, content FROM record_notes ORDER BY id',
          )
          .get();
      expect(notes.map((r) => r.data['content']), ['local note', 'peer note']);
      expect(notes.last.data['uuid'], 'from-peer');
      expect(notes.last.data['id'], isNot(7));
    });

    test('an older DocumentReference replaces a local one whose file is '
        'missing', () async {
      await insertFhir(
        db,
        id: 'doc',
        resourceType: 'DocumentReference',
        updatedAt: ms(at(5)),
        raw: documentReferenceRaw([
          {'url': 'file://gone.pdf'},
        ]),
      );
      await dirs.writeDoc('present.pdf', pdfBytes);
      await service.applyBatch(
        incoming('fhir_resource', [
          fhirRow(
            'doc',
            updatedAt: ms(at(1)),
            resourceType: 'DocumentReference',
            raw: documentReferenceRaw([
              {'url': 'file://present.pdf'},
            ]),
          ),
        ]),
      );
      expect(
        (await fetchRow(db, 'fhir_resource', 'doc'))!['resource_raw'],
        contains('present.pdf'),
      );
    });

    test('a newer DocumentReference keeps the local file of an attachment '
        'it names differently', () async {
      await dirs.writeDoc('mine_1234.pdf', pdfBytes);
      await insertFhir(
        db,
        id: 'doc',
        resourceType: 'DocumentReference',
        updatedAt: ms(at(1)),
        raw: documentReferenceRaw([
          {'url': 'file://mine_1234.pdf', 'title': 'Lab'},
        ]),
      );
      await service.applyBatch(
        incoming('fhir_resource', [
          fhirRow(
            'doc',
            updatedAt: ms(at(2)),
            title: 'edited',
            resourceType: 'DocumentReference',
            raw: documentReferenceRaw([
              {'url': 'file://theirs.pdf', 'title': 'Lab'},
            ]),
          ),
        ]),
      );
      final raw =
          (await fetchRow(db, 'fhir_resource', 'doc'))!['resource_raw']
              as String;
      expect(raw, contains('mine_1234.pdf'));
      expect(await titleOf('doc'), 'edited');
    });

    test('an older live row does not resurrect a local tombstoned document '
        'whose file was removed', () async {
      await insertFhir(
        db,
        id: 'doc',
        updatedAt: ms(at(5)),
        deletedAt: ms(at(5)),
        resourceType: 'DocumentReference',
        title: 'deleted',
        raw: documentReferenceRaw([
          {'url': 'file://removed.pdf'},
        ]),
      );

      final applied = await service.applyBatch(
        incoming('fhir_resource', [
          fhirRow(
            'doc',
            updatedAt: ms(at(1)),
            resourceType: 'DocumentReference',
          ),
        ]),
      );

      expect(applied.count, 0);
      final row = await fetchRow(db, 'fhir_resource', 'doc');
      expect(row!['deleted_at'], ms(at(5)));
      expect(row['title'], 'deleted');
    });

    test('an older tombstone does not delete a newer local document whose '
        'file is missing', () async {
      await insertFhir(
        db,
        id: 'doc',
        updatedAt: ms(at(5)),
        resourceType: 'DocumentReference',
        title: 'edited later',
        raw: documentReferenceRaw([
          {'url': 'file://lost.pdf'},
        ]),
      );

      final applied = await service.applyBatch(
        incoming('fhir_resource', [
          fhirRow(
            'doc',
            updatedAt: ms(at(1)),
            deletedAt: ms(at(1)),
            resourceType: 'DocumentReference',
          ),
        ]),
      );

      expect(applied.count, 0);
      final row = await fetchRow(db, 'fhir_resource', 'doc');
      expect(row!['deleted_at'], isNull);
      expect(row['title'], 'edited later');
    });

    test('a newer tombstone still replaces a local document whose file is '
        'missing', () async {
      await insertFhir(
        db,
        id: 'doc',
        updatedAt: ms(at(1)),
        resourceType: 'DocumentReference',
        raw: documentReferenceRaw([
          {'url': 'file://lost.pdf'},
        ]),
      );

      final applied = await service.applyBatch(
        incoming('fhir_resource', [
          fhirRow(
            'doc',
            updatedAt: ms(at(5)),
            deletedAt: ms(at(5)),
            resourceType: 'DocumentReference',
          ),
        ]),
      );

      expect(applied.count, 1);
      expect(
        (await fetchRow(db, 'fhir_resource', 'doc'))!['deleted_at'],
        ms(at(5)),
      );
    });

    test(
      'a tombstoned DocumentReference asks for no file and serves none',
      () async {
        await dirs.writeDoc('r.pdf', pdfBytes);
        for (final (id, url) in [('kept', 'r.pdf'), ('lost', 'gone.pdf')]) {
          await insertFhir(
            db,
            id: id,
            updatedAt: ms(at(1)),
            deletedAt: ms(at(1)),
            resourceType: 'DocumentReference',
            raw: documentReferenceRaw([
              {'url': 'file://$url'},
            ]),
          );
        }

        expect(await service.missingAttachmentPaths(), isEmpty);
        expect(await service.fileForRequest('r.pdf'), isNull);
      },
    );
  });

  group('reconciliation', () {
    late AppDatabase otherDb;
    late LwwSyncService other;

    setUp(() async {
      otherDb = openTestDatabase();
      other = LwwSyncService(
        otherDb,
        prefs,
        AttachmentSyncService(FakePathResolver(dirs.docs.path)),
      );
    });

    tearDown(() => otherDb.close());

    test('the digest is the same for the same rows and changes with any '
        'row', () async {
      for (final d in [db, otherDb]) {
        await insertFhir(d, id: 'a', updatedAt: ms(at(1)));
        await insertSource(d, id: 's', updatedAt: ms(at(1)));
      }
      expect(await service.computeDigest(), await other.computeDigest());

      await otherDb.customStatement(
        "UPDATE fhir_resource SET updated_at = ${ms(at(2))} WHERE id = 'a'",
      );
      final mine = await service.computeDigest();
      final theirs = await other.computeDigest();
      expect(mine['sources'], theirs['sources']);
      expect(mine['fhir_resource'], isNot(theirs['fhir_resource']));
    });

    test('queues only the rows the peer lacks or holds older', () async {
      await insertFhir(db, id: 'only-here', updatedAt: ms(at(1)));
      await insertFhir(db, id: 'newer-here', updatedAt: ms(at(5)));
      await insertFhir(db, id: 'newer-there', updatedAt: ms(at(1)));
      await insertFhir(db, id: 'same', updatedAt: ms(at(3)));
      await service.pruneOutbox(await service.currentOutboxSeq());

      final queued = await service.queueRowsNewerThan('fhir_resource', {
        'newer-here': ms(at(1)),
        'newer-there': ms(at(9)),
        'same': ms(at(3)),
        'only-there': ms(at(1)),
      });
      expect(queued, 2);
      final batch = (await service.nextBatch(0))!;
      expect(
        batch.tables['fhir_resource']!.map((r) => r['id']).toSet(),
        {'only-here', 'newer-here'},
      );
    });

    test('two devices converge through manifests and batches', () async {
      await insertFhir(db, id: 'a', updatedAt: ms(at(1)), title: 'phone');
      await insertFhir(otherDb, id: 'a', updatedAt: ms(at(2)), title: 'desk');
      await insertFhir(db, id: 'b', updatedAt: ms(at(1)));
      await insertFhir(otherDb, id: 'c', updatedAt: ms(at(1)));
      await service.pruneOutbox(await service.currentOutboxSeq());
      await other.pruneOutbox(await other.currentOutboxSeq());

      Future<void> send(LwwSyncService from, LwwSyncService to) async {
        var after = 0;
        while (true) {
          final batch = await from.nextBatch(after);
          if (batch == null) return;
          await to.applyBatch(
            SyncBatch.fromJson(jsonDecode(jsonEncode(batch.toJson()))),
          );
          after = batch.id;
        }
      }

      for (final table in LwwSyncService.syncedTables) {
        await service.queueRowsNewerThan(table, await other.manifest(table));
        await other.queueRowsNewerThan(table, await service.manifest(table));
      }
      await send(service, other);
      await send(other, service);

      expect(await service.computeDigest(), await other.computeDigest());
      expect(await titleOf('a'), 'desk');
      expect(await fetchRow(db, 'fhir_resource', 'c'), isNotNull);
      expect(await fetchRow(otherDb, 'fhir_resource', 'b'), isNotNull);
    });
  });

  group('the peer', () {
    test('a new peer starts after what is already logged; the same peer '
        'keeps its place; another peer starts over', () async {
      await insertFhir(db, id: 'before-pairing');
      final first = await service.peerStateFor('desk-A', peerName: 'Desk A');
      expect(first.ackedSeq, await service.currentOutboxSeq());
      expect(await outboxSize(), 0, reason: 'reconciled instead');

      await insertFhir(db, id: 'later');
      await service.savePeerState(first.copyWith(ackedSeq: 0));
      expect((await service.peerStateFor('desk-A')).ackedSeq, 0);

      final other = await service.peerStateFor('desk-B', peerName: 'Desk B');
      expect(other.ackedSeq, await service.currentOutboxSeq());
      expect(other.peerName, 'Desk B');
      expect(other.lastSyncAt, isNull);
    });

    test('resetPeerState forgets the peer', () async {
      await service.peerStateFor('desk-A');
      await service.resetPeerState();
      expect(service.loadPeerState(), isNull);
    });
  });

  group('attachment files', () {
    Future<void> insertDoc(String id, List<Map<String, dynamic>> attachments) =>
        insertFhir(
          db,
          id: id,
          resourceType: 'DocumentReference',
          updatedAt: ms(at(1)),
          raw: documentReferenceRaw(attachments),
        );

    test('lists the missing files of the given documents only', () async {
      await dirs.writeDoc('here.pdf', pdfBytes);
      await insertDoc('d1', [
        {'url': 'file://here.pdf'},
        {'url': 'file://lab%20result.pdf'},
      ]);
      await insertDoc('d2', [
        {'url': 'file://other.pdf'},
      ]);
      expect(await service.missingAttachmentPaths(['d1']), ['lab result.pdf']);
      expect(
        (await service.missingAttachmentPaths()).toSet(),
        {'lab result.pdf', 'other.pdf'},
      );
    });

    test('serves only files a live DocumentReference refers to', () async {
      await dirs.writeDoc('report.pdf', pdfBytes);
      await dirs.writeDoc('ai_models/model.gguf', [1, 2, 3]);
      await dirs.writeDoc('db.sqlite', [1]);
      await insertDoc('d', [
        {'url': 'file://report.pdf'},
      ]);
      expect(await service.fileForRequest('report.pdf'), isNotNull);
      expect(await service.fileForRequest('ai_models/model.gguf'), isNull);
      expect(await service.fileForRequest('db.sqlite'), isNull);
      expect(await service.fileForRequest('../report.pdf'), isNull);
    });

    test('a file sent in chunks lands under a free name and the record '
        'points at it, without counting as an edit', () async {
      final bytes = Uint8List.fromList(
        List.generate(LwwSyncService.fileChunkBytes * 2 + 10, (i) => i % 251),
      );
      final source = await dirs.writeDoc('send/Analize sânge.pdf', bytes);
      await insertDoc('d', [
        {'url': 'file://Analize%20s%C3%A2nge.pdf'},
      ]);
      await service.pruneOutbox(await service.currentOutboxSeq());
      final before = await stampOf('d');

      String? saved;
      final chunks = await service
          .readChunks('Analize sânge.pdf', source)
          .toList();
      expect(chunks, hasLength(3));
      for (final chunk in chunks) {
        saved = await service.saveChunk(chunk) ?? saved;
      }

      expect(saved, 'Analize_sânge.pdf');
      expect(dirs.docFile(saved!).readAsBytesSync(), bytes);
      final raw =
          (await fetchRow(db, 'fhir_resource', 'd'))!['resource_raw'] as String;
      expect(raw, contains('Analize_sânge.pdf'));
      expect(await service.missingAttachmentPaths(['d']), isEmpty);
      expect(await stampOf('d'), before);
      expect(await outboxSize(), 0);
    });

    test('a chunk out of order is refused and the partial file can be '
        'discarded', () async {
      await expectLater(
        service.saveChunk(
          FileChunk(path: 'x.pdf', offset: 10, total: 20, bytes: Uint8List(10)),
        ),
        throwsStateError,
      );
      await service.saveChunk(
        FileChunk(path: 'x.pdf', offset: 0, total: 20, bytes: Uint8List(10)),
      );
      await service.discardAllPartials();
      expect(
        dirs.docs.listSync().where((f) => f.path.endsWith('.part')),
        isEmpty,
      );
    });

    test(
      'a received name never replaces the database or leaves Documents',
      () async {
        for (final name in ['db.sqlite', '../../escape.pdf', '.hidden']) {
          final saved = await service.saveChunk(
            FileChunk(path: name, offset: 0, total: 1, bytes: Uint8List(1)),
          );
          expect(saved, isNot(name));
          expect(File('${dirs.docs.path}/$saved').existsSync(), isTrue);
        }
        expect(File('${dirs.root.path}/escape.pdf').existsSync(), isFalse);
      },
    );

    test(
      'a broken url is repointed only to a file of exactly that name',
      () async {
        await dirs.writeDoc('lab_results_other_patient.pdf', pdfBytes);
        await dirs.writeDoc('scan.pdf', pdfBytes);
        await insertDoc('lab', [
          {'url': 'file://lab.pdf'},
        ]);
        await insertDoc('scan', [
          {'url': 'file://old/container/scan.pdf'},
        ]);
        await service.pruneOutbox(await service.currentOutboxSeq());

        await service.fixBrokenAttachmentUrls();

        expect(
          (await fetchRow(db, 'fhir_resource', 'lab'))!['resource_raw'],
          contains('file://lab.pdf'),
        );
        expect(
          (await fetchRow(db, 'fhir_resource', 'scan'))!['resource_raw'],
          contains('"file://scan.pdf"'),
        );
        expect(await outboxSize(), 0);
      },
    );
  });

  group('housekeeping', () {
    test(
      'backfill stamps rows from before the sync columns, not as edits',
      () async {
        await dropSyncTriggers(db);
        await insertFhir(db, id: 'old');
        await service.pruneOutbox(await service.currentOutboxSeq());
        expect(await service.backfillExistingRows(), 1);
        expect(await stampOf('old'), isNotNull);
        expect(await outboxSize(), 0);
      },
    );

    test('cleanupTombstones purges a deleted source together with its deleted '
        'notes, with foreign keys on as in the app', () async {
      final old = ms(DateTime.now().subtract(const Duration(days: 40)));
      await insertSource(db, id: 'clinic', updatedAt: old, deletedAt: old);
      await insertNote(
        db,
        id: 1,
        content: 'note of a deleted source',
        sourceId: 'clinic',
        updatedAt: old,
        deletedAt: old,
      );

      expect(await service.cleanupTombstones(), 2);

      expect(await countRows(db, 'sources'), 0);
      expect(await countRows(db, 'record_notes'), 0);
    });

    test('cleanupTombstones keeps a deleted source that a newer note still '
        'points at, and purges it once the note is gone', () async {
      final old = ms(DateTime.now().subtract(const Duration(days: 40)));
      final recent = ms(DateTime.now().subtract(const Duration(days: 2)));
      await insertSource(db, id: 'clinic', updatedAt: old, deletedAt: old);
      await insertNote(
        db,
        id: 1,
        content: 'live note',
        sourceId: 'clinic',
        updatedAt: recent,
      );

      expect(await service.cleanupTombstones(), 0);
      expect(await countRows(db, 'sources'), 1);

      await db.customStatement('DELETE FROM record_notes');
      expect(await service.cleanupTombstones(), 1);
      expect(await countRows(db, 'sources'), 0);
    });

    test('tombstones older than 30 days are removed', () async {
      final old = DateTime.now().subtract(const Duration(days: 31));
      await insertFhir(db, id: 'old', deletedAt: ms(old));
      await insertFhir(db, id: 'recent', deletedAt: ms(DateTime.now()));
      expect(await service.cleanupTombstones(), 1);
      expect(await fetchRow(db, 'fhir_resource', 'recent'), isNotNull);
    });
  });
}
