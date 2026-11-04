import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/data/local/app_database.dart';
import 'package:health_wallet/features/wallet_pass/domain/service/emergency_card_builder.dart';

import '../../../records/records_test_helpers.dart';

void main() {
  late AppDatabase db;
  late EmergencyCardBuilder builder;

  setUp(() async {
    db = openTestDatabase();
    builder = EmergencyCardBuilder(await openRepository(db));
    await insertResource(
      db,
      id: 'tom',
      type: 'Patient',
      sourceId: 's2',
      raw: {
        'name': [
          {
            'family': 'Doe',
            'given': ['Tom'],
          },
        ],
      },
    );
    await insertResource(
      db,
      id: 'tom-asthma',
      type: 'Condition',
      sourceId: 's2',
      raw: {
        'code': {'text': 'Asthma'},
      },
    );
    await insertResource(
      db,
      id: 'tom-penicillin',
      type: 'AllergyIntolerance',
      sourceId: 's2',
      raw: {
        'patient': {'reference': 'Patient/tom'},
        'code': {'text': 'Penicillin'},
      },
    );
  });

  tearDown(() => db.close());

  test('a patient without a source gets none of the other patients\' '
      'records', () async {
    await insertResource(
      db,
      id: 'jane',
      type: 'Patient',
      sourceId: '',
      raw: {
        'name': [
          {
            'family': 'Doe',
            'given': ['Jane'],
          },
        ],
      },
    );

    final card = await builder.build(patientId: 'jane');

    expect(card.conditions, isEmpty);
    expect(card.allergies, isEmpty);
  });

  test('a patient gets the records of their own sources', () async {
    final card = await builder.build(patientId: 'tom');

    expect(card.conditions, ['Asthma']);
    expect(card.allergies, ['Penicillin']);
  });

  test(
    "the person's wallet row gets the records of all their sources",
    () async {
      await insertResource(
        db,
        id: 'tom-wallet',
        type: 'Patient',
        sourceId: 'wallet-tom',
        raw: {
          'name': [
            {
              'family': 'Doe',
              'given': ['Tom'],
            },
          ],
        },
      );

      final card = await builder.build(
        patientId: 'tom-wallet',
        sourceIds: ['s2', 'wallet-tom'],
      );

      expect(card.conditions, ['Asthma']);
      expect(card.allergies, ['Penicillin']);
    },
  );
}
