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

part 'allergy_intolerance.freezed.dart';

@freezed
class AllergyIntolerance with _$AllergyIntolerance implements IFhirResource {
  const AllergyIntolerance._();

  const factory AllergyIntolerance({
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
    CodeableConcept? clinicalStatus,
    CodeableConcept? verificationStatus,
    AllergyIntoleranceType? type,
    List<AllergyIntoleranceCategory>? category,
    AllergyIntoleranceCriticality? criticality,
    CodeableConcept? code,
    Reference? patient,
    OnsetXAllergyIntolerance? onsetX,
    FhirDateTime? recordedDate,
    Reference? recorder,
    Reference? asserter,
    FhirDateTime? lastOccurrence,
    List<Annotation>? note,
    List<AllergyIntoleranceReaction>? reaction,
  }) = _AllergyIntolerance;

  @override
  FhirType get fhirType => FhirType.AllergyIntolerance;

  factory AllergyIntolerance.fromLocalData(FhirResourceLocalDto data) {
    final resourceJson = jsonDecode(data.resourceRaw);
    final fhirAllergyIntolerance =
        fhir_r4.AllergyIntolerance.fromJson(resourceJson);

    return AllergyIntolerance(
      id: data.id,
      sourceId: data.sourceId ?? '',
      resourceId: data.resourceId ?? '',
      title: data.title ?? '',
      date: data.date,
      rawResource: resourceJson,
      encounterId: data.encounterId ?? '',
      subjectId: data.subjectId ?? '',
      text: fhirAllergyIntolerance.text,
      identifier: fhirAllergyIntolerance.identifier,
      clinicalStatus: fhirAllergyIntolerance.clinicalStatus,
      verificationStatus: fhirAllergyIntolerance.verificationStatus,
      type: fhirAllergyIntolerance.type,
      category: fhirAllergyIntolerance.category,
      criticality: fhirAllergyIntolerance.criticality,
      code: fhirAllergyIntolerance.code,
      patient: fhirAllergyIntolerance.patient,
      onsetX: fhirAllergyIntolerance.onsetX,
      recordedDate: fhirAllergyIntolerance.recordedDate,
      recorder: fhirAllergyIntolerance.recorder,
      asserter: fhirAllergyIntolerance.asserter,
      lastOccurrence: fhirAllergyIntolerance.lastOccurrence,
      note: fhirAllergyIntolerance.note,
      reaction: fhirAllergyIntolerance.reaction,
    );
  }

  @override
  FhirResourceDto toDto() => FhirResourceDto(
        id: id,
        sourceId: sourceId,
        resourceType: 'AllergyIntolerance',
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

    // Clinical Status
    final statusDisplay =
        FhirFieldExtractor.extractCodeableConceptText(clinicalStatus);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createStatusLine(statusDisplay,
          prefix: 'Clinical Status'),
    );

    // Verification Status
    final verificationDisplay =
        FhirFieldExtractor.extractCodeableConceptText(verificationStatus);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createStatusLine(verificationDisplay,
          prefix: 'Verification'),
    );

    // Type (allergy or intolerance)
    final typeDisplay = type?.valueString;
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createStatusLine(typeDisplay, prefix: 'Type'),
    );

    // Category (food, medication, environment, biologic)
    if (category != null && category!.isNotEmpty) {
      final categoryDisplay =
          category!.map((c) => c.valueString).where((c) => c != null).join(', ');
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createCategoryLine(
            categoryDisplay.isNotEmpty ? categoryDisplay : null,
            prefix: 'Category'),
      );
    }

    // Criticality
    final criticalityDisplay = criticality?.valueString;
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createWarningLine(criticalityDisplay,
          prefix: 'Criticality'),
    );

    // Onset
    final onsetDisplay = FhirFieldExtractor.extractOnsetX(onsetX);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createDateLine(onsetDisplay, prefix: 'Onset'),
    );

    // Last Occurrence
    final lastOccurrenceDisplay = lastOccurrence?.valueString;
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createDateLine(lastOccurrenceDisplay,
          prefix: 'Last Occurrence'),
    );

    // Recorder
    final recorderDisplay =
        FhirFieldExtractor.extractReferenceDisplay(recorder);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createUserLine(recorderDisplay, prefix: 'Recorder'),
    );

    // Asserter
    final asserterDisplay =
        FhirFieldExtractor.extractReferenceDisplay(asserter);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createUserLine(asserterDisplay, prefix: 'Asserter'),
    );

    // Reactions
    if (reaction != null && reaction!.isNotEmpty) {
      final reactionManifestations = reaction!
          .expand((r) => r.manifestation)
          .map((m) => FhirFieldExtractor.extractCodeableConceptText(m))
          .where((m) => m != null && m.isNotEmpty)
          .take(3)
          .join(', ');
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createWarningLine(
            reactionManifestations.isNotEmpty ? reactionManifestations : null,
            prefix: 'Reactions'),
      );
    }

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
      patient?.reference?.valueString,
      recorder?.reference?.valueString,
      asserter?.reference?.valueString,
    }.where((reference) => reference != null).toList();
  }

  @override
  String get statusDisplay =>
      FhirFieldExtractor.extractCodeableConceptText(clinicalStatus) ?? '';
}
