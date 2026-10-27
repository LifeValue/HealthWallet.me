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
import 'package:intl/intl.dart';

part 'condition.freezed.dart';

@freezed
abstract class Condition with _$Condition implements IFhirResource {
  const Condition._();

  const factory Condition({
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
    CodeableConcept? clinicalStatus,
    CodeableConcept? verificationStatus,
    List<CodeableConcept>? category,
    CodeableConcept? severity,
    CodeableConcept? code,
    List<CodeableConcept>? bodySite,
    Reference? subject,
    Reference? encounter,
    OnsetXCondition? onsetX,
    AbatementXCondition? abatementX,
    FhirDateTime? recordedDate,
    Reference? recorder,
    Reference? asserter,
    List<ConditionStage>? stage,
    List<ConditionEvidence>? evidence,
    List<Annotation>? note,
  }) = _Condition;

  @override
  FhirType get fhirType => FhirType.Condition;

  factory Condition.fromLocalData(FhirResourceLocalDto data) {
    final resourceJson = jsonDecode(data.resourceRaw);
    final fhirCondition = fhir_r4.Condition.fromJson(resourceJson);

    return Condition(
      id: data.id,
      sourceId: data.sourceId ?? '',
      resourceId: data.resourceId ?? '',
      title: data.title ?? '',
      date: data.date,
      rawResource: resourceJson,
      encounterId: data.encounterId ?? '',
      subjectId: data.subjectId ?? '',
      specialtyOverride: data.specialtyOverride,
      text: fhirCondition.text,
      identifier: fhirCondition.identifier,
      clinicalStatus: fhirCondition.clinicalStatus,
      verificationStatus: fhirCondition.verificationStatus,
      category: fhirCondition.category,
      severity: fhirCondition.severity,
      code: fhirCondition.code,
      bodySite: fhirCondition.bodySite,
      subject: fhirCondition.subject,
      encounter: fhirCondition.encounter,
      onsetX: fhirCondition.onsetX,
      abatementX: fhirCondition.abatementX,
      recordedDate: fhirCondition.recordedDate,
      recorder: fhirCondition.recorder,
      asserter: fhirCondition.asserter,
      stage: fhirCondition.stage,
      evidence: fhirCondition.evidence,
      note: fhirCondition.note,
    );
  }

  @override
  FhirResourceDto toDto() => FhirResourceDto(
    id: id,
    sourceId: sourceId,
    resourceType: 'Condition',
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
  List<RecordInfoLine> additionalInfo(AppLocalizations l10n) {
    final List<RecordInfoLine> infoLines = [];

    // Clinical Status
    final statusDisplay = FhirFieldExtractor.extractCodeableConceptText(
      clinicalStatus,
    );
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createStatusLine(
        statusDisplay,
        prefix: l10n.fieldClinicalStatus,
      ),
    );

    // Verification Status
    final verificationDisplay = FhirFieldExtractor.extractCodeableConceptText(
      verificationStatus,
    );
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createStatusLine(
        verificationDisplay,
        prefix: l10n.fieldVerification,
      ),
    );

    // Severity
    final severityDisplay = FhirFieldExtractor.extractCodeableConceptText(
      severity,
    );
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createWarningLine(
        severityDisplay,
        prefix: l10n.fieldSeverity,
      ),
    );

    // Category
    final categoryDisplay =
        FhirFieldExtractor.extractFirstCodeableConceptFromArray(category);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createCategoryLine(
        categoryDisplay,
        prefix: l10n.fieldCategory,
      ),
    );

    // Body Site
    final bodySiteDisplay =
        FhirFieldExtractor.extractFirstCodeableConceptFromArray(bodySite);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createBodySiteLine(
        bodySiteDisplay,
        prefix: l10n.fieldBodySite,
      ),
    );

    // Onset Date
    final onsetDisplay = FhirFieldExtractor.extractOnsetX(onsetX, l10n: l10n);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createDateLine(onsetDisplay, prefix: l10n.fieldOnset),
    );

    // Abatement Date
    final abatementDisplay = FhirFieldExtractor.extractAbatementX(
      abatementX,
      l10n: l10n,
    );
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createDateLine(
        abatementDisplay,
        prefix: l10n.fieldResolved,
      ),
    );

    // Stage
    if (stage != null && stage!.isNotEmpty) {
      final stageDisplay = FhirFieldExtractor.extractCodeableConceptText(
        stage!.first.summary,
      );
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createActivityLine(
          stageDisplay,
          prefix: l10n.fieldStage,
        ),
      );
    }

    // Recorder
    final recorderDisplay = FhirFieldExtractor.extractReferenceDisplay(
      recorder,
    );
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createUserLine(
        recorderDisplay,
        prefix: l10n.fieldRecorder,
      ),
    );

    // Asserter
    final asserterDisplay = FhirFieldExtractor.extractReferenceDisplay(
      asserter,
    );
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createUserLine(
        asserterDisplay,
        prefix: l10n.fieldAsserter,
      ),
    );

    // Recorded Date
    if (date != null) {
      infoLines.add(
        RecordInfoLine(
          icon: Assets.icons.calendar,
          info: DateFormat.yMMMMd().format(date!),
        ),
      );
    }

    // Notes
    final notesDisplay = FhirFieldExtractor.extractAnnotations(note);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createNotesLine(
        notesDisplay,
        prefix: l10n.fieldNotes,
      ),
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
    }.where((reference) => reference != null).toList();
  }

  @override
  String get statusDisplay =>
      FhirFieldExtractor.extractCodeableConceptText(clinicalStatus) ?? '';
}
