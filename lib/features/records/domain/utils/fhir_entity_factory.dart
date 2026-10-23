import 'dart:convert';
import 'package:health_wallet/core/data/local/app_database.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';

/// Centralized factory for creating FHIR entities from raw data
/// Eliminates code duplication and provides consistent entity creation
class FhirEntityFactory {
  /// Create entity from raw data using FHIR R4 parsing
  static IFhirResource createFromRawData(Map<String, dynamic> data) {
    final resourceType = data['resourceType'] as String? ?? 'Unknown';

    // Create DTO for entity creation
    final dto = FhirResourceLocalDto(
      id: data['id'] as String? ?? '',
      resourceType: resourceType,
      resourceRaw: jsonEncode(data),
      sourceId: data['sourceId'] as String? ?? '',
      resourceId: data['resourceId'] as String? ?? '',
      title: data['title'] as String? ?? '',
      date: null, // Let entities handle their own date extraction
    );

    // Use reflection-based factory pattern
    return _createEntityByType(resourceType, dto);
  }

  /// Create entity by resource type using a centralized mapping
  static IFhirResource _createEntityByType(
      String resourceType, FhirResourceLocalDto dto) {
    switch (resourceType) {
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
        return GeneralResource.fromLocalData(dto);
    }
  }
}
