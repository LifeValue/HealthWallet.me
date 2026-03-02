import 'dart:convert';

import 'package:health_wallet/core/data/local/app_database.dart';
import 'package:health_wallet/features/home/domain/entities/overview_card.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/records/presentation/models/record_info_line.dart';
import 'package:health_wallet/features/sync/data/dto/fhir_resource_dto.dart';
import 'package:health_wallet/gen/assets.gen.dart';

abstract class IFhirResource {
  String get id;
  String get sourceId;
  FhirType get fhirType;
  String get resourceId;
  String get title;
  DateTime? get date;
  Map<String, dynamic> get rawResource;
  String get encounterId;
  String get subjectId;

  factory IFhirResource.fromLocalDto(FhirResourceLocalDto dto) {
    switch (dto.resourceType) {
      case 'Patient':
        return Patient.fromLocalData(dto);
      case 'Observation':
        return Observation.fromLocalData(dto);
      case 'Encounter':
        return Encounter.fromLocalData(dto);
      case 'Condition':
        return Condition.fromLocalData(dto);
      case 'AllergyIntolerance':
        return AllergyIntolerance.fromLocalData(dto);
      case 'Medication':
        return Medication.fromLocalData(dto);
      case 'MedicationRequest':
        return MedicationRequest.fromLocalData(dto);
      case 'MedicationStatement':
        return MedicationStatement.fromLocalData(dto);
      case 'MedicationAdministration':
        return MedicationAdministration.fromLocalData(dto);
      case 'MedicationDispense':
        return MedicationDispense.fromLocalData(dto);
      case 'Procedure':
        return Procedure.fromLocalData(dto);
      case 'DiagnosticReport':
        return DiagnosticReport.fromLocalData(dto);
      case 'DocumentReference':
        return DocumentReference.fromLocalData(dto);
      case 'Immunization':
        return Immunization.fromLocalData(dto);
      case 'CareTeam':
        return CareTeam.fromLocalData(dto);
      case 'Goal':
        return Goal.fromLocalData(dto);
      case 'Location':
        return Location.fromLocalData(dto);
      case 'Organization':
        return Organization.fromLocalData(dto);
      case 'Practitioner':
        return Practitioner.fromLocalData(dto);
      case 'PractitionerRole':
        return PractitionerRole.fromLocalData(dto);
      case 'RelatedPerson':
        return RelatedPerson.fromLocalData(dto);
      case 'ServiceRequest':
        return ServiceRequest.fromLocalData(dto);
      case 'Specimen':
        return Specimen.fromLocalData(dto);
      case 'Binary':
        return Binary.fromLocalData(dto);
      case 'Media':
        return Media.fromLocalData(dto);
      case 'AdverseEvent':
        return AdverseEvent.fromLocalData(dto);
      case 'Claim':
        return Claim.fromLocalData(dto);
      case 'ExplanationOfBenefit':
        return ExplanationOfBenefit.fromLocalData(dto);
      case 'Coverage':
        return Coverage.fromLocalData(dto);
      default:
        return GeneralResource(
          id: dto.id,
          sourceId: dto.sourceId ?? '',
          resourceId: dto.resourceId ?? '',
          title: dto.title ?? '',
          date: dto.date,
          rawResource: jsonDecode(dto.resourceRaw),
        );
    }
  }

  FhirResourceDto toDto();

  String get displayTitle;
  List<RecordInfoLine> get additionalInfo;
  List<String?> get resourceReferences;
  String get statusDisplay;
}

enum FhirType {
  AdverseEvent("Adverse Event"),
  AllergyIntolerance("Allergy"),
  Binary("Binary"),
  CareTeam("Care Team"),
  Claim("Claim"),
  Condition("Condition"),
  Coverage("Coverage"),
  DiagnosticReport("Diagnostic Report"),
  DocumentReference("Document"),
  Encounter("Encounter"),
  ExplanationOfBenefit("Explanation of Benefit"),
  Goal("Goal"),
  Immunization("Immunization"),
  Location("Location"),
  Media("Media"),
  Medication("Medication"),
  MedicationAdministration("Medication Administration"),
  MedicationDispense("Medication Dispense"),
  MedicationRequest("Medication Request"),
  MedicationStatement("MedicationStatement"),
  Observation("Observation"),
  Organization("Organization"),
  Patient("Patient"),
  Practitioner("Practitioner"),
  PractitionerRole("Practitioner Role"),
  Procedure("Procedure"),
  RelatedPerson("Related Person"),
  ServiceRequest("Service Request"),
  Specimen("Specimen"),
  GeneralResource("Resource");

  const FhirType(this.display);

  final String display;

  SvgGenImage get icon {
    if (this == FhirType.GeneralResource) return Assets.icons.stethoscope;

    return HomeRecordsCategory.values
        .firstWhere((category) => category.resourceTypes.contains(this))
        .icon;
  }
}

extension FhirResourceListExtension on List<IFhirResource> {
  Map<FhirType, int> countByType() {
    final counts = <FhirType, int>{};
    for (final resource in this) {
      counts[resource.fhirType] = (counts[resource.fhirType] ?? 0) + 1;
    }
    return counts;
  }
}
