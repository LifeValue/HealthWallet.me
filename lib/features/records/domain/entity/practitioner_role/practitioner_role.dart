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

part 'practitioner_role.freezed.dart';

@freezed
abstract class PractitionerRole
    with _$PractitionerRole
    implements IFhirResource {
  const PractitionerRole._();

  const factory PractitionerRole({
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
    FhirBoolean? active,
    Period? period,
    Reference? practitioner,
    Reference? organization,
    List<CodeableConcept>? code,
    List<CodeableConcept>? specialty,
    List<Reference>? location,
    List<Reference>? healthcareService,
    List<ContactPoint>? telecom,
    List<PractitionerRoleAvailableTime>? availableTime,
    List<PractitionerRoleNotAvailable>? notAvailable,
    FhirString? availabilityExceptions,
    List<Reference>? endpoint,
  }) = _PractitionerRole;

  @override
  FhirType get fhirType => FhirType.PractitionerRole;

  factory PractitionerRole.fromLocalData(FhirResourceLocalDto data) {
    final resourceJson = jsonDecode(data.resourceRaw);
    final fhirPractitionerRole = fhir_r4.PractitionerRole.fromJson(
      resourceJson,
    );

    return PractitionerRole(
      id: data.id,
      sourceId: data.sourceId ?? '',
      resourceId: data.resourceId ?? '',
      title: data.title ?? '',
      date: data.date,
      rawResource: resourceJson,
      encounterId: data.encounterId ?? '',
      subjectId: data.subjectId ?? '',
      specialtyOverride: data.specialtyOverride,
      text: fhirPractitionerRole.text,
      identifier: fhirPractitionerRole.identifier,
      active: fhirPractitionerRole.active,
      period: fhirPractitionerRole.period,
      practitioner: fhirPractitionerRole.practitioner,
      organization: fhirPractitionerRole.organization,
      code: fhirPractitionerRole.code,
      specialty: fhirPractitionerRole.specialty,
      location: fhirPractitionerRole.location,
      healthcareService: fhirPractitionerRole.healthcareService,
      telecom: fhirPractitionerRole.telecom,
      availableTime: fhirPractitionerRole.availableTime,
      notAvailable: fhirPractitionerRole.notAvailable,
      availabilityExceptions: fhirPractitionerRole.availabilityExceptions,
      endpoint: fhirPractitionerRole.endpoint,
    );
  }

  @override
  FhirResourceDto toDto() => FhirResourceDto(
    id: id,
    sourceId: sourceId,
    resourceType: 'PractitionerRole',
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
      code,
    );
    if (displayText != null) return displayText;

    return fhirType.display;
  }

  @override
  List<RecordInfoLine> additionalInfo(AppLocalizations l10n) {
    final List<RecordInfoLine> infoLines = [];

    // Active Status
    final activeStatus = active?.valueBoolean;
    if (activeStatus != null) {
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createStatusLine(
          activeStatus ? l10n.active : l10n.inactive,
          prefix: l10n.fieldStatus,
        ),
      );
    }

    // Practitioner
    final practitionerDisplay = practitioner?.display?.valueString;
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createUserLine(
        practitionerDisplay,
        prefix: l10n.fieldPractitioner,
      ),
    );

    // Organization
    final organizationDisplay = organization?.display?.valueString;
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createOrganizationLine(
        organizationDisplay,
        prefix: l10n.fieldOrganization,
      ),
    );

    // Role/Code
    final roleDisplay = FhirFieldExtractor.extractFirstCodeableConceptFromArray(
      code,
    );
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createStatusLine(roleDisplay, prefix: l10n.fieldRole),
    );

    // Specialty
    if (specialty != null && specialty!.isNotEmpty) {
      final specialtyDisplay = specialty!
          .map(FhirFieldExtractor.extractCodeableConceptText)
          .where((s) => s != null && s.isNotEmpty)
          .take(3)
          .join(', ');
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createStatusLine(
          specialtyDisplay.isNotEmpty ? specialtyDisplay : null,
          prefix: l10n.fieldSpecialty,
        ),
      );
    }

    // Location
    if (location != null && location!.isNotEmpty) {
      final locationDisplay = location!
          .map((l) => l.display?.valueString)
          .where((l) => l != null && l.isNotEmpty)
          .take(2)
          .join(', ');
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createLocationLine(
          locationDisplay.isNotEmpty ? locationDisplay : null,
          prefix: l10n.fieldLocation,
        ),
      );
    }

    // Healthcare Service
    if (healthcareService != null && healthcareService!.isNotEmpty) {
      final serviceDisplay = healthcareService!
          .map((s) => s.display?.valueString)
          .where((s) => s != null && s.isNotEmpty)
          .take(2)
          .join(', ');
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createStatusLine(
          serviceDisplay.isNotEmpty ? serviceDisplay : null,
          prefix: l10n.fieldHealthcareService,
        ),
      );
    }

    // Telecom (phone/email)
    if (telecom != null && telecom!.isNotEmpty) {
      final phone = telecom!
          .where((t) => t.system?.valueString == 'phone')
          .firstOrNull
          ?.value
          ?.valueString;
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createStatusLine(phone, prefix: l10n.fieldPhone),
      );

      final email = telecom!
          .where((t) => t.system?.valueString == 'email')
          .firstOrNull
          ?.value
          ?.valueString;
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createStatusLine(email, prefix: l10n.fieldEmail),
      );
    }

    // Period
    final periodDisplay = FhirFieldExtractor.extractPeriodFormatted(
      period,
      l10n: l10n,
    );
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createDateLine(
        periodDisplay,
        prefix: l10n.fieldPeriod,
      ),
    );

    // Availability Exceptions
    final exceptionsDisplay = availabilityExceptions?.valueString;
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createNotesLine(
        exceptionsDisplay,
        prefix: l10n.fieldAvailabilityNotes,
      ),
    );

    // Date (last updated)
    if (date != null) {
      infoLines.add(
        RecordInfoLine(
          icon: Assets.icons.calendar,
          info:
              '${l10n.fieldLastUpdated}: ${FhirFieldExtractor.formatRecordDate(date!, l10n.localeName)}',
        ),
      );
    }

    return infoLines;
  }

  @override
  List<String?> get resourceReferences {
    return {
      practitioner?.reference?.valueString,
      organization?.reference?.valueString,
      ...?location?.map((reference) => reference.reference?.valueString),
      ...?healthcareService?.map(
        (reference) => reference.reference?.valueString,
      ),
      ...?endpoint?.map((reference) => reference.reference?.valueString),
    }.where((reference) => reference != null).toList();
  }

  @override
  String get statusDisplay =>
      active?.valueBoolean == true ? 'Active' : 'Inactive';
}
