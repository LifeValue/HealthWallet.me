import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/gen/assets.gen.dart';

class OverviewCard {
  final HomeRecordsCategory category;
  final String count;

  OverviewCard({
    required this.category,
    required this.count,
  });
}

enum HomeRecordsCategory {
  allergies(
    display: 'Allergies',
    resourceTypes: [FhirType.AllergyIntolerance, FhirType.AdverseEvent],
  ),
  careTeam(
    display: 'Care Team',
    resourceTypes: [
      FhirType.CareTeam,
      FhirType.Practitioner,
      FhirType.Patient,
      FhirType.RelatedPerson,
      FhirType.PractitionerRole,
    ],
  ),
  clinicalNotes(
    display: 'Clinical Notes',
    resourceTypes: [FhirType.DocumentReference, FhirType.DiagnosticReport],
  ),
  files(
    display: 'Files',
    resourceTypes: [FhirType.Binary, FhirType.DocumentReference],
  ),
  labResults(
    display: 'Lab Results',
    resourceTypes: [FhirType.Observation, FhirType.Specimen],
  ),
  healthIssues(
    display: 'Health Issues',
    resourceTypes: [FhirType.Condition, FhirType.Encounter],
  ),
  facilities(
    display: 'Facilities',
    resourceTypes: [FhirType.Organization, FhirType.Location],
  ),
  healthGoals(
    display: 'Health Goals',
    resourceTypes: [FhirType.Goal],
  ),
  immunizations(
    display: 'Immunizations',
    resourceTypes: [FhirType.Immunization],
  ),
  medications(
    display: 'Medications',
    resourceTypes: [
      FhirType.Medication,
      FhirType.MedicationRequest,
      FhirType.MedicationStatement,
      FhirType.MedicationAdministration,
      FhirType.MedicationDispense,
    ],
  ),
  demographics(
    display: 'Demographics',
    resourceTypes: [FhirType.Patient],
  ),
  procedures(
    display: 'Procedures',
    resourceTypes: [FhirType.Procedure, FhirType.ServiceRequest],
  ),
  healthInsurance(
    display: 'Health Insurance',
    resourceTypes: [
      FhirType.Claim,
      FhirType.ExplanationOfBenefit,
      FhirType.Coverage,
    ],
  ),
  visionPrescriptions(
    display: 'Vision Prescriptions',
    resourceTypes: [FhirType.VisionPrescription],
  );

  const HomeRecordsCategory({
    required this.display,
    required this.resourceTypes,
  });

  final String display;
  final List<FhirType> resourceTypes;

  SvgGenImage get icon {
    switch (this) {
      case HomeRecordsCategory.allergies:
        return Assets.icons.faceMask;
      case HomeRecordsCategory.medications:
        return Assets.icons.medication;
      case HomeRecordsCategory.healthIssues:
        return Assets.icons.stethoscope;
      case HomeRecordsCategory.immunizations:
        return Assets.icons.shield;
      case HomeRecordsCategory.labResults:
        return Assets.icons.lab;
      case HomeRecordsCategory.procedures:
        return Assets.icons.briefcaseProcedures;
      case HomeRecordsCategory.healthGoals:
        return Assets.icons.improveRelevance;
      case HomeRecordsCategory.careTeam:
        return Assets.icons.eventsTeam;
      case HomeRecordsCategory.clinicalNotes:
        return Assets.icons.catalogNotes;
      case HomeRecordsCategory.files:
        return Assets.icons.documentFile;
      case HomeRecordsCategory.facilities:
        return Assets.icons.hospital;
      case HomeRecordsCategory.demographics:
        return Assets.icons.identification;
      case HomeRecordsCategory.healthInsurance:
        return Assets.icons.hospital;
      case HomeRecordsCategory.visionPrescriptions:
        return Assets.specialities.ophthalmology;
    }
  }
}
