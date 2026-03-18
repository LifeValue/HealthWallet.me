import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:health_wallet/core/utils/validator.dart';
import 'package:health_wallet/features/scan/domain/entity/mapping_resources/mapped_property.dart';
import 'package:health_wallet/features/scan/domain/entity/mapping_resources/mapping_resource.dart';
import 'package:health_wallet/features/scan/domain/entity/text_field_descriptor.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:fhir_r4/fhir_r4.dart' as fhir_r4;
import 'package:uuid/uuid.dart';

part 'mapping_diagnostic_report.freezed.dart';

@freezed
class MappingDiagnosticReport
    with _$MappingDiagnosticReport
    implements MappingResource {
  const MappingDiagnosticReport._();

  const factory MappingDiagnosticReport({
    @Default('') String id,
    @Default(MappedProperty()) MappedProperty reportName,
    @Default(MappedProperty()) MappedProperty conclusion,
    @Default(MappedProperty()) MappedProperty issuedDate,
  }) = _MappingDiagnosticReport;

  factory MappingDiagnosticReport.fromJson(Map<String, dynamic> json) {
    return MappingDiagnosticReport(
      id: json["id"] ?? const Uuid().v4(),
      reportName: MappedProperty.fromJson(json['reportName']),
      conclusion: MappedProperty.fromJson(json['conclusion']),
      issuedDate: MappedProperty.fromJson(json['issuedDate']),
    );
  }

  factory MappingDiagnosticReport.empty() {
    return MappingDiagnosticReport(
      id: const Uuid().v4(),
      reportName: MappedProperty.empty(),
      conclusion: MappedProperty.empty(),
      issuedDate: MappedProperty.empty(),
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'resourceType': 'DiagnosticReport',
        'reportName': reportName.toJson(),
        'conclusion': conclusion.toJson(),
        'issuedDate': issuedDate.toJson(),
      };

  @override
  IFhirResource toFhirResource({
    String? sourceId,
    String? encounterId,
    String? subjectId,
  }) {
    fhir_r4.DiagnosticReport diagnosticReport = fhir_r4.DiagnosticReport(
      code: fhir_r4.CodeableConcept(text: fhir_r4.FhirString(reportName.value)),
      conclusion: fhir_r4.FhirString(conclusion.value),
      issued: fhir_r4.FhirInstant.fromDateTime(
          DateTime.tryParse(issuedDate.value) ?? DateTime.now()),
      status: fhir_r4.DiagnosticReportStatus.unknown,
      subject: fhir_r4.Reference(
          reference: fhir_r4.FhirString('Patient/$subjectId')),
      encounter: fhir_r4.Reference(
          reference: fhir_r4.FhirString('Encounter/$encounterId')),
    );

    Map<String, dynamic> rawResource = diagnosticReport.toJson();

    return DiagnosticReport(
      id: id,
      resourceId: id,
      title: reportName.value,
      date: DateTime.tryParse(issuedDate.value),
      sourceId: sourceId ?? '',
      encounterId: encounterId ?? '',
      subjectId: subjectId ?? '',
      rawResource: rawResource,
      code: diagnosticReport.code,
      conclusion: diagnosticReport.conclusion,
      issued: diagnosticReport.issued,
    );
  }

  @override
  Map<String, TextFieldDescriptor> getFieldDescriptors() => {
        'reportName': TextFieldDescriptor(
          label: 'Report Name',
          value: reportName.value,
          confidenceLevel: reportName.confidenceLevel,
        ),
        'conclusion': TextFieldDescriptor(
          label: 'Conclusion',
          value: conclusion.value,
          confidenceLevel: conclusion.confidenceLevel,
        ),
        'issuedDate': TextFieldDescriptor(
          label: 'Issued Date',
          value: issuedDate.value,
          confidenceLevel: issuedDate.confidenceLevel,
          validators: [nonEmptyValidator, dateValidator],
        ),
      };

  @override
  MappingResource copyWithMap(Map<String, dynamic> newValues) =>
      MappingDiagnosticReport(
        id: id,
        reportName: MappedProperty(
          value: newValues['reportName'] ?? reportName.value,
          confidenceLevel:
              newValues['reportName'] != null ? 1 : reportName.confidenceLevel,
        ),
        conclusion: MappedProperty(
          value: newValues['conclusion'] ?? conclusion.value,
          confidenceLevel:
              newValues['conclusion'] != null ? 1 : conclusion.confidenceLevel,
        ),
        issuedDate: MappedProperty(
          value: newValues['issuedDate'] ?? issuedDate.value,
          confidenceLevel:
              newValues['issuedDate'] != null ? 1 : issuedDate.confidenceLevel,
        ),
      );

  @override
  String get label => 'Diagnostic Report';

  @override
  MappingResource populateConfidence(String inputText) => copyWith(
        reportName: reportName.calculateConfidence(inputText),
        conclusion: conclusion.calculateConfidence(inputText),
        issuedDate: issuedDate.calculateDateConfidence(inputText),
      );

  @override
  bool get isValid =>
      reportName.isValid || conclusion.isValid || issuedDate.isValid;
}
