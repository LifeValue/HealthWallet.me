import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/features/home/domain/entities/medical_specialty.dart';
import 'package:health_wallet/features/home/domain/entities/overview_card.dart';
import 'package:health_wallet/features/home/domain/entities/patient_vitals.dart';
import 'package:health_wallet/features/processing/domain/entity/processing_session.dart';
import 'package:health_wallet/features/records/domain/entity/i_fhir_resource.dart';

/// Localized display names for enums whose English names double as lookup
/// or persistence keys (`PatientVitalType.title`, `MedicalSpecialty.displayName`,
/// `HomeRecordsCategory.display`, `FhirType.display`, and the
/// `ProcessingStatus`/`ProcessingOrigin` `toString()` values).
///
/// Translate only at display time: never compare, store or match on these.

extension PatientVitalTypeL10n on PatientVitalType {
  String localizedName(AppLocalizations l10n) => switch (this) {
    PatientVitalType.heartRate => l10n.vitalHeartRate,
    PatientVitalType.bloodPressure => l10n.vitalBloodPressure,
    PatientVitalType.temperature => l10n.vitalTemperature,
    PatientVitalType.bloodOxygen => l10n.vitalBloodOxygen,
    PatientVitalType.respiratoryRate => l10n.vitalRespiratoryRate,
    PatientVitalType.weight => l10n.vitalWeight,
    PatientVitalType.height => l10n.vitalHeight,
    PatientVitalType.bmi => l10n.vitalBmi,
    PatientVitalType.bloodGlucose => l10n.vitalBloodGlucose,
    PatientVitalType.systolicBloodPressure => l10n.vitalSystolicBloodPressure,
    PatientVitalType.diastolicBloodPressure => l10n.vitalDiastolicBloodPressure,
  };
}

/// Localizes a vital title stored in English (the `PatientVitalType.title`
/// key). A title outside `PatientVitalType` is returned unchanged.
String localizedVitalTitle(String title, AppLocalizations l10n) =>
    PatientVitalTypeX.fromTitle(title)?.localizedName(l10n) ?? title;

extension MedicalSpecialtyL10n on MedicalSpecialty {
  String localizedName(AppLocalizations l10n) => switch (this) {
    MedicalSpecialty.allergology => l10n.specialtyAllergology,
    MedicalSpecialty.cardiology => l10n.specialtyCardiology,
    MedicalSpecialty.dental => l10n.specialtyDental,
    MedicalSpecialty.dermatology => l10n.specialtyDermatology,
    MedicalSpecialty.emergencyMedicine => l10n.specialtyEmergencyMedicine,
    MedicalSpecialty.endocrinology => l10n.specialtyEndocrinology,
    MedicalSpecialty.gastroenterology => l10n.specialtyGastroenterology,
    MedicalSpecialty.generalCare => l10n.specialtyGeneralCare,
    MedicalSpecialty.gynecology => l10n.specialtyGynecology,
    MedicalSpecialty.nephrology => l10n.specialtyNephrology,
    MedicalSpecialty.neurology => l10n.specialtyNeurology,
    MedicalSpecialty.oncology => l10n.specialtyOncology,
    MedicalSpecialty.ophthalmology => l10n.specialtyOphthalmology,
    MedicalSpecialty.orthopedics => l10n.specialtyOrthopedics,
    MedicalSpecialty.psychiatry => l10n.specialtyPsychiatry,
    MedicalSpecialty.pulmonology => l10n.specialtyPulmonology,
    MedicalSpecialty.rheumatology => l10n.specialtyRheumatology,
    MedicalSpecialty.urology => l10n.specialtyUrology,
  };
}

/// Localizes a specialty stored by its English `displayName`. An unknown
/// name is returned unchanged.
String localizedSpecialtyName(String displayName, AppLocalizations l10n) {
  for (final specialty in MedicalSpecialty.values) {
    if (specialty.displayName == displayName) {
      return specialty.localizedName(l10n);
    }
  }
  return displayName;
}

extension HomeRecordsCategoryL10n on HomeRecordsCategory {
  String localizedName(AppLocalizations l10n) => switch (this) {
    HomeRecordsCategory.allergies => l10n.categoryAllergies,
    HomeRecordsCategory.careTeam => l10n.categoryCareTeam,
    HomeRecordsCategory.clinicalNotes => l10n.categoryClinicalNotes,
    HomeRecordsCategory.files => l10n.categoryFiles,
    HomeRecordsCategory.labResults => l10n.categoryLabResults,
    HomeRecordsCategory.healthIssues => l10n.categoryHealthIssues,
    HomeRecordsCategory.facilities => l10n.categoryFacilities,
    HomeRecordsCategory.healthGoals => l10n.categoryHealthGoals,
    HomeRecordsCategory.immunizations => l10n.categoryImmunizations,
    HomeRecordsCategory.medications => l10n.categoryMedications,
    HomeRecordsCategory.demographics => l10n.categoryDemographics,
    HomeRecordsCategory.procedures => l10n.categoryProcedures,
    HomeRecordsCategory.healthInsurance => l10n.categoryHealthInsurance,
  };
}

extension FhirTypeL10n on FhirType {
  String localizedName(AppLocalizations l10n) => switch (this) {
    FhirType.AdverseEvent => l10n.fhirTypeAdverseEvent,
    FhirType.AllergyIntolerance => l10n.fhirTypeAllergyIntolerance,
    FhirType.Binary => l10n.fhirTypeBinary,
    FhirType.CareTeam => l10n.fhirTypeCareTeam,
    FhirType.Claim => l10n.fhirTypeClaim,
    FhirType.Condition => l10n.fhirTypeCondition,
    FhirType.Coverage => l10n.fhirTypeCoverage,
    FhirType.DiagnosticReport => l10n.fhirTypeDiagnosticReport,
    FhirType.DocumentReference => l10n.fhirTypeDocumentReference,
    FhirType.Encounter => l10n.fhirTypeEncounter,
    FhirType.ExplanationOfBenefit => l10n.fhirTypeExplanationOfBenefit,
    FhirType.Goal => l10n.fhirTypeGoal,
    FhirType.Immunization => l10n.fhirTypeImmunization,
    FhirType.Location => l10n.fhirTypeLocation,
    FhirType.Media => l10n.fhirTypeMedia,
    FhirType.Medication => l10n.fhirTypeMedication,
    FhirType.MedicationAdministration => l10n.fhirTypeMedicationAdministration,
    FhirType.MedicationDispense => l10n.fhirTypeMedicationDispense,
    FhirType.MedicationRequest => l10n.fhirTypeMedicationRequest,
    FhirType.MedicationStatement => l10n.fhirTypeMedicationStatement,
    FhirType.Observation => l10n.fhirTypeObservation,
    FhirType.Organization => l10n.fhirTypeOrganization,
    FhirType.Patient => l10n.fhirTypePatient,
    FhirType.Practitioner => l10n.fhirTypePractitioner,
    FhirType.PractitionerRole => l10n.fhirTypePractitionerRole,
    FhirType.Procedure => l10n.fhirTypeProcedure,
    FhirType.RelatedPerson => l10n.fhirTypeRelatedPerson,
    FhirType.ServiceRequest => l10n.fhirTypeServiceRequest,
    FhirType.Specimen => l10n.fhirTypeSpecimen,
    FhirType.GeneralResource => l10n.fhirTypeGeneralResource,
  };
}

extension ProcessingOriginL10n on ProcessingOrigin {
  String localizedName(AppLocalizations l10n) => switch (this) {
    ProcessingOrigin.scan => l10n.processingOriginScan,
    ProcessingOrigin.import => l10n.processingOriginImport,
    ProcessingOrigin.handover => l10n.processingOriginHandover,
  };
}

extension ProcessingStatusL10n on ProcessingStatus {
  String localizedName(AppLocalizations l10n) => switch (this) {
    ProcessingStatus.pending => l10n.processingStatusPending,
    ProcessingStatus.processingPatient =>
      l10n.processingStatusProcessingPatient,
    ProcessingStatus.patientExtracted => l10n.processingStatusPatientExtracted,
    ProcessingStatus.processing => l10n.processingStatusProcessing,
    ProcessingStatus.draft => l10n.processingStatusDraft,
    ProcessingStatus.cancelled => l10n.processingStatusCancelled,
  };
}
