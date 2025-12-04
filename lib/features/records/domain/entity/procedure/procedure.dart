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
    infoLines.add(ResourceFieldMapper.createSectionHeader('Procedure Details'));

    // Performed Date/Period (CRITICAL - When it happened)
    final performedDisplay = FhirFieldExtractor.extractPerformedX(performedX);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createDateLine(performedDisplay,
          prefix: 'Date Performed'),
    );

    // Performer (Who performed it - CRITICAL)
    if (performer != null && performer!.isNotEmpty) {
      for (final perf in performer!) {
        final performerName = FhirFieldExtractor.extractReferenceDisplay(perf.actor);
        final performerFunction = FhirFieldExtractor.extractCodeableConceptText(perf.function_);
        
        final performerDisplay = performerFunction != null && performerName != null
            ? '$performerName ($performerFunction)'
            : performerName ?? performerFunction;
        
        ResourceFieldMapper.addIfNotNull(
          infoLines,
          ResourceFieldMapper.createUserLine(performerDisplay, prefix: 'Performed By'),
        );
      }
    }

    // Outcome (Result - CRITICAL)
    final outcomeDisplay =
        FhirFieldExtractor.extractCodeableConceptText(outcome);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createStatusLine(outcomeDisplay, prefix: 'Outcome'),
    );

    // Body Site (Where on body - IMPORTANT)
    if (bodySite != null && bodySite!.isNotEmpty) {
      final bodySiteDisplay = bodySite!
          .map((b) => FhirFieldExtractor.extractCodeableConceptText(b))
          .where((b) => b != null && b.isNotEmpty)
          .join(', ');
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createBodySiteLine(
            bodySiteDisplay.isNotEmpty ? bodySiteDisplay : null,
            prefix: 'Body Site'),
      );
    }

    infoLines.add(ResourceFieldMapper.createSectionHeader('Basic Information'));

    // Status
    final statusText = status?.valueString;
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createStatusLine(statusText, prefix: 'Status'),
    );

    // Status Reason (if not completed)
    final statusReasonDisplay =
        FhirFieldExtractor.extractCodeableConceptText(statusReason);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createStatusLine(statusReasonDisplay,
          prefix: 'Status Reason'),
    );

    // Category (Type of procedure)
    final categoryDisplay =
        FhirFieldExtractor.extractCodeableConceptText(category);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createCategoryLine(categoryDisplay,
          prefix: 'Category'),
    );

    // Procedure Code (CPT/ICD-10-PCS)
    final codeDisplay = FhirFieldExtractor.extractCodeableConceptText(code);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createProcedureLine(codeDisplay,
          prefix: 'Procedure Code'),
    );

    // Location (Facility/Room where performed)
    final locationDisplay =
        FhirFieldExtractor.extractReferenceDisplay(location);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createLocationLine(locationDisplay,
          prefix: 'Location'),
    );

    // Reason Code (Why procedure was done)
    final reasonCodeDisplay =
        FhirFieldExtractor.extractReasonCodes(reasonCode);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createNotesLine(reasonCodeDisplay, prefix: 'Reason'),
    );

    // Reason Reference (Link to condition/observation)
    if (reasonReference != null && reasonReference!.isNotEmpty) {
      final reasonRefDisplay = reasonReference!
          .map((r) => FhirFieldExtractor.extractReferenceDisplay(r))
          .where((r) => r != null && r.isNotEmpty)
          .join(', ');
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createNotesLine(
            reasonRefDisplay.isNotEmpty ? reasonRefDisplay : null,
            prefix: 'Related Condition'),
      );
    }

    infoLines.add(ResourceFieldMapper.createSectionHeader('Additional Information'));

    // Recorder (Who documented the procedure)
    final recorderDisplay =
        FhirFieldExtractor.extractReferenceDisplay(recorder);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createUserLine(recorderDisplay, prefix: 'Recorder'),
    );

    // Asserter (Who verified/confirmed)
    final asserterDisplay =
        FhirFieldExtractor.extractReferenceDisplay(asserter);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createUserLine(asserterDisplay, prefix: 'Verified By'),
    );

    // Complications (Problems during/after - WARNING)
    if (complication != null && complication!.isNotEmpty) {
      final complicationDisplay = complication!
          .map((c) => FhirFieldExtractor.extractCodeableConceptText(c))
          .where((c) => c != null && c.isNotEmpty)
          .join(', ');
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createWarningLine(
            complicationDisplay.isNotEmpty ? complicationDisplay : null,
            prefix: 'Complications'),
      );
    } else {
      // Explicitly show "None" if no complications
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createStatusLine('None', prefix: 'Complications'),
      );
    }

    // Complication Details (Link to detailed conditions)
    if (complicationDetail != null && complicationDetail!.isNotEmpty) {
      final complicationDetailDisplay = complicationDetail!
          .map((c) => FhirFieldExtractor.extractReferenceDisplay(c))
          .where((c) => c != null && c.isNotEmpty)
          .join(', ');
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createWarningLine(
            complicationDetailDisplay.isNotEmpty ? complicationDetailDisplay : null,
            prefix: 'Complication Details'),
      );
    }

    // Follow-up Required
    if (followUp != null && followUp!.isNotEmpty) {
      final followUpDisplay = followUp!
          .map((f) => FhirFieldExtractor.extractCodeableConceptText(f))
          .where((f) => f != null && f.isNotEmpty)
          .join(', ');
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createTimelineLine(
            followUpDisplay.isNotEmpty ? followUpDisplay : null,
            prefix: 'Follow-up'),
      );
    }

    // Focal Device (Equipment/implants used)
    if (focalDevice != null && focalDevice!.isNotEmpty) {
      for (final device in focalDevice!) {
        final deviceDisplay = FhirFieldExtractor.extractReferenceDisplay(device.manipulated);
        final actionDisplay = FhirFieldExtractor.extractCodeableConceptText(device.action);
        
        final focalDeviceDisplay = actionDisplay != null && deviceDisplay != null
            ? '$deviceDisplay ($actionDisplay)'
            : deviceDisplay ?? actionDisplay;
        
        ResourceFieldMapper.addIfNotNull(
          infoLines,
          ResourceFieldMapper.createProcedureLine(focalDeviceDisplay,
              prefix: 'Focal Device'),
        );
      }
    }

    // Items Used (Supplies/medications)
    if (usedReference != null && usedReference!.isNotEmpty) {
      final usedDisplay = usedReference!
          .map((u) => FhirFieldExtractor.extractReferenceDisplay(u))
          .where((u) => u != null && u.isNotEmpty)
          .join(', ');
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createProcedureLine(
            usedDisplay.isNotEmpty ? usedDisplay : null,
            prefix: 'Items Used'),
      );
    }

    // Used Code (Coded items/supplies)
    if (usedCode != null && usedCode!.isNotEmpty) {
      final usedCodeDisplay = usedCode!
          .map((u) => FhirFieldExtractor.extractCodeableConceptText(u))
          .where((u) => u != null && u.isNotEmpty)
          .join(', ');
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createProcedureLine(
            usedCodeDisplay.isNotEmpty ? usedCodeDisplay : null,
            prefix: 'Supplies'),
      );
    }

    // Report (Links to procedure reports)
    if (report != null && report!.isNotEmpty) {
      final reportDisplay = report!
          .map((r) => FhirFieldExtractor.extractReferenceDisplay(r))
          .where((r) => r != null && r.isNotEmpty)
          .take(3)
          .join(', ');
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createDocumentLine(
            reportDisplay.isNotEmpty ? reportDisplay : null,
            prefix: 'Report'),
      );
    }

    // Part Of (Parent procedure if this is a sub-procedure)
    if (partOf != null && partOf!.isNotEmpty) {
      final partOfDisplay = partOf!
          .map((p) => FhirFieldExtractor.extractReferenceDisplay(p))
          .where((p) => p != null && p.isNotEmpty)
          .join(', ');
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createProcedureLine(
            partOfDisplay.isNotEmpty ? partOfDisplay : null,
            prefix: 'Part Of'),
      );
    }

    // Based On (Order/Request that led to this procedure)
    if (basedOn != null && basedOn!.isNotEmpty) {
      final basedOnDisplay = basedOn!
          .map((b) => FhirFieldExtractor.extractReferenceDisplay(b))
          .where((b) => b != null && b.isNotEmpty)
          .join(', ');
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createDocumentLine(
            basedOnDisplay.isNotEmpty ? basedOnDisplay : null,
            prefix: 'Based On'),
      );
    }

    // Date
    if (date != null) {
      infoLines.add(RecordInfoLine(
        icon: Assets.icons.calendar,
        info: DateFormat.yMMMMd().format(date!),
      ));
    }

    // Notes (Procedure report/findings)
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
