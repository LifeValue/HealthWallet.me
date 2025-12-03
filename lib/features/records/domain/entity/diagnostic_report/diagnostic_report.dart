import 'dart:convert';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:fhir_r4/fhir_r4.dart' as fhir_r4;
import 'package:fhir_r4/fhir_r4.dart';
import 'package:health_wallet/features/records/domain/entity/i_fhir_resource.dart';
import 'package:health_wallet/core/data/local/app_database.dart';
import 'package:health_wallet/features/records/domain/utils/fhir_field_extractor.dart';
import 'package:health_wallet/features/records/domain/utils/resource_field_mapper.dart';
import 'package:health_wallet/features/records/presentation/models/record_info_line.dart';
import 'package:health_wallet/features/sync/data/dto/fhir_resource_dto.dart';
import 'package:health_wallet/gen/assets.gen.dart';
import 'package:intl/intl.dart';

part 'diagnostic_report.freezed.dart';

@freezed
class DiagnosticReport with _$DiagnosticReport implements IFhirResource {
  const DiagnosticReport._();

  const factory DiagnosticReport({
    @Default('') String id,
    @Default('') String sourceId,
    @Default('') String resourceId,
    @Default('') String title,
    DateTime? date,
    @Default({}) Map<String, dynamic> rawResource,
    @Default('') String encounterId,
    @Default('') String subjectId,
    Narrative? text,
    List<Identifier>? identifier,
    List<Reference>? basedOn,
    DiagnosticReportStatus? status,
    List<CodeableConcept>? category,
    CodeableConcept? code,
    Reference? subject,
    Reference? encounter,
    EffectiveXDiagnosticReport? effectiveX,
    FhirInstant? issued,
    List<Reference>? performer,
    List<Reference>? resultsInterpreter,
    List<Reference>? specimen,
    List<Reference>? result,
    List<Reference>? imagingStudy,
    List<DiagnosticReportMedia>? media,
    FhirString? conclusion,
    List<CodeableConcept>? conclusionCode,
    List<Attachment>? presentedForm,
  }) = _DiagnosticReport;

  @override
  FhirType get fhirType => FhirType.DiagnosticReport;

  factory DiagnosticReport.fromLocalData(FhirResourceLocalDto data) {
    final resourceJson = jsonDecode(data.resourceRaw);
    final fhirDiagnosticReport =
        fhir_r4.DiagnosticReport.fromJson(resourceJson);

    return DiagnosticReport(
      id: data.id,
      sourceId: data.sourceId ?? '',
      resourceId: data.resourceId ?? '',
      title: data.title ?? '',
      date: data.date,
      rawResource: resourceJson,
      encounterId: data.encounterId ?? '',
      subjectId: data.subjectId ?? '',
      text: fhirDiagnosticReport.text,
      identifier: fhirDiagnosticReport.identifier,
      basedOn: fhirDiagnosticReport.basedOn,
      status: fhirDiagnosticReport.status,
      category: fhirDiagnosticReport.category,
      code: fhirDiagnosticReport.code,
      subject: fhirDiagnosticReport.subject,
      encounter: fhirDiagnosticReport.encounter,
      effectiveX: fhirDiagnosticReport.effectiveX,
      issued: fhirDiagnosticReport.issued,
      performer: fhirDiagnosticReport.performer,
      resultsInterpreter: fhirDiagnosticReport.resultsInterpreter,
      specimen: fhirDiagnosticReport.specimen,
      result: fhirDiagnosticReport.result,
      imagingStudy: fhirDiagnosticReport.imagingStudy,
      media: fhirDiagnosticReport.media,
      conclusion: fhirDiagnosticReport.conclusion,
      conclusionCode: fhirDiagnosticReport.conclusionCode,
      presentedForm: fhirDiagnosticReport.presentedForm,
    );
  }

  @override
  FhirResourceDto toDto() => FhirResourceDto(
        id: id,
        sourceId: sourceId,
        resourceType: 'DiagnosticReport',
        resourceId: resourceId,
        title: title,
        date: date,
        resourceRaw: rawResource,
        encounterId: encounterId,
        subjectId: subjectId,
      );

  @override
  String get displayTitle {
    if (title.isNotEmpty) {
      return title;
    }

    final displayText = FhirFieldExtractor.extractCodeableConceptText(code);
    if (displayText != null) return displayText;

    return fhirType.display;
  }

  @override
  List<RecordInfoLine> get additionalInfo {
    List<RecordInfoLine> infoLines = [];

    // Status
    final statusText = status?.valueString;
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createStatusLine(statusText, prefix: 'Status'),
    );

    // Category
    final categoryDisplay =
        FhirFieldExtractor.extractFirstCodeableConceptFromArray(category);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createCategoryLine(categoryDisplay,
          prefix: 'Category'),
    );

    // Performer
    final performerDisplay =
        FhirFieldExtractor.extractMultipleReferenceDisplays(performer);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createUserLine(performerDisplay, prefix: 'Performer'),
    );

    // Results Interpreter
    final interpreterDisplay =
        FhirFieldExtractor.extractMultipleReferenceDisplays(resultsInterpreter);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createUserLine(interpreterDisplay,
          prefix: 'Interpreter'),
    );

    // Effective Date
    final effectiveDisplay = FhirFieldExtractor.extractEffectiveX(effectiveX);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createDateLine(effectiveDisplay, prefix: 'Effective'),
    );

    // Conclusion
    final conclusionText = conclusion?.valueString;
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createLabLine(conclusionText, prefix: 'Conclusion'),
    );

    // Conclusion Code
    final conclusionCodeDisplay =
        FhirFieldExtractor.extractFirstCodeableConceptFromArray(conclusionCode);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createLabLine(conclusionCodeDisplay,
          prefix: 'Conclusion Code'),
    );

    // Number of Results
    if (result != null && result!.isNotEmpty) {
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createLabLine('${result!.length} result(s)',
            prefix: 'Results'),
      );
    }

    // Number of Specimens
    if (specimen != null && specimen!.isNotEmpty) {
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createLabLine('${specimen!.length} specimen(s)',
            prefix: 'Specimens'),
      );
    }

    // Has Media/Images
    if (media != null && media!.isNotEmpty) {
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createImageLine('${media!.length} image(s)',
            prefix: 'Media'),
      );
    }

    // Date
    if (date != null) {
      infoLines.add(RecordInfoLine(
        icon: Assets.icons.calendar,
        info: DateFormat.yMMMMd().format(date!),
      ));
    }

    return infoLines;
  }

  @override
  List<String?> get resourceReferences {
    return {
      subject?.reference?.valueString,
      encounter?.reference?.valueString,
      ...?basedOn?.map((reference) => reference.reference?.valueString),
      ...?performer?.map((reference) => reference.reference?.valueString),
      ...?resultsInterpreter
          ?.map((reference) => reference.reference?.valueString),
      ...?specimen?.map((reference) => reference.reference?.valueString),
      ...?result?.map((reference) => reference.reference?.valueString),
      ...?imagingStudy?.map((reference) => reference.reference?.valueString),
    }.where((reference) => reference != null).toList();
  }

  @override
  String get statusDisplay => status?.valueString ?? '';
}
