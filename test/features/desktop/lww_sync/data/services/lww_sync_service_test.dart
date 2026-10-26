import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/data/local/app_database.dart';
import 'package:health_wallet/features/desktop/lww_sync/data/services/attachment_sync_service.dart';
import 'package:health_wallet/features/desktop/lww_sync/data/services/lww_sync_service.dart';
import 'package:health_wallet/features/desktop/lww_sync/domain/entity/sync_delta.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../lww_sync_test_helpers.dart';

void main() {
  late TestDirs dirs;
  late AppDatabase db;
  late SharedPreferences prefs;
  late LwwSyncService service;

  final pdfBytes = utf8.encode('%PDF-1.7 fake');

  SyncDelta incoming(
    String table,
    List<Map<String, dynamic>> rows, {
    String deviceId = 'device-m',
  }) => SyncDelta(
    tableName: table,
    rows: rows,
    deviceId: deviceId,
    timestamp: at(100),
  );

  Map<String, dynamic> fhirRow(
    String id, {
    required int updatedAt,
    String title = 'remote',
    String deviceId = 'device-m',
    String resourceType = 'Observation',
    String? raw,
    int? deletedAt,
  }) => {
    'id': id,
    'resource_type': resourceType,
    'resource_raw': raw ?? jsonEncode({'resourceType': resourceType}),
    'title': title,
    'updated_at': updatedAt,
    'device_id': deviceId,
    'deleted_at': deletedAt,
  };

  Future<String?> titleOf(String id) async =>
      (await fetchRow(db, 'fhir_resource', id))?['title'] as String?;

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

  test('syncs exactly fhir_resource, sources and record_notes', () {
    expect(LwwSyncService.syncedTables, [
      'fhir_resource',
      'sources',
      'record_notes',
    ]);
  });

  group('computeDelta', () {
    test('returns rows with updated_at at or after since', () async {
      await insertFhir(db, id: 'old', updatedAt: ms(at(0)));
      await insertFhir(db, id: 'boundary', updatedAt: ms(at(5)));
      await insertFhir(db, id: 'new', updatedAt: ms(at(9)));

      final delta = await service.computeDelta('fhir_resource', at(5));

      expect(delta.tableName, 'fhir_resource');
      expect(delta.deviceId, 'device-local');
      expect(
        delta.rows.map((r) => r['id']),
        unorderedEquals(['boundary', 'new']),
      );
      expect(delta.rows.first.keys, containsAll(['updated_at', 'deleted_at']));
    });

    test('includes tombstones so deletes can travel', () async {
      await insertSource(
        db,
        id: 'gone',
        updatedAt: ms(at(5)),
        deletedAt: ms(at(5)),
      );

      final delta = await service.computeDelta('sources', at(0));

      expect(delta.rows.single['deleted_at'], ms(at(5)));
    });

    test('embeds DocumentReference files for fhir_resource only', () async {
      await dirs.writeDoc('r.pdf', pdfBytes);
      await insertFhir(
        db,
        id: 'doc',
        updatedAt: ms(at(1)),
        resourceType: 'DocumentReference',
        raw: documentReferenceRaw([
          {'url': 'file://r.pdf', 'title': 'r.pdf'},
        ]),
      );

      final delta = await service.computeDelta('fhir_resource', at(0));

      final raw = jsonDecode(delta.rows.single['resource_raw'] as String);
      final attachment = (raw['content'] as List).single['attachment'] as Map;
      expect(base64Decode(attachment['data'] as String), pdfBytes);
      expect(attachment.containsKey('url'), isFalse);
      final stored = await fetchRow(db, 'fhir_resource', 'doc');
      expect(stored!['resource_raw'], contains('file://r.pdf'));
    });

    test('generates and persists a device id when none is stored', () async {
      await prefs.remove('lww_local_device_id');

      final first = await service.getLocalDeviceId();
      final second = await service.getLocalDeviceId();

      expect(first, matches(RegExp(r'^[0-9a-f-]{36}$')));
      expect(second, first);
      expect(prefs.getString('lww_local_device_id'), first);
    });
  });

  group('computeAllDeltas', () {
    test('only returns non-empty deltas of the synced tables', () async {
      await insertFhir(db, id: 'f', updatedAt: ms(at(1)));
      await insertNote(db, id: 1, content: 'n', updatedAt: ms(at(1)));
      await insertSource(db, id: 'old-source', updatedAt: ms(at(-10)));
      await insertProcessingSession(db, id: 'session', updatedAt: ms(at(1)));

      final deltas = await service.computeAllDeltas(at(0));

      expect(deltas.map((d) => d.tableName), ['fhir_resource', 'record_notes']);
    });

    test('returns nothing when nothing changed', () async {
      expect(await service.computeAllDeltas(at(0)), isEmpty);
    });
  });

  group('applyDelta conflict rules', () {
    test('inserts a row that does not exist locally', () async {
      final applied = await service.applyDelta(
        incoming('fhir_resource', [fhirRow('a', updatedAt: ms(at(1)))]),
      );

      expect(applied, 1);
      final row = await fetchRow(db, 'fhir_resource', 'a');
      expect(row!['title'], 'remote');
      expect(row['updated_at'], ms(at(1)), reason: 'timestamp is kept');
      expect(row['device_id'], 'device-m');
    });

    test('newer incoming row overwrites the local row', () async {
      await insertFhir(db, id: 'a', updatedAt: ms(at(1)), title: 'local');

      final applied = await service.applyDelta(
        incoming('fhir_resource', [fhirRow('a', updatedAt: ms(at(2)))]),
      );

      expect(applied, 1);
      expect(await titleOf('a'), 'remote');
      expect(
        (await fetchRow(db, 'fhir_resource', 'a'))!['updated_at'],
        ms(at(2)),
      );
    });

    test('older incoming row loses to the newer local row', () async {
      await insertFhir(db, id: 'a', updatedAt: ms(at(2)), title: 'local');

      final applied = await service.applyDelta(
        incoming('fhir_resource', [fhirRow('a', updatedAt: ms(at(1)))]),
      );

      expect(applied, 0);
      expect(await titleOf('a'), 'local');
      expect(
        (await fetchRow(db, 'fhir_resource', 'a'))!['updated_at'],
        ms(at(2)),
      );
    });

    test('a 1 ms difference is enough to decide', () async {
      await insertFhir(db, id: 'a', updatedAt: ms(at(1)), title: 'local');
      await insertFhir(db, id: 'b', updatedAt: ms(at(1)), title: 'local');

      await service.applyDelta(
        incoming('fhir_resource', [
          fhirRow('a', updatedAt: ms(at(1)) + 1),
          fhirRow('b', updatedAt: ms(at(1)) - 1),
        ]),
      );

      expect(await titleOf('a'), 'remote');
      expect(await titleOf('b'), 'local');
    });

    test('applies each row of a mixed delta on its own merits', () async {
      await insertFhir(db, id: 'keep', updatedAt: ms(at(5)), title: 'local');
      await insertFhir(db, id: 'take', updatedAt: ms(at(1)), title: 'local');

      final applied = await service.applyDelta(
        incoming('fhir_resource', [
          fhirRow('keep', updatedAt: ms(at(3))),
          fhirRow('take', updatedAt: ms(at(3))),
          fhirRow('new', updatedAt: ms(at(3))),
        ]),
      );

      expect(applied, 2);
      expect(await titleOf('keep'), 'local');
      expect(await titleOf('take'), 'remote');
      expect(await titleOf('new'), 'remote');
    });

    group('tie on updated_at (fhir_resource keeps device_id)', () {
      test('the larger incoming device id wins', () async {
        await insertFhir(
          db,
          id: 'a',
          updatedAt: ms(at(1)),
          deviceId: 'device-a',
          title: 'local',
        );

        final applied = await service.applyDelta(
          incoming('fhir_resource', [
            fhirRow('a', updatedAt: ms(at(1)), deviceId: 'device-b'),
          ], deviceId: 'device-b'),
        );

        expect(applied, 1);
        expect(await titleOf('a'), 'remote');
      });

      test('the smaller incoming device id loses', () async {
        await insertFhir(
          db,
          id: 'a',
          updatedAt: ms(at(1)),
          deviceId: 'device-b',
          title: 'local',
        );

        final applied = await service.applyDelta(
          incoming('fhir_resource', [
            fhirRow('a', updatedAt: ms(at(1))),
          ], deviceId: 'device-a'),
        );

        expect(applied, 0);
        expect(await titleOf('a'), 'local');
      });

      test('an identical device id is not re-applied', () async {
        await insertFhir(
          db,
          id: 'a',
          updatedAt: ms(at(1)),
          deviceId: 'device-m',
          title: 'local',
        );

        final applied = await service.applyDelta(
          incoming('fhir_resource', [fhirRow('a', updatedAt: ms(at(1)))]),
        );

        expect(applied, 0);
      });

      test('a local row without device id loses the tie', () async {
        await insertFhir(db, id: 'a', updatedAt: ms(at(1)), title: 'local');

        expect(
          await service.applyDelta(
            incoming('fhir_resource', [fhirRow('a', updatedAt: ms(at(1)))]),
          ),
          1,
        );
      });

      test('KNOWN ISSUE: an unchanged row delivered again is re-applied and '
          're-stamped with the wall clock', () async {
        // Rows written by the app have no device_id, so the tie-break compares
        // the sender's id with '' and the sender always wins. A duplicate
        // delivery (offline queue, or the full resend after a count mismatch)
        // therefore rewrites the row and makes it look like a new edit.
        await insertFhir(db, id: 'a', updatedAt: ms(at(1)), title: 'same');
        final echo = incoming('fhir_resource', [
          {...fhirRow('a', updatedAt: ms(at(1))), 'title': 'same'},
        ]);

        expect(await service.applyDelta(echo), 1);
        final restamped =
            (await fetchRow(db, 'fhir_resource', 'a'))!['updated_at'] as int;
        expect(restamped, greaterThan(ms(at(1))));

        // A genuine edit the peer made before the echo was processed now
        // loses, although it is newer than the echoed version.
        final peerEdit = ms(at(1)) + 1000;
        expect(
          await service.applyDelta(
            incoming('fhir_resource', [
              {...fhirRow('a', updatedAt: peerEdit), 'title': 'peer edit'},
            ]),
          ),
          0,
        );
        expect(await titleOf('a'), 'same');
      });

      test('KNOWN ISSUE: the tie winner gets a fresh updated_at from the '
          'update trigger, so the two devices no longer agree', () async {
        await insertFhir(
          db,
          id: 'a',
          updatedAt: ms(at(1)),
          deviceId: 'device-a',
          title: 'local',
        );

        await service.applyDelta(
          incoming('fhir_resource', [
            fhirRow('a', updatedAt: ms(at(1)), deviceId: 'device-b'),
          ], deviceId: 'device-b'),
        );

        final row = await fetchRow(db, 'fhir_resource', 'a');
        expect(row!['title'], 'remote');
        // The upsert leaves updated_at unchanged, which is exactly the
        // condition of fhir_resource_update_updated_at, so the row is stamped
        // "now" and will be sent back to the peer as a newer change.
        expect(row['updated_at'], isNot(ms(at(1))));
        expect(row['updated_at'] as int, greaterThan(ms(at(1))));
      });
    });

    test('tie in sources (no local device_id): any non-empty incoming '
        'device id wins', () async {
      await insertSource(db, id: 's', updatedAt: ms(at(1)), label: 'local');

      final applied = await service.applyDelta(
        incoming('sources', [
          {'id': 's', 'label_source': 'remote', 'updated_at': ms(at(1))},
        ], deviceId: '0'),
      );

      expect(applied, 1);
      expect((await fetchRow(db, 'sources', 's'))!['label_source'], 'remote');
    });

    test('a local row with NULL updated_at always loses', () async {
      await dropSyncTriggers(db);
      await insertFhir(db, id: 'legacy', title: 'local');

      final applied = await service.applyDelta(
        incoming('fhir_resource', [fhirRow('legacy', updatedAt: 1)]),
      );

      expect(applied, 1);
      expect(await titleOf('legacy'), 'remote');
    });

    group('deletes (deleted_at tombstones)', () {
      test('a newer tombstone deletes the local row', () async {
        await insertFhir(db, id: 'a', updatedAt: ms(at(1)), title: 'local');

        await service.applyDelta(
          incoming('fhir_resource', [
            fhirRow('a', updatedAt: ms(at(2)), deletedAt: ms(at(2))),
          ]),
        );

        expect(
          (await fetchRow(db, 'fhir_resource', 'a'))!['deleted_at'],
          ms(at(2)),
        );
        expect((await service.getTableRowCounts())['fhir_resource'], 0);
      });

      test('an older tombstone does not delete a newer local edit', () async {
        await insertFhir(db, id: 'a', updatedAt: ms(at(3)), title: 'edited');

        final applied = await service.applyDelta(
          incoming('fhir_resource', [
            fhirRow('a', updatedAt: ms(at(2)), deletedAt: ms(at(2))),
          ]),
        );

        expect(applied, 0);
        final row = await fetchRow(db, 'fhir_resource', 'a');
        expect(row!['deleted_at'], isNull);
        expect(row['title'], 'edited');
      });

      test('a newer update resurrects a locally deleted row', () async {
        await insertFhir(
          db,
          id: 'a',
          updatedAt: ms(at(1)),
          deletedAt: ms(at(1)),
        );

        await service.applyDelta(
          incoming('fhir_resource', [fhirRow('a', updatedAt: ms(at(2)))]),
        );

        expect(
          (await fetchRow(db, 'fhir_resource', 'a'))!['deleted_at'],
          isNull,
        );
      });

      test(
        'an older update does not resurrect a newer local tombstone',
        () async {
          await insertFhir(
            db,
            id: 'a',
            updatedAt: ms(at(3)),
            deletedAt: ms(at(3)),
          );

          await service.applyDelta(
            incoming('fhir_resource', [fhirRow('a', updatedAt: ms(at(2)))]),
          );

          expect(
            (await fetchRow(db, 'fhir_resource', 'a'))!['deleted_at'],
            ms(at(3)),
          );
        },
      );

      test(
        'a tombstone for a row missing locally is stored as a tombstone',
        () async {
          await service.applyDelta(
            incoming('fhir_resource', [
              fhirRow('ghost', updatedAt: ms(at(2)), deletedAt: ms(at(2))),
            ]),
          );

          expect(await countRows(db, 'fhir_resource'), 1);
          expect((await service.getTableRowCounts())['fhir_resource'], 0);
        },
      );
    });

    test('ignores tables outside the synced set', () async {
      final applied = await service.applyDelta(
        incoming('processing_sessions', [
          {'id': 'p', 'status': 'done', 'updated_at': ms(at(1))},
        ]),
      );

      expect(applied, 0);
      expect(await countRows(db, 'processing_sessions'), 0);
    });

    test('skips rows without id or without a usable updated_at', () async {
      final applied = await service.applyDelta(
        incoming('fhir_resource', [
          {'resource_raw': '{}', 'updated_at': ms(at(1))},
          {'id': 'no-ts', 'resource_raw': '{}'},
          {'id': 'bad-ts', 'resource_raw': '{}', 'updated_at': 'yesterday'},
          {'id': 'double-ts', 'resource_raw': '{}', 'updated_at': 1.5e12},
        ]),
      );

      expect(applied, 0);
      expect(await countRows(db, 'fhir_resource'), 0);
    });

    test(
      'accepts updated_at as a numeric string or an ISO-8601 string',
      () async {
        await insertFhir(db, id: 'num', updatedAt: ms(at(1)), title: 'local');
        await insertFhir(db, id: 'iso', updatedAt: ms(at(1)), title: 'local');

        final applied = await service.applyDelta(
          incoming('fhir_resource', [
            {...fhirRow('num', updatedAt: 0), 'updated_at': '${ms(at(2))}'},
            {
              ...fhirRow('iso', updatedAt: 0),
              'updated_at': at(2).toIso8601String(),
            },
          ]),
        );

        expect(applied, 2);
        expect(await titleOf('num'), 'remote');
        expect(await titleOf('iso'), 'remote');
      },
    );

    test('stores bools as integers and other values as strings', () async {
      await service.applyDelta(
        incoming('fhir_resource', [
          {
            ...fhirRow('a', updatedAt: ms(at(1))),
            'title': true,
            'resource_raw': {'nested': 1},
            'specialty_override': 2.5,
          },
        ]),
      );

      final row = await fetchRow(db, 'fhir_resource', 'a');
      expect(row!['title'], '1');
      expect(row['resource_raw'], '{nested: 1}');
      expect(row['specialty_override'], '2.5');
    });

    test('a row with a column the local schema lacks aborts the delta '
        'midway', () async {
      final delta = incoming('fhir_resource', [
        fhirRow('first', updatedAt: ms(at(1))),
        {...fhirRow('second', updatedAt: ms(at(1))), 'future_column': 'x'},
        fhirRow('third', updatedAt: ms(at(1))),
      ]);

      await expectLater(service.applyDelta(delta), throwsA(anything));

      expect(await titleOf('first'), 'remote');
      expect(await fetchRow(db, 'fhir_resource', 'second'), isNull);
      expect(await fetchRow(db, 'fhir_resource', 'third'), isNull);
    });

    test('record_notes rows keep their integer id', () async {
      await insertNote(db, id: 7, content: 'local', updatedAt: ms(at(1)));

      await service.applyDelta(
        incoming('record_notes', [
          {
            'id': 7,
            'resource_id': 'obs-1',
            'content': 'remote',
            'timestamp': ms(t0) ~/ 1000,
            'updated_at': ms(at(2)),
          },
        ]),
      );

      final row = await fetchRow(db, 'record_notes', 7);
      expect(row!['content'], 'remote');
      expect(await countRows(db, 'record_notes'), 1);
    });

    test('KNOWN ISSUE: two different notes that got the same autoincrement '
        'id on each device overwrite each other', () async {
      // Desktop wrote its own note #1; mobile independently wrote a note #1
      // on another record. Last write wins treats them as one row.
      await insertNote(
        db,
        id: 1,
        content: 'desktop note on obs-1',
        updatedAt: ms(at(1)),
      );

      await service.applyDelta(
        incoming('record_notes', [
          {
            'id': 1,
            'resource_id': 'obs-2',
            'content': 'mobile note on obs-2',
            'timestamp': ms(t0) ~/ 1000,
            'updated_at': ms(at(2)),
          },
        ]),
      );

      final notes = await db
          .customSelect('SELECT content FROM record_notes')
          .get();
      expect(notes.map((r) => r.data['content']), ['mobile note on obs-2']);
    });
  });

  group('applyDelta attachments', () {
    test('restores inline files of incoming DocumentReferences', () async {
      final applied = await service.applyDelta(
        incoming('fhir_resource', [
          fhirRow(
            'doc',
            updatedAt: ms(at(1)),
            resourceType: 'DocumentReference',
            raw: documentReferenceRaw([
              {'data': base64Encode(pdfBytes), 'title': 'scan.pdf'},
            ]),
          ),
        ]),
      );

      expect(applied, 1);
      final raw = (await fetchRow(db, 'fhir_resource', 'doc'))!['resource_raw'];
      final url =
          ((jsonDecode(raw as String)['content'] as List).single
                  as Map)['attachment']['url']
              as String;
      expect(url, startsWith('file://scan_'));
      expect(await dirs.docFile(url.substring(7)).readAsBytes(), pdfBytes);
    });

    test('an older incoming DocumentReference replaces a local one whose file '
        'is missing', () async {
      await insertFhir(
        db,
        id: 'doc',
        updatedAt: ms(at(5)),
        resourceType: 'DocumentReference',
        title: 'local',
        raw: documentReferenceRaw([
          {'url': 'file://lost.pdf'},
        ]),
      );

      final applied = await service.applyDelta(
        incoming('fhir_resource', [
          fhirRow(
            'doc',
            updatedAt: ms(at(1)),
            resourceType: 'DocumentReference',
          ),
        ]),
      );

      expect(applied, 1);
      expect(await titleOf('doc'), 'remote');
    });

    test(
      'an absolute url whose file name exists in documents is not broken',
      () async {
        await dirs.writeDoc('kept.pdf', pdfBytes);
        await insertFhir(
          db,
          id: 'doc',
          updatedAt: ms(at(5)),
          resourceType: 'DocumentReference',
          title: 'local',
          raw: documentReferenceRaw([
            {'url': 'https://example.org/x.pdf'},
            {'url': 'file:///other/device/kept.pdf'},
            {'url': 'file://kept.pdf'},
          ]),
        );

        final applied = await service.applyDelta(
          incoming('fhir_resource', [
            fhirRow(
              'doc',
              updatedAt: ms(at(1)),
              resourceType: 'DocumentReference',
            ),
          ]),
        );

        expect(applied, 0);
        expect(await titleOf('doc'), 'local');
      },
    );

    test('an older row never replaces a newer local non-document or a '
        'document without attachments', () async {
      await insertFhir(db, id: 'obs', updatedAt: ms(at(5)), title: 'local');
      await insertFhir(
        db,
        id: 'doc',
        updatedAt: ms(at(5)),
        resourceType: 'DocumentReference',
        title: 'local',
        raw: '{"resourceType":"DocumentReference"}',
      );
      await insertFhir(
        db,
        id: 'bad',
        updatedAt: ms(at(5)),
        resourceType: 'DocumentReference',
        title: 'local',
        raw: 'not json',
      );

      final applied = await service.applyDelta(
        incoming('fhir_resource', [
          fhirRow('obs', updatedAt: ms(at(1))),
          fhirRow('doc', updatedAt: ms(at(1))),
          fhirRow('bad', updatedAt: ms(at(1))),
        ]),
      );

      expect(applied, 0);
    });
  });

  test('a delta survives the wire and converges a second database', () async {
    await dirs.writeDoc('report.pdf', pdfBytes);
    await insertFhir(db, id: 'obs', updatedAt: ms(at(1)), deviceId: 'd1');
    await insertFhir(
      db,
      id: 'doc',
      updatedAt: ms(at(2)),
      resourceType: 'DocumentReference',
      raw: documentReferenceRaw([
        {'url': 'file://report.pdf', 'title': 'report.pdf'},
      ]),
    );
    await insertSource(db, id: 'src', updatedAt: ms(at(1)), label: 'Clinic');
    await insertNote(db, id: 3, content: 'note', updatedAt: ms(at(1)));

    final peerDocs = Directory('${dirs.root.path}/peer')..createSync();
    final peerDb = openTestDatabase();
    addTearDown(peerDb.close);
    final peer = LwwSyncService(
      peerDb,
      prefs,
      AttachmentSyncService(FakePathResolver(peerDocs.path)),
    );

    var applied = 0;
    for (final delta in await service.computeAllDeltas(at(0))) {
      final wire = jsonDecode(jsonEncode(delta.toJson()));
      applied += await peer.applyDelta(
        SyncDelta.fromJson(wire as Map<String, dynamic>),
      );
    }

    expect(applied, 4);
    expect(await peer.getTableRowCounts(), await service.getTableRowCounts());
    final obs = await fetchRow(peerDb, 'fhir_resource', 'obs');
    expect(obs, await fetchRow(db, 'fhir_resource', 'obs'));
    expect(
      (await fetchRow(peerDb, 'sources', 'src'))!['label_source'],
      'Clinic',
    );
    expect((await fetchRow(peerDb, 'record_notes', 3))!['content'], 'note');
    final peerFiles = peerDocs.listSync().whereType<File>().toList();
    expect(peerFiles.single.readAsBytesSync(), pdfBytes);
  });

  group('timestamps written outside lww_sync', () {
    test(
      'the triggers stamp rows with whole seconds in milliseconds',
      () async {
        await insertFhir(db, id: 'a');
        await db.customStatement(
          "UPDATE fhir_resource SET title = 'x' WHERE id = 'a'",
        );

        final updatedAt =
            (await fetchRow(db, 'fhir_resource', 'a'))!['updated_at'] as int;
        expect(updatedAt % 1000, 0);
        expect(
          updatedAt,
          closeTo(DateTime.now().millisecondsSinceEpoch, 60 * 1000),
        );
      },
    );

    test('KNOWN ISSUE: drift stores Sources.updatedAt in seconds, so a '
        'label edit made through drift is never in a delta and loses every '
        'conflict', () async {
      final edit = DateTime.now();
      await db
          .into(db.sources)
          .insertOnConflictUpdate(
            SourcesCompanion(
              id: const Value('s'),
              labelSource: const Value('renamed'),
              updatedAt: Value(edit),
            ),
          );

      final stored = (await fetchRow(db, 'sources', 's'))!['updated_at'];
      expect(stored, edit.millisecondsSinceEpoch ~/ 1000);

      final delta = await service.computeDelta(
        'sources',
        edit.subtract(const Duration(hours: 1)),
      );
      expect(delta.rows, isEmpty);

      final applied = await service.applyDelta(
        incoming('sources', [
          {
            'id': 's',
            'label_source': 'stale remote',
            'updated_at': ms(DateTime.utc(2020)),
          },
        ]),
      );
      expect(applied, 1);
      expect(
        (await fetchRow(db, 'sources', 's'))!['label_source'],
        'stale remote',
      );
    });
  });

  group('last sync timestamp', () {
    test('is null until set, then round-trips with ms precision', () async {
      expect(await service.getLastSyncTimestamp(), isNull);

      await service.setLastSyncTimestamp(
        at(3).add(
          const Duration(
            milliseconds: 7,
          ),
        ),
      );

      expect(
        (await service.getLastSyncTimestamp())!.millisecondsSinceEpoch,
        ms(at(3)) + 7,
      );
      expect(prefs.getInt('lww_last_sync_timestamp'), ms(at(3)) + 7);
    });

    test('reset clears it', () async {
      await service.setLastSyncTimestamp(at(1));

      await service.resetLastSyncTimestamp();

      expect(await service.getLastSyncTimestamp(), isNull);
    });
  });

  test('getTableRowCounts counts live rows of each synced table', () async {
    await insertFhir(db, id: 'a', updatedAt: ms(at(1)));
    await insertFhir(db, id: 'b', updatedAt: ms(at(1)), deletedAt: ms(at(1)));
    await insertSource(db, id: 's', updatedAt: ms(at(1)));
    await insertProcessingSession(db, id: 'p');

    expect(await service.getTableRowCounts(), {
      'fhir_resource': 1,
      'sources': 1,
      'record_notes': 0,
    });
  });

  test(
    'cleanupTombstones hard-deletes tombstones older than 30 days',
    () async {
      final now = DateTime.now();
      int daysAgo(int d) => ms(now.subtract(Duration(days: d)));
      await insertFhir(
        db,
        id: 'old',
        updatedAt: daysAgo(31),
        deletedAt: daysAgo(31),
      );
      await insertFhir(
        db,
        id: 'recent',
        updatedAt: daysAgo(29),
        deletedAt: daysAgo(29),
      );
      await insertFhir(db, id: 'live', updatedAt: daysAgo(90));
      await insertSource(
        db,
        id: 'old-s',
        updatedAt: daysAgo(40),
        deletedAt: daysAgo(40),
      );
      await insertNote(
        db,
        id: 1,
        content: 'x',
        updatedAt: daysAgo(40),
        deletedAt: daysAgo(40),
      );

      expect(await service.cleanupTombstones(), 3);

      expect(await fetchRow(db, 'fhir_resource', 'old'), isNull);
      expect(await fetchRow(db, 'fhir_resource', 'recent'), isNotNull);
      expect(await fetchRow(db, 'fhir_resource', 'live'), isNotNull);
      expect(await countRows(db, 'sources'), 0);
      expect(await countRows(db, 'record_notes'), 0);
      expect(await service.cleanupTombstones(), 0);
    },
  );

  test(
    'backfillExistingRows stamps rows that predate the sync columns',
    () async {
      await dropSyncTriggers(db);
      await insertFhir(db, id: 'legacy');
      await insertFhir(db, id: 'stamped', updatedAt: ms(at(1)), deviceId: 'x');
      await insertSource(db, id: 's');
      await insertNote(db, id: 1, content: 'n');
      await insertNote(db, id: 2, content: 'n');
      await insertProcessingSession(db, id: 'p');
      final before = DateTime.now().millisecondsSinceEpoch;

      expect(await service.backfillExistingRows(), 4);

      final legacy = (await fetchRow(db, 'fhir_resource', 'legacy'))!;
      expect(legacy['updated_at'] as int, greaterThanOrEqualTo(before));
      expect(legacy['device_id'], 'device-local');
      final stamped = (await fetchRow(db, 'fhir_resource', 'stamped'))!;
      expect(stamped['updated_at'], ms(at(1)));
      expect(stamped['device_id'], 'x');
      expect((await fetchRow(db, 'sources', 's'))!['updated_at'], isNotNull);
      expect(
        (await fetchRow(db, 'processing_sessions', 'p'))!['updated_at'],
        isNull,
        reason: 'processing_sessions is local-only',
      );
      expect(await service.backfillExistingRows(), 0);
    },
  );

  group('missing attachment files', () {
    Future<void> insertDoc(
      String id,
      List<Map<String, dynamic>> attachments, {
      int? deletedAt,
    }) => insertFhir(
      db,
      id: id,
      updatedAt: ms(at(1)),
      resourceType: 'DocumentReference',
      raw: documentReferenceRaw(attachments),
      deletedAt: deletedAt,
    );

    test('getMissingAttachmentPaths lists file:// urls with no file', () async {
      await dirs.writeDoc('present.pdf', pdfBytes);
      await insertDoc('d1', [
        {'url': 'file://present.pdf'},
        {'url': 'file://sub/missing%20one.pdf'},
        {'url': 'https://example.org/remote.pdf'},
        {'title': 'no url'},
      ]);
      await insertDoc('d2', [
        {'url': 'file:///abs/elsewhere.pdf'},
      ]);
      await insertDoc('deleted', [
        {'url': 'file://deleted.pdf'},
      ], deletedAt: ms(at(1)));
      await insertFhir(
        db,
        id: 'broken',
        resourceType: 'DocumentReference',
        raw: 'nope',
      );
      await insertFhir(
        db,
        id: 'no-content',
        resourceType: 'DocumentReference',
        raw: '{"content":["x"]}',
      );
      await insertFhir(
        db,
        id: 'obs',
        raw: documentReferenceRaw([
          {'url': 'file://observation.pdf'},
        ]),
      );

      expect(
        await service.getMissingAttachmentPaths(),
        unorderedEquals(['sub/missing one.pdf', '/abs/elsewhere.pdf']),
      );
    });

    test(
      'resolveFileRequests returns base64 for the files it can find',
      () async {
        await dirs.writeDoc('a.pdf', pdfBytes);

        final resolved = await service.resolveFileRequests([
          'a.pdf',
          '/old/path/a.pdf',
          'unknown.pdf',
        ]);

        expect(resolved.keys, ['a.pdf', '/old/path/a.pdf']);
        expect(base64Decode(resolved['a.pdf']!), pdfBytes);
      },
    );

    test('saveReceivedFiles writes files and repoints the matching '
        'attachment urls', () async {
      await insertDoc('d1', [
        {'url': 'file://scans/lab result.pdf'},
        {'url': 'file://other.pdf'},
      ]);
      await insertDoc('d2', [
        {'url': 'file://unrelated.pdf'},
      ]);

      final saved = await service.saveReceivedFiles({
        'scans/lab result.pdf': base64Encode(pdfBytes),
        'bad.pdf': '***',
      });

      expect(saved, 1);
      expect(await dirs.docFile('lab_result.pdf').readAsBytes(), pdfBytes);
      expect(dirs.docFile('bad.pdf').existsSync(), isFalse);
      final d1 = jsonDecode(
        (await fetchRow(db, 'fhir_resource', 'd1'))!['resource_raw'] as String,
      );
      final urls = [
        for (final c in d1['content'] as List) (c as Map)['attachment']['url'],
      ];
      expect(urls, ['file://lab_result.pdf', 'file://other.pdf']);
      final d2 = (await fetchRow(db, 'fhir_resource', 'd2'))!;
      expect(d2['resource_raw'], contains('file://unrelated.pdf'));
      expect(d2['updated_at'], ms(at(1)));
    });

    test(
      'fixBrokenAttachmentUrls repoints urls to files found by name',
      () async {
        await dirs.writeDoc('exact.pdf', pdfBytes);
        await dirs.writeDoc('present.pdf', pdfBytes);
        await insertDoc('by-name', [
          {'url': 'file:///old/device/Documents/exact.pdf'},
        ]);
        await insertDoc('fine', [
          {'url': 'file://present.pdf'},
          {'url': 'https://example.org/x.pdf'},
        ]);
        await insertDoc('lost', [
          {'url': 'file://zzz.pdf'},
        ]);

        expect(await service.fixBrokenAttachmentUrls(), 1);

        expect(
          (await fetchRow(db, 'fhir_resource', 'by-name'))!['resource_raw'],
          contains('"file://exact.pdf"'),
        );
        expect(
          (await fetchRow(db, 'fhir_resource', 'fine'))!['updated_at'],
          ms(at(1)),
        );
        expect(
          (await fetchRow(db, 'fhir_resource', 'lost'))!['resource_raw'],
          contains('file://zzz.pdf'),
        );
      },
    );

    test('KNOWN ISSUE: fixBrokenAttachmentUrls links a missing file to any '
        'file whose name contains its stem', () async {
      await dirs.writeDoc('lab_results_other_patient.pdf', pdfBytes);
      await insertDoc('doc', [
        {'url': 'file://lab.pdf'},
      ]);

      expect(await service.fixBrokenAttachmentUrls(), 1);

      final row = (await fetchRow(db, 'fhir_resource', 'doc'))!;
      expect(
        row['resource_raw'],
        contains('file://lab_results_other_patient.pdf'),
      );
      // The repair is an UPDATE without updated_at, so the trigger stamps the
      // row as a fresh local edit that wins over the peer's copy.
      expect(row['updated_at'], isNot(ms(at(1))));
    });
  });
}
