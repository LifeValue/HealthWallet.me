import 'dart:convert';

import 'package:fhir_r4/fhir_r4.dart' as fhir_r4;
import 'package:fhir_r4/fhir_r4.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:health_wallet/core/data/local/app_database.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/features/records/domain/entity/i_fhir_resource.dart';
import 'package:health_wallet/features/records/domain/utils/fhir_field_extractor.dart';
import 'package:health_wallet/features/records/domain/utils/resource_field_mapper.dart';
import 'package:health_wallet/features/records/presentation/models/record_info_line.dart';
import 'package:health_wallet/features/sync/data/dto/fhir_resource_dto.dart';
import 'package:health_wallet/gen/assets.gen.dart';

part 'goal.freezed.dart';

@freezed
abstract class Goal with _$Goal implements IFhirResource {
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
    String? specialtyOverride,
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
      specialtyOverride: data.specialtyOverride,
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

    final displayText = FhirFieldExtractor.extractCodeableConceptText(
      description,
    );
    if (displayText != null) return displayText;

    return fhirType.display;
  }

  @override
  List<RecordInfoLine> additionalInfo(AppLocalizations l10n) {
    final List<RecordInfoLine> infoLines = [];
    infoLines.add(
      ResourceFieldMapper.createSectionHeader(l10n.fieldGoalDetails),
    );

    // Description (What is the goal - CRITICAL)
    final descriptionDisplay = FhirFieldExtractor.extractCodeableConceptText(
      description,
    );
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createActivityLine(
        descriptionDisplay,
        prefix: l10n.fieldGoal,
      ),
    );

    // Target Measures (Specific targets - CRITICAL)
    if (target != null && target!.isNotEmpty) {
      for (final tgt in target!) {
        final measure = FhirFieldExtractor.extractCodeableConceptText(
          tgt.measure,
        );

        // Extract target value
        String? targetValue;
        if (tgt.detailQuantity != null) {
          targetValue = FhirFieldExtractor.extractQuantity(tgt.detailQuantity);
        } else if (tgt.detailRange != null) {
          final low = tgt.detailRange!.low != null
              ? FhirFieldExtractor.extractQuantity(tgt.detailRange!.low)
              : null;
          final high = tgt.detailRange!.high != null
              ? FhirFieldExtractor.extractQuantity(tgt.detailRange!.high)
              : null;
          if (low != null && high != null) {
            targetValue = '$low - $high';
          } else if (low != null) {
            targetValue = '> $low';
          } else if (high != null) {
            targetValue = '< $high';
          }
        } else if (tgt.detailCodeableConcept != null) {
          targetValue = FhirFieldExtractor.extractCodeableConceptText(
            tgt.detailCodeableConcept,
          );
        } else if (tgt.detailString != null) {
          targetValue = tgt.detailString!.valueString;
        } else if (tgt.detailBoolean != null) {
          targetValue = tgt.detailBoolean!.valueBoolean == true
              ? l10n.yes
              : l10n.no;
        } else if (tgt.detailInteger != null) {
          targetValue = tgt.detailInteger!.valueString;
        } else if (tgt.detailRatio != null) {
          final numerator = FhirFieldExtractor.extractQuantity(
            tgt.detailRatio!.numerator,
          );
          final denominator = FhirFieldExtractor.extractQuantity(
            tgt.detailRatio!.denominator,
          );
          if (numerator != null && denominator != null) {
            targetValue = '$numerator / $denominator';
          }
        }

        // Due date
        final dueDate =
            tgt.dueX?.isAs<fhir_r4.FhirDate>()?.valueString ??
            tgt.dueX?.isAs<fhir_r4.FhirDuration>()?.value?.valueString;

        // Build target display
        final targetDisplay = [
          ?measure,
          ?targetValue,
          if (dueDate != null) l10n.goalDueBy(dueDate),
        ].join(': ');

        ResourceFieldMapper.addIfNotNull(
          infoLines,
          ResourceFieldMapper.createValueLine(
            targetDisplay.isNotEmpty ? targetDisplay : null,
            prefix: l10n.fieldTarget,
          ),
        );
      }
    }

    // Achievement Status (Progress - CRITICAL)
    final achievementDisplay = FhirFieldExtractor.extractCodeableConceptText(
      achievementStatus,
    );
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createStatusLine(
        achievementDisplay,
        prefix: l10n.fieldAchievementStatus,
      ),
    );

    infoLines.add(
      ResourceFieldMapper.createSectionHeader(l10n.fieldBasicInformation),
    );

    // Lifecycle Status (Active, Completed, Cancelled)
    final lifecycleDisplay = lifecycleStatus?.valueString;
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createStatusLine(
        lifecycleDisplay,
        prefix: l10n.fieldLifecycleStatus,
      ),
    );

    // Status Date (When status last changed)
    final statusDateDisplay = statusDate?.valueString;
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createDateLine(
        statusDateDisplay,
        prefix: l10n.fieldStatusDate,
      ),
    );

    // Category (Type of goal)
    if (category != null && category!.isNotEmpty) {
      final categoryDisplay = category!
          .map(FhirFieldExtractor.extractCodeableConceptText)
          .where((c) => c != null && c.isNotEmpty)
          .join(', ');
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createCategoryLine(
          categoryDisplay.isNotEmpty ? categoryDisplay : null,
          prefix: l10n.fieldCategory,
        ),
      );
    }

    // Priority
    final priorityDisplay = FhirFieldExtractor.extractCodeableConceptText(
      priority,
    );
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createWarningLine(
        priorityDisplay,
        prefix: l10n.fieldPriority,
      ),
    );

    // Start Date
    final startDisplay =
        startX?.isAs<fhir_r4.FhirDate>()?.valueString ??
        FhirFieldExtractor.extractCodeableConceptText(
          startX?.isAs<fhir_r4.CodeableConcept>(),
        );
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createDateLine(
        startDisplay,
        prefix: l10n.fieldStartDate,
      ),
    );

    // Set By / Expressed By
    final expressedByDisplay = FhirFieldExtractor.extractReferenceDisplay(
      expressedBy,
    );
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createUserLine(
        expressedByDisplay,
        prefix: l10n.fieldSetBy,
      ),
    );

    // Addresses (What conditions/issues this goal addresses)
    if (addresses != null && addresses!.isNotEmpty) {
      final addressesDisplay = addresses!
          .map(FhirFieldExtractor.extractReferenceDisplay)
          .where((a) => a != null && a.isNotEmpty)
          .join(', ');
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createNotesLine(
          addressesDisplay.isNotEmpty ? addressesDisplay : null,
          prefix: l10n.fieldAddresses,
        ),
      );
    }

    infoLines.add(
      ResourceFieldMapper.createSectionHeader(l10n.fieldAdditionalInformation),
    );

    // Status Reason (Why goal is in this status)
    final statusReasonText = statusReason?.valueString;
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createNotesLine(
        statusReasonText,
        prefix: l10n.fieldStatusReason,
      ),
    );

    // Outcome Code (Results of pursuing this goal)
    if (outcomeCode != null && outcomeCode!.isNotEmpty) {
      final outcomeDisplay = outcomeCode!
          .map(FhirFieldExtractor.extractCodeableConceptText)
          .where((o) => o != null && o.isNotEmpty)
          .join(', ');
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createStatusLine(
          outcomeDisplay.isNotEmpty ? outcomeDisplay : null,
          prefix: l10n.fieldOutcome,
        ),
      );
    }

    // Outcome Reference (Links to observation/results)
    if (outcomeReference != null && outcomeReference!.isNotEmpty) {
      final outcomeRefDisplay = outcomeReference!
          .map(FhirFieldExtractor.extractReferenceDisplay)
          .where((o) => o != null && o.isNotEmpty)
          .take(3)
          .join(', ');

      if (outcomeRefDisplay.isNotEmpty) {
        final suffix = outcomeReference!.length > 3
            ? ' (${l10n.moreCount(outcomeReference!.length - 3)})'
            : '';
        ResourceFieldMapper.addIfNotNull(
          infoLines,
          ResourceFieldMapper.createLabLine(
            outcomeRefDisplay + suffix,
            prefix: l10n.fieldOutcomeMeasurements,
          ),
        );
      }
    }

    // Date
    if (date != null) {
      infoLines.add(
        RecordInfoLine(
          icon: Assets.icons.calendar,
          info: FhirFieldExtractor.formatRecordDate(date!, l10n.localeName),
        ),
      );
    }

    // Notes (Progress notes, action plan)
    final notesDisplay = FhirFieldExtractor.extractAnnotations(note);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createNotesLine(
        notesDisplay,
        prefix: l10n.fieldProgressNotes,
      ),
    );

    return infoLines;
  }

  @override
  List<String?> get resourceReferences {
    return {
      subject?.reference?.valueString,
      expressedBy?.reference?.valueString,
      ...?addresses?.map((reference) => reference.reference?.valueString),
      ...?outcomeReference?.map(
        (reference) => reference.reference?.valueString,
      ),
    }.where((reference) => reference != null).toList();
  }

  @override
  String get statusDisplay => lifecycleStatus?.valueString ?? '';
}
