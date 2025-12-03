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

part 'immunization.freezed.dart';

@freezed
class Immunization with _$Immunization implements IFhirResource {
  const Immunization._();

  const factory Immunization({
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
    ImmunizationStatusCodes? status,
    CodeableConcept? statusReason,
    CodeableConcept? vaccineCode,
    Reference? patient,
    Reference? encounter,
    OccurrenceXImmunization? occurrenceX,
    FhirDateTime? recorded,
    FhirBoolean? primarySource,
    CodeableConcept? reportOrigin,
    Reference? location,
    Reference? manufacturer,
    FhirString? lotNumber,
    FhirDate? expirationDate,
    CodeableConcept? site,
    CodeableConcept? route,
    Quantity? doseQuantity,
    List<ImmunizationPerformer>? performer,
    List<Annotation>? note,
    List<CodeableConcept>? reasonCode,
    List<Reference>? reasonReference,
    FhirBoolean? isSubpotent,
    List<CodeableConcept>? subpotentReason,
    List<ImmunizationEducation>? education,
    List<CodeableConcept>? programEligibility,
    CodeableConcept? fundingSource,
    List<ImmunizationReaction>? reaction,
    List<ImmunizationProtocolApplied>? protocolApplied,
  }) = _Immunization;

  @override
  FhirType get fhirType => FhirType.Immunization;

  factory Immunization.fromLocalData(FhirResourceLocalDto data) {
    final resourceJson = jsonDecode(data.resourceRaw);
    final fhirImmunization = fhir_r4.Immunization.fromJson(resourceJson);

    return Immunization(
      id: data.id,
      sourceId: data.sourceId ?? '',
      resourceId: data.resourceId ?? '',
      title: data.title ?? '',
      date: data.date,
      rawResource: resourceJson,
      encounterId: data.encounterId ?? '',
      subjectId: data.subjectId ?? '',
      text: fhirImmunization.text,
      identifier: fhirImmunization.identifier,
      status: fhirImmunization.status,
      statusReason: fhirImmunization.statusReason,
      vaccineCode: fhirImmunization.vaccineCode,
      patient: fhirImmunization.patient,
      encounter: fhirImmunization.encounter,
      recorded: fhirImmunization.recorded,
      primarySource: fhirImmunization.primarySource,
      reportOrigin: fhirImmunization.reportOrigin,
      location: fhirImmunization.location,
      manufacturer: fhirImmunization.manufacturer,
      lotNumber: fhirImmunization.lotNumber,
      expirationDate: fhirImmunization.expirationDate,
      site: fhirImmunization.site,
      route: fhirImmunization.route,
      doseQuantity: fhirImmunization.doseQuantity,
      performer: fhirImmunization.performer,
      note: fhirImmunization.note,
      reasonCode: fhirImmunization.reasonCode,
      reasonReference: fhirImmunization.reasonReference,
      isSubpotent: fhirImmunization.isSubpotent,
      subpotentReason: fhirImmunization.subpotentReason,
      education: fhirImmunization.education,
      programEligibility: fhirImmunization.programEligibility,
      fundingSource: fhirImmunization.fundingSource,
      reaction: fhirImmunization.reaction,
      protocolApplied: fhirImmunization.protocolApplied,
    );
  }

  @override
  FhirResourceDto toDto() => FhirResourceDto(
        id: id,
        sourceId: sourceId,
        resourceType: 'Immunization',
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
        FhirFieldExtractor.extractCodeableConceptText(vaccineCode);
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

    // Status Reason
    final statusReasonDisplay =
        FhirFieldExtractor.extractCodeableConceptText(statusReason);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createStatusLine(statusReasonDisplay,
          prefix: 'Status Reason'),
    );

    // Occurrence
    final occurrenceDisplay =
        FhirFieldExtractor.extractOccurrenceX(occurrenceX);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createDateLine(occurrenceDisplay,
          prefix: 'Occurrence'),
    );

    // Performer
    if (performer != null && performer!.isNotEmpty) {
      final performerDisplay = performer!
          .map((p) => p.actor.display?.toString())
          .where((d) => d != null && d.isNotEmpty)
          .join(', ');
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createUserLine(
            performerDisplay.isNotEmpty ? performerDisplay : null,
            prefix: 'Performer'),
      );
    }

    // Location
    final locationDisplay =
        FhirFieldExtractor.extractReferenceDisplay(location);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createLocationLine(locationDisplay,
          prefix: 'Location'),
    );

    // Manufacturer
    final manufacturerDisplay =
        FhirFieldExtractor.extractReferenceDisplay(manufacturer);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createOrganizationLine(manufacturerDisplay,
          prefix: 'Manufacturer'),
    );

    // Lot Number
    final lotNumberDisplay = lotNumber?.valueString;
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createIdentificationLine(lotNumberDisplay,
          prefix: 'Lot Number'),
    );

    // Expiration Date
    final expirationDisplay = expirationDate?.valueString;
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createDateLine(expirationDisplay,
          prefix: 'Expiration'),
    );

    // Site
    final siteDisplay = FhirFieldExtractor.extractCodeableConceptText(site);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createBodySiteLine(siteDisplay, prefix: 'Site'),
    );

    // Route
    final routeDisplay = FhirFieldExtractor.extractCodeableConceptText(route);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createActivityLine(routeDisplay, prefix: 'Route'),
    );

    // Dose Quantity
    final doseDisplay = FhirFieldExtractor.extractQuantity(doseQuantity);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createValueLine(doseDisplay, prefix: 'Dose'),
    );

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
      patient?.reference?.valueString,
      encounter?.reference?.valueString,
      location?.reference?.valueString,
      manufacturer?.reference?.valueString,
      ...?reasonReference?.map((reference) => reference.reference?.valueString),
    }.where((reference) => reference != null).toList();
  }

  @override
  String get statusDisplay => status?.valueString ?? '';
}
