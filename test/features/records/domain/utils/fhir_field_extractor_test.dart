import 'package:fhir_r4/fhir_r4.dart' as fhir;
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/config/constants/region_preset.dart';
import 'package:health_wallet/features/home/domain/entities/patient_vitals.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/records/domain/utils/fhir_field_extractor.dart';

import '../../../../fixtures/fhir/fhir_fixtures.dart';
import '../../../../fixtures/local_time.dart';

/// [FhirFieldExtractor] is a facade over the specialised extractors; these
/// tests check that every entry point is wired to the right implementation
/// using realistic resources.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final encounter = fhir.Encounter.fromJson(encounterJson());
  final procedure = fhir.Procedure.fromJson(procedureJson());
  final condition = fhir.Condition.fromJson(
    conditionJson(
      abatement: {
        'abatementPeriod': {'start': '2020-01-01T00:00:00Z'},
      },
    ),
  );
  final medicationRequest = fhir.MedicationRequest.fromJson(
    medicationRequestJson(),
  );
  final immunization = fhir.Immunization.fromJson(immunizationJson());
  final fhirPatient = fhir.Patient.fromJson(patientJson());
  final patient = entityFromJson(patientJson()) as Patient;
  final heartRate = entityFromJson(
    observationJson(
      code: '8867-4',
      codeDisplay: 'Heart rate',
      value: {'valueQuantity': quantity(72.4, unit: '/min')},
      interpretation: [
        codeableConcept(
          text: 'Normal',
          codings: [
            coding(
              'http://terminology.hl7.org/CodeSystem/v3-ObservationInterpretation',
              'N',
            ),
          ],
        ),
      ],
    ),
  ) as Observation;
  final bloodType = entityFromJson(
    observationJson(
      code: '34530-6',
      value: {'valueCodeableConcept': codeableConcept(text: 'O+')},
    ),
  ) as Observation;

  test('common fields', () {
    expect(
      FhirFieldExtractor.extractStatus(fhir.EncounterStatus.finished),
      'finished',
    );
    expect(
      FhirFieldExtractor.extractCodeableConceptText(condition.code),
      'Type 2 diabetes mellitus',
    );
    expect(
      FhirFieldExtractor.extractReferenceDisplay(
        encounter.participant!.first.individual,
      ),
      'Dr. Gregory House',
    );
    expect(
      FhirFieldExtractor.extractDate(condition.recordedDate),
      '2019-02-03',
    );
    expect(
      FhirFieldExtractor.extractFirstCodeableConceptFromArray(encounter.type),
      'Checkup',
    );
    expect(FhirFieldExtractor.joinNullable(['a', null, 'b'], '-'), 'a-b');
    expect(
      FhirFieldExtractor.extractCodingDisplay(encounter.class_),
      'ambulatory',
    );
    expect(
      FhirFieldExtractor.extractQuantity(
        fhir.Quantity.fromJson(quantity(5, unit: 'mg')),
      ),
      '5.00 mg',
    );
    expect(
      FhirFieldExtractor.extractAllCodeableConceptsFromArray(encounter.type),
      'Checkup',
    );
    final notes = [
      fhir.Annotation.fromJson({'text': 'Stable'}),
    ];
    expect(FhirFieldExtractor.extractFirstAnnotation(notes), 'Stable');
    expect(FhirFieldExtractor.extractAnnotations(notes), 'Stable');
    expect(
      FhirFieldExtractor.formatAddress(fhirPatient.address!.first),
      'Springfield, MA, US',
    );
    expect(
      FhirFieldExtractor.extractMultipleReferenceDisplays([
        encounter.diagnosis!.first.condition,
      ]),
      'Diabetes',
    );
    expect(
      FhirFieldExtractor.extractDosageInstructions(
        medicationRequest.dosageInstruction,
      ),
      'Oral route, Twice a day, 500 mg',
    );
    expect(FhirFieldExtractor.extractReasonCodes(encounter.type), 'Checkup');
    expect(
      FhirFieldExtractor.extractReasonReferences([
        encounter.diagnosis!.first.condition,
      ]),
      'Diabetes',
    );
    expect(
      FhirFieldExtractor.extractFirstIdentifier(fhirPatient.identifier),
      'syn-1',
    );
    expect(FhirFieldExtractor.extractServiceType(encounter.type), 'Checkup');
    expect(
      FhirFieldExtractor.extractPriority(medicationRequest.priority),
      'urgent',
    );
    expect(FhirFieldExtractor.extractIntent(medicationRequest.intent), 'order');
    expect(
      FhirFieldExtractor.extractPerformers(procedure.performer),
      'Dr. Who',
    );
    expect(
      FhirFieldExtractor.extractParticipants(encounter.participant),
      'Dr. Gregory House',
    );
    expect(
      FhirFieldExtractor.extractLocations(encounter.location),
      'Springfield Clinic',
    );
    expect(
      FhirFieldExtractor.extractDiagnoses(encounter.diagnosis),
      'Diabetes',
    );
  });

  test('observation fields', () {
    expect(
      FhirFieldExtractor.extractObservationValue(heartRate.valueX),
      '72.40 /min',
    );
    expect(
      FhirFieldExtractor.extractObservationValueForRegion(
        heartRate.valueX,
        RegionPreset.europe,
        measured: null,
      ),
      '72.40 /min',
    );
    final converted = FhirFieldExtractor.convertQuantityForRegion(
      100,
      'kg',
      RegionPreset.us,
      measured: PatientVitalType.weight,
    );
    expect(converted.unit, 'lbs');
    expect(converted.value, closeTo(220.46, 0.01));
    expect(FhirFieldExtractor.isVitalSign(heartRate), isTrue);
    expect(FhirFieldExtractor.extractVitalSignTitle(heartRate), 'Heart rate');
    expect(FhirFieldExtractor.extractVitalSignValue(heartRate), '72');
    expect(FhirFieldExtractor.extractVitalSignUnit(heartRate), '/min');
    expect(FhirFieldExtractor.extractVitalSignStatus(heartRate), 'Normal');
    expect(
      FhirFieldExtractor.extractInterpretation(heartRate.interpretation),
      'Normal',
    );
    expect(
      FhirFieldExtractor.extractBloodTypeFromObservations([
        heartRate,
        bloodType,
      ]),
      'O+',
    );
  });

  test('patient fields', () {
    final name = fhirPatient.name!.first;
    expect(FhirFieldExtractor.extractHumanName(name), 'Mrs. Jane Marie, Doe');
    expect(
      FhirFieldExtractor.extractHumanNameForHome(name),
      'Mrs. Jane Marie Doe',
    );
    expect(
      FhirFieldExtractor.extractHumanNameFamilyFirst(name),
      'Doe, Jane Marie',
    );
    expect(
      FhirFieldExtractor.extractFirstHumanNameFromArray(fhirPatient.name),
      'Mrs. Jane Marie, Doe',
    );
    expect(FhirFieldExtractor.extractPatientGiven(patient), 'Jane Marie');
    expect(FhirFieldExtractor.extractPatientFamily(patient), 'Doe');
    expect(FhirFieldExtractor.extractPatientId(patient), 'syn-1');
    expect(FhirFieldExtractor.extractPatientAge(patient), endsWith(' years'));
    expect(
      FhirFieldExtractor.extractPatientBirthDate(patient),
      DateTime(1985, 7, 14),
    );
    expect(FhirFieldExtractor.extractPatientGender(patient), 'female');
    expect(FhirFieldExtractor.extractPatientIdentifierLabel(patient), 'MRN');
    expect(
      FhirFieldExtractor.extractPatientIdentifierValue(patient),
      'MRN-0042',
    );
    expect(
      FhirFieldExtractor.extractMultipleBirth(fhir.FhirBoolean(false)),
      'No',
    );
    expect(
      FhirFieldExtractor.extractCommunicationLanguages(
        fhirPatient.communication,
      ),
      'English, Spanish',
    );
    expect(FhirFieldExtractor.calculateAge(null), isNull);
    expect(
      FhirFieldExtractor.extractIdentifierByType(fhirPatient.identifier, 'MR'),
      'MRN-0042',
    );
    expect(
      FhirFieldExtractor.extractTelecomBySystem(
        fhirPatient.telecom,
        'phone',
        use: 'mobile',
      ),
      '555-0199',
    );
    expect(
      FhirFieldExtractor.extractAllTelecomBySystem(
        fhirPatient.telecom,
        'email',
      ),
      [
        {'value': 'jane@example.org', 'use': ''},
      ],
    );
    expect(
      FhirFieldExtractor.extractTelecom(fhirPatient.telecom),
      '555-0100 (home)',
    );
    expect(
      FhirFieldExtractor.formatFullAddress(fhirPatient.address!.first),
      '12 Main St\nApt 3\nSpringfield, MA, 01101\nUS',
    );
    final raw = patientJson();
    expect(
      FhirFieldExtractor.extractRaceOrEthnicity(raw, usCoreRaceUrl),
      'White',
    );
    expect(
      FhirFieldExtractor.extractExtensionValue(raw, usCoreBirthSexUrl),
      'F',
    );
    expect(
      FhirFieldExtractor.extractBirthPlace(raw),
      'Boston, Massachusetts, US',
    );
  });

  test('temporal fields', () {
    final period = encounter.period;
    expect(
      FhirFieldExtractor.extractPeriod(period),
      '2024-01-10T09:00:00Z - 2024-01-10T09:30:00Z',
    );
    expect(
      FhirFieldExtractor.extractPeriodStart(period),
      '2024-01-10T09:00:00Z',
    );
    expect(FhirFieldExtractor.extractPeriodEnd(period), '2024-01-10T09:30:00Z');
    expect(
      FhirFieldExtractor.extractPeriodFormatted(period),
      '${localDateTime('2024-01-10T09:00:00Z')} - '
      '${localTime('2024-01-10T09:30:00Z')}',
    );
    expect(FhirFieldExtractor.extractOnsetX(condition.onsetX), '2019-02-01');
    expect(
      FhirFieldExtractor.extractAbatementX(condition.abatementX),
      'From 2020-01-01T00:00:00Z',
    );
    expect(
      FhirFieldExtractor.extractPerformedX(procedure.performedX),
      '2022-05-04T08:00:00Z - 2022-05-04T09:00:00Z',
    );
    expect(
      FhirFieldExtractor.extractEffectiveX(heartRate.effectiveX),
      '2024-03-15T10:30:00Z',
    );
    expect(
      FhirFieldExtractor.extractOccurrenceX(immunization.occurrenceX),
      '2023-10-01T08:00:00Z',
    );
    expect(
      FhirFieldExtractor.extractDateTime(medicationRequest.authoredOn),
      '2024-01-10T09:20:00Z',
    );
    expect(
      FhirFieldExtractor.formatFhirDateTime(medicationRequest.authoredOn),
      localDateTime('2024-01-10T09:20:00Z'),
    );
    expect(
      FhirFieldExtractor.formatFhirDate(fhirPatient.birthDate),
      'Jul 14, 1985',
    );
    expect(
      FhirFieldExtractor.formatFhirInstant(heartRate.issued),
      localDateTime('2024-03-15T12:00:00.000Z', withSeconds: true),
    );
    expect(
      FhirFieldExtractor.formatDateTimeString('2024-03-15'),
      'Mar 15, 2024',
    );
    expect(
      FhirFieldExtractor.extractOnsetXFormatted(condition.onsetX),
      'Feb 1, 2019',
    );
    expect(
      FhirFieldExtractor.extractAbatementXFormatted(condition.abatementX),
      'From ${localDateTime('2020-01-01T00:00:00Z', separator: ' ')}',
    );
    expect(
      FhirFieldExtractor.extractPerformedXFormatted(procedure.performedX),
      '${localDateTime('2022-05-04T08:00:00Z')} - '
      '${localTime('2022-05-04T09:00:00Z')}',
    );
    expect(
      FhirFieldExtractor.extractEffectiveXFormatted(heartRate.effectiveX),
      localDateTime('2024-03-15T10:30:00Z'),
    );
    expect(
      FhirFieldExtractor.extractOccurrenceXFormatted(immunization.occurrenceX),
      localDateTime('2023-10-01T08:00:00Z'),
    );
  });
}
