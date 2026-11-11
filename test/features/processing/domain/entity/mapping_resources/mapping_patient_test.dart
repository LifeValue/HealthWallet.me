import 'package:fhir_r4/fhir_r4.dart' show FhirDate;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapped_property.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_patient.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a patient without a birth date is read with none, not today', () {
    final read = MappingPatient.fromFhirResource(
      const Patient(id: 'p1', rawResource: {'resourceType': 'Patient'}),
    );
    expect(read.dateOfBirth.value, isEmpty);
  });

  test('a scanned patient without a gender is saved without one', () {
    final saved = const MappingPatient(
      id: 'p1',
      givenName: MappedProperty(value: 'Ana'),
    ).toFhirResource();
    expect(saved.rawResource.containsKey('gender'), isFalse);
  });

  group('isIdentified', () {
    test('a name or an identifier says who the patient is', () {
      expect(
        const MappingPatient(familyName: MappedProperty(value: 'Pop'))
            .isIdentified,
        isTrue,
      );
      expect(
        const MappingPatient(givenName: MappedProperty(value: 'Ana'))
            .isIdentified,
        isTrue,
      );
      expect(
        const MappingPatient(
          patientIdentifier: MappedProperty(value: '1850101123456'),
        ).isIdentified,
        isTrue,
      );
    });

    test('a birth date or a gender alone does not', () {
      expect(MappingPatient.empty().isIdentified, isFalse);
      expect(
        const MappingPatient(
          dateOfBirth: MappedProperty(value: '1980-01-01'),
          gender: MappedProperty(value: 'female'),
        ).isIdentified,
        isFalse,
      );
    });
  });

  test('an empty patient has a fresh id and empty fields at full '
      'confidence', () {
    final first = MappingPatient.empty();
    final second = MappingPatient.empty();

    expect(first.id, isNotEmpty);
    expect(first.id, isNot(second.id));
    expect(first.givenName, const MappedProperty(confidenceLevel: 1));
    expect(first.patientIdentifier.value, isEmpty);
  });

  test('a patient is valid with any one confident field', () {
    const confident = MappedProperty(value: 'x', confidenceLevel: 0.9);
    for (final patient in [
      const MappingPatient(familyName: confident),
      const MappingPatient(givenName: confident),
      const MappingPatient(dateOfBirth: confident),
      const MappingPatient(gender: confident),
      const MappingPatient(patientIdentifier: confident),
    ]) {
      expect(patient.isValid, isTrue);
    }
    expect(
      const MappingPatient(
        familyName: MappedProperty(value: 'x', confidenceLevel: 0.5),
      ).isValid,
      isFalse,
    );
  });

  test('a stored birth date is read as a date', () {
    final read = MappingPatient.fromFhirResource(
      Patient(id: 'p1', birthDate: FhirDate.fromString('1980-02-03')),
    );
    expect(read.dateOfBirth.value, '1980-02-03');
  });

  test('an identifier with its own system is saved as a medical record '
      'number of that system', () {
    final saved = const MappingPatient(
      id: 'p1',
      patientIdentifier: MappedProperty(value: 'PA-01234'),
      identifierLabel: 'Patient no.',
      identifierSystem: 'http://healthwallet.me/clinic/optica/patient',
    ).toFhirResource();

    final identifier =
        (saved.rawResource['identifier'] as List).single
            as Map<String, dynamic>;
    expect(
      identifier['system'],
      'http://healthwallet.me/clinic/optica/patient',
    );
    expect(identifier['value'], 'PA-01234');
    expect(
      ((identifier['type'] as Map)['coding'] as List).single['code'],
      'MR',
    );
  });

  test('the field labels come from the translations', () {
    final l10n = lookupAppLocalizations(const Locale('en'));

    expect(MappingPatient.localizedLabels(l10n), {
      'givenName': l10n.labelFirstName,
      'familyName': l10n.labelFamilyName,
      'dateOfBirth': l10n.labelDateOfBirth,
      'gender': l10n.labelGender,
    });
  });

  test('an edit sets the changed fields at full confidence and keeps the '
      'others', () {
    const patient = MappingPatient(
      id: 'p1',
      givenName: MappedProperty(value: 'Ana', confidenceLevel: 0.4),
      familyName: MappedProperty(value: 'Pop', confidenceLevel: 0.5),
    );

    final edited = patient.copyWithMap({'givenName': 'Anna'}) as MappingPatient;

    expect(edited.id, 'p1');
    expect(
      edited.givenName,
      const MappedProperty(value: 'Anna', confidenceLevel: 1),
    );
    expect(edited.familyName, patient.familyName);
  });
}
