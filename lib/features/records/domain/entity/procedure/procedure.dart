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

part 'procedure.freezed.dart';

@freezed
class Procedure with _$Procedure implements IFhirResource {
  const Procedure._();

  const factory Procedure({
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
    List<FhirCanonical>? instantiatesCanonical,
    List<FhirUri>? instantiatesUri,
    List<Reference>? basedOn,
    List<Reference>? partOf,
    EventStatus? status,
    CodeableConcept? statusReason,
    CodeableConcept? category,
    CodeableConcept? code,
    Reference? subject,
    Reference? encounter,
    PerformedXProcedure? performedX,
    Reference? recorder,
    Reference? asserter,
    List<ProcedurePerformer>? performer,
    Reference? location,
    List<CodeableConcept>? reasonCode,
    List<Reference>? reasonReference,
    List<CodeableConcept>? bodySite,
    CodeableConcept? outcome,
    List<Reference>? report,
    List<CodeableConcept>? complication,
    List<Reference>? complicationDetail,
    List<CodeableConcept>? followUp,
    List<Annotation>? note,
    List<ProcedureFocalDevice>? focalDevice,
    List<Reference>? usedReference,
    List<CodeableConcept>? usedCode,
  }) = _Procedure;

  @override
  FhirType get fhirType => FhirType.Procedure;

  factory Procedure.fromLocalData(FhirResourceLocalDto data) {
    final resourceJson = jsonDecode(data.resourceRaw);
    final fhirProcedure = fhir_r4.Procedure.fromJson(resourceJson);

    return Procedure(
      id: data.id,
      sourceId: data.sourceId ?? '',
      resourceId: data.resourceId ?? '',
      title: data.title ?? '',
      date: data.date,
      rawResource: resourceJson,
      encounterId: data.encounterId ?? '',
      subjectId: data.subjectId ?? '',
      text: fhirProcedure.text,
      identifier: fhirProcedure.identifier,
      instantiatesCanonical: fhirProcedure.instantiatesCanonical,
      instantiatesUri: fhirProcedure.instantiatesUri,
      basedOn: fhirProcedure.basedOn,
      partOf: fhirProcedure.partOf,
      status: fhirProcedure.status,
      statusReason: fhirProcedure.statusReason,
      category: fhirProcedure.category,
      code: fhirProcedure.code,
      subject: fhirProcedure.subject,
      encounter: fhirProcedure.encounter,
      performedX: fhirProcedure.performedX,
      recorder: fhirProcedure.recorder,
      asserter: fhirProcedure.asserter,
      performer: fhirProcedure.performer,
      location: fhirProcedure.location,
      reasonCode: fhirProcedure.reasonCode,
      reasonReference: fhirProcedure.reasonReference,
      bodySite: fhirProcedure.bodySite,
      outcome: fhirProcedure.outcome,
      report: fhirProcedure.report,
      complication: fhirProcedure.complication,
      complicationDetail: fhirProcedure.complicationDetail,
      followUp: fhirProcedure.followUp,
      note: fhirProcedure.note,
      focalDevice: fhirProcedure.focalDevice,
      usedReference: fhirProcedure.usedReference,
      usedCode: fhirProcedure.usedCode,
    );
  }

  @override
  FhirResourceDto toDto() => FhirResourceDto(
        id: id,
        sourceId: sourceId,
        resourceType: 'Procedure',
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
        FhirFieldExtractor.extractCodeableConceptText(category);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createCategoryLine(categoryDisplay,
          prefix: 'Category'),
    );

    // Performer
    final performerDisplay = FhirFieldExtractor.extractPerformers(performer);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createUserLine(performerDisplay, prefix: 'Performer'),
    );

    // Location
    final locationDisplay =
        FhirFieldExtractor.extractReferenceDisplay(location);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createLocationLine(locationDisplay,
          prefix: 'Location'),
    );

    // Body Site
    final bodySiteDisplay =
        FhirFieldExtractor.extractFirstCodeableConceptFromArray(bodySite);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createBodySiteLine(bodySiteDisplay,
          prefix: 'Body Site'),
    );

    // Performed Date/Period
    final performedDisplay = FhirFieldExtractor.extractPerformedX(performedX);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createDateLine(performedDisplay,
          prefix: 'Performed'),
    );

    // Reason Code
    final reasonCodeDisplay =
        FhirFieldExtractor.extractReasonCodes(reasonCode);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createNotesLine(reasonCodeDisplay, prefix: 'Reason'),
    );

    // Outcome
    final outcomeDisplay =
        FhirFieldExtractor.extractCodeableConceptText(outcome);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createStatusLine(outcomeDisplay, prefix: 'Outcome'),
    );

    // Complication
    final complicationDisplay =
        FhirFieldExtractor.extractFirstCodeableConceptFromArray(complication);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createWarningLine(complicationDisplay,
          prefix: 'Complication'),
    );

    // Follow-up
    final followUpDisplay =
        FhirFieldExtractor.extractFirstCodeableConceptFromArray(followUp);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createTimelineLine(followUpDisplay,
          prefix: 'Follow-up'),
    );

    // Date
    if (date != null) {
      infoLines.add(RecordInfoLine(
        icon: Assets.icons.calendar,
        info: DateFormat.yMMMMd().format(date!),
      ));
    }

    // Notes
    final notesDisplay = FhirFieldExtractor.extractAnnotations(note);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createNotesLine(notesDisplay, prefix: 'Notes'),
    );

    return infoLines;
  }

  @override
  List<String?> get resourceReferences {
    return {
      subject?.reference?.valueString,
      encounter?.reference?.valueString,
      recorder?.reference?.valueString,
      asserter?.reference?.valueString,
      location?.reference?.valueString,
      ...?basedOn?.map((reference) => reference.reference?.valueString),
      ...?partOf?.map((reference) => reference.reference?.valueString),
      ...?reasonReference?.map((reference) => reference.reference?.valueString),
      ...?report?.map((reference) => reference.reference?.valueString),
      ...?complicationDetail
          ?.map((reference) => reference.reference?.valueString),
      ...?usedReference?.map((reference) => reference.reference?.valueString),
    }.where((reference) => reference != null).toList();
  }

  @override
  String get statusDisplay => status?.valueString ?? '';
}
