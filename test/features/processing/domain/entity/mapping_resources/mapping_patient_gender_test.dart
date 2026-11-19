import 'package:fhir_r4/fhir_r4.dart' as fhir_r4;
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapped_property.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_patient.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';

void main() {
  // toFhirResource reads the device locale for the identifier system.
  TestWidgetsFlutterBinding.ensureInitialized();

  Patient save(MappingPatient draft) =>
      draft.toFhirResource(subjectId: 'p') as Patient;

  Patient saveGender(String gender) => save(
    MappingPatient(
      id: 'p',
      givenName: const MappedProperty(value: 'Ana'),
      familyName: const MappedProperty(value: 'Pop'),
      gender: MappedProperty(value: gender),
    ),
  );

  group('MappingPatient.toFhirResource gender', () {
    // The phase-1 extraction schema lets the AI answer '' for the gender.
    test('an empty gender is left out instead of throwing', () {
      final patient = saveGender('');

      expect(patient.gender, isNull);
      expect(patient.rawResource.containsKey('gender'), isFalse);
      expect(patient.id, 'p');
      expect(patient.title, 'Ana Pop');
    });

    test('a whitespace-only gender is left out', () {
      final patient = saveGender('  ');

      expect(patient.gender, isNull);
      expect(patient.rawResource.containsKey('gender'), isFalse);
    });

    test('a known code in any case is saved as the FHIR code', () {
      final patient = saveGender('Female');

      expect(
        patient.gender?.valueEnum,
        fhir_r4.AdministrativeGenderEnum.female,
      );
      expect(patient.rawResource['gender'], 'female');
    });

    test('every FHIR gender code is kept, with surrounding spaces trimmed', () {
      for (final (raw, code) in [
        ('male', 'male'),
        ('FEMALE', 'female'),
        (' Other ', 'other'),
        ('unknown', 'unknown'),
      ]) {
        expect(saveGender(raw).rawResource['gender'], code, reason: raw);
      }
    });

    // Not a FHIR code: no value is invented for it.
    test('an unrecognised gender is left out instead of throwing', () {
      final patient = saveGender('x');

      expect(patient.gender, isNull);
      expect(patient.rawResource.containsKey('gender'), isFalse);
    });

    test('a null gender from the AI JSON is left out', () {
      for (final json in [
        {'gender': null},
        {
          'gender': {'value': null, 'confidenceLevel': 0.0},
        },
        <String, dynamic>{},
      ]) {
        final patient = save(
          MappingPatient.fromJson({'id': 'p', 'givenName': 'Ana', ...json}),
        );

        expect(patient.gender, isNull, reason: '$json');
        expect(patient.rawResource.containsKey('gender'), isFalse);
      }
    });
  });
}
