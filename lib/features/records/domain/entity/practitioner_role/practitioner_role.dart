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

part 'practitioner_role.freezed.dart';

@freezed
class PractitionerRole with _$PractitionerRole implements IFhirResource {
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
    final fhirPractitionerRole =
        fhir_r4.PractitionerRole.fromJson(resourceJson);

    return PractitionerRole(
      id: data.id,
      sourceId: data.sourceId ?? '',
      resourceId: data.resourceId ?? '',
      title: data.title ?? '',
      date: data.date,
      rawResource: resourceJson,
      encounterId: data.encounterId ?? '',
      subjectId: data.subjectId ?? '',
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

    final displayText =
        FhirFieldExtractor.extractFirstCodeableConceptFromArray(code);
    if (displayText != null) return displayText;

    return fhirType.display;
  }

  @override
  List<RecordInfoLine> get additionalInfo {
    List<RecordInfoLine> infoLines = [];

    // Active Status
    final activeStatus = active?.valueBoolean;
    if (activeStatus != null) {
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createStatusLine(
            activeStatus ? 'Active' : 'Inactive',
            prefix: 'Status'),
      );
    }

    // Practitioner
    final practitionerDisplay = practitioner?.display?.valueString;
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createUserLine(practitionerDisplay,
          prefix: 'Practitioner'),
    );

    // Organization
    final organizationDisplay = organization?.display?.valueString;
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createOrganizationLine(organizationDisplay,
          prefix: 'Organization'),
    );

    // Role/Code
    final roleDisplay =
        FhirFieldExtractor.extractFirstCodeableConceptFromArray(code);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createStatusLine(roleDisplay, prefix: 'Role'),
    );

    // Specialty
    if (specialty != null && specialty!.isNotEmpty) {
      final specialtyDisplay = specialty!
          .map((s) => FhirFieldExtractor.extractCodeableConceptText(s))
          .where((s) => s != null && s.isNotEmpty)
          .take(3)
          .join(', ');
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createStatusLine(
            specialtyDisplay.isNotEmpty ? specialtyDisplay : null,
            prefix: 'Specialty'),
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
            prefix: 'Location'),
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
            prefix: 'Healthcare Service'),
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
        ResourceFieldMapper.createStatusLine(phone, prefix: 'Phone'),
      );

      final email = telecom!
          .where((t) => t.system?.valueString == 'email')
          .firstOrNull
          ?.value
          ?.valueString;
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createStatusLine(email, prefix: 'Email'),
      );
    }

    // Period
    final periodDisplay = FhirFieldExtractor.extractPeriodFormatted(period);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createDateLine(periodDisplay, prefix: 'Period'),
    );

    // Availability Exceptions
    final exceptionsDisplay = availabilityExceptions?.valueString;
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createNotesLine(exceptionsDisplay,
          prefix: 'Availability Notes'),
    );

    // Date (last updated)
    if (date != null) {
      infoLines.add(RecordInfoLine(
        icon: Assets.icons.calendar,
        info: 'Last Updated: ${DateFormat.yMMMMd().format(date!)}',
      ));
    }

    return infoLines;
  }

  @override
  List<String?> get resourceReferences {
    return {
      practitioner?.reference?.valueString,
      organization?.reference?.valueString,
      ...?location?.map((reference) => reference.reference?.valueString),
      ...?healthcareService
          ?.map((reference) => reference.reference?.valueString),
      ...?endpoint?.map((reference) => reference.reference?.valueString),
    }.where((reference) => reference != null).toList();
  }

  @override
  String get statusDisplay =>
      active?.valueBoolean == true ? 'Active' : 'Inactive';
}
