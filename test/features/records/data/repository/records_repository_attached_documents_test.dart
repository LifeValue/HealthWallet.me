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
  });

  tearDown(() => db.close());

  Future<void> document(
    String id, {
    DateTime? date,
    String? encounterId,
    Map<String, dynamic>? context,
  }) => insertResource(
    db,
    id: id,
    type: 'DocumentReference',
    date: date ?? DateTime(2024),
    encounterId: encounterId,
    raw: {'context': ?context},
  );

  Future<List<String>> attachedTo(IFhirResource record) async => [
    for (final doc in await repository.getAttachedDocuments(record)) doc.id,
  ];

  test('finds an old document behind more than 100 newer ones', () async {
    await document(
      'old-scan',
      date: DateTime(2015),
      context: {
        'related': [
          {'reference': 'Condition/cond-1'},
        ],
      },
    );
    for (var i = 0; i < 150; i++) {
      await document('note-$i', date: DateTime(2024, 1, 1 + i % 28));
    }

    expect(
      await attachedTo(const Condition(id: 'cond-1', resourceId: 'cond-1')),
      ['old-scan'],
    );
  });

  test('an encounter has the documents of the encounter', () async {
    await document('by-column', encounterId: 'enc-1');
    await document(
      'by-context',
      context: {
        'encounter': [
          {'reference': 'Encounter/enc-1'},
        ],
      },
    );
    await document('other-encounter', encounterId: 'enc-2');

    expect(
      await attachedTo(const Encounter(id: 'enc-1', resourceId: 'enc-1')),
      unorderedEquals(['by-column', 'by-context']),
    );
  });

  test('a record has only the documents related to it', () async {
    await document(
      'mine',
      context: {
        'related': [
          {'reference': 'Condition/cond-1'},
        ],
      },
    );
    await document(
      'similar id',
      context: {
        'related': [
          {'reference': 'Condition/cond-10'},
        ],
      },
    );

    expect(
      await attachedTo(const Condition(id: 'cond-1', resourceId: 'cond-1')),
      ['mine'],
    );
  });
}
