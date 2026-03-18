import 'package:health_wallet/core/config/constants/region_preset.dart';
import 'package:health_wallet/features/records/domain/entity/observation/observation.dart';
import 'package:health_wallet/features/records/domain/entity/patient/patient.dart';
import 'package:fhir_r4/fhir_r4.dart' as fhir_r4;
import 'package:health_wallet/features/records/domain/utils/extractors/fhir_common_extractor.dart';
import 'package:health_wallet/features/records/domain/utils/extractors/fhir_observation_extractor.dart';
import 'package:health_wallet/features/records/domain/utils/extractors/fhir_patient_extractor.dart';
import 'package:health_wallet/features/records/domain/utils/extractors/fhir_temporal_extractor.dart';

class FhirFieldExtractor {
  static String? extractStatus(dynamic status) =>
      FhirCommonExtractor.extractStatus(status);

  static String? extractCodeableConceptText(dynamic codeableConcept) =>
      FhirCommonExtractor.extractCodeableConceptText(codeableConcept);

  static String? extractReferenceDisplay(dynamic reference) =>
      FhirCommonExtractor.extractReferenceDisplay(reference);

  static String? extractDate(dynamic date) =>
      FhirCommonExtractor.extractDate(date);

  static String? extractFirstCodeableConceptFromArray(
          List<dynamic>? codeableConceptArray) =>
      FhirCommonExtractor.extractFirstCodeableConceptFromArray(
          codeableConceptArray);

  static String? joinNullable(List<String?> values, String separator) =>
      FhirCommonExtractor.joinNullable(values, separator);

  static String? extractCodingDisplay(dynamic coding) =>
      FhirCommonExtractor.extractCodingDisplay(coding);

  static String? extractQuantity(fhir_r4.Quantity? quantity) =>
      FhirCommonExtractor.extractQuantity(quantity);

  static String? extractAllCodeableConceptsFromArray(
          List<dynamic>? codeableConceptArray) =>
      FhirCommonExtractor.extractAllCodeableConceptsFromArray(
          codeableConceptArray);

  static String? extractFirstAnnotation(List<dynamic>? annotations) =>
      FhirCommonExtractor.extractFirstAnnotation(annotations);

  static String? extractAnnotations(List<dynamic>? annotations) =>
      FhirCommonExtractor.extractAnnotations(annotations);

  static String? formatAddress(fhir_r4.Address? address) =>
      FhirCommonExtractor.formatAddress(address);

  static String? extractMultipleReferenceDisplays(
          List<dynamic>? references) =>
      FhirCommonExtractor.extractMultipleReferenceDisplays(references);

  static String? extractDosageInstructions(List<dynamic>? dosages) =>
      FhirCommonExtractor.extractDosageInstructions(dosages);

  static String? extractDosage(List<fhir_r4.Dosage>? dosages) =>
      FhirCommonExtractor.extractDosage(dosages);

  static String? extractReasonCodes(List<dynamic>? reasonCodes) =>
      FhirCommonExtractor.extractReasonCodes(reasonCodes);

  static String? extractReasonReferences(List<dynamic>? reasonReferences) =>
      FhirCommonExtractor.extractReasonReferences(reasonReferences);

  static String? extractFirstIdentifier(
          List<fhir_r4.Identifier>? identifiers) =>
      FhirCommonExtractor.extractFirstIdentifier(identifiers);

  static String? extractServiceType(List<dynamic>? serviceTypes) =>
      FhirCommonExtractor.extractServiceType(serviceTypes);

  static String? extractPriority(dynamic priority) =>
      FhirCommonExtractor.extractPriority(priority);

  static String? extractIntent(dynamic intent) =>
      FhirCommonExtractor.extractIntent(intent);

  static String? extractObservationValue(dynamic valueX) =>
      FhirObservationExtractor.extractObservationValue(valueX);

  static String? extractObservationValueForRegion(
          dynamic valueX, RegionPreset region) =>
      FhirObservationExtractor.extractObservationValueForRegion(
          valueX, region);

  static ({double value, String unit}) convertQuantityForRegion(
          double value, String unit, RegionPreset region) =>
      FhirObservationExtractor.convertQuantityForRegion(value, unit, region);

  static bool isVitalSign(Observation observation) =>
      FhirObservationExtractor.isVitalSign(observation);

  static String extractVitalSignTitle(Observation observation) =>
      FhirObservationExtractor.extractVitalSignTitle(observation);

  static String extractVitalSignValue(Observation observation) =>
      FhirObservationExtractor.extractVitalSignValue(observation);

  static String extractVitalSignUnit(Observation observation) =>
      FhirObservationExtractor.extractVitalSignUnit(observation);

  static String? extractVitalSignStatus(Observation observation) =>
      FhirObservationExtractor.extractVitalSignStatus(observation);

  static String? extractInterpretation(List<dynamic>? interpretations) =>
      FhirObservationExtractor.extractInterpretation(interpretations);

  static String? extractBloodTypeFromObservations(
          List<dynamic> observations) =>
      FhirObservationExtractor.extractBloodTypeFromObservations(observations);

  static String? extractHumanName(dynamic name) =>
      FhirPatientExtractor.extractHumanName(name);

  static String? extractHumanNameForHome(dynamic name) =>
      FhirPatientExtractor.extractHumanNameForHome(name);

  static String? extractHumanNameFamilyFirst(dynamic name) =>
      FhirPatientExtractor.extractHumanNameFamilyFirst(name);

  static String? extractFirstHumanNameFromArray(List<dynamic>? nameArray) =>
      FhirPatientExtractor.extractFirstHumanNameFromArray(nameArray);

  static String extractPatientGiven(Patient patient) =>
      FhirPatientExtractor.extractPatientGiven(patient);

  static String extractPatientFamily(Patient patient) =>
      FhirPatientExtractor.extractPatientFamily(patient);

  static String extractPatientId(Patient patient) =>
      FhirPatientExtractor.extractPatientId(patient);

  static String extractPatientAge(Patient patient) =>
      FhirPatientExtractor.extractPatientAge(patient);

  static DateTime? extractPatientBirthDate(Patient patient) =>
      FhirPatientExtractor.extractPatientBirthDate(patient);

  static String extractPatientGender(Patient patient) =>
      FhirPatientExtractor.extractPatientGender(patient);

  static String extractPatientIdentifierLabel(Patient patient) =>
      FhirPatientExtractor.extractPatientIdentifierLabel(patient);

  static String extractPatientMRN(Patient patient) =>
      FhirPatientExtractor.extractPatientMRN(patient);

  static String? extractMultipleBirth(dynamic multipleBirthX) =>
      FhirPatientExtractor.extractMultipleBirth(multipleBirthX);

  static String? extractCommunicationLanguages(
          List<fhir_r4.PatientCommunication>? communication) =>
      FhirPatientExtractor.extractCommunicationLanguages(communication);

  static int? calculateAge(DateTime? birthDate) =>
      FhirPatientExtractor.calculateAge(birthDate);

  static String? extractIdentifierByType(
          List<fhir_r4.Identifier>? identifiers, String typeCode) =>
      FhirPatientExtractor.extractIdentifierByType(identifiers, typeCode);

  static String? extractTelecomBySystem(
          List<fhir_r4.ContactPoint>? telecom, String system,
          {String? use}) =>
      FhirPatientExtractor.extractTelecomBySystem(telecom, system, use: use);

  static List<Map<String, String>> extractAllTelecomBySystem(
          List<fhir_r4.ContactPoint>? telecom, String system) =>
      FhirPatientExtractor.extractAllTelecomBySystem(telecom, system);

  static String? extractTelecom(List<fhir_r4.ContactPoint>? telecom) =>
      FhirPatientExtractor.extractTelecom(telecom);

  static String? formatFullAddress(fhir_r4.Address? address) =>
      FhirPatientExtractor.formatFullAddress(address);

  static String? extractPerformers(List<dynamic>? performers) =>
      FhirCommonExtractor.extractPerformers(performers);

  static String? extractParticipants(List<dynamic>? participants) =>
      FhirCommonExtractor.extractParticipants(participants);

  static String? extractLocations(List<dynamic>? locations) =>
      FhirCommonExtractor.extractLocations(locations);

  static String? extractDiagnoses(List<dynamic>? diagnoses) =>
      FhirCommonExtractor.extractDiagnoses(diagnoses);

  static String? extractRaceOrEthnicity(
          Map<String, dynamic> rawResource, String extensionUrl) =>
      FhirPatientExtractor.extractRaceOrEthnicity(rawResource, extensionUrl);

  static String? extractExtensionValue(
          Map<String, dynamic> rawResource, String extensionUrl) =>
      FhirPatientExtractor.extractExtensionValue(rawResource, extensionUrl);

  static String? extractBirthPlace(Map<String, dynamic> rawResource) =>
      FhirPatientExtractor.extractBirthPlace(rawResource);

  static String? extractPeriod(fhir_r4.Period? period) =>
      FhirTemporalExtractor.extractPeriod(period);

  static String? extractPeriodStart(fhir_r4.Period? period) =>
      FhirTemporalExtractor.extractPeriodStart(period);

  static String? extractPeriodEnd(fhir_r4.Period? period) =>
      FhirTemporalExtractor.extractPeriodEnd(period);

  static String? extractPeriodFormatted(fhir_r4.Period? period) =>
      FhirTemporalExtractor.extractPeriodFormatted(period);

  static String? extractOnsetX(dynamic onsetX) =>
      FhirTemporalExtractor.extractOnsetX(onsetX);

  static String? extractAbatementX(dynamic abatementX) =>
      FhirTemporalExtractor.extractAbatementX(abatementX);

  static String? extractPerformedX(dynamic performedX) =>
      FhirTemporalExtractor.extractPerformedX(performedX);

  static String? extractEffectiveX(dynamic effectiveX) =>
      FhirTemporalExtractor.extractEffectiveX(effectiveX);

  static String? extractOccurrenceX(dynamic occurrenceX) =>
      FhirTemporalExtractor.extractOccurrenceX(occurrenceX);

  static String? extractDateTime(dynamic dateX) =>
      FhirTemporalExtractor.extractDateTime(dateX);

  static String? formatFhirDateTime(fhir_r4.FhirDateTime? fhirDateTime) =>
      FhirTemporalExtractor.formatFhirDateTime(fhirDateTime);

  static String? formatFhirDate(fhir_r4.FhirDate? fhirDate) =>
      FhirTemporalExtractor.formatFhirDate(fhirDate);

  static String? formatFhirInstant(fhir_r4.FhirInstant? fhirInstant) =>
      FhirTemporalExtractor.formatFhirInstant(fhirInstant);

  static String? formatDateTimeString(String? dateTimeString) =>
      FhirTemporalExtractor.formatDateTimeString(dateTimeString);

  static String? extractOnsetXFormatted(dynamic onsetX) =>
      FhirTemporalExtractor.extractOnsetXFormatted(onsetX);

  static String? extractAbatementXFormatted(dynamic abatementX) =>
      FhirTemporalExtractor.extractAbatementXFormatted(abatementX);

  static String? extractPerformedXFormatted(dynamic performedX) =>
      FhirTemporalExtractor.extractPerformedXFormatted(performedX);

  static String? extractEffectiveXFormatted(dynamic effectiveX) =>
      FhirTemporalExtractor.extractEffectiveXFormatted(effectiveX);

  static String? extractOccurrenceXFormatted(dynamic occurrenceX) =>
      FhirTemporalExtractor.extractOccurrenceXFormatted(occurrenceX);
}
