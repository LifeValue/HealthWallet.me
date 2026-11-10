import 'package:fhir_r4/fhir_r4.dart' as fhir_r4;
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/features/home/domain/entities/medical_specialty.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapped_property.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_encounter.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';

void main() {
  final ophthalmology = MedicalSpecialty.ophthalmology.displayName;

  test('a saved visit shows the specialty it was saved with', () {
    final saved = MappingEncounter(
      id: 'e1',
      encounterType: const MappedProperty(value: 'Rezultat examinare'),
      periodStart: const MappedProperty(value: '2024-03-14'),
      specialty: MappedProperty(value: ophthalmology),
    ).toFhirResource(subjectId: 'p1') as Encounter;

    expect(
      MappingEncounter.fromFhirResource(saved).specialty.value,
      ophthalmology,
    );
  });

  test('the specialty the user chose wins over the saved one', () {
    final encounter = Encounter(
      id: 'e1',
      serviceType: fhir_r4.CodeableConcept(
        text: fhir_r4.FhirString(ophthalmology),
      ),
      specialtyOverride: MedicalSpecialty.cardiology.name,
    );

    expect(
      MappingEncounter.storedSpecialty(encounter),
      MedicalSpecialty.cardiology.displayName,
    );
  });

  test('a SNOMED-coded service type is read as its specialty', () {
    final encounter = Encounter(
      id: 'e1',
      serviceType: fhir_r4.CodeableConcept(
        coding: [
          fhir_r4.Coding(
            system: fhir_r4.FhirUri('http://snomed.info/sct'),
            code: fhir_r4.FhirCode(
              MedicalSpecialty.cardiology.snomedSpecialtyCode,
            ),
          ),
        ],
      ),
    );

    expect(
      MappingEncounter.storedSpecialty(encounter),
      MedicalSpecialty.cardiology.displayName,
    );
  });

  test('a visit saved without a specialty shows none', () {
    expect(MappingEncounter.storedSpecialty(const Encounter(id: 'e1')), '');
  });
}
