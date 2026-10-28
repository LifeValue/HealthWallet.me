import 'dart:convert';

import 'package:fhir_r4/fhir_r4.dart' as fhir_r4;
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/data/local/app_database.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/records/domain/repository/records_repository.dart';
import 'package:health_wallet/features/wallet_pass/domain/service/emergency_card_builder.dart';

class _FakeRecordsRepository extends Fake implements RecordsRepository {
  final resources = <IFhirResource>[];
  final bloodTypeObservations = <IFhirResource>[];
  final requests = <({List<FhirType> types, List<String>? sourceIds})>[];
  final bloodTypeRequests = <String>[];

  @override
  Future<List<IFhirResource>> getResources({
    List<FhirType> resourceTypes = const [],
    String? sourceId,
    List<String>? sourceIds,
    int limit = 20,
    int offset = 0,
    DateFilter? dateFilter,
  }) async {
    requests.add((types: resourceTypes, sourceIds: sourceIds));
    expect(limit, 100);
    return resources
        .where((r) => resourceTypes.contains(r.fhirType))
        .where((r) => sourceIds == null || sourceIds.contains(r.sourceId))
        .toList();
  }

  @override
  Future<List<IFhirResource>> getBloodTypeObservations({
    required String patientId,
    String? sourceId,
  }) async {
    bloodTypeRequests.add(patientId);
    return bloodTypeObservations;
  }
}

/// The app entity for [json] as read from the database: local id
/// `<sourceId>_<id>` unless [id] is given.
IFhirResource _record(
  Map<String, dynamic> json, {
  String sourceId = 'src-1',
  String? id,
  String title = '',
}) => IFhirResource.fromLocalDto(
  FhirResourceLocalDto(
    id: id ?? '${sourceId}_${json['id']}',
    sourceId: sourceId,
    resourceType: json['resourceType'] as String,
    resourceId: json['id'] as String?,
    title: title,
    resourceRaw: jsonEncode(json),
  ),
);

Map<String, dynamic> _status(String code) => {
  'coding': [
    {'code': code},
  ],
};

IFhirResource _allergy(
  String name, {
  String? clinical,
  String? verification,
  Map<String, dynamic>? clinicalConcept,
  String sourceId = 'src-1',
}) => _record({
  'resourceType': 'AllergyIntolerance',
  'id': 'allergy-$name-$clinical-$verification',
  'patient': {'reference': 'Patient/pat-1'},
  'code': {'text': name},
  'clinicalStatus': ?(clinical == null ? clinicalConcept : _status(clinical)),
  if (verification != null) 'verificationStatus': _status(verification),
}, sourceId: sourceId);

IFhirResource _condition(
  String name, {
  String? clinical,
  String? verification,
  String sourceId = 'src-1',
}) => _record({
  'resourceType': 'Condition',
  'id': 'condition-$name-$clinical-$verification',
  'subject': {'reference': 'Patient/pat-1'},
  'code': {'text': name},
  if (clinical != null) 'clinicalStatus': _status(clinical),
  if (verification != null) 'verificationStatus': _status(verification),
}, sourceId: sourceId);

IFhirResource _statement(
  String title, {
  String status = 'active',
  Map<String, dynamic>? medication,
}) => _record(
  {
    'resourceType': 'MedicationStatement',
    'id': 'statement-$title-$status',
    'status': status,
    'subject': {'reference': 'Patient/pat-1'},
    'medicationCodeableConcept': medication ?? {'text': 'coded $title'},
  },
  title: title,
);

IFhirResource _request({
  required String id,
  String status = 'active',
  Map<String, dynamic>? concept,
  Map<String, dynamic>? reference,
  String title = '',
}) => _record(
  {
    'resourceType': 'MedicationRequest',
    'id': id,
    'status': status,
    'intent': 'order',
    'subject': {'reference': 'Patient/pat-1'},
    'medicationCodeableConcept': ?concept,
    'medicationReference': ?reference,
  },
  title: title,
);

IFhirResource _patient({
  String sourceId = 'src-1',
  String id = 'src-1_pat-1',
}) => _record(
  {
    'resourceType': 'Patient',
    'id': 'pat-1',
    'name': [
      {
        'family': 'Doe',
        'given': ['Jane', 'Ann'],
      },
    ],
    'birthDate': '1980-05-17',
    'gender': 'female',
    'telecom': [
      {'system': 'email', 'value': 'jane@example.com'},
      {'system': 'phone', 'value': '+40 700 000 001'},
    ],
    'contact': [
      {
        'name': {
          'given': ['John'],
          'family': 'Doe',
        },
        'telecom': [
          {'system': 'phone', 'value': '+40 700 000 002'},
        ],
      },
    ],
  },
  sourceId: sourceId,
  id: id,
);

void main() {
  late _FakeRecordsRepository repository;
  late EmergencyCardBuilder builder;

  setUp(() {
    repository = _FakeRecordsRepository();
    builder = EmergencyCardBuilder(repository);
  });

  group('patient', () {
    test('throws when the patient is not stored', () async {
      repository.resources.add(_patient(id: 'src-1_other'));

      await expectLater(
        builder.build(patientId: 'src-1_pat-1'),
        throwsA(
          isA<Exception>().having(
            (e) => '$e',
            'message',
            contains('Patient not found'),
          ),
        ),
      );
    });

    test('reads name, birth date, gender, phone and contact', () async {
      repository.resources.add(_patient());

      final card = await builder.build(patientId: 'src-1_pat-1');

      expect(card.patientName, 'Doe, Jane Ann');
      expect(card.dateOfBirth, DateTime(1980, 5, 17));
      expect(card.gender, 'female');
      expect(card.patientPhone, '+40 700 000 001');
      expect(card.emergencyContactName, isNotNull);
      expect(card.emergencyContactName, contains('John'));
      expect(card.emergencyContactPhone, '+40 700 000 002');
      expect(card.bloodType, isNull);
      expect(card.allergies, isEmpty);
      expect(card.conditions, isEmpty);
      expect(card.medications, isEmpty);
    });

    test('a patient without name or contact gives empty fields', () async {
      repository.resources.add(
        _record({'resourceType': 'Patient', 'id': 'pat-1'}),
      );

      final card = await builder.build(patientId: 'src-1_pat-1');

      expect(card.patientName, '');
      expect(card.dateOfBirth, isNull);
      expect(card.patientPhone, isNull);
      expect(card.emergencyContactName, isNull);
      expect(card.emergencyContactPhone, isNull);
    });

    test('reads the blood type of the patient', () async {
      repository.resources.add(_patient());
      repository.bloodTypeObservations.add(
        _record({
          'resourceType': 'Observation',
          'id': 'blood',
          'status': 'final',
          'code': {
            'coding': [
              {'system': 'http://loinc.org', 'code': '34530-6'},
            ],
          },
          'valueCodeableConcept': {'text': 'A+'},
        }),
      );

      final card = await builder.build(patientId: 'src-1_pat-1');

      expect(repository.bloodTypeRequests, ['src-1_pat-1']);
      expect(card.bloodType, 'A+');
    });
  });

  group('sources', () {
    test('reads items only from the sources of the patient', () async {
      repository.resources.addAll([
        _patient(),
        _patient(sourceId: 'src-2', id: 'src-1_pat-1'),
        _patient(sourceId: 'src-3', id: 'src-3_pat-9'),
        _allergy('Peanuts'),
        _allergy('Latex', sourceId: 'src-2'),
        _allergy('Pollen', sourceId: 'src-3'),
      ]);

      final card = await builder.build(patientId: 'src-1_pat-1');

      expect(card.allergies, ['Peanuts', 'Latex']);
      final itemRequests = repository.requests.skip(1);
      expect(itemRequests.map((r) => r.types), [
        [FhirType.AllergyIntolerance],
        [FhirType.Condition],
        [FhirType.MedicationStatement],
        [FhirType.MedicationRequest],
      ]);
      for (final request in itemRequests) {
        expect(request.sourceIds, ['src-1', 'src-2']);
      }
    });

    test('reads every source when the patient has no source id', () async {
      repository.resources.addAll([
        _patient(sourceId: '', id: 'pat-1'),
        _allergy('Pollen', sourceId: 'src-3'),
      ]);

      final card = await builder.build(patientId: 'pat-1');

      expect(card.allergies, ['Pollen']);
      expect(repository.requests.skip(1).map((r) => r.sourceIds), [
        null,
        null,
        null,
        null,
      ]);
    });
  });

  group('allergies', () {
    test('keeps active and status-less allergies', () async {
      repository.resources.addAll([
        _patient(),
        _allergy('Peanuts', clinical: 'active'),
        _allergy('Latex'),
        _allergy('Shellfish', verification: 'confirmed'),
        _allergy('Dust', verification: 'unconfirmed'),
      ]);

      final card = await builder.build(patientId: 'src-1_pat-1');

      expect(card.allergies, ['Peanuts', 'Latex', 'Shellfish', 'Dust']);
    });

    test('drops inactive and resolved allergies', () async {
      repository.resources.addAll([
        _patient(),
        _allergy('Penicillin', clinical: 'inactive'),
        _allergy('Eggs', clinical: 'resolved'),
        _allergy('Peanuts', clinical: 'active'),
      ]);

      final card = await builder.build(patientId: 'src-1_pat-1');

      expect(card.allergies, ['Peanuts']);
    });

    test('drops refuted and entered-in-error allergies', () async {
      repository.resources.addAll([
        _patient(),
        _allergy('Penicillin', clinical: 'active', verification: 'refuted'),
        _allergy('Eggs', verification: 'entered-in-error'),
        _allergy('Peanuts', verification: 'confirmed'),
      ]);

      final card = await builder.build(patientId: 'src-1_pat-1');

      expect(card.allergies, ['Peanuts']);
    });

    test('reads an uncoded status from its text, ignoring case', () async {
      repository.resources.addAll([
        _patient(),
        _allergy('Penicillin', clinicalConcept: {'text': ' Resolved '}),
        _allergy(
          'Eggs',
          clinicalConcept: {
            'coding': [
              {'code': 'INACTIVE'},
            ],
          },
        ),
        _allergy('Peanuts', clinicalConcept: {'text': 'Active'}),
        _allergy(
          'Latex',
          clinicalConcept: {
            'coding': [
              {'display': 'Active'},
            ],
          },
        ),
      ]);

      final card = await builder.build(patientId: 'src-1_pat-1');

      expect(card.allergies, ['Peanuts', 'Latex']);
    });

    test('skips allergies without a name', () async {
      repository.resources.addAll([
        _patient(),
        _record({
          'resourceType': 'AllergyIntolerance',
          'id': 'nameless',
          'patient': {'reference': 'Patient/pat-1'},
        }),
        _allergy('   '),
        _allergy('Peanuts'),
      ]);

      final card = await builder.build(patientId: 'src-1_pat-1');

      expect(card.allergies, ['Peanuts']);
    });
  });

  group('conditions', () {
    test('keeps active, recurring and status-less conditions', () async {
      repository.resources.addAll([
        _patient(),
        _condition('Asthma', clinical: 'active'),
        _condition('Migraine', clinical: 'recurrence'),
        _condition('Diabetes'),
        _condition('Epilepsy', verification: 'provisional'),
      ]);

      final card = await builder.build(patientId: 'src-1_pat-1');

      expect(card.conditions, ['Asthma', 'Migraine', 'Diabetes', 'Epilepsy']);
    });

    test('drops inactive, resolved and remission conditions', () async {
      repository.resources.addAll([
        _patient(),
        _condition('Flu', clinical: 'resolved'),
        _condition('Fracture', clinical: 'inactive'),
        _condition('Leukemia', clinical: 'remission'),
        _condition('Asthma', clinical: 'active'),
      ]);

      final card = await builder.build(patientId: 'src-1_pat-1');

      expect(card.conditions, ['Asthma']);
    });

    test('drops refuted and entered-in-error conditions', () async {
      repository.resources.addAll([
        _patient(),
        _condition('Lupus', clinical: 'active', verification: 'refuted'),
        _condition('Gout', verification: 'entered-in-error'),
        _condition('Asthma', verification: 'confirmed'),
      ]);

      final card = await builder.build(patientId: 'src-1_pat-1');

      expect(card.conditions, ['Asthma']);
    });
  });

  group('medications', () {
    test('keeps MedicationStatements that may be current', () async {
      repository.resources.addAll([
        _patient(),
        _statement('Aspirin'),
        _statement('Insulin', status: 'intended'),
        _statement('Warfarin', status: 'on-hold'),
        _statement('Metformin', status: 'unknown'),
        const MedicationStatement(sourceId: 'src-1', title: 'Ibuprofen'),
      ]);

      final card = await builder.build(patientId: 'src-1_pat-1');

      expect(card.medications, [
        'Aspirin',
        'Insulin',
        'Warfarin',
        'Metformin',
        'Ibuprofen',
      ]);
    });

    test(
      'drops completed, stopped, not-taken and erroneous statements',
      () async {
        repository.resources.addAll([
          _patient(),
          _statement('Amoxicillin', status: 'completed'),
          _statement('Codeine', status: 'stopped'),
          _statement('Prednisone', status: 'not-taken'),
          _statement('Heparin', status: 'entered-in-error'),
          _statement('Aspirin'),
        ]);

        final card = await builder.build(patientId: 'src-1_pat-1');

        expect(card.medications, ['Aspirin']);
      },
    );

    test('names a statement by its title, else by its medication', () async {
      repository.resources.addAll([
        _patient(),
        _statement('Aspirin 100 mg'),
        _statement(' ', medication: {'text': 'Lisinopril'}),
        _statement(
          '',
          medication: {
            'coding': [
              {'code': '123'},
            ],
          },
        ),
      ]);

      final card = await builder.build(patientId: 'src-1_pat-1');

      expect(card.medications, ['Aspirin 100 mg', 'Lisinopril']);
    });

    test('keeps MedicationRequests that may be current', () async {
      repository.resources.addAll([
        _patient(),
        _request(id: 'r1', concept: {'text': 'Atorvastatin'}),
        _request(id: 'r2', status: 'on-hold', concept: {'text': 'Warfarin'}),
        _request(id: 'r3', status: 'unknown', concept: {'text': 'Metformin'}),
        MedicationRequest(
          sourceId: 'src-1',
          medicationX: fhir_r4.CodeableConcept(
            text: fhir_r4.FhirString('Ibuprofen'),
          ),
        ),
      ]);

      final card = await builder.build(patientId: 'src-1_pat-1');

      expect(card.medications, [
        'Atorvastatin',
        'Warfarin',
        'Metformin',
        'Ibuprofen',
      ]);
    });

    test(
      'drops cancelled, completed, stopped, draft and erroneous requests',
      () async {
        repository.resources.addAll([
          _patient(),
          for (final status in [
            'cancelled',
            'completed',
            'stopped',
            'draft',
            'entered-in-error',
          ])
            _request(id: status, status: status, concept: {'text': status}),
          _request(id: 'kept', concept: {'text': 'Atorvastatin'}),
        ]);

        final card = await builder.build(patientId: 'src-1_pat-1');

        expect(card.medications, ['Atorvastatin']);
      },
    );

    test('names a request by its medication, else by its title', () async {
      repository.resources.addAll([
        _patient(),
        _request(
          id: 'coded',
          concept: {'text': 'Atorvastatin'},
          title: 'Prescription',
        ),
        _request(id: 'referenced', reference: {'display': 'Levothyroxine'}),
        const MedicationRequest(sourceId: 'src-1', title: 'Omeprazole'),
        const MedicationRequest(sourceId: 'src-1'),
      ]);

      final card = await builder.build(patientId: 'src-1_pat-1');

      expect(card.medications, ['Atorvastatin', 'Levothyroxine', 'Omeprazole']);
    });

    test('lists statements before requests', () async {
      repository.resources.addAll([
        _patient(),
        _request(id: 'r1', concept: {'text': 'Atorvastatin'}),
        _statement('Aspirin'),
      ]);

      final card = await builder.build(patientId: 'src-1_pat-1');

      expect(card.medications, ['Aspirin', 'Atorvastatin']);
    });
  });

  group('de-duplication', () {
    test(
      'drops repeated names ignoring case; the first spelling wins',
      () async {
        repository.resources.addAll([
          _patient(),
          _allergy('Peanuts'),
          _allergy('peanuts', clinical: 'active'),
          _allergy('PEANUTS ', sourceId: 'src-1', verification: 'confirmed'),
          _condition('Asthma'),
          _condition('asthma', clinical: 'active'),
          _statement('Aspirin'),
          _request(id: 'r1', concept: {'text': 'ASPIRIN'}),
          _request(id: 'r2', concept: {'text': 'Atorvastatin'}),
        ]);

        final card = await builder.build(patientId: 'src-1_pat-1');

        expect(card.allergies, ['Peanuts']);
        expect(card.conditions, ['Asthma']);
        expect(card.medications, ['Aspirin', 'Atorvastatin']);
      },
    );

    test('a dropped item does not hide a kept one of the same name', () async {
      repository.resources.addAll([
        _patient(),
        _condition('Asthma', clinical: 'resolved'),
        _condition('ASTHMA', clinical: 'active'),
      ]);

      final card = await builder.build(patientId: 'src-1_pat-1');

      expect(card.conditions, ['ASTHMA']);
    });
  });
}
