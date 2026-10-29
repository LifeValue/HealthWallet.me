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

part 'medication_statement.freezed.dart';

@freezed
abstract class MedicationStatement
    with _$MedicationStatement
    implements IFhirResource {
  const MedicationStatement._();

  const factory MedicationStatement({
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
    List<Reference>? basedOn,
    List<Reference>? partOf,
    MedicationStatementStatusCodes? status,
    List<CodeableConcept>? statusReason,
    CodeableConcept? category,
    MedicationXMedicationStatement? medicationX,
    Reference? subject,
    Reference? context,
    EffectiveXMedicationStatement? effectiveX,
    FhirDateTime? dateAsserted,
    Reference? informationSource,
    List<Reference>? derivedFrom,
    List<CodeableConcept>? reasonCode,
    List<Reference>? reasonReference,
    List<Annotation>? note,
    List<Dosage>? dosage,
  }) = _MedicationStatement;

  @override
  FhirType get fhirType => FhirType.MedicationStatement;

  factory MedicationStatement.fromLocalData(FhirResourceLocalDto data) {
    final resourceJson = jsonDecode(data.resourceRaw);
    final fhirMedicationStatement = fhir_r4.MedicationStatement.fromJson(
      resourceJson,
    );

    return MedicationStatement(
      id: data.id,
      sourceId: data.sourceId ?? '',
      resourceId: data.resourceId ?? '',
      title: data.title ?? '',
      date: data.date,
      rawResource: resourceJson,
      encounterId: data.encounterId ?? '',
      subjectId: data.subjectId ?? '',
      specialtyOverride: data.specialtyOverride,
      text: fhirMedicationStatement.text,
      identifier: fhirMedicationStatement.identifier,
      basedOn: fhirMedicationStatement.basedOn,
      partOf: fhirMedicationStatement.partOf,
      status: fhirMedicationStatement.status,
      statusReason: fhirMedicationStatement.statusReason,
      category: fhirMedicationStatement.category,
      medicationX: fhirMedicationStatement.medicationX,
      subject: fhirMedicationStatement.subject,
      context: fhirMedicationStatement.context,
      effectiveX: fhirMedicationStatement.effectiveX,
      dateAsserted: fhirMedicationStatement.dateAsserted,
      informationSource: fhirMedicationStatement.informationSource,
      derivedFrom: fhirMedicationStatement.derivedFrom,
      reasonCode: fhirMedicationStatement.reasonCode,
      reasonReference: fhirMedicationStatement.reasonReference,
      note: fhirMedicationStatement.note,
      dosage: fhirMedicationStatement.dosage,
    );
  }

  @override
  FhirResourceDto toDto() => FhirResourceDto(
    id: id,
    sourceId: sourceId,
    resourceType: 'MedicationStatement',
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

    final displayText = FhirFieldExtractor.extractCodeableConceptText(category);
    if (displayText != null) return displayText;

    return fhirType.display;
  }

  @override
  List<RecordInfoLine> additionalInfo(AppLocalizations l10n) {
    final List<RecordInfoLine> infoLines = [];

    // Medication
    final medicationDisplay = FhirFieldExtractor.extractCodeableConceptText(
      medicationX?.isAs<CodeableConcept>(),
    );
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createMedicationLine(medicationDisplay),
    );

    // Status
    final statusDisplay = status?.display?.valueString;
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createStatusLine(
        statusDisplay,
        prefix: l10n.fieldStatus,
      ),
    );

    // Status Reason
    final statusReasonDisplay =
        FhirFieldExtractor.extractFirstCodeableConceptFromArray(statusReason);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createStatusLine(
        statusReasonDisplay,
        prefix: l10n.fieldStatusReason,
      ),
    );

    // Category
    final categoryDisplay = FhirFieldExtractor.extractCodeableConceptText(
      category,
    );
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createCategoryLine(
        categoryDisplay,
        prefix: l10n.fieldCategory,
      ),
    );

    // Effective Period
    final effectiveDisplay = FhirFieldExtractor.extractEffectiveX(
      effectiveX,
      l10n: l10n,
    );
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createDateLine(
        effectiveDisplay,
        prefix: l10n.fieldEffective,
      ),
    );

    // Information Source
    final informationSourceDisplay = FhirFieldExtractor.extractReferenceDisplay(
      informationSource,
    );
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createUserLine(
        informationSourceDisplay,
        prefix: l10n.fieldInformationSource,
      ),
    );

    // Dosage Instructions
    final dosageDisplay = FhirFieldExtractor.extractDosageInstructions(dosage);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createNotesLine(
        dosageDisplay,
        prefix: l10n.fieldDosage,
      ),
    );

    // Reason Code
    final reasonCodeDisplay = FhirFieldExtractor.extractReasonCodes(reasonCode);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createNotesLine(
        reasonCodeDisplay,
        prefix: l10n.fieldReason,
      ),
    );

    // Date
    if (date != null) {
      infoLines.add(
        RecordInfoLine(
          icon: Assets.icons.calendar,
          info: FhirFieldExtractor.formatRecordDate(date!, l10n.localeName),
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
      context?.reference?.valueString,
      informationSource?.reference?.valueString,
      ...?basedOn?.map((reference) => reference.reference?.valueString),
      ...?partOf?.map((reference) => reference.reference?.valueString),
      ...?derivedFrom?.map((reference) => reference.reference?.valueString),
      ...?reasonReference?.map((reference) => reference.reference?.valueString),
    }.where((reference) => reference != null).toList();
  }

  @override
  String get statusDisplay => status?.valueString ?? '';
}
