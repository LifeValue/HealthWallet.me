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

part 'specimen.freezed.dart';

@freezed
class Specimen with _$Specimen implements IFhirResource {
  const Specimen._();

  const factory Specimen({
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
    Identifier? accessionIdentifier,
    SpecimenStatus? status,
    CodeableConcept? type,
    Reference? subject,
    FhirDateTime? receivedTime,
    List<Reference>? parent,
    List<Reference>? request,
    SpecimenCollection? collection,
    List<SpecimenProcessing>? processing,
    List<SpecimenContainer>? container,
    List<CodeableConcept>? condition,
    List<Annotation>? note,
  }) = _Specimen;

  @override
  FhirType get fhirType => FhirType.Specimen;

  factory Specimen.fromLocalData(FhirResourceLocalDto data) {
    final resourceJson = jsonDecode(data.resourceRaw);
    final fhirSpecimen = fhir_r4.Specimen.fromJson(resourceJson);

    return Specimen(
      id: data.id,
      sourceId: data.sourceId ?? '',
      resourceId: data.resourceId ?? '',
      title: data.title ?? '',
      date: data.date,
      rawResource: resourceJson,
      encounterId: data.encounterId ?? '',
      subjectId: data.subjectId ?? '',
      text: fhirSpecimen.text,
      identifier: fhirSpecimen.identifier,
      accessionIdentifier: fhirSpecimen.accessionIdentifier,
      status: fhirSpecimen.status,
      type: fhirSpecimen.type,
      subject: fhirSpecimen.subject,
      receivedTime: fhirSpecimen.receivedTime,
      parent: fhirSpecimen.parent,
      request: fhirSpecimen.request,
      collection: fhirSpecimen.collection,
      processing: fhirSpecimen.processing,
      container: fhirSpecimen.container,
      condition: fhirSpecimen.condition,
      note: fhirSpecimen.note,
    );
  }

  @override
  FhirResourceDto toDto() => FhirResourceDto(
        id: id,
        sourceId: sourceId,
        resourceType: 'Specimen',
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
      ResourceFieldMapper.createLabLine(typeDisplay, prefix: 'Type'),
    );

    // Accession Identifier
    final accessionId = accessionIdentifier?.value?.valueString;
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createIdentificationLine(accessionId,
          prefix: 'Accession ID'),
    );

    // Received Time
    final receivedTimeDisplay = receivedTime?.valueString;
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createDateLine(receivedTimeDisplay,
          prefix: 'Received'),
    );

    // Collection
    if (collection != null) {
      final collectedTime = collection!.collectedX?.isAs<fhir_r4.FhirDateTime>();
      if (collectedTime != null) {
        ResourceFieldMapper.addIfNotNull(
          infoLines,
          ResourceFieldMapper.createDateLine(collectedTime.valueString,
              prefix: 'Collected'),
        );
      }

      final collector =
          FhirFieldExtractor.extractReferenceDisplay(collection!.collector);
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createUserLine(collector, prefix: 'Collector'),
      );

      final bodySite =
          FhirFieldExtractor.extractCodeableConceptText(collection!.bodySite);
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createBodySiteLine(bodySite, prefix: 'Body Site'),
      );
    }

    // Condition
    final conditionDisplay =
        FhirFieldExtractor.extractFirstCodeableConceptFromArray(condition);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createStatusLine(conditionDisplay,
          prefix: 'Condition'),
    );

    // Container count
    if (container != null && container!.isNotEmpty) {
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createLabLine('${container!.length} container(s)',
            prefix: 'Containers'),
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
      subject?.reference?.valueString,
      ...?parent?.map((reference) => reference.reference?.valueString),
      ...?request?.map((reference) => reference.reference?.valueString),
    }.where((reference) => reference != null).toList();
  }

  @override
  String get statusDisplay => status?.valueString ?? '';
}
