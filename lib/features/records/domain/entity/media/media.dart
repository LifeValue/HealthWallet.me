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

part 'media.freezed.dart';

@freezed
class Media with _$Media implements IFhirResource {
  const Media._();

  const factory Media({
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
    List<Reference>? partOf,
    EventStatus? status,
    CodeableConcept? type,
    CodeableConcept? modality,
    CodeableConcept? view,
    Reference? subject,
    Reference? encounter,
    CreatedXMedia? createdX,
    FhirInstant? issued,
    Reference? operator_,
    List<CodeableConcept>? reasonCode,
    CodeableConcept? bodySite,
    FhirString? deviceName,
    Reference? device,
    FhirPositiveInt? height,
    FhirPositiveInt? width,
    FhirPositiveInt? frames,
    FhirDecimal? duration,
    Attachment? content,
    List<Annotation>? note,
  }) = _Media;

  @override
  FhirType get fhirType => FhirType.Media;

  factory Media.fromLocalData(FhirResourceLocalDto data) {
    final resourceJson = jsonDecode(data.resourceRaw);
    final fhirMedia = fhir_r4.Media.fromJson(resourceJson);

    return Media(
      id: data.id,
      sourceId: data.sourceId ?? '',
      resourceId: data.resourceId ?? '',
      title: data.title ?? '',
      date: data.date,
      rawResource: resourceJson,
      encounterId: data.encounterId ?? '',
      subjectId: data.subjectId ?? '',
      text: fhirMedia.text,
      identifier: fhirMedia.identifier,
      basedOn: fhirMedia.basedOn,
      partOf: fhirMedia.partOf,
      status: fhirMedia.status,
      type: fhirMedia.type,
      modality: fhirMedia.modality,
      view: fhirMedia.view,
      subject: fhirMedia.subject,
      encounter: fhirMedia.encounter,
      createdX: fhirMedia.createdX,
      issued: fhirMedia.issued,
      operator_: fhirMedia.operator_,
      reasonCode: fhirMedia.reasonCode,
      bodySite: fhirMedia.bodySite,
      deviceName: fhirMedia.deviceName,
      device: fhirMedia.device,
      height: fhirMedia.height,
      width: fhirMedia.width,
      frames: fhirMedia.frames,
      duration: fhirMedia.duration,
      content: fhirMedia.content,
      note: fhirMedia.note,
    );
  }

  @override
  FhirResourceDto toDto() => FhirResourceDto(
        id: id,
        sourceId: sourceId,
        resourceType: 'Media',
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

    final displayText = FhirFieldExtractor.extractCodeableConceptText(type);
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

    // Type
    final typeDisplay = FhirFieldExtractor.extractCodeableConceptText(type);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createCategoryLine(typeDisplay, prefix: 'Type'),
    );

    // Modality
    final modalityDisplay =
        FhirFieldExtractor.extractCodeableConceptText(modality);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createStatusLine(modalityDisplay, prefix: 'Modality'),
    );

    // View
    final viewDisplay = FhirFieldExtractor.extractCodeableConceptText(view);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createStatusLine(viewDisplay, prefix: 'View'),
    );

    // Device Name
    final deviceNameText = deviceName?.valueString;
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createStatusLine(deviceNameText, prefix: 'Device'),
    );

    // Operator
    final operatorDisplay =
        FhirFieldExtractor.extractReferenceDisplay(operator_);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createUserLine(operatorDisplay, prefix: 'Operator'),
    );

    // Body Site
    final bodySiteDisplay =
        FhirFieldExtractor.extractCodeableConceptText(bodySite);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createBodySiteLine(bodySiteDisplay,
          prefix: 'Body Site'),
    );

    // Dimensions
    if (width != null && height != null) {
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createImageLine(
            '${width?.valueString} x ${height?.valueString}',
            prefix: 'Dimensions'),
      );
    }

    // Duration
    if (duration != null) {
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createTimeLine('${duration?.valueString} seconds',
            prefix: 'Duration'),
      );
    }

    // Content Type
    if (content?.contentType != null) {
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createAttachmentLine(content!.contentType.toString(),
            prefix: 'Content Type'),
      );
    }

    // Reason Code
    final reasonCodeDisplay =
        FhirFieldExtractor.extractReasonCodes(reasonCode);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createNotesLine(reasonCodeDisplay, prefix: 'Reason'),
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
      operator_?.reference?.valueString,
      device?.reference?.valueString,
      ...?basedOn?.map((reference) => reference.reference?.valueString),
      ...?partOf?.map((reference) => reference.reference?.valueString),
    }.where((reference) => reference != null).toList();
  }

  @override
  String get statusDisplay => status?.valueString ?? '';
}
