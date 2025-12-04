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

part 'related_person.freezed.dart';

@freezed
class RelatedPerson with _$RelatedPerson implements IFhirResource {
  const RelatedPerson._();

  const factory RelatedPerson({
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
    Reference? patient,
    List<CodeableConcept>? relationship,
    List<HumanName>? name,
    List<ContactPoint>? telecom,
    AdministrativeGender? gender,
    FhirDate? birthDate,
    List<Address>? address,
    List<Attachment>? photo,
    Period? period,
    List<RelatedPersonCommunication>? communication,
  }) = _RelatedPerson;

  @override
  FhirType get fhirType => FhirType.RelatedPerson;

  factory RelatedPerson.fromLocalData(FhirResourceLocalDto data) {
    final resourceJson = jsonDecode(data.resourceRaw);
    final fhirRelatedPerson = fhir_r4.RelatedPerson.fromJson(resourceJson);

    return RelatedPerson(
      id: data.id,
      sourceId: data.sourceId ?? '',
      resourceId: data.resourceId ?? '',
      title: data.title ?? '',
      date: data.date,
      rawResource: resourceJson,
      encounterId: data.encounterId ?? '',
      subjectId: data.subjectId ?? '',
      text: fhirRelatedPerson.text,
      identifier: fhirRelatedPerson.identifier,
      active: fhirRelatedPerson.active,
      patient: fhirRelatedPerson.patient,
      relationship: fhirRelatedPerson.relationship,
      name: fhirRelatedPerson.name,
      telecom: fhirRelatedPerson.telecom,
      gender: fhirRelatedPerson.gender,
      birthDate: fhirRelatedPerson.birthDate,
      address: fhirRelatedPerson.address,
      photo: fhirRelatedPerson.photo,
      period: fhirRelatedPerson.period,
      communication: fhirRelatedPerson.communication,
    );
  }

  @override
  FhirResourceDto toDto() => FhirResourceDto(
        id: id,
        sourceId: sourceId,
        resourceType: 'RelatedPerson',
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

    if (name?.isNotEmpty == true) {
      final personName = name!.first;
      final humanName = FhirFieldExtractor.extractHumanName(personName);
      if (humanName != null) return humanName;
    }

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

    // Relationship
    if (relationship != null && relationship!.isNotEmpty) {
      final relationDisplay = relationship!
          .map((r) => FhirFieldExtractor.extractCodeableConceptText(r))
          .where((r) => r != null && r.isNotEmpty)
          .join(', ');
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createStatusLine(
            relationDisplay.isNotEmpty ? relationDisplay : null,
            prefix: 'Relationship'),
      );
    }

    // Patient Reference
    final patientDisplay = patient?.display?.valueString;
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createUserLine(patientDisplay, prefix: 'Patient'),
    );

    // Gender
    final genderDisplay = gender?.display?.valueString;
    if (genderDisplay != null) {
      infoLines.add(RecordInfoLine(
        icon: genderDisplay.toLowerCase() == 'male'
            ? Assets.icons.genderMale
            : genderDisplay.toLowerCase() == 'female'
                ? Assets.icons.genderFemale
                : Assets.icons.user,
        info: 'Gender: $genderDisplay',
      ));
    }

    // Birth Date
    if (birthDate != null) {
      final birthDateValue = birthDate?.valueString;
      if (birthDateValue != null) {
        try {
          final parsedDate = DateTime.parse(birthDateValue);
          infoLines.add(RecordInfoLine(
            icon: Assets.icons.calendar,
            info: 'Birth Date: ${DateFormat.yMMMMd().format(parsedDate)}',
          ));
        } catch (_) {
          // Use raw string if parsing fails
          infoLines.add(RecordInfoLine(
            icon: Assets.icons.calendar,
            info: 'Birth Date: $birthDateValue',
          ));
        }
      }
    }

    // Address
    final addressDisplay =
        FhirFieldExtractor.formatAddress(address?.firstOrNull);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createLocationLine(addressDisplay, prefix: 'Address'),
    );

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

    // Communication/Languages
    if (communication != null && communication!.isNotEmpty) {
      final languages = communication!
          .map((c) => FhirFieldExtractor.extractCodeableConceptText(c.language))
          .where((l) => l != null && l.isNotEmpty)
          .join(', ');
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createStatusLine(
            languages.isNotEmpty ? languages : null,
            prefix: 'Languages'),
      );
    }

    // Period
    final periodDisplay = FhirFieldExtractor.extractPeriodFormatted(period);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createDateLine(periodDisplay, prefix: 'Period'),
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
      patient?.reference?.valueString,
    }.where((reference) => reference != null).toList();
  }

  @override
  String get statusDisplay =>
      active?.valueBoolean == true ? 'Active' : 'Inactive';
}
