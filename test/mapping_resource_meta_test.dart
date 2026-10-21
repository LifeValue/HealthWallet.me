import 'package:fhir_r4/fhir_r4.dart' as fhir_r4;
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_encounter.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_resource.dart';

void main() {
  final specialtyMeta = fhir_r4.FhirMeta(tag: [
    fhir_r4.Coding(
      system: fhir_r4.FhirUri('http://healthwallet.me/specialty'),
      code: fhir_r4.FhirCode('cardiology'),
      display: fhir_r4.FhirString('Cardiology'),
    ),
  ]);

  List<dynamic>? tagsOf(Map<String, dynamic> raw) =>
      (raw['meta'] as Map<String, dynamic>?)?['tag'] as List<dynamic>?;

  group('toFhirResource meta', () {
    // The AI pipeline's resources after a scan; the processing handler tags
    // them with the encounter's specialty when the user saves.
    final resources = [
      {'resourceType': 'Condition', 'conditionName': 'Infarct miocardic acut'},
      {'resourceType': 'MedicationStatement', 'medicationName': 'Aspirina', 'dosage': '100 mg/zi'},
      {'resourceType': 'Observation', 'observationName': 'Troponina I', 'value': '8.5', 'unit': 'ng/ml'},
      {'resourceType': 'Procedure', 'procedureName': 'Coronarografie'},
      {'resourceType': 'Practitioner', 'practitionerName': 'Dr. Tudor Alexandru'},
      {'resourceType': 'Organization', 'organizationName': 'Spital Clinic Municipal'},
      {'resourceType': 'AllergyIntolerance', 'substance': 'Penicilina'},
    ].map(MappingResource.fromJson);

    for (final resource in resources) {
      test('${resource.runtimeType} carries the specialty tag into the saved JSON', () {
        final fhir = resource.toFhirResource(
          sourceId: 'source',
          subjectId: 'patient',
          encounterId: 'encounter',
          meta: specialtyMeta,
        );

        final saved = fhir.toDto().resourceRaw!;
        expect(tagsOf(saved), [
          {
            'system': 'http://healthwallet.me/specialty',
            'code': 'cardiology',
            'display': 'Cardiology',
          }
        ]);
      });
    }

    test('resources without meta have no tags', () {
      final fhir = MappingResource.fromJson(
              {'resourceType': 'MedicationStatement', 'medicationName': 'Aspirina'})
          .toFhirResource(sourceId: 'source', subjectId: 'patient');

      expect(fhir.rawResource['meta'], isNull);
    });

    test('an encounter keeps its own specialty tag unless meta is given', () {
      final encounter = MappingEncounter.fromJson({
        'resourceType': 'Encounter',
        'encounterType': 'Internare cardiologie',
        'specialty': 'Cardiology',
      });

      final own = tagsOf(encounter.toFhirResource(subjectId: 'patient').rawResource);
      expect(own?.single['display'], 'Cardiology');

      final overridden = tagsOf(encounter
          .toFhirResource(subjectId: 'patient', meta: const fhir_r4.FhirMeta(tag: []))
          .rawResource);
      expect(overridden, anyOf(isNull, isEmpty));
    });
  });

  group('AllergyIntolerance category', () {
    Map<String, dynamic> saved(String category) => MappingResource.fromJson({
          'resourceType': 'AllergyIntolerance',
          'substance': 'Penicilina',
          'category': category,
        }).toFhirResource(subjectId: 'patient').rawResource;

    test('keeps a valid category, normalised to the FHIR code', () {
      expect(saved('Medication')['category'], ['medication']);
    });

    test('drops an empty or unknown category instead of failing', () {
      expect(saved('')['category'], isNull);
      expect(saved('drug')['category'], isNull);
    });
  });
}
