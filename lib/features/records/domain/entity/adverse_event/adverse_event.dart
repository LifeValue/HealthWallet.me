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

part 'adverse_event.freezed.dart';

@freezed
class AdverseEvent with _$AdverseEvent implements IFhirResource {
  const AdverseEvent._();

  const factory AdverseEvent({
    @Default('') String id,
    @Default('') String sourceId,
    @Default('') String resourceId,
    @Default('') String title,
    DateTime? date,
    @Default({}) Map<String, dynamic> rawResource,
    @Default('') String encounterId,
    @Default('') String subjectId,
    Narrative? text,
    Identifier? identifier,
    AdverseEventActuality? actuality,
    List<CodeableConcept>? category,
    CodeableConcept? event,
    Reference? subject,
    Reference? encounter,
    FhirDateTime? fhirDate,
    FhirDateTime? detected,
    FhirDateTime? recordedDate,
    List<Reference>? resultingCondition,
    Reference? location,
    CodeableConcept? seriousness,
    CodeableConcept? severity,
    CodeableConcept? outcome,
    Reference? recorder,
    List<Reference>? contributor,
    List<AdverseEventSuspectEntity>? suspectEntity,
    List<Reference>? subjectMedicalHistory,
    List<Reference>? referenceDocument,
    List<Reference>? study,
  }) = _AdverseEvent;

  @override
  FhirType get fhirType => FhirType.AdverseEvent;

  factory AdverseEvent.fromLocalData(FhirResourceLocalDto data) {
    final resourceJson = jsonDecode(data.resourceRaw);
    final fhirAdverseEvent = fhir_r4.AdverseEvent.fromJson(resourceJson);

    return AdverseEvent(
      id: data.id,
      sourceId: data.sourceId ?? '',
      resourceId: data.resourceId ?? '',
      title: data.title ?? '',
      date: data.date,
      rawResource: resourceJson,
      encounterId: data.encounterId ?? '',
      subjectId: data.subjectId ?? '',
      text: fhirAdverseEvent.text,
      identifier: fhirAdverseEvent.identifier,
      actuality: fhirAdverseEvent.actuality,
      category: fhirAdverseEvent.category,
      event: fhirAdverseEvent.event,
      subject: fhirAdverseEvent.subject,
      encounter: fhirAdverseEvent.encounter,
      fhirDate: fhirAdverseEvent.date,
      detected: fhirAdverseEvent.detected,
      recordedDate: fhirAdverseEvent.recordedDate,
      resultingCondition: fhirAdverseEvent.resultingCondition,
      location: fhirAdverseEvent.location,
      seriousness: fhirAdverseEvent.seriousness,
      severity: fhirAdverseEvent.severity,
      outcome: fhirAdverseEvent.outcome,
      recorder: fhirAdverseEvent.recorder,
      contributor: fhirAdverseEvent.contributor,
      suspectEntity: fhirAdverseEvent.suspectEntity,
      subjectMedicalHistory: fhirAdverseEvent.subjectMedicalHistory,
      referenceDocument: fhirAdverseEvent.referenceDocument,
      study: fhirAdverseEvent.study,
    );
  }

  @override
  FhirResourceDto toDto() => FhirResourceDto(
        id: id,
        sourceId: sourceId,
        resourceType: 'AdverseEvent',
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

    final displayText = FhirFieldExtractor.extractCodeableConceptText(event);
    if (displayText != null) return displayText;

    return fhirType.display;
  }

  @override
  List<RecordInfoLine> get additionalInfo {
    List<RecordInfoLine> infoLines = [];

    // Actuality
    final actualityDisplay = actuality?.valueString;
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createStatusLine(actualityDisplay,
          prefix: 'Actuality'),
    );

    // Category
    final categoryDisplay =
        FhirFieldExtractor.extractFirstCodeableConceptFromArray(category);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createCategoryLine(categoryDisplay,
          prefix: 'Category'),
    );

    // Seriousness
    final seriousnessDisplay =
        FhirFieldExtractor.extractCodeableConceptText(seriousness);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createWarningLine(seriousnessDisplay,
          prefix: 'Seriousness'),
    );

    // Severity
    final severityDisplay =
        FhirFieldExtractor.extractCodeableConceptText(severity);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createWarningLine(severityDisplay, prefix: 'Severity'),
    );

    // Outcome
    final outcomeDisplay =
        FhirFieldExtractor.extractCodeableConceptText(outcome);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createStatusLine(outcomeDisplay, prefix: 'Outcome'),
    );

    // Location
    final locationDisplay =
        FhirFieldExtractor.extractReferenceDisplay(location);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createLocationLine(locationDisplay,
          prefix: 'Location'),
    );

    // Recorder
    final recorderDisplay =
        FhirFieldExtractor.extractReferenceDisplay(recorder);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createUserLine(recorderDisplay, prefix: 'Recorder'),
    );

    // Detected Date
    final detectedDisplay = detected?.valueString;
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createDateLine(detectedDisplay, prefix: 'Detected'),
    );

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
      location?.reference?.valueString,
      recorder?.reference?.valueString,
      ...?resultingCondition
          ?.map((reference) => reference.reference?.valueString),
      ...?subjectMedicalHistory
          ?.map((reference) => reference.reference?.valueString),
      ...?referenceDocument
          ?.map((reference) => reference.reference?.valueString),
      ...?study?.map((reference) => reference.reference?.valueString),
    }.where((reference) => reference != null).toList();
  }

  @override
  String get statusDisplay => actuality?.valueString ?? '';
}
