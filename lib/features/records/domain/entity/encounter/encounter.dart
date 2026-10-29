import 'dart:convert';

import 'package:fhir_r4/fhir_r4.dart' as fhir_r4;
import 'package:fhir_r4/fhir_r4.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:health_wallet/core/data/local/app_database.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/core/utils/logger.dart';
import 'package:health_wallet/features/records/domain/entity/i_fhir_resource.dart';
import 'package:health_wallet/features/records/domain/utils/fhir_field_extractor.dart';
import 'package:health_wallet/features/records/domain/utils/resource_field_mapper.dart';
import 'package:health_wallet/features/records/presentation/models/record_info_line.dart';
import 'package:health_wallet/features/sync/data/dto/fhir_resource_dto.dart';
import 'package:health_wallet/gen/assets.gen.dart';
import 'package:intl/intl.dart';

part 'encounter.freezed.dart';

@freezed
abstract class Encounter with _$Encounter implements IFhirResource {
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
    String? specialtyOverride,
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
        specialtyOverride: data.specialtyOverride,
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
        'Failed to parse Encounter ${data.id}, creating minimal entity: $e',
      );
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
        'Failed to parse Encounter ${dto.id}, creating minimal entity: $e',
      );
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

    final displayText = FhirFieldExtractor.extractFirstCodeableConceptFromArray(
      type,
    );
    if (displayText != null) return displayText;

    return fhirType.display;
  }

  @override
  List<RecordInfoLine> additionalInfo(AppLocalizations l10n) {
    final List<RecordInfoLine> infoLines = [];
    infoLines.add(
      ResourceFieldMapper.createSectionHeader(l10n.fieldVisitDetails),
    );

    // Class (Inpatient/Outpatient/Emergency - CRITICAL)
    final classDisplay = FhirFieldExtractor.extractCodingDisplay(class_);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createCategoryLine(
        classDisplay,
        prefix: l10n.fieldVisitType,
      ),
    );

    // Type (specific type of encounter)
    final typeDisplay = FhirFieldExtractor.extractFirstCodeableConceptFromArray(
      type,
    );
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createStatusLine(
        typeDisplay,
        prefix: l10n.fieldEncounterType,
      ),
    );

    // Period (Start and End times - CRITICAL)
    final periodDisplay = FhirFieldExtractor.extractPeriodFormatted(
      period,
      l10n: l10n,
    );
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createTimelineLine(
        periodDisplay,
        prefix: l10n.fieldTimePeriod,
      ),
    );

    // Length/Duration
    if (length != null) {
      final lengthValue = length!.value?.valueDouble?.toStringAsFixed(1);
      final lengthUnit = length!.unit?.toString() ?? 'minutes';
      if (lengthValue != null) {
        ResourceFieldMapper.addIfNotNull(
          infoLines,
          ResourceFieldMapper.createTimeLine(
            '$lengthValue $lengthUnit',
            prefix: l10n.fieldDuration,
          ),
        );
      }
    }

    // Participants (Doctors/Nurses involved - IMPORTANT)
    final participantsDisplay = FhirFieldExtractor.extractParticipants(
      participant,
    );
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createUserLine(
        participantsDisplay,
        prefix: l10n.fieldCareTeam,
      ),
    );

    // Reason Code (Chief Complaint/Reason for visit - CRITICAL)
    final reasonCodeDisplay = FhirFieldExtractor.extractReasonCodes(reasonCode);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createNotesLine(
        reasonCodeDisplay,
        prefix: l10n.fieldReasonForVisit,
      ),
    );

    // Diagnosis (Conditions addressed - CRITICAL)
    final diagnosisDisplay = FhirFieldExtractor.extractDiagnoses(diagnosis);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createNotesLine(
        diagnosisDisplay,
        prefix: l10n.fieldDiagnoses,
      ),
    );

    infoLines.add(
      ResourceFieldMapper.createSectionHeader(l10n.fieldLocationProvider),
    );

    // Service Provider (Hospital/Clinic)
    final serviceProviderDisplay = FhirFieldExtractor.extractReferenceDisplay(
      serviceProvider,
    );
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createOrganizationLine(
        serviceProviderDisplay,
        prefix: l10n.fieldHealthcareFacility,
      ),
    );

    // Location (Where it happened - specific room/department)
    final locationDisplay = FhirFieldExtractor.extractLocations(location);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createLocationLine(
        locationDisplay,
        prefix: l10n.fieldLocation,
      ),
    );

    // Service Type
    final serviceTypeDisplay = FhirFieldExtractor.extractCodeableConceptText(
      serviceType,
    );
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createActivityLine(
        serviceTypeDisplay,
        prefix: l10n.fieldServiceType,
      ),
    );

    infoLines.add(
      ResourceFieldMapper.createSectionHeader(l10n.fieldAdditionalInformation),
    );

    // Status
    final statusText = status?.valueString;
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createStatusLine(
        statusText,
        prefix: l10n.fieldStatus,
      ),
    );

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

    // Hospitalization Details (if applicable)
    if (hospitalization != null) {
      // Admission Source
      final admitSourceDisplay = FhirFieldExtractor.extractCodeableConceptText(
        hospitalization!.admitSource,
      );
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createStatusLine(
          admitSourceDisplay,
          prefix: l10n.fieldAdmissionSource,
        ),
      );

      // Re-admission indicator
      final reAdmission = FhirFieldExtractor.extractCodeableConceptText(
        hospitalization!.reAdmission,
      );
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createStatusLine(
          reAdmission,
          prefix: l10n.fieldReAdmission,
        ),
      );

      // Diet Preference
      if (hospitalization!.dietPreference != null &&
          hospitalization!.dietPreference!.isNotEmpty) {
        final dietDisplay = hospitalization!.dietPreference!
            .map(FhirFieldExtractor.extractCodeableConceptText)
            .where((d) => d != null && d.isNotEmpty)
            .join(', ');
        ResourceFieldMapper.addIfNotNull(
          infoLines,
          ResourceFieldMapper.createNotesLine(
            dietDisplay.isNotEmpty ? dietDisplay : null,
            prefix: l10n.fieldDietPreference,
          ),
        );
      }

      // Special Arrangements
      if (hospitalization!.specialArrangement != null &&
          hospitalization!.specialArrangement!.isNotEmpty) {
        final arrangementsDisplay = hospitalization!.specialArrangement!
            .map(FhirFieldExtractor.extractCodeableConceptText)
            .where((a) => a != null && a.isNotEmpty)
            .join(', ');
        ResourceFieldMapper.addIfNotNull(
          infoLines,
          ResourceFieldMapper.createNotesLine(
            arrangementsDisplay.isNotEmpty ? arrangementsDisplay : null,
            prefix: l10n.fieldSpecialArrangements,
          ),
        );
      }

      // Discharge Disposition
      final dischargeDisposition =
          FhirFieldExtractor.extractCodeableConceptText(
            hospitalization!.dischargeDisposition,
          );
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createStatusLine(
          dischargeDisposition,
          prefix: l10n.fieldDischargeDisposition,
        ),
      );

      // Discharge Destination
      final dischargeDestination = FhirFieldExtractor.extractReferenceDisplay(
        hospitalization!.destination,
      );
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createLocationLine(
          dischargeDestination,
          prefix: l10n.fieldDischargeTo,
        ),
      );
    }

    // Appointment reference
    if (appointment != null && appointment!.isNotEmpty) {
      final appointmentDisplay = appointment!
          .map(FhirFieldExtractor.extractReferenceDisplay)
          .where((a) => a != null && a.isNotEmpty)
          .join(', ');
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createTimelineLine(
          appointmentDisplay.isNotEmpty ? appointmentDisplay : null,
          prefix: l10n.fieldRelatedAppointment,
        ),
      );
    }

    // Episode of Care
    if (episodeOfCare != null && episodeOfCare!.isNotEmpty) {
      final episodeDisplay = episodeOfCare!
          .map(FhirFieldExtractor.extractReferenceDisplay)
          .where((e) => e != null && e.isNotEmpty)
          .join(', ');
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createTimelineLine(
          episodeDisplay.isNotEmpty ? episodeDisplay : null,
          prefix: l10n.fieldEpisodeOfCare,
        ),
      );
    }

    // Part Of (if this encounter is part of another)
    final partOfDisplay = FhirFieldExtractor.extractReferenceDisplay(partOf);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createStatusLine(
        partOfDisplay,
        prefix: l10n.fieldPartOf,
      ),
    );

    // Status History (show if status changed during encounter)
    if (statusHistory != null &&
        statusHistory!.isNotEmpty &&
        statusHistory!.length > 1) {
      final statusChanges = statusHistory!
          .map((h) {
            final status = h.status.valueString;
            final period = FhirFieldExtractor.extractPeriodFormatted(
              h.period,
              l10n: l10n,
            );
            return status != null && period != null
                ? '$status: $period'
                : status ?? period;
          })
          .where((s) => s != null && s.isNotEmpty)
          .take(3)
          .join('; ');
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createTimelineLine(
          statusChanges.isNotEmpty ? statusChanges : null,
          prefix: l10n.fieldStatusHistory,
        ),
      );
    }

    // Date
    if (date != null) {
      infoLines.add(
        RecordInfoLine(
          icon: Assets.icons.calendar,
          info: DateFormat.yMMMMd(l10n.localeName).format(date!),
        ),
      );
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
