import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/data/local/app_database.dart';
import 'package:health_wallet/core/data/local/soft_delete.dart';

import '../../../features/desktop/lww_sync/lww_sync_test_helpers.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = openTestDatabase());
  tearDown(() => db.close());

  Future<Map<String, Object?>> row(String table, Object id) async =>
      (await fetchRow(db, table, id))!;

  Future<void> fhir(
    String id, {
    String? sourceId,
    String type = 'Observation',
    String? encounterId,
    int? deletedAt,
  }) => db.customStatement(
    'INSERT INTO fhir_resource (id, source_id, resource_type, resource_raw, '
    'encounter_id, updated_at, deleted_at) VALUES (?, ?, ?, ?, ?, ?, ?)',
    [id, sourceId, type, '{}', encounterId, ms(at(0)), deletedAt],
  );

  /// Asserts [r] was tombstoned now, in milliseconds, with `updated_at`
  /// equal to `deleted_at`.
  void expectFreshTombstone(Map<String, Object?> r, int beforeMs) {
    final deletedAt = r['deleted_at'] as int?;
    expect(deletedAt, isNotNull);
    expect(deletedAt, greaterThanOrEqualTo(beforeMs));
    // One past the row's own stamp when it was written in the same
    // millisecond, so the stamp never goes back.
    expect(
      deletedAt,
      lessThanOrEqualTo(DateTime.now().millisecondsSinceEpoch + 1),
    );
    expect(r['updated_at'], deletedAt);
  }

  void expectLive(Map<String, Object?> r) {
    expect(r['deleted_at'], isNull);
    expect(r['updated_at'], ms(at(0)));
  }

  group('softDeleteResources', () {
    test('tombstones the rows in milliseconds and keeps them', () async {
      await fhir('a');
      await fhir('b');
      await fhir('c');
      final before = DateTime.now().millisecondsSinceEpoch;

      final count = await db.softDeleteResources(['a', 'b']);

      expect(count, 2);
      expect(await countRows(db, 'fhir_resource'), 3);
      expectFreshTombstone(await row('fhir_resource', 'a'), before);
      expectFreshTombstone(await row('fhir_resource', 'b'), before);
      expectLive(await row('fhir_resource', 'c'));
      // A millisecond stamp, not drift's seconds.
      expect(
        (await row('fhir_resource', 'a'))['deleted_at'],
        greaterThan(1e12),
      );
    });

    test('tombstones the notes of the deleted records only', () async {
      await fhir('a');
      await fhir('b');
      await insertNote(db, id: 1, content: 'on a', resourceId: 'a');
      await insertNote(db, id: 2, content: 'on b', resourceId: 'b');
      await insertNote(db, id: 3, content: 'also on a', resourceId: 'a');
      final before = DateTime.now().millisecondsSinceEpoch;

      await db.softDeleteResources(['a']);

      expectFreshTombstone(await row('record_notes', 1), before);
      expectFreshTombstone(await row('record_notes', 3), before);
      expect((await row('record_notes', 2))['deleted_at'], isNull);
    });

    test('leaves rows that are already tombstoned as they are', () async {
      await fhir('a', deletedAt: ms(at(0)));
      await insertNote(
        db,
        id: 1,
        content: 'n',
        resourceId: 'a',
        updatedAt: ms(at(0)),
        deletedAt: ms(at(0)),
      );

      final count = await db.softDeleteResources(['a']);

      expect(count, 0);
      final r = await row('fhir_resource', 'a');
      expect(r['deleted_at'], ms(at(0)));
      expect(r['updated_at'], ms(at(0)));
      expect((await row('record_notes', 1))['updated_at'], ms(at(0)));
    });

    test('is a no-op for no ids or unknown ids', () async {
      await fhir('a');

      expect(await db.softDeleteResources(const []), 0);
      expect(await db.softDeleteResources(['missing']), 0);

      expectLive(await row('fhir_resource', 'a'));
    });

    test(
      'notifies drift streams so the change watcher sends a delta',
      () async {
        await fhir('a');
        final emissions = <int>[];
        final sub = db
            .select(db.fhirResource)
            .watch()
            .listen((rows) => emissions.add(rows.length));
        final notes = <int>[];
        final notesSub = db
            .select(db.recordNotes)
            .watch()
            .listen((rows) => notes.add(rows.length));
        addTearDown(sub.cancel);
        addTearDown(notesSub.cancel);
        await pumpEventQueue();
        final resourceEmissions = emissions.length;
        final noteEmissions = notes.length;

        await db.softDeleteResources(['a']);
        await pumpEventQueue();

        expect(emissions.length, greaterThan(resourceEmissions));
        expect(notes.length, greaterThan(noteEmissions));
      },
    );
  });

  group('softDeleteResourcesOfSource', () {
    test('tombstones the records of the source and their notes', () async {
      await fhir('a1', sourceId: 'a');
      await fhir('a2', sourceId: 'a');
      await fhir('b1', sourceId: 'b');
      await insertNote(db, id: 1, content: 'n', resourceId: 'a2');
      await insertNote(db, id: 2, content: 'n', resourceId: 'b1');
      final before = DateTime.now().millisecondsSinceEpoch;

      final count = await db.softDeleteResourcesOfSource('a');

      expect(count, 2);
      expectFreshTombstone(await row('fhir_resource', 'a1'), before);
      expectFreshTombstone(await row('fhir_resource', 'a2'), before);
      expectLive(await row('fhir_resource', 'b1'));
      expectFreshTombstone(await row('record_notes', 1), before);
      expect((await row('record_notes', 2))['deleted_at'], isNull);
    });

    test('is a no-op for an unknown source', () async {
      await fhir('a1', sourceId: 'a');
      expect(await db.softDeleteResourcesOfSource('missing'), 0);
      expectLive(await row('fhir_resource', 'a1'));
    });
  });

  group('softDeleteDocumentReferences', () {
    test('tombstones only the DocumentReferences of the source and '
        'encounter', () async {
      await fhir(
        'doc',
        sourceId: 's',
        type: 'DocumentReference',
        encounterId: 'e',
      );
      await fhir(
        'other-enc',
        sourceId: 's',
        type: 'DocumentReference',
        encounterId: 'x',
      );
      await fhir(
        'other-src',
        sourceId: 't',
        type: 'DocumentReference',
        encounterId: 'e',
      );
      await fhir('obs', sourceId: 's', encounterId: 'e');
      await insertNote(db, id: 1, content: 'n', resourceId: 'doc');
      final before = DateTime.now().millisecondsSinceEpoch;

      final count = await db.softDeleteDocumentReferences(
        sourceId: 's',
        encounterId: 'e',
      );

      expect(count, 1);
      expectFreshTombstone(await row('fhir_resource', 'doc'), before);
      expectLive(await row('fhir_resource', 'other-enc'));
      expectLive(await row('fhir_resource', 'other-src'));
      expectLive(await row('fhir_resource', 'obs'));
      expectFreshTombstone(await row('record_notes', 1), before);
    });
  });

  group('softDeleteSource', () {
    test('tombstones the source row, its records and their notes', () async {
      await insertSource(db, id: 'a', updatedAt: ms(at(0)), label: 'A');
      await insertSource(db, id: 'b', updatedAt: ms(at(0)), label: 'B');
      await fhir('a1', sourceId: 'a');
      await fhir('b1', sourceId: 'b');
      await insertNote(db, id: 1, content: 'n', resourceId: 'a1');
      final before = DateTime.now().millisecondsSinceEpoch;

      await db.softDeleteSource('a');

      final source = await row('sources', 'a');
      expectFreshTombstone(source, before);
      expect(source['label_source'], 'A');
      expectLive(await row('sources', 'b'));
      expectFreshTombstone(await row('fhir_resource', 'a1'), before);
      expectLive(await row('fhir_resource', 'b1'));
      expectFreshTombstone(await row('record_notes', 1), before);
    });

    test('tombstones the records even without a source row', () async {
      await fhir('a1', sourceId: 'a');
      final before = DateTime.now().millisecondsSinceEpoch;

      await db.softDeleteSource('a');

      expectFreshTombstone(await row('fhir_resource', 'a1'), before);
      expect(await countRows(db, 'sources'), 0);
    });

    test('leaves an already tombstoned source as it is', () async {
      await insertSource(
        db,
        id: 'a',
        updatedAt: ms(at(0)),
        deletedAt: ms(at(0)),
      );

      await db.softDeleteSource('a');

      final source = await row('sources', 'a');
      expect(source['deleted_at'], ms(at(0)));
      expect(source['updated_at'], ms(at(0)));
    });
  });

  test('softDeleteSource and softDeleteNote notify drift streams', () async {
    await insertSource(db, id: 'a', updatedAt: ms(at(0)));
    await insertNote(db, id: 1, content: 'n', updatedAt: ms(at(0)));
    var sources = 0;
    var notes = 0;
    final subs = [
      db.select(db.sources).watch().listen((_) => sources++),
      db.select(db.recordNotes).watch().listen((_) => notes++),
    ];
    for (final sub in subs) {
      addTearDown(sub.cancel);
    }
    await pumpEventQueue();
    final sourcesBefore = sources;

    await db.softDeleteSource('a');
    await pumpEventQueue();
    final notesBefore = notes;
    await db.softDeleteNote(1);
    await pumpEventQueue();

    expect(sources, greaterThan(sourcesBefore));
    expect(notes, greaterThan(notesBefore));
  });

  group('softDeleteNote', () {
    test('tombstones one note', () async {
      await insertNote(db, id: 1, content: 'a', updatedAt: ms(at(0)));
      await insertNote(db, id: 2, content: 'b', updatedAt: ms(at(0)));
      final before = DateTime.now().millisecondsSinceEpoch;

      expect(await db.softDeleteNote(1), 1);

      final note = await row('record_notes', 1);
      expectFreshTombstone(note, before);
      expect(note['content'], 'a');
      expectLive(await row('record_notes', 2));
    });

    test('returns 0 for a missing or already deleted note', () async {
      await insertNote(
        db,
        id: 1,
        content: 'a',
        updatedAt: ms(at(0)),
        deletedAt: ms(at(0)),
      );

      expect(await db.softDeleteNote(1), 0);
      expect(await db.softDeleteNote(99), 0);
      expect((await row('record_notes', 1))['updated_at'], ms(at(0)));
    });
  });
}
