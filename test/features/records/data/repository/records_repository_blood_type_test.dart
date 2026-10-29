import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/constants/blood_types.dart';
import 'package:health_wallet/core/data/local/app_database.dart';
import 'package:health_wallet/features/records/data/repository/records_repository_impl.dart';

import '../../records_test_helpers.dart';

void main() {
  late AppDatabase db;
  late RecordsRepositoryImpl repository;

  setUp(() async {
    db = openTestDatabase();
    repository = await openRepository(db);
    await insertResource(db, id: 'jane', type: 'Patient', sourceId: 's1');
    await insertResource(db, id: 'tom', type: 'Patient', sourceId: 's2');
  });

  tearDown(() => db.close());

  Future<void> bloodType(String id, String patient, DateTime date) =>
      insertResource(
        db,
        id: id,
        type: 'Observation',
        sourceId: patient == 'jane' ? 's1' : 's2',
        date: date,
        raw: {
          'code': {
            'coding': [
              {'system': 'http://loinc.org', 'code': BloodTypes.aboLoincCode},
            ],
          },
          'subject': {'reference': 'Patient/$patient'},
          'valueCodeableConcept': {'text': 'A+'},
        },
      );

  test(
    'finds the blood type behind more than 100 newer observations',
    () async {
      await bloodType('jane-abo', 'jane', DateTime(2015));
      for (var i = 0; i < 150; i++) {
        await insertResource(
          db,
          id: 'lab-$i',
          type: 'Observation',
          sourceId: 's1',
          date: DateTime(2024, 1, 1 + i % 28),
          raw: {
            'subject': {'reference': 'Patient/jane'},
          },
        );
      }

      final found = await repository.getBloodTypeObservations(
        patientId: 'jane',
      );

      expect(found.map((o) => o.id), ['jane-abo']);
    },
  );

  test('another patient\'s blood type is not returned', () async {
    await bloodType('tom-abo', 'tom', DateTime(2020));

    final found = await repository.getBloodTypeObservations(patientId: 'jane');

    expect(found, isEmpty);
  });

  test('an unknown patient gets nothing, not the first patient\'s', () async {
    await bloodType('jane-abo', 'jane', DateTime(2020));

    final found = await repository.getBloodTypeObservations(
      patientId: 'missing',
    );

    expect(found, isEmpty);
  });
}
