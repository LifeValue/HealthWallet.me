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

  static final _slashDateDmy = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$');
  static final _slashDateYmd = RegExp(r'^(\d{4})/(\d{1,2})/(\d{1,2})$');
  static final _dotDateDmy = RegExp(r'^(\d{1,2})\.(\d{1,2})\.(\d{4})$');
  static final _dashDateDmy = RegExp(r'^(\d{1,2})-(\d{1,2})-(\d{4})$');

  static String normalizeDateValue(String value) {
    if (value.isEmpty) return value;

    final trimmed = value.trim();

    final parsed = DateTime.tryParse(trimmed);
    if (parsed != null) {
      return '${parsed.year.toString().padLeft(4, '0')}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}';
    }

    final dmySlash = _slashDateDmy.firstMatch(trimmed);
    if (dmySlash != null) {
      final d = int.tryParse(dmySlash.group(1)!);
      final m = int.tryParse(dmySlash.group(2)!);
      final y = int.tryParse(dmySlash.group(3)!);
      if (d != null && m != null && y != null && m >= 1 && m <= 12 && d >= 1 && d <= 31) {
        return '${y.toString().padLeft(4, '0')}-${m.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';
      }
    }

    final ymdSlash = _slashDateYmd.firstMatch(trimmed);
    if (ymdSlash != null) {
      final y = int.tryParse(ymdSlash.group(1)!);
      final m = int.tryParse(ymdSlash.group(2)!);
      final d = int.tryParse(ymdSlash.group(3)!);
      if (d != null && m != null && y != null && m >= 1 && m <= 12 && d >= 1 && d <= 31) {
        return '${y.toString().padLeft(4, '0')}-${m.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';
      }
    }

    final dmyDot = _dotDateDmy.firstMatch(trimmed);
    if (dmyDot != null) {
      final d = int.tryParse(dmyDot.group(1)!);
      final m = int.tryParse(dmyDot.group(2)!);
      final y = int.tryParse(dmyDot.group(3)!);
      if (d != null && m != null && y != null && m >= 1 && m <= 12 && d >= 1 && d <= 31) {
        return '${y.toString().padLeft(4, '0')}-${m.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';
      }
    }

    final dmyDash = _dashDateDmy.firstMatch(trimmed);
    if (dmyDash != null) {
      final d = int.tryParse(dmyDash.group(1)!);
      final m = int.tryParse(dmyDash.group(2)!);
      final y = int.tryParse(dmyDash.group(3)!);
      if (d != null && m != null && y != null && m >= 1 && m <= 12 && d >= 1 && d <= 31) {
        return '${y.toString().padLeft(4, '0')}-${m.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';
      }
    }

    return value;
  }
}
