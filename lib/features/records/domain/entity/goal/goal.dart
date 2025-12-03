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

part 'goal.freezed.dart';

@freezed
class Goal with _$Goal implements IFhirResource {
  const Goal._();

  const factory Goal({
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
    GoalLifecycleStatus? lifecycleStatus,
    CodeableConcept? achievementStatus,
    List<CodeableConcept>? category,
    CodeableConcept? priority,
    CodeableConcept? description,
    Reference? subject,
    StartXGoal? startX,
    List<GoalTarget>? target,
    FhirDate? statusDate,
    FhirString? statusReason,
    Reference? expressedBy,
    List<Reference>? addresses,
    List<Annotation>? note,
    List<CodeableConcept>? outcomeCode,
    List<Reference>? outcomeReference,
  }) = _Goal;

  @override
  FhirType get fhirType => FhirType.Goal;

  factory Goal.fromLocalData(FhirResourceLocalDto data) {
    final resourceJson = jsonDecode(data.resourceRaw);
    final fhirGoal = fhir_r4.Goal.fromJson(resourceJson);

    return Goal(
      id: data.id,
      sourceId: data.sourceId ?? '',
      resourceId: data.resourceId ?? '',
      title: data.title ?? '',
      date: data.date,
      rawResource: resourceJson,
      encounterId: data.encounterId ?? '',
      subjectId: data.subjectId ?? '',
      text: fhirGoal.text,
      identifier: fhirGoal.identifier,
      lifecycleStatus: fhirGoal.lifecycleStatus,
      achievementStatus: fhirGoal.achievementStatus,
      category: fhirGoal.category,
      priority: fhirGoal.priority,
      description: fhirGoal.description,
      subject: fhirGoal.subject,
      startX: fhirGoal.startX,
      target: fhirGoal.target,
      statusDate: fhirGoal.statusDate,
      statusReason: fhirGoal.statusReason,
      expressedBy: fhirGoal.expressedBy,
      addresses: fhirGoal.addresses,
      note: fhirGoal.note,
      outcomeCode: fhirGoal.outcomeCode,
      outcomeReference: fhirGoal.outcomeReference,
    );
  }

  @override
  FhirResourceDto toDto() => FhirResourceDto(
        id: id,
        sourceId: sourceId,
        resourceType: 'Goal',
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

    final displayText =
        FhirFieldExtractor.extractCodeableConceptText(description);
    if (displayText != null) return displayText;

    return fhirType.display;
  }

  @override
  List<RecordInfoLine> get additionalInfo {
    List<RecordInfoLine> infoLines = [];

    // Lifecycle Status
    final lifecycleDisplay = lifecycleStatus?.valueString;
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createStatusLine(lifecycleDisplay, prefix: 'Status'),
    );

    // Achievement Status
    final achievementDisplay =
        FhirFieldExtractor.extractCodeableConceptText(achievementStatus);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createStatusLine(achievementDisplay,
          prefix: 'Achievement'),
    );

    // Priority
    final priorityDisplay =
        FhirFieldExtractor.extractCodeableConceptText(priority);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createWarningLine(priorityDisplay, prefix: 'Priority'),
    );

    // Category
    final categoryDisplay =
        FhirFieldExtractor.extractFirstCodeableConceptFromArray(category);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createCategoryLine(categoryDisplay,
          prefix: 'Category'),
    );

    // Target
    if (target != null && target!.isNotEmpty) {
      final targetMeasure = FhirFieldExtractor.extractCodeableConceptText(
          target!.first.measure);
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createActivityLine(targetMeasure, prefix: 'Target'),
      );
    }

    // Expressed By
    final expressedByDisplay =
        FhirFieldExtractor.extractReferenceDisplay(expressedBy);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createUserLine(expressedByDisplay,
          prefix: 'Expressed By'),
    );

    // Status Reason
    final statusReasonText = statusReason?.valueString;
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createNotesLine(statusReasonText,
          prefix: 'Status Reason'),
    );

    // Outcome Code
    final outcomeCodeDisplay =
        FhirFieldExtractor.extractFirstCodeableConceptFromArray(outcomeCode);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createStatusLine(outcomeCodeDisplay,
          prefix: 'Outcome'),
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
      expressedBy?.reference?.valueString,
      ...?addresses?.map((reference) => reference.reference?.valueString),
      ...?outcomeReference
          ?.map((reference) => reference.reference?.valueString),
    }.where((reference) => reference != null).toList();
  }

  @override
  String get statusDisplay => lifecycleStatus?.valueString ?? '';
}
