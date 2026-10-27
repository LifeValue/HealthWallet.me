import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/features/sync/data/dto/fhir_resource_dto.dart';

void main() {
  group('FhirResourceDto.fromJson', () {
    test('maps the backend snake_case keys', () {
      final dto = FhirResourceDto.fromJson({
        'id': 'row-1',
        'source_id': 'src-1',
        'source_resource_type': 'Observation',
        'source_resource_id': 'obs-1',
        'sort_title': 'Heart rate',
        'sort_date': '2024-05-06T07:08:09.000Z',
        'resource_raw': {'resourceType': 'Observation', 'id': 'obs-1'},
        'encounterId': 'enc-1',
        'subjectId': 'pat-1',
        'deleted_at': '2024-06-01T00:00:00.000Z',
        'change_type': 'deleted',
      });
      expect(
        dto,
        FhirResourceDto(
          id: 'row-1',
          sourceId: 'src-1',
          resourceType: 'Observation',
          resourceId: 'obs-1',
          title: 'Heart rate',
          date: DateTime.utc(2024, 5, 6, 7, 8, 9),
          resourceRaw: const {'resourceType': 'Observation', 'id': 'obs-1'},
          encounterId: 'enc-1',
          subjectId: 'pat-1',
          deletedAt: DateTime.utc(2024, 6),
          changeType: 'deleted',
        ),
      );
    });

    test('leaves every field null for an empty object', () {
      expect(FhirResourceDto.fromJson({}), const FhirResourceDto());
    });

    final dates = <Object?, DateTime?>{
      '2024-05-06': DateTime(2024, 5, 6),
      '2024-05-06T07:08:09Z': DateTime.utc(2024, 5, 6, 7, 8, 9),
      '2024-05-06T07:08:09+02:00': DateTime.utc(2024, 5, 6, 5, 8, 9),
      'yesterday': null,
      '': null,
      null: null,
    };
    dates.forEach((raw, expected) {
      test(
        'parses sort_date and deleted_at ${raw is String ? '"$raw"' : raw}',
        () {
          final dto = FhirResourceDto.fromJson({
            'sort_date': raw,
            'deleted_at': raw,
          });
          expect(dto.date, expected);
          expect(dto.deletedAt, expected);
        },
      );
    });

    test('round-trips through toJson', () {
      final dto = FhirResourceDto(
        id: 'row-1',
        sourceId: 'src-1',
        resourceType: 'Condition',
        resourceId: 'c-1',
        title: 'Asthma',
        date: DateTime.utc(2020, 1, 2),
        resourceRaw: const {'resourceType': 'Condition'},
        encounterId: 'e',
        subjectId: 's',
        changeType: 'created',
      );
      final json = dto.toJson();
      expect(json['source_resource_id'], 'c-1');
      expect(json['sort_date'], '2020-01-02T00:00:00.000Z');
      expect(json['deleted_at'], isNull);
      expect(FhirResourceDto.fromJson(json), dto);
    });
  });

  group('FhirResourceDto.populateEncounterIdFromRaw', () {
    final cases = <String, (Map<String, dynamic>?, String?)>{
      'relative reference': (
        {
          'encounter': {'reference': 'Encounter/enc-1'},
        },
        'enc-1',
      ),
      'urn:uuid reference': (
        {
          'encounter': {'reference': 'urn:uuid:1234-abcd'},
        },
        '1234-abcd',
      ),
      'absolute reference': (
        {
          'encounter': {'reference': 'https://fhir.example/Encounter/e9'},
        },
        'e9',
      ),
      'DocumentReference context.encounter': (
        {
          'context': {
            'encounter': [
              {'reference': 'Encounter/ctx-1'},
              {'reference': 'Encounter/ctx-2'},
            ],
          },
        },
        'ctx-1',
      ),
      'direct encounter wins over context': (
        {
          'encounter': {'reference': 'Encounter/direct'},
          'context': {
            'encounter': [
              {'reference': 'Encounter/ctx'},
            ],
          },
        },
        'direct',
      ),
      'display-only encounter falls back to context': (
        {
          'encounter': {'display': 'Visit'},
          'context': {
            'encounter': [
              {'reference': 'Encounter/ctx'},
            ],
          },
        },
        'ctx',
      ),
      'context without encounter': (
        {
          'context': {'period': {}},
        },
        null,
      ),
      'empty context.encounter': (
        {
          'context': {'encounter': <Object>[]},
        },
        null,
      ),
      'context.encounter without reference': (
        {
          'context': {
            'encounter': [
              {'display': 'x'},
            ],
          },
        },
        null,
      ),
      'no encounter at all': ({'resourceType': 'Patient'}, null),
      'no raw resource': (null, null),
    };

    cases.forEach((name, testCase) {
      final (raw, expected) = testCase;
      test(name, () {
        final dto = FhirResourceDto(
          resourceId: 'r',
          resourceRaw: raw,
          encounterId: 'previous',
        );
        final result = dto.populateEncounterIdFromRaw();
        if (expected == null) {
          expect(identical(result, dto), isTrue);
          expect(result.encounterId, 'previous');
        } else {
          expect(result, dto.copyWith(encounterId: expected));
        }
      });
    });
  });

  group('FhirResourceDto.populateSubjectIdFromRaw', () {
    test('extracts the subject id', () {
      const dto = FhirResourceDto(
        resourceRaw: {
          'subject': {'reference': 'Patient/pat-7'},
        },
      );
      expect(dto.populateSubjectIdFromRaw().subjectId, 'pat-7');
    });

    test('returns the same instance when there is no subject reference', () {
      const withoutSubject = FhirResourceDto(resourceRaw: {'id': 'x'});
      const displayOnly = FhirResourceDto(
        resourceRaw: {
          'subject': {'display': 'Jane'},
        },
      );
      expect(
        identical(withoutSubject.populateSubjectIdFromRaw(), withoutSubject),
        isTrue,
      );
      expect(
        identical(displayOnly.populateSubjectIdFromRaw(), displayOnly),
        isTrue,
      );
    });

    test('chains with populateEncounterIdFromRaw', () {
      const dto = FhirResourceDto(
        resourceRaw: {
          'subject': {'reference': 'Patient/p'},
          'encounter': {'reference': 'Encounter/e'},
        },
      );
      final result = dto
          .populateEncounterIdFromRaw()
          .populateSubjectIdFromRaw();
      expect(result.encounterId, 'e');
      expect(result.subjectId, 'p');
    });
  });

  group('FhirResourceDto.extractReferenceId', () {
    test('reads any reference-typed key', () {
      const dto = FhirResourceDto(
        resourceRaw: {
          'performer': {'reference': 'Practitioner/doc-1'},
        },
      );
      expect(dto.extractReferenceId('performer'), 'doc-1');
      expect(dto.extractReferenceId('missing'), isNull);
    });
  });

  group('FhirResourceDto change flags', () {
    final cases = <(String?, DateTime?), (bool, bool, bool, String)>{
      (null, null): (false, false, false, 'Unknown'),
      ('created', null): (false, true, false, 'Created'),
      ('updated', null): (false, false, true, 'Updated'),
      ('deleted', null): (true, false, false, 'Deleted'),
      ('other', null): (false, false, false, 'Unknown'),
      (null, DateTime(2024)): (true, false, false, 'Deleted'),
      ('created', DateTime(2024)): (true, true, false, 'Deleted'),
      ('updated', DateTime(2024)): (true, false, true, 'Deleted'),
    };
    cases.forEach((input, expected) {
      final (changeType, deletedAt) = input;
      final (isDeleted, isCreated, isUpdated, description) = expected;
      test('changeType=$changeType deletedAt=$deletedAt → $description', () {
        final dto = FhirResourceDto(
          changeType: changeType,
          deletedAt: deletedAt,
        );
        expect(dto.isDeleted, isDeleted);
        expect(dto.isCreated, isCreated);
        expect(dto.isUpdated, isUpdated);
        expect(dto.changeDescription, description);
      });
    });

    test('isDemoData is true only for the demo_data source', () {
      expect(const FhirResourceDto(sourceId: 'demo_data').isDemoData, isTrue);
      expect(const FhirResourceDto(sourceId: 'wallet').isDemoData, isFalse);
      expect(const FhirResourceDto().isDemoData, isFalse);
    });
  });
}
