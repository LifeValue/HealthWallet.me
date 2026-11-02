import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/data/local/app_database.dart';
import 'package:health_wallet/features/records/data/repository/records_repository_impl.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';

import '../../records_test_helpers.dart';

void main() {
  late AppDatabase db;
  late RecordsRepositoryImpl repository;

  setUp(() async {
    db = openTestDatabase();
    repository = await openRepository(db);
    // Two patients on one phone: Jane's records come from s1 and s2, Tom's
    // from s3.
    await insertResource(
      db,
      id: 'jane-insulin',
      type: 'MedicationRequest',
      sourceId: 's1',
      title: 'Insulin glargine',
    );
    await insertResource(
      db,
      id: 'jane-insulin-2',
      type: 'MedicationRequest',
      sourceId: 's2',
      title: 'Insulin lispro',
    );
    await insertResource(
      db,
      id: 'tom-insulin',
      type: 'MedicationRequest',
      sourceId: 's3',
      title: 'Insulin aspart',
    );
  });

  tearDown(() => db.close());

  Set<String> ids(List<IFhirResource> resources) =>
      resources.map((r) => r.id).toSet();

  group('search', () {
    test('keeps to the patient\'s sources', () async {
      final results = await repository.searchResources(
        query: 'insulin',
        sourceIds: ['s1', 's2'],
      );

      expect(ids(results), {'jane-insulin', 'jane-insulin-2'});
    });

    test('keeps to one source', () async {
      final results = await repository.searchResources(
        query: 'insulin',
        sourceId: 's3',
      );

      expect(ids(results), {'tom-insulin'});
    });
  });

  group('an empty source list', () {
    test('lists nothing instead of every patient', () async {
      final results = await repository.getResources(sourceIds: []);

      expect(results, isEmpty);
    });

    test('finds nothing instead of every patient', () async {
      final results = await repository.searchResources(
        query: 'insulin',
        sourceIds: [],
      );

      expect(results, isEmpty);
    });
  });

  test('no scope still lists every source', () async {
    final results = await repository.getResources();

    expect(ids(results), {'jane-insulin', 'jane-insulin-2', 'tom-insulin'});
  });
}
