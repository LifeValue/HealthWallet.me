import 'dart:convert';

import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/data/local/app_database.dart' hide Source;
import 'package:health_wallet/features/records/data/data_source/shared_notes_datasource.dart';
import 'package:health_wallet/features/records/data/repository/records_repository_impl.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/records/domain/entity/record_note/record_note.dart';
import 'package:health_wallet/features/records/domain/repository/records_repository.dart';
import 'package:health_wallet/features/sync/data/data_source/local/sync_local_data_source.dart';
import 'package:health_wallet/features/sync/data/dto/fhir_resource_dto.dart';
import 'package:health_wallet/features/sync/domain/entities/source.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../desktop/lww_sync/lww_sync_test_helpers.dart';
import '../../records_test_helpers.dart' show DocumentsPathResolver;

void main() {
  late TestDirs dirs;
  late AppDatabase db;
  late SyncLocalDataSourceImpl syncLocal;
  late RecordsRepositoryImpl repository;

  setUp(() async {
    dirs = await TestDirs.create();
    db = openTestDatabase();
    SharedPreferences.setMockInitialValues({});
    syncLocal = SyncLocalDataSourceImpl(
      db,
      await SharedPreferences.getInstance(),
    );
    repository = RecordsRepositoryImpl(
      db,
      syncLocal,
      SharedNotesDatasource(),
      DocumentsPathResolver('/nonexistent'),
    );
  });

  tearDown(() async {
    await db.close();
    await dirs.dispose();
  });

  Map<String, dynamic> rawOf(
    String type,
    String id, {
    String? subject,
    String? encounter,
    String? text,
  }) => {
    'resourceType': type,
    'id': id,
    if (type == 'Observation') 'status': 'final',
    if (type == 'Observation') 'code': {'text': text ?? 'Heart rate'},
    if (type == 'Encounter') 'status': 'finished',
    if (type == 'Encounter') 'class': {'code': 'AMB'},
    if (type == 'DocumentReference') 'status': 'current',
    if (type == 'DocumentReference')
      'content': [
        {
          'attachment': {'title': 'scan.pdf'},
        },
      ],
    if (subject != null) 'subject': {'reference': subject},
    if (encounter != null) 'encounter': {'reference': encounter},
  };

  FhirResourceDto dto(
    String id, {
    String type = 'Observation',
    String? sourceId = 'src-1',
    String? title,
    DateTime? date,
    String? encounterId,
    String? subjectId,
    Map<String, dynamic>? raw,
  }) => FhirResourceDto(
    resourceId: id,
    sourceId: sourceId,
    resourceType: type,
    title: title ?? id,
    date: date,
    encounterId: encounterId,
    subjectId: subjectId,
    resourceRaw: raw ?? rawOf(type, id),
  );

  Future<void> seed(List<FhirResourceDto> dtos) =>
      syncLocal.cacheFhirResources(dtos);

  Future<void> tombstone(String table, Object id) => db.customStatement(
    'UPDATE $table SET deleted_at = ?, updated_at = ? WHERE id = ?',
    [ms(at(0)), ms(at(0)), id],
  );

  Future<Map<String, Object?>> rowOf(String table, Object id) async =>
      (await fetchRow(db, table, id))!;

  void expectTombstone(Map<String, Object?> row, int beforeMs) {
    expect(row['deleted_at'], isA<int>());
    expect(row['deleted_at'] as int, greaterThanOrEqualTo(beforeMs));
    expect(row['updated_at'], row['deleted_at']);
  }

  Future<List<String>> ids(Future<List<IFhirResource>> resources) async =>
      (await resources).map((r) => r.id).toList();

  Future<void> until(Future<bool> Function() condition) async {
    for (var i = 0; i < 200; i++) {
      if (await condition()) return;
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    fail('condition not met');
  }

  group('getResources', () {
    test('returns every record, newest first', () async {
      await seed([
        dto('old', date: DateTime(2020)),
        dto('new', date: DateTime(2024)),
        dto('mid', date: DateTime(2022)),
      ]);

      expect(await ids(repository.getResources()), ['new', 'mid', 'old']);
    });

    test('filters by type, source, sources, limit and offset', () async {
      await seed([
        dto('o1', date: DateTime(2024, 3)),
        dto('o2', date: DateTime(2024, 2), sourceId: 'src-2'),
        dto('p1', type: 'Patient', date: DateTime(2024, 1)),
        dto('o3', date: DateTime(2023), sourceId: 'src-3'),
      ]);

      expect(
        await ids(repository.getResources(resourceTypes: [FhirType.Patient])),
        ['p1'],
      );
      expect(await ids(repository.getResources(sourceId: 'src-2')), ['o2']);
      expect(
        await ids(repository.getResources(sourceIds: ['src-2', 'src-3'])),
        ['o2', 'o3'],
      );
      expect(
        await ids(
          repository.getResources(sourceId: 'src-1', sourceIds: ['src-3']),
        ),
        ['o1', 'p1'],
        reason: 'sourceId wins over sourceIds',
      );
      expect(
        await ids(repository.getResources(sourceIds: const [])),
        isEmpty,
        reason: 'a patient without sources has no records',
      );
      expect(
        await ids(repository.getResources(limit: 2, offset: 1)),
        ['o2', 'p1'],
      );
    });

    test('skips a record that cannot be parsed', () async {
      await seed([dto('good')]);
      await db.customStatement(
        'INSERT INTO fhir_resource (id, resource_type, resource_raw) '
        "VALUES ('bad', 'Observation', 'not json')",
      );

      expect(await ids(repository.getResources()), ['good']);
    });

    test('hides deleted records', () async {
      await seed([dto('kept'), dto('gone')]);
      await tombstone('fhir_resource', 'gone');

      expect(await ids(repository.getResources()), ['kept']);
    });
  });

  group('getResourcePage', () {
    Future<List<String>> pageIds(Future<ResourcePage> page) async =>
        (await page).resources.map((r) => r.id).toList();

    test('a date filter drops dated records outside it, keeps undated '
        'ones', () async {
      await seed([
        dto('in', date: DateTime(2024, 5, 6)),
        dto('out', date: DateTime(2023, 5, 6)),
        dto('undated'),
      ]);

      expect(
        await pageIds(
          repository.getResourcePage(
            dateFilter: const DateFilter(fromYear: 2024),
          ),
        ),
        unorderedEquals(['in', 'undated']),
      );
      expect(
        await pageIds(
          repository.getResourcePage(dateFilter: const DateFilter()),
        ),
        hasLength(3),
      );
    });

    test('fills a page past the rows a filter skips, and the next page '
        'starts after the last row read', () async {
      // 250 rows, newest first r000..r249; every tenth one matches.
      await seed([
        for (var i = 0; i < 250; i++)
          dto(
            'r${i.toString().padLeft(3, '0')}',
            date: DateTime(2024).subtract(Duration(days: i)),
          ),
      ]);
      bool everyTenth(IFhirResource r) =>
          int.parse(r.id.substring(1)) % 10 == 0;

      final first = await repository.getResourcePage(
        where: everyTenth,
        limit: 20,
      );
      expect(first.resources.map((r) => r.id).first, 'r000');
      expect(first.resources.map((r) => r.id).last, 'r190');
      expect(first.nextOffset, 191);
      expect(first.hasMore, isTrue);

      final second = await repository.getResourcePage(
        where: everyTenth,
        limit: 20,
        offset: first.nextOffset,
      );
      expect(second.resources.map((r) => r.id), [
        'r200',
        'r210',
        'r220',
        'r230',
        'r240',
      ]);
      expect(second.hasMore, isFalse);
    });

    test('pages records with the same date without overlap', () async {
      await seed([
        for (var i = 0; i < 7; i++) dto('s$i', date: DateTime(2024)),
      ]);

      final seen = <String>[];
      var offset = 0;
      var hasMore = true;
      while (hasMore) {
        final page = await repository.getResourcePage(limit: 3, offset: offset);
        seen.addAll(page.resources.map((r) => r.id));
        offset = page.nextOffset;
        hasMore = page.hasMore;
      }

      expect(seen, hasLength(7));
      expect(seen.toSet(), hasLength(7));
    });

    test('a row that cannot be parsed still moves the next page on', () async {
      await seed([
        dto('a', date: DateTime(2024, 3)),
        dto('b', date: DateTime(2024, 1)),
      ]);
      await db.customStatement(
        'INSERT INTO fhir_resource (id, resource_type, resource_raw, date) '
        "VALUES ('bad', 'Observation', 'not json', ?)",
        [DateTime(2024, 2).millisecondsSinceEpoch ~/ 1000],
      );

      final first = await repository.getResourcePage(limit: 1);
      final second = await repository.getResourcePage(
        limit: 1,
        offset: first.nextOffset,
      );

      expect([...first.resources, ...second.resources].map((r) => r.id), [
        'a',
        'b',
      ]);
    });

    test('without a limit returns every match', () async {
      await seed([for (var i = 0; i < 30; i++) dto('x$i')]);

      final all = await repository.getResourcePage(limit: null);

      expect(all.resources, hasLength(30));
      expect(all.hasMore, isFalse);
    });
  });

  group('getResourcesByIds', () {
    test('returns the records asked for, newest first, without deleted '
        'ones', () async {
      await seed([
        dto('old', date: DateTime(2020)),
        dto('new', date: DateTime(2024)),
        dto('gone', date: DateTime(2022)),
        dto('other', date: DateTime(2023)),
      ]);
      await tombstone('fhir_resource', 'gone');

      expect(await ids(repository.getResourcesByIds(['old', 'gone', 'new'])), [
        'new',
        'old',
      ]);
      expect(await repository.getResourcesByIds(const []), isEmpty);
    });
  });

  group('related records', () {
    Future<void> seedVisit() => seed([
      dto('enc-1', type: 'Encounter', raw: rawOf('Encounter', 'enc-1')),
      dto('obs-1', encounterId: 'enc-1'),
      dto(
        'doc-1',
        type: 'DocumentReference',
        encounterId: 'enc-1',
        raw: rawOf('DocumentReference', 'doc-1'),
      ),
      dto('obs-2', encounterId: 'enc-1', sourceId: 'src-2'),
      dto('obs-3', encounterId: 'enc-2'),
    ]);

    test('getRelatedResourcesForEncounter lists the visit, documents '
        'first', () async {
      await seedVisit();

      final related = await ids(
        repository.getRelatedResourcesForEncounter(encounterId: 'enc-1'),
      );

      expect(related.first, 'doc-1');
      expect(related, unorderedEquals(['doc-1', 'obs-1', 'obs-2']));
      expect(
        await ids(
          repository.getRelatedResourcesForEncounter(
            encounterId: 'enc-1',
            sourceId: 'src-2',
          ),
        ),
        ['obs-2'],
      );
    });

    test('getRelatedResourcesForEncounter hides deleted records', () async {
      await seedVisit();
      await tombstone('fhir_resource', 'doc-1');

      expect(
        await ids(
          repository.getRelatedResourcesForEncounter(encounterId: 'enc-1'),
        ),
        unorderedEquals(['obs-1', 'obs-2']),
      );
    });

    test('getRelatedResources resolves the references of a record', () async {
      await seed([
        dto('pat-1', type: 'Patient'),
        dto('enc-1', type: 'Encounter', raw: rawOf('Encounter', 'enc-1')),
        dto(
          'obs-1',
          raw: rawOf(
            'Observation',
            'obs-1',
            subject: 'Patient/pat-1',
            encounter: 'urn:uuid:enc-1',
          ),
        ),
        dto(
          'obs-2',
          raw: rawOf('Observation', 'obs-2', subject: 'Patient/missing'),
        ),
      ]);
      final obs = (await repository.getResources()).firstWhere(
        (r) => r.id == 'obs-1',
      );
      final orphan = (await repository.getResources()).firstWhere(
        (r) => r.id == 'obs-2',
      );

      expect(
        await ids(repository.getRelatedResources(resource: obs)),
        unorderedEquals(['pat-1', 'enc-1']),
      );
      expect(await repository.getRelatedResources(resource: orphan), isEmpty);

      await tombstone('fhir_resource', 'pat-1');
      expect(await ids(repository.getRelatedResources(resource: obs)), [
        'enc-1',
      ]);
    });
  });

  group('resolveReference', () {
    setUp(() => seed([dto('obs-1'), dto('pat-1', type: 'Patient')]));

    test('finds Type/id and urn:uuid references', () async {
      expect((await repository.resolveReference('Patient/pat-1'))!.id, 'pat-1');
      expect(
        (await repository.resolveReference('urn:uuid:obs-1'))!.id,
        'obs-1',
      );
    });

    test('returns null for unknown or malformed references', () async {
      expect(await repository.resolveReference('Patient/other'), isNull);
      expect(await repository.resolveReference('Observation/pat-1'), isNull);
      expect(await repository.resolveReference('pat-1'), isNull);
      expect(await repository.resolveReference('a/b/c'), isNull);
      expect(await repository.resolveReference('urn:uuid:missing'), isNull);
    });

    test('returns null for a deleted record', () async {
      await tombstone('fhir_resource', 'pat-1');
      await tombstone('fhir_resource', 'obs-1');

      expect(await repository.resolveReference('Patient/pat-1'), isNull);
      expect(await repository.resolveReference('urn:uuid:obs-1'), isNull);
    });
  });

  group('record notes', () {
    test('add, list newest first, and edit', () async {
      // The app always notes a record of a source it has stored.
      await insertSource(db, id: 'src-1');
      final first = await repository.addRecordNote(
        resourceId: 'obs-1',
        sourceId: 'src-1',
        content: 'first',
      );
      await db.customStatement(
        'UPDATE record_notes SET timestamp = timestamp - 60 WHERE id = ?',
        [first],
      );
      final second = await repository.addRecordNote(
        resourceId: 'obs-1',
        content: 'second',
      );
      await repository.addRecordNote(resourceId: 'obs-2', content: 'other');

      final notes = await repository.getRecordNotes('obs-1');
      expect(notes.map((n) => n.id), [second, first]);
      expect(notes.last.sourceId, 'src-1');

      final edited = await repository.editRecordNote(
        notes.last.copyWith(content: 'edited'),
      );
      expect(edited, 1);
      expect(
        (await repository.getRecordNotes('obs-1')).last.content,
        'edited',
      );
    });

    test('deleteRecordNote keeps a millisecond tombstone and hides the '
        'note', () async {
      final id = await repository.addRecordNote(
        resourceId: 'obs-1',
        content: 'gone',
      );
      await repository.addRecordNote(resourceId: 'obs-1', content: 'kept');
      final note = (await repository.getRecordNotes(
        'obs-1',
      )).firstWhere((n) => n.id == id);
      final before = DateTime.now().millisecondsSinceEpoch;

      expect(await repository.deleteRecordNote(note), 1);

      expectTombstone(await rowOf('record_notes', id), before);
      expect((await repository.getRecordNotes('obs-1')).map((n) => n.content), [
        'kept',
      ]);
    });

    test('editing a deleted note does not bring it back', () async {
      final id = await repository.addRecordNote(
        resourceId: 'obs-1',
        content: 'gone',
      );
      final note = (await repository.getRecordNotes('obs-1')).single;
      await repository.deleteRecordNote(note);

      await repository.editRecordNote(note.copyWith(content: 'late edit'));

      expect(await repository.getRecordNotes('obs-1'), isEmpty);
      expect((await rowOf('record_notes', id))['deleted_at'], isNotNull);
    });

    test('deleting a missing note returns 0', () async {
      expect(
        await repository.deleteRecordNote(
          RecordNote(id: 42, timestamp: DateTime(2024)),
        ),
        0,
      );
    });
  });

  group('deleteResource and deleteResourcesByIds', () {
    test('tombstone the record and its notes, which every read then '
        'hides', () async {
      await seed([
        dto('obs-1', title: 'Glucose', encounterId: 'enc-1'),
        dto('obs-2', title: 'Glucose'),
      ]);
      final noteId = await repository.addRecordNote(
        resourceId: 'obs-1',
        content: 'n',
      );
      final before = DateTime.now().millisecondsSinceEpoch;

      await repository.deleteResource('obs-1');

      expectTombstone(await rowOf('fhir_resource', 'obs-1'), before);
      expectTombstone(await rowOf('record_notes', noteId), before);
      expect(await ids(repository.getResources()), ['obs-2']);
      expect(await ids(repository.searchResources(query: 'glucose')), [
        'obs-2',
      ]);
      expect(await repository.resolveReference('urn:uuid:obs-1'), isNull);
      expect(await repository.getRecordNotes('obs-1'), isEmpty);
      expect(
        await repository.getRelatedResourcesForEncounter(encounterId: 'enc-1'),
        isEmpty,
      );
    });

    test('deleteResourcesByIds tombstones each listed record', () async {
      await seed([dto('a'), dto('b'), dto('c')]);
      final before = DateTime.now().millisecondsSinceEpoch;

      await repository.deleteResourcesByIds(['a', 'c']);

      expectTombstone(await rowOf('fhir_resource', 'a'), before);
      expectTombstone(await rowOf('fhir_resource', 'c'), before);
      expect(await ids(repository.getResources()), ['b']);
      await repository.deleteResourcesByIds(const []);
      expect(await ids(repository.getResources()), ['b']);
    });
  });

  group('getRelatedResourceCount and getRelatedResourcesForDeletion', () {
    Future<void> seedVisit() => seed([
      dto('enc-1', type: 'Encounter', raw: rawOf('Encounter', 'enc-1')),
      dto(
        'rep-1',
        type: 'DiagnosticReport',
        raw: {'resourceType': 'DiagnosticReport', 'id': 'rep-1'},
      ),
      dto('obs-1', encounterId: 'enc-1'),
      dto('obs-2', encounterId: 'enc-1'),
      dto('obs-3', encounterId: 'rep-1'),
      dto('lone'),
    ]);

    test('an encounter counts and lists its records', () async {
      await seedVisit();

      expect(await repository.getRelatedResourceCount('enc-1'), 2);
      expect(
        await ids(repository.getRelatedResourcesForDeletion('enc-1')),
        unorderedEquals(['obs-1', 'obs-2']),
      );
      expect(await repository.getRelatedResourceCount('rep-1'), 1);
    });

    test('a record of a visit counts the encounter too', () async {
      await seedVisit();

      expect(await repository.getRelatedResourceCount('obs-1'), 3);
      expect(
        await ids(repository.getRelatedResourcesForDeletion('obs-1')),
        unorderedEquals(['enc-1', 'obs-2']),
      );
    });

    test('a record without a visit, or an unknown one, has none', () async {
      await seedVisit();

      expect(await repository.getRelatedResourceCount('lone'), 0);
      expect(await repository.getRelatedResourcesForDeletion('lone'), isEmpty);
      expect(await repository.getRelatedResourceCount('missing'), 0);
      expect(
        await repository.getRelatedResourcesForDeletion('missing'),
        isEmpty,
      );
    });

    test('deleted records are neither counted nor listed', () async {
      await seedVisit();
      await tombstone('fhir_resource', 'obs-2');

      expect(await repository.getRelatedResourceCount('enc-1'), 1);
      expect(await ids(repository.getRelatedResourcesForDeletion('enc-1')), [
        'obs-1',
      ]);
      expect(await repository.getRelatedResourceCount('obs-1'), 2);
      expect(await ids(repository.getRelatedResourcesForDeletion('obs-1')), [
        'enc-1',
      ]);

      await tombstone('fhir_resource', 'enc-1');
      expect(await repository.getRelatedResourceCount('enc-1'), 0);
      expect(await repository.getRelatedResourcesForDeletion('enc-1'), isEmpty);
      expect(await ids(repository.getRelatedResourcesForDeletion('obs-1')), []);
    });
  });

  group('demo data', () {
    Future<int> liveDemoRows() async {
      final row = await db
          .customSelect(
            'SELECT COUNT(*) AS c FROM fhir_resource WHERE source_id = '
            "'demo_data' AND deleted_at IS NULL",
          )
          .getSingle();
      return row.data['c'] as int;
    }

    test('loadDemoData stores the demo source, records and PDF', () async {
      await repository.loadDemoData();
      await until(() async => await liveDemoRows() == 27);

      expect(await repository.hasDemoData(), isTrue);
      expect(await fetchRow(db, 'sources', 'demo_data'), isNotNull);
      expect(dirs.docNames(), contains('demo_medical_report.pdf'));
      final pdfDoc = await rowOf('fhir_resource', 'demo-doc-ref-pdf-001');
      expect(pdfDoc['encounter_id'], 'demo-encounter-001');
    });

    test('loadDemoData adapts the demo patient to the saved country', () async {
      SharedPreferences.setMockInitialValues({'countryCode': 'RO'});
      await repository.loadDemoData();
      await until(() async => await liveDemoRows() == 27);

      final patient = await repository.resolveReference(
        'Patient/john-doe-patient-001',
      );
      expect(patient, isA<Patient>());
      expect(jsonEncode(patient!.rawResource), contains('+40'));
    });

    test('clearDemoData tombstones the demo records, notes and source, and '
        'leaves the rest', () async {
      await repository.loadDemoData();
      await until(() async => await liveDemoRows() == 27);
      await seed([dto('mine')]);
      final noteId = await repository.addRecordNote(
        resourceId: 'observation-bp-001',
        content: 'n',
      );
      final before = DateTime.now().millisecondsSinceEpoch;
      // A tombstone is stamped at least one past the row's last write, so a
      // delete in the same millisecond as that write would get a second
      // stamp; let the clock move on first.
      while (DateTime.now().millisecondsSinceEpoch <= before) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }

      await repository.clearDemoData();

      expect(await repository.hasDemoData(), isFalse);
      expect(await liveDemoRows(), 0);
      expectTombstone(await rowOf('sources', 'demo_data'), before);
      expectTombstone(await rowOf('record_notes', noteId), before);
      expectTombstone(
        await rowOf('fhir_resource', 'john-doe-patient-001'),
        before,
      );
      expect(await ids(repository.getResources()), ['mine']);
      expect(
        (await syncLocal.getSources()).map((s) => s.id),
        isNot(contains('demo_data')),
      );
      final stamps = await db
          .customSelect(
            'SELECT DISTINCT deleted_at FROM fhir_resource '
            "WHERE source_id = 'demo_data' UNION "
            "SELECT deleted_at FROM sources WHERE id = 'demo_data' UNION "
            'SELECT deleted_at FROM record_notes WHERE id = ?',
            variables: [Variable.withInt(noteId)],
          )
          .get();
      expect(stamps, hasLength(1), reason: 'one transaction, one stamp');
    });

    test('clearDemoData also removes what was scanned or attached for the '
        "demo person, and leaves other people's sources", () async {
      await repository.loadDemoData();
      await until(() async => await liveDemoRows() == 27);
      await db.customStatement(
        "UPDATE sources SET holder_id = 'john-doe-patient-001' "
        "WHERE id = 'demo_data'",
      );
      await syncLocal.cacheSources(const [
        Source(
          id: 'wallet-john-doe-patient-001',
          holderId: 'john-doe-patient-001',
        ),
        Source(id: 'wallet-jane', holderId: 'jane'),
      ]);
      await seed([dto('scan-1', sourceId: 'wallet-john-doe-patient-001')]);
      await seed([dto('mine', sourceId: 'wallet-jane')]);

      await repository.clearDemoData();

      expect(await ids(repository.getResources()), ['mine']);
      expect(
        (await syncLocal.getSources()).map((s) => s.id),
        ['wallet-jane'],
      );
    });

    test(
      'loading demo data again after clearing brings the rows back',
      () async {
        await repository.loadDemoData();
        await until(() async => await liveDemoRows() == 27);
        await repository.clearDemoData();

        await repository.loadDemoData();
        await until(() async => await liveDemoRows() == 27);

        expect(await repository.hasDemoData(), isTrue);
        final source = await rowOf('sources', 'demo_data');
        expect(source['deleted_at'], isNull);
        expect(
          source['updated_at'] as int,
          greaterThan(1e12),
          reason: 'stamped by the trigger in ms units, not drift seconds',
        );
        expect(
          (await syncLocal.getSources()).map((s) => s.id),
          contains('demo_data'),
        );
      },
    );
  });

  group('saveObservation and updatePatient', () {
    Observation observation({String id = 'obs-1'}) => Observation.fromLocalData(
      FhirResourceLocalDto(
        id: id,
        sourceId: 'src-1',
        resourceType: 'Observation',
        resourceId: id,
        title: 'Blood type',
        resourceRaw: jsonEncode(
          rawOf(
            'Observation',
            id,
            subject: 'Patient/pat-1',
            encounter: 'Encounter/enc-1',
          ),
        ),
      ),
    );

    Patient patient({String id = 'pat-1'}) => Patient.fromLocalData(
      FhirResourceLocalDto(
        id: id,
        sourceId: 'src-1',
        resourceType: 'Patient',
        resourceId: id,
        title: 'Jane',
        resourceRaw: jsonEncode({'resourceType': 'Patient', 'id': id}),
      ),
    );

    test('saveObservation stores the record with its visit and '
        'patient', () async {
      await repository.saveObservation(observation());

      final row = await rowOf('fhir_resource', 'obs-1');
      expect(row['encounter_id'], 'enc-1');
      expect(row['subject_id'], 'pat-1');
      expect(row['title'], 'Blood type');
    });

    test('saveObservation without references stores no ids', () async {
      final bare = Observation.fromLocalData(
        FhirResourceLocalDto(
          id: 'obs-2',
          resourceType: 'Observation',
          resourceRaw: jsonEncode(rawOf('Observation', 'obs-2')),
        ),
      );
      await repository.saveObservation(bare);

      final row = await rowOf('fhir_resource', 'obs-2');
      expect(row['encounter_id'], isNull);
      expect(row['subject_id'], isNull);
    });

    test('saveObservation rejects other types', () async {
      await expectLater(
        repository.saveObservation(patient()),
        throwsA(isA<Exception>()),
      );
    });

    test('saving a deleted observation again brings it back', () async {
      await repository.saveObservation(observation());
      await repository.deleteResource('obs-1');

      await repository.saveObservation(observation());

      expect((await rowOf('fhir_resource', 'obs-1'))['deleted_at'], isNull);
      expect(await ids(repository.getResources()), ['obs-1']);
    });

    test('updatePatient stores the patient as its own subject', () async {
      await repository.updatePatient(patient());

      final row = await rowOf('fhir_resource', 'pat-1');
      expect(row['subject_id'], 'pat-1');
      expect(row['encounter_id'], isNull);
    });

    test('updatePatient rejects other types and resurrects a deleted '
        'patient', () async {
      await expectLater(
        repository.updatePatient(observation()),
        throwsA(isA<Exception>()),
      );

      await repository.updatePatient(patient());
      await repository.deleteResource('pat-1');
      await repository.updatePatient(patient());

      expect((await rowOf('fhir_resource', 'pat-1'))['deleted_at'], isNull);
    });
  });

  group('searchResources', () {
    test('matches every term in the title or the raw record', () async {
      await seed([
        dto('a', title: 'Blood glucose', date: DateTime(2020)),
        dto(
          'b',
          title: 'Panel',
          date: DateTime(2024),
          raw: rawOf('Observation', 'b', text: 'Glucose fasting'),
        ),
        dto('c', title: 'Heart rate'),
      ]);

      expect(
        await ids(repository.searchResources(query: 'GLUCOSE')),
        ['a', 'b'],
        reason: 'title matches first',
      );
      expect(await ids(repository.searchResources(query: 'glucose fasting')), [
        'b',
      ]);
      expect(await repository.searchResources(query: '   '), isEmpty);
    });

    test(
      'filters by type, source and limit; a type name ranks first',
      () async {
        await seed([
          dto('obs', title: 'patient note', date: DateTime(2024)),
          dto('pat', type: 'Patient', title: 'Jane', date: DateTime(2020)),
          dto('other', title: 'patient', sourceId: 'src-2'),
        ]);

        expect(await ids(repository.searchResources(query: 'patient')), [
          'pat',
          'obs',
          'other',
        ]);
        expect(
          await ids(
            repository.searchResources(
              query: 'patient',
              resourceTypes: [FhirType.Observation],
              sourceId: 'src-1',
            ),
          ),
          ['obs'],
        );
        expect(
          await ids(repository.searchResources(query: 'patient', limit: 1)),
          hasLength(1),
        );
      },
    );

    test('keeps to a date filter and a test, then to the limit', () async {
      await seed([
        dto('a', title: 'glucose', date: DateTime(2024, 3)),
        dto('b', title: 'glucose', date: DateTime(2024, 2)),
        dto('c', title: 'glucose', date: DateTime(2023)),
        dto('d', title: 'glucose', date: DateTime(2024, 1)),
      ]);

      expect(
        await ids(
          repository.searchResources(
            query: 'glucose',
            dateFilter: const DateFilter(fromYear: 2024),
            where: (r) => r.id != 'a',
            limit: 1,
          ),
        ),
        ['b'],
      );
    });
  });

  test('searchResources keeps type and title matches ahead when they are '
      'already first', () async {
    await seed([
      dto('p', type: 'Patient', title: 'Jane', date: DateTime(2025)),
      dto('q', title: 'patient summary', date: DateTime(2024)),
      dto(
        'r',
        title: 'Vitals',
        date: DateTime(2023),
        raw: rawOf('Observation', 'r', subject: 'Patient/p'),
      ),
    ]);

    expect(await ids(repository.searchResources(query: 'patient')), [
      'p',
      'q',
      'r',
    ]);
  });

  group('buildIpsExport', () {
    test('throws when there is no patient', () async {
      await seed([dto('obs-1')]);

      await expectLater(
        repository.buildIpsExport(),
        throwsA(isA<Exception>()),
      );
    });

    test('renders the IPS PDF of the chosen patient', () async {
      await seed([
        dto(
          'pat-1',
          type: 'Patient',
          raw: {
            'resourceType': 'Patient',
            'id': 'pat-1',
            'name': [
              {
                'family': "O'Neil",
                'given': ['Mary Ann'],
              },
            ],
          },
        ),
        dto('pat-2', type: 'Patient', sourceId: 'src-2'),
        dto(
          'obs-1',
          raw: rawOf('Observation', 'obs-1', subject: 'Patient/pat-1'),
        ),
      ]);

      final export = await repository.buildIpsExport(patientId: 'pat-1');

      expect(String.fromCharCodes(export.bytes.take(4)), '%PDF');
      expect(export.patientName, 'ONeil_Mary_Ann');

      final first = await repository.buildIpsExport(sourceId: 'src-2');
      expect(first.patientName, 'Unknown');
    });

    test("with the person's sources, the export reads those sources", () async {
      await seed([
        dto('pat-1', type: 'Patient'),
        dto('obs-1', sourceId: 'src-2'),
      ]);

      final export = await repository.buildIpsExport(
        patientId: 'pat-1',
        sourceIds: ['src-1', 'src-2'],
      );
      expect(String.fromCharCodes(export.bytes.take(4)), '%PDF');

      await expectLater(
        repository.buildIpsExport(patientId: 'pat-1', sourceIds: ['src-2']),
        throwsA(isA<Exception>()),
        reason: 'the Patient row is read from the given sources too',
      );
    });

    test('a deleted patient is not exported', () async {
      await seed([dto('pat-1', type: 'Patient')]);
      await tombstone('fhir_resource', 'pat-1');

      await expectLater(
        repository.buildIpsExport(patientId: 'pat-1'),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('in-place updates', () {
    test('updateResourceRaw and setSpecialtyOverride change one '
        'column', () async {
      await seed([dto('obs-1')]);

      await repository.updateResourceRaw('obs-1', '{"x":1}');
      await repository.setSpecialtyOverride('obs-1', 'Cardiology');

      final row = await rowOf('fhir_resource', 'obs-1');
      expect(row['resource_raw'], '{"x":1}');
      expect(row['specialty_override'], 'Cardiology');

      await repository.setSpecialtyOverride('obs-1', null);
      expect(
        (await rowOf('fhir_resource', 'obs-1'))['specialty_override'],
        isNull,
      );
    });

    test('they do not bring a deleted record back', () async {
      await seed([dto('obs-1')]);
      await repository.deleteResource('obs-1');

      await repository.updateResourceRaw('obs-1', '{"x":1}');
      await repository.setSpecialtyOverride('obs-1', 'Cardiology');

      expect((await rowOf('fhir_resource', 'obs-1'))['deleted_at'], isNotNull);
      expect(await repository.getResources(), isEmpty);
    });
  });
}
