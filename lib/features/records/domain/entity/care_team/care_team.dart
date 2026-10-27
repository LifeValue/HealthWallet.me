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

part 'care_team.freezed.dart';

@freezed
abstract class CareTeam with _$CareTeam implements IFhirResource {
  const CareTeam._();

  const factory CareTeam({
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
    CareTeamStatus? status,
    List<CodeableConcept>? category,
    FhirString? name,
    Reference? subject,
    Reference? encounter,
    Period? period,
    List<CareTeamParticipant>? participant,
    List<CodeableConcept>? reasonCode,
    List<Reference>? reasonReference,
    List<Reference>? managingOrganization,
    List<ContactPoint>? telecom,
    List<Annotation>? note,
  }) = _CareTeam;

  @override
  FhirType get fhirType => FhirType.CareTeam;

  factory CareTeam.fromLocalData(FhirResourceLocalDto data) {
    final resourceJson = jsonDecode(data.resourceRaw);
    final fhirCareTeam = fhir_r4.CareTeam.fromJson(resourceJson);

    return CareTeam(
      id: data.id,
      sourceId: data.sourceId ?? '',
      resourceId: data.resourceId ?? '',
      title: data.title ?? '',
      date: data.date,
      rawResource: resourceJson,
      encounterId: data.encounterId ?? '',
      subjectId: data.subjectId ?? '',
      specialtyOverride: data.specialtyOverride,
      text: fhirCareTeam.text,
      identifier: fhirCareTeam.identifier,
      status: fhirCareTeam.status,
      category: fhirCareTeam.category,
      name: fhirCareTeam.name,
      subject: fhirCareTeam.subject,
      encounter: fhirCareTeam.encounter,
      period: fhirCareTeam.period,
      participant: fhirCareTeam.participant,
      reasonCode: fhirCareTeam.reasonCode,
      reasonReference: fhirCareTeam.reasonReference,
      managingOrganization: fhirCareTeam.managingOrganization,
      telecom: fhirCareTeam.telecom,
      note: fhirCareTeam.note,
    );
  }

  @override
  FhirResourceDto toDto() => FhirResourceDto(
    id: id,
    sourceId: sourceId,
    resourceType: 'CareTeam',
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

    final careTeamName = name?.toString();
    if (careTeamName != null && careTeamName.isNotEmpty) return careTeamName;

    return fhirType.display;
  }

  @override
  List<RecordInfoLine> additionalInfo(AppLocalizations l10n) {
    final List<RecordInfoLine> infoLines = [];

    // Status
    final statusText = status?.valueString;
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createStatusLine(
        statusText,
        prefix: l10n.fieldStatus,
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

    // Managing Organization
    final organizationDisplay =
        FhirFieldExtractor.extractMultipleReferenceDisplays(
          managingOrganization,
        );
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createOrganizationLine(
        organizationDisplay,
        prefix: l10n.fieldOrganization,
      ),
    );

    // Participants/Members
    final participantsDisplay = FhirFieldExtractor.extractParticipants(
      participant,
    );
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createTeamLine(
        participantsDisplay,
        prefix: l10n.fieldMembers,
      ),
    );

    // Period
    final periodDisplay = FhirFieldExtractor.extractPeriodFormatted(
      period,
      l10n: l10n,
    );
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createTimelineLine(
        periodDisplay,
        prefix: l10n.fieldPeriod,
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
      ...?reasonReference?.map((reference) => reference.reference?.valueString),
      ...?managingOrganization?.map(
        (reference) => reference.reference?.valueString,
      ),
    }.where((reference) => reference != null).toList();
  }

  @override
  String get statusDisplay => status?.valueString ?? '';
}
