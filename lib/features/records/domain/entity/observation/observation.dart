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

part 'observation.freezed.dart';

@freezed
class Observation with _$Observation implements IFhirResource {
  const Observation._();

  const factory Observation({
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
    ObservationStatus? status,
    List<CodeableConcept>? category,
    CodeableConcept? code,
    Reference? subject,
    List<Reference>? focus,
    Reference? encounter,
    EffectiveXObservation? effectiveX,
    FhirInstant? issued,
    List<Reference>? performer,
    ValueXObservation? valueX,
    CodeableConcept? dataAbsentReason,
    List<CodeableConcept>? interpretation,
    List<Annotation>? note,
    CodeableConcept? bodySite,
    CodeableConcept? method,
    Reference? specimen,
    Reference? device,
    List<ObservationReferenceRange>? referenceRange,
    List<Reference>? hasMember,
    List<Reference>? derivedFrom,
    List<ObservationComponent>? component,
  }) = _Observation;

  @override
  FhirType get fhirType => FhirType.Observation;

  factory Observation.fromLocalData(FhirResourceLocalDto data) {
    final resourceJson = jsonDecode(data.resourceRaw);
    final fhirObservation = fhir_r4.Observation.fromJson(resourceJson);

    return Observation(
      id: data.id,
      sourceId: data.sourceId ?? '',
      resourceId: data.resourceId ?? '',
      title: data.title ?? '',
      date: data.date,
      rawResource: resourceJson,
      encounterId: data.encounterId ?? '',
      subjectId: data.subjectId ?? '',
      text: fhirObservation.text,
      identifier: fhirObservation.identifier,
      basedOn: fhirObservation.basedOn,
      partOf: fhirObservation.partOf,
      status: fhirObservation.status,
      category: fhirObservation.category,
      code: fhirObservation.code,
      subject: fhirObservation.subject,
      focus: fhirObservation.focus,
      encounter: fhirObservation.encounter,
      effectiveX: fhirObservation.effectiveX,
      issued: fhirObservation.issued,
      performer: fhirObservation.performer,
      valueX: fhirObservation.valueX,
      dataAbsentReason: fhirObservation.dataAbsentReason,
      interpretation: fhirObservation.interpretation,
      note: fhirObservation.note,
      bodySite: fhirObservation.bodySite,
      method: fhirObservation.method,
      specimen: fhirObservation.specimen,
      device: fhirObservation.device,
      referenceRange: fhirObservation.referenceRange,
      hasMember: fhirObservation.hasMember,
      derivedFrom: fhirObservation.derivedFrom,
      component: fhirObservation.component,
    );
  }

  @override
  FhirResourceDto toDto() => FhirResourceDto(
        id: id,
        sourceId: sourceId,
        resourceType: 'Observation',
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

    // Value
    final valueDisplay = FhirFieldExtractor.extractObservationValue(valueX);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createValueLine(valueDisplay),
    );

    // Component values (e.g., for blood pressure with systolic/diastolic)
    if (component != null && component!.isNotEmpty) {
      final componentValues = component!
          .map((component) =>
              FhirFieldExtractor.extractObservationValue(component.valueX))
          .toList();

      final componentValuesDisplay =
          FhirFieldExtractor.joinNullable(componentValues, ", ");

      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createValueLine(componentValuesDisplay),
      );
    }

    // Status
    final statusText = status?.valueString;
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createStatusLine(statusText, prefix: 'Status'),
    );

    // Category
    final categoryDisplay =
        FhirFieldExtractor.extractFirstCodeableConceptFromArray(category);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createCategoryLine(categoryDisplay,
          prefix: 'Category'),
    );

    // Interpretation
    final interpretationDisplay =
        FhirFieldExtractor.extractInterpretation(interpretation);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createWarningLine(interpretationDisplay,
          prefix: 'Interpretation'),
    );

    // Body Site
    final bodySiteDisplay =
        FhirFieldExtractor.extractCodeableConceptText(bodySite);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createBodySiteLine(bodySiteDisplay,
          prefix: 'Body Site'),
    );

    // Method
    final methodDisplay = FhirFieldExtractor.extractCodeableConceptText(method);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createProcedureLine(methodDisplay, prefix: 'Method'),
    );

    // Performer
    final performerDisplay = FhirFieldExtractor.extractPerformers(performer);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createUserLine(performerDisplay, prefix: 'Performer'),
    );

    // Reference Range
    if (referenceRange != null && referenceRange!.isNotEmpty) {
      final range = referenceRange!.first;
      final lowValue = range.low?.value?.valueDouble?.toStringAsFixed(2);
      final highValue = range.high?.value?.valueDouble?.toStringAsFixed(2);
      final unit = range.low?.unit ?? range.high?.unit ?? '';
      if (lowValue != null && highValue != null) {
        ResourceFieldMapper.addIfNotNull(
          infoLines,
          ResourceFieldMapper.createLabLine('$lowValue - $highValue $unit',
              prefix: 'Reference Range'),
        );
      }
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
      subject?.reference?.valueString,
      encounter?.reference?.valueString,
      specimen?.reference?.valueString,
      device?.reference?.valueString,
      ...?basedOn?.map((reference) => reference.reference?.valueString),
      ...?partOf?.map((reference) => reference.reference?.valueString),
      ...?focus?.map((reference) => reference.reference?.valueString),
      ...?performer?.map((reference) => reference.reference?.valueString),
      ...?hasMember?.map((reference) => reference.reference?.valueString),
      ...?derivedFrom?.map((reference) => reference.reference?.valueString),
    }.where((reference) => reference != null).toList();
  }

  @override
  String get statusDisplay => status?.valueString ?? '';
}
