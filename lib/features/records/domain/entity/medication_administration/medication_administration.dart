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

part 'medication_administration.freezed.dart';

@freezed
class MedicationAdministration
    with _$MedicationAdministration
    implements IFhirResource {
  const MedicationAdministration._();

  const factory MedicationAdministration({
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
    List<FhirUri>? instantiates,
    List<Reference>? partOf,
    MedicationAdministrationStatusCodes? status,
    List<CodeableConcept>? statusReason,
    CodeableConcept? category,
    MedicationXMedicationAdministration? medicationX,
    Reference? subject,
    Reference? context,
    List<Reference>? supportingInformation,
    EffectiveXMedicationAdministration? effectiveX,
    List<MedicationAdministrationPerformer>? performer,
    List<CodeableConcept>? reasonCode,
    List<Reference>? reasonReference,
    Reference? request,
    List<Reference>? device,
    List<Annotation>? note,
    MedicationAdministrationDosage? dosage,
    List<Reference>? eventHistory,
  }) = _MedicationAdministration;

  @override
  FhirType get fhirType => FhirType.MedicationAdministration;

  factory MedicationAdministration.fromLocalData(FhirResourceLocalDto data) {
    final resourceJson = jsonDecode(data.resourceRaw);
    final fhirMedicationAdministration =
        fhir_r4.MedicationAdministration.fromJson(resourceJson);

    return MedicationAdministration(
      id: data.id,
      sourceId: data.sourceId ?? '',
      resourceId: data.resourceId ?? '',
      title: data.title ?? '',
      date: data.date,
      rawResource: resourceJson,
      encounterId: data.encounterId ?? '',
      subjectId: data.subjectId ?? '',
      text: fhirMedicationAdministration.text,
      identifier: fhirMedicationAdministration.identifier,
      instantiates: fhirMedicationAdministration.instantiates,
      partOf: fhirMedicationAdministration.partOf,
      status: fhirMedicationAdministration.status,
      statusReason: fhirMedicationAdministration.statusReason,
      category: fhirMedicationAdministration.category,
      medicationX: fhirMedicationAdministration.medicationX,
      subject: fhirMedicationAdministration.subject,
      context: fhirMedicationAdministration.context,
      supportingInformation: fhirMedicationAdministration.supportingInformation,
      effectiveX: fhirMedicationAdministration.effectiveX,
      performer: fhirMedicationAdministration.performer,
      reasonCode: fhirMedicationAdministration.reasonCode,
      reasonReference: fhirMedicationAdministration.reasonReference,
      request: fhirMedicationAdministration.request,
      device: fhirMedicationAdministration.device,
      note: fhirMedicationAdministration.note,
      dosage: fhirMedicationAdministration.dosage,
      eventHistory: fhirMedicationAdministration.eventHistory,
    );
  }

  @override
  FhirResourceDto toDto() => FhirResourceDto(
        id: id,
        sourceId: sourceId,
        resourceType: 'MedicationAdministration',
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
  List<RecordInfoLine> get additionalInfo {
    List<RecordInfoLine> infoLines = [];

    // Medication
    final medicationDisplay = FhirFieldExtractor.extractCodeableConceptText(
        medicationX?.isAs<CodeableConcept>());
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createMedicationLine(medicationDisplay),
    );

    // Status
    final statusText = status?.valueString;
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createStatusLine(statusText, prefix: 'Status'),
    );

    // Status Reason
    final statusReasonDisplay =
        FhirFieldExtractor.extractFirstCodeableConceptFromArray(statusReason);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createStatusLine(statusReasonDisplay,
          prefix: 'Status Reason'),
    );

    // Category
    final categoryDisplay =
        FhirFieldExtractor.extractCodeableConceptText(category);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createCategoryLine(categoryDisplay,
          prefix: 'Category'),
    );

    // Effective Time
    final effectiveDisplay = FhirFieldExtractor.extractEffectiveX(effectiveX);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createDateLine(effectiveDisplay, prefix: 'Effective'),
    );

    // Performer
    if (performer != null && performer!.isNotEmpty) {
      final performerDisplay = performer!
          .map((p) => FhirFieldExtractor.extractReferenceDisplay(p.actor))
          .where((d) => d != null && d.isNotEmpty)
          .join(', ');
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createUserLine(
            performerDisplay.isNotEmpty ? performerDisplay : null,
            prefix: 'Performer'),
      );
    }

    // Dosage
    if (dosage != null) {
      final doseText = dosage!.text?.valueString;
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createValueLine(doseText, prefix: 'Dosage'),
      );

      final route = FhirFieldExtractor.extractCodeableConceptText(dosage!.route);
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createActivityLine(route, prefix: 'Route'),
      );

      final site = FhirFieldExtractor.extractCodeableConceptText(dosage!.site);
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createBodySiteLine(site, prefix: 'Site'),
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
      context?.reference?.valueString,
      request?.reference?.valueString,
      ...?partOf?.map((reference) => reference.reference?.valueString),
      ...?supportingInformation
          ?.map((reference) => reference.reference?.valueString),
      ...?reasonReference?.map((reference) => reference.reference?.valueString),
      ...?device?.map((reference) => reference.reference?.valueString),
      ...?eventHistory?.map((reference) => reference.reference?.valueString),
    }.where((reference) => reference != null).toList();
  }

  @override
  String get statusDisplay => status?.valueString ?? '';
}
