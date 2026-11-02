import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/utils/fhir_reference_utils.dart';

void main() {
  group('FhirReferenceUtils.extractReferenceId', () {
    test('returns null for null input', () {
      expect(FhirReferenceUtils.extractReferenceId(null), isNull);
    });

    test('extracts id from urn:uuid: format', () {
      expect(
        FhirReferenceUtils.extractReferenceId('urn:uuid:1234-5678'),
        '1234-5678',
      );
    });

    test('extracts id from ResourceType/id format', () {
      expect(
        FhirReferenceUtils.extractReferenceId('Patient/abc-123'),
        'abc-123',
      );
      expect(
        FhirReferenceUtils.extractReferenceId('Observation/xyz-789'),
        'xyz-789',
      );
    });

    test('ignores the version of a versioned reference', () {
      expect(
        FhirReferenceUtils.extractReferenceId('Patient/pat-7/_history/3'),
        'pat-7',
      );
      expect(
        FhirReferenceUtils.extractReferenceId(
          'https://fhir.example.org/r4/Patient/pat-7/_history/12',
        ),
        'pat-7',
      );
    });

    test('returns id for plain id', () {
      expect(FhirReferenceUtils.extractReferenceId('plain-id'), 'plain-id');
    });
  });

  group('FhirReferenceUtils.patientIdOf', () {
    Map<String, dynamic> withRef(String field, String reference) => {
      field: {'reference': reference},
    };

    test('reads subject', () {
      expect(
        FhirReferenceUtils.patientIdOf(withRef('subject', 'Patient/p1')),
        'p1',
      );
    });

    test('reads patient, as allergies and immunizations name it', () {
      expect(
        FhirReferenceUtils.patientIdOf(withRef('patient', 'Patient/p1')),
        'p1',
      );
    });

    test('reads beneficiary, as coverage names it', () {
      expect(
        FhirReferenceUtils.patientIdOf(withRef('beneficiary', 'Patient/p1')),
        'p1',
      );
    });

    test('reads absolute and urn:uuid references', () {
      expect(
        FhirReferenceUtils.patientIdOf(
          withRef('patient', 'https://ehr.example/fhir/Patient/p1'),
        ),
        'p1',
      );
      expect(
        FhirReferenceUtils.patientIdOf(withRef('subject', 'urn:uuid:abc')),
        'abc',
      );
    });

    test('ignores a subject that is not a patient', () {
      expect(
        FhirReferenceUtils.patientIdOf(withRef('subject', 'Group/g1')),
        isNull,
      );
      expect(FhirReferenceUtils.patientIdOf(const {}), isNull);
      expect(
        FhirReferenceUtils.patientIdOf(withRef('subject', 'Patient/')),
        isNull,
      );
    });
  });
}
