import 'package:health_wallet/features/scan/domain/entity/mapping_resources/mapping_allergy_intolerance.dart';
import 'package:health_wallet/features/scan/domain/entity/mapping_resources/mapping_condition.dart';
import 'package:health_wallet/features/scan/domain/entity/mapping_resources/mapping_diagnostic_report.dart';
import 'package:health_wallet/features/scan/domain/entity/mapping_resources/mapping_encounter.dart';
import 'package:health_wallet/features/scan/domain/entity/mapping_resources/mapping_medication_statement.dart';
import 'package:health_wallet/features/scan/domain/entity/mapping_resources/mapping_observation.dart';
import 'package:health_wallet/features/scan/domain/entity/mapping_resources/mapping_organization.dart';
import 'package:health_wallet/features/scan/domain/entity/mapping_resources/mapping_patient.dart';
import 'package:health_wallet/features/scan/domain/entity/mapping_resources/mapping_practitioner.dart';
import 'package:health_wallet/features/scan/domain/entity/mapping_resources/mapping_procedure.dart';
import 'package:health_wallet/features/scan/domain/entity/text_field_descriptor.dart';
import 'package:health_wallet/features/records/domain/entity/i_fhir_resource.dart';

abstract class MappingResource {
  factory MappingResource.fromJson(Map<String, dynamic> json) {
    if (!json.containsKey('resourceType')) {
      throw Exception();
    }

    switch (json['resourceType']) {
      case 'AllergyIntolerance':
        return MappingAllergyIntolerance.fromJson(json);
      case 'Condition':
        return MappingCondition.fromJson(json);
      case 'DiagnosticReport':
        return MappingDiagnosticReport.fromJson(json);
      case 'Encounter':
        return MappingEncounter.fromJson(json);
      case 'MedicationStatement':
        return MappingMedicationStatement.fromJson(json);
      case 'Observation':
        return MappingObservation.fromJson(json);
      case 'Organization':
        return MappingOrganization.fromJson(json);
      case 'Patient':
        return MappingPatient.fromJson(json);
      case 'Practitioner':
        return MappingPractitioner.fromJson(json);
      case 'Procedure':
        return MappingProcedure.fromJson(json);
      default:
        throw Exception();
    }
  }

  factory MappingResource.empty(String resourceType) {
    switch (resourceType) {
      case 'AllergyIntolerance':
        return MappingAllergyIntolerance.empty();
      case 'Condition':
        return MappingCondition.empty();
      case 'DiagnosticReport':
        return MappingDiagnosticReport.empty();
      case 'Encounter':
        return MappingEncounter.empty();
      case 'MedicationStatement':
        return MappingMedicationStatement.empty();
      case 'Observation':
        return MappingObservation.empty();
      case 'Organization':
        return MappingOrganization.empty();
      case 'Patient':
        return MappingPatient.empty();
      case 'Practitioner':
        return MappingPractitioner.empty();
      case 'Procedure':
        return MappingProcedure.empty();
      default:
        throw Exception();
    }
  }

  Map<String, dynamic> toJson();

  IFhirResource toFhirResource({
    String? sourceId,
    String? encounterId,
    String? subjectId,
  });

  Map<String, TextFieldDescriptor> getFieldDescriptors();

  MappingResource copyWithMap(Map<String, dynamic> newValues);

  String get label;

  MappingResource populateConfidence(String inputText);

  bool get isValid;

  String get id;
}
