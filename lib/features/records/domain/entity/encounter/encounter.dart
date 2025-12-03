import 'dart:convert';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:fhir_r4/fhir_r4.dart' as fhir_r4;
import 'package:fhir_r4/fhir_r4.dart';
import 'package:health_wallet/core/utils/logger.dart';
import 'package:health_wallet/features/records/domain/entity/i_fhir_resource.dart';
import 'package:health_wallet/core/data/local/app_database.dart';
import 'package:health_wallet/features/records/domain/utils/fhir_field_extractor.dart';
import 'package:health_wallet/features/records/presentation/models/record_info_line.dart';
import 'package:health_wallet/features/sync/data/dto/fhir_resource_dto.dart';
import 'package:health_wallet/gen/assets.gen.dart';
import 'package:intl/intl.dart';

part 'encounter.freezed.dart';

@freezed
class Encounter with _$Encounter implements IFhirResource {
  const Encounter._();

  const factory Encounter({
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
    EncounterStatus? status,
    List<EncounterStatusHistory>? statusHistory,
    Coding? class_,
    List<EncounterClassHistory>? classHistory,
    List<CodeableConcept>? type,
    CodeableConcept? serviceType,
    CodeableConcept? priority,
    Reference? subject,
    List<Reference>? episodeOfCare,
    List<Reference>? basedOn,
    List<EncounterParticipant>? participant,
    List<Reference>? appointment,
    Period? period,
    FhirDuration? length,
    List<CodeableConcept>? reasonCode,
    List<Reference>? reasonReference,
    List<EncounterDiagnosis>? diagnosis,
    List<Reference>? account,
    EncounterHospitalization? hospitalization,
    List<EncounterLocation>? location,
    Reference? serviceProvider,
    Reference? partOf,
  }) = _Encounter;

  @override
  FhirType get fhirType => FhirType.Encounter;

  factory Encounter.fromLocalData(FhirResourceLocalDto data) {
    try {
      final resourceJson = jsonDecode(data.resourceRaw);
      final fhirEncounter = fhir_r4.Encounter.fromJson(resourceJson);

      return Encounter(
        id: data.id,
        sourceId: data.sourceId ?? '',
        resourceId: data.resourceId ?? '',
        title: data.title ?? '',
        date: data.date,
        rawResource: resourceJson,
        encounterId: data.encounterId ?? '',
        subjectId: data.subjectId ?? '',
        text: fhirEncounter.text,
        identifier: fhirEncounter.identifier,
        status: fhirEncounter.status,
        statusHistory: fhirEncounter.statusHistory,
        class_: fhirEncounter.class_,
        classHistory: fhirEncounter.classHistory,
        type: fhirEncounter.type,
        serviceType: fhirEncounter.serviceType,
        priority: fhirEncounter.priority,
        subject: fhirEncounter.subject,
        episodeOfCare: fhirEncounter.episodeOfCare,
        basedOn: fhirEncounter.basedOn,
        participant: fhirEncounter.participant,
        appointment: fhirEncounter.appointment,
        period: fhirEncounter.period,
        length: fhirEncounter.length,
        reasonCode: fhirEncounter.reasonCode,
        reasonReference: fhirEncounter.reasonReference,
        diagnosis: fhirEncounter.diagnosis,
        account: fhirEncounter.account,
        hospitalization: fhirEncounter.hospitalization,
        location: fhirEncounter.location,
        serviceProvider: fhirEncounter.serviceProvider,
        partOf: fhirEncounter.partOf,
      );
    } catch (e) {
      logger.e(
          'Failed to parse Encounter ${data.id}, creating minimal entity: $e');
      return Encounter(
        id: data.id,
        sourceId: data.sourceId ?? '',
        resourceId: data.resourceId ?? '',
        title: data.title ?? 'Encounter',
        date: data.date,
        rawResource: jsonDecode(data.resourceRaw),
      );
    }
  }

  factory Encounter.fromDto(FhirResourceDto dto) {
    try {
      final resourceJson = dto.resourceRaw ?? {};
      final fhirEncounter = fhir_r4.Encounter.fromJson(resourceJson);

      return Encounter(
        id: dto.id ?? '',
        sourceId: dto.sourceId ?? '',
        resourceId: dto.resourceId ?? '',
        title: dto.title ?? '',
        date: dto.date,
        rawResource: resourceJson,
        encounterId: dto.encounterId ?? '',
        subjectId: dto.subjectId ?? '',
        text: fhirEncounter.text,
        identifier: fhirEncounter.identifier,
        status: fhirEncounter.status,
        statusHistory: fhirEncounter.statusHistory,
        class_: fhirEncounter.class_,
        classHistory: fhirEncounter.classHistory,
        type: fhirEncounter.type,
        serviceType: fhirEncounter.serviceType,
        priority: fhirEncounter.priority,
        subject: fhirEncounter.subject,
        episodeOfCare: fhirEncounter.episodeOfCare,
        basedOn: fhirEncounter.basedOn,
        participant: fhirEncounter.participant,
        appointment: fhirEncounter.appointment,
        period: fhirEncounter.period,
        length: fhirEncounter.length,
        reasonCode: fhirEncounter.reasonCode,
        reasonReference: fhirEncounter.reasonReference,
        diagnosis: fhirEncounter.diagnosis,
        account: fhirEncounter.account,
        hospitalization: fhirEncounter.hospitalization,
        location: fhirEncounter.location,
        serviceProvider: fhirEncounter.serviceProvider,
        partOf: fhirEncounter.partOf,
      );
    } catch (e) {
      logger.e(
          'Failed to parse Encounter ${dto.id}, creating minimal entity: $e');
      return Encounter(
        id: dto.id ?? '',
        sourceId: dto.sourceId ?? '',
        resourceId: dto.resourceId ?? '',
        title: dto.title ?? 'Encounter',
        date: dto.date,
        rawResource: dto.resourceRaw ?? {},
      );
    }
  }

  @override
  FhirResourceDto toDto() => FhirResourceDto(
        id: id,
        sourceId: sourceId,
        resourceType: 'Encounter',
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
        FhirFieldExtractor.extractFirstCodeableConceptFromArray(type);
    if (displayText != null) return displayText;

    return fhirType.display;
  }

  @override
  List<RecordInfoLine> get additionalInfo {
    List<RecordInfoLine> infoLines = [];

    final participantDisplay =
        participant?.firstOrNull?.individual?.display?.valueString;
    if (participantDisplay != null) {
      infoLines.add(RecordInfoLine(
        icon: Assets.icons.user,
        info: participantDisplay,
      ));
    }

    final serviceProviderDisplay = serviceProvider?.display?.valueString;
    if (serviceProviderDisplay != null) {
      infoLines.add(RecordInfoLine(
        icon: Assets.icons.hospital,
        info: serviceProviderDisplay,
      ));
    }

    if (date != null) {
      infoLines.add(RecordInfoLine(
        icon: Assets.icons.calendar,
        info: DateFormat.yMMMMd().format(date!),
      ));
    }

    return infoLines;
  }

  // Encounter is a special case, we get the related resources from the records
  // that have their encounter id referenced directly in the db
  @override
  List<String> get resourceReferences => [];

  @override
  String get statusDisplay => status?.valueString ?? '';
}
