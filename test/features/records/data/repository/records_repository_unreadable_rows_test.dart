import 'package:drift/drift.dart' show BooleanExpressionOperators, Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/constants/blood_types.dart';
import 'package:health_wallet/core/data/local/app_database.dart';
import 'package:health_wallet/features/records/data/repository/records_repository_impl.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';

import '../../records_test_helpers.dart';

/// Rows whose `resource_raw` is not valid JSON, as a crash mid-write or an
/// old bug can leave them: the repository skips them and goes on.
void main() {
  late AppDatabase db;
  late RecordsRepositoryImpl repository;

  setUp(() async {
    db = openTestDatabase();
    repository = await openRepository(db);
  });

  tearDown(() => db.close());

  Future<void> insertUnreadable(
    String id, {
    required String type,
    required String raw,
    String? sourceId,
  }) => db
      .into(db.fhirResource)
      .insert(
        FhirResourceCompanion.insert(
          id: id,
          sourceId: Value(sourceId),
          resourceType: Value(type),
          resourceId: Value(id),
          resourceRaw: raw,
        ),
      );

  Future<bool> isLive(String id) async =>
      (await (db.select(
            db.fhirResource,
          )..where((r) => r.id.equals(id) & r.deletedAt.isNull()))
          .getSingleOrNull()) !=
      null;

  test('an unreadable document is left out of a record\'s attached '
      'documents', () async {
    await insertResource(
      db,
      id: 'doc-1',
      type: 'DocumentReference',
      encounterId: 'enc-1',
    );
    await insertUnreadable(
      'doc-broken',
      type: 'DocumentReference',
      raw: '{"context": {"encounter": [{"reference": "Encounter/enc-1"',
    );

    final documents = await repository.getAttachedDocuments(
      const Encounter(id: 'enc-1', resourceId: 'enc-1'),
    );

    expect(documents.map((d) => d.id), ['doc-1']);
  });

  test(
    'deleting a record keeps an unreadable document that mentions it',
    () async {
      await insertResource(db, id: 'obs-1', type: 'Observation');
      await insertUnreadable(
        'doc-broken',
        type: 'DocumentReference',
        raw: '{"context": {"related": [{"reference": "Observation/obs-1"}',
      );

      await repository.deleteResource('obs-1');

      expect(await isLive('obs-1'), isFalse);
      expect(await isLive('doc-broken'), isTrue);
    },
  );

  test(
    'clearing the demo data also clears an unreadable demo record',
    () async {
      await insertResource(
        db,
        id: 'demo-obs',
        type: 'Observation',
        sourceId: 'demo_data',
      );
      await insertUnreadable(
        'demo-broken',
        type: 'DocumentReference',
        sourceId: 'demo_data',
        raw: '{"content": [{"attachment": {"url": "file://demo.pdf"',
      );

      await repository.clearDemoData();

      expect(await isLive('demo-obs'), isFalse);
      expect(await isLive('demo-broken'), isFalse);
      expect(await repository.hasDemoData(), isFalse);
    },
  );

  test('an unreadable blood type observation is skipped', () async {
    await insertResource(db, id: 'jane', type: 'Patient');
    await insertResource(
      db,
      id: 'jane-abo',
      type: 'Observation',
      date: DateTime(2020),
      raw: {
        'code': {
          'coding': [
            {'system': 'http://loinc.org', 'code': BloodTypes.aboLoincCode},
          ],
        },
        'subject': {'reference': 'Patient/jane'},
      },
    );
    await insertUnreadable(
      'broken-abo',
      type: 'Observation',
      raw: '{"code": {"coding": [{"code": "${BloodTypes.aboLoincCode}"',
    );

    final found = await repository.getBloodTypeObservations(patientId: 'jane');

    expect(found.map((o) => o.id), ['jane-abo']);
  });
}
