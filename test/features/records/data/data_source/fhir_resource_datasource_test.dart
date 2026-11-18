import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/data/local/app_database.dart';
import 'package:health_wallet/features/records/data/data_source/fhir_resource_datasource.dart';

import '../../../desktop/lww_sync/lww_sync_test_helpers.dart';

void main() {
  late AppDatabase db;
  late FhirResourceDatasource datasource;

  setUp(() {
    db = openTestDatabase();
    datasource = FhirResourceDatasource(db);
  });

  tearDown(() => db.close());

  FhirResourceLocalDto local(
    String id, {
    String? sourceId = 'src-1',
    String type = 'Observation',
    String? encounterId,
    String? subjectId,
    String raw = '{}',
  }) => FhirResourceLocalDto(
    id: id,
    sourceId: sourceId,
    resourceType: type,
    resourceId: id,
    title: id,
    resourceRaw: raw,
    encounterId: encounterId,
    subjectId: subjectId,
  );

  Future<void> tombstone(String id) => db.customStatement(
    'UPDATE fhir_resource SET deleted_at = ?, updated_at = ? WHERE id = ?',
    [ms(at(0)), ms(at(0)), id],
  );

  Future<Map<String, Object?>> rowOf(String id) async =>
      (await fetchRow(db, 'fhir_resource', id))!;

  group('insertResource', () {
    test('inserts, then updates the same id', () async {
      await datasource.insertResource(local('a', encounterId: 'e'));
      await datasource.insertResource(
        local('a', sourceId: 'src-2', subjectId: 'p', raw: '{"v":2}'),
      );

      final row = await rowOf('a');
      expect(row['source_id'], 'src-2');
      expect(row['subject_id'], 'p');
      expect(row['resource_raw'], '{"v":2}');
      expect(row['encounter_id'], 'e', reason: 'absent ids are kept');
      expect(await countRows(db, 'fhir_resource'), 1);
    });

    test('saving a deleted record clears its tombstone', () async {
      await datasource.insertResource(local('a'));
      await tombstone('a');

      await datasource.insertResource(local('a', raw: '{"v":2}'));

      final row = await rowOf('a');
      expect(row['deleted_at'], isNull);
      expect(row['resource_raw'], '{"v":2}');
      expect(row['updated_at'], isNot(ms(at(0))));
    });
  });

  group('deletes are soft', () {
    setUp(() async {
      for (final dto in [
        local('a1'),
        local('a2'),
        local('b1', sourceId: 'src-2'),
      ]) {
        await datasource.insertResource(dto);
      }
      await insertNote(db, id: 1, content: 'n', resourceId: 'a1');
    });

    test('deleteResourceById tombstones one record and its notes', () async {
      final before = DateTime.now().millisecondsSinceEpoch;

      expect(await datasource.deleteResourceById('a1'), 1);

      final row = await rowOf('a1');
      expect(row['deleted_at'] as int, greaterThanOrEqualTo(before));
      expect(row['updated_at'], row['deleted_at']);
      expect(
        (await fetchRow(db, 'record_notes', 1))!['deleted_at'],
        row['deleted_at'],
      );
      expect(await countRows(db, 'fhir_resource'), 3);
      expect(await datasource.deleteResourceById('a1'), 0);
    });

    test('deleteResourcesByIds tombstones each record', () async {
      expect(await datasource.deleteResourcesByIds(['a1', 'b1']), 2);

      expect((await rowOf('a1'))['deleted_at'], isNotNull);
      expect((await rowOf('a2'))['deleted_at'], isNull);
      expect((await rowOf('b1'))['deleted_at'], isNotNull);
    });

    test('deleteResourcesBySourceId tombstones the records of a '
        'source', () async {
      expect(await datasource.deleteResourcesBySourceId('src-1'), 2);

      expect((await rowOf('a1'))['deleted_at'], isNotNull);
      expect((await rowOf('a2'))['deleted_at'], isNotNull);
      expect((await rowOf('b1'))['deleted_at'], isNull);
      expect((await fetchRow(db, 'record_notes', 1))!['deleted_at'], isNotNull);
    });
  });

  group('reads hide deleted records', () {
    setUp(() async {
      for (final dto in [
        local('live', encounterId: 'e', subjectId: 'p'),
        local('gone', encounterId: 'e', subjectId: 'p', sourceId: 'src-2'),
        local('other', subjectId: 'p', sourceId: ''),
        local('nosource', subjectId: 'p', sourceId: null),
      ]) {
        await datasource.insertResource(dto);
      }
      await tombstone('gone');
    });

    test('getResources and getResourcesByEncounterId', () async {
      expect(
        (await datasource.getResources(resourceTypes: const [])).map(
          (r) => r.id,
        ),
        unorderedEquals(['live', 'other', 'nosource']),
      );
      expect(
        (await datasource.getResourcesByEncounterId(encounterId: 'e')).map(
          (r) => r.id,
        ),
        ['live'],
      );
      expect(
        await datasource.getResourcesByEncounterId(
          encounterId: 'e',
          sourceId: 'src-2',
        ),
        isEmpty,
      );
    });

    test('getRelatedResourceCount', () async {
      expect(await datasource.getRelatedResourceCount('e'), 1);
      expect(await datasource.getRelatedResourceCount('none'), 0);
    });

    test('getSourceIdsForSubject lists the non-empty sources of live '
        'records', () async {
      expect(await datasource.getSourceIdsForSubject('p'), ['src-1']);
      expect(await datasource.getSourceIdsForSubject('nobody'), isEmpty);
    });

    test('resolveReference and searchResources', () async {
      expect(await datasource.resolveReference('Observation/gone'), isNull);
      expect(await datasource.resolveReference('urn:uuid:gone'), isNull);
      expect(
        (await datasource.resolveReference('Observation/live'))!.id,
        'live',
      );
      expect(
        await datasource.searchResources(
          query: 'gone',
          resourceTypes: const [],
        ),
        isEmpty,
      );
    });
  });
}
