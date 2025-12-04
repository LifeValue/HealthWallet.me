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

part 'practitioner.freezed.dart';

@freezed
class Practitioner with _$Practitioner implements IFhirResource {
  const Practitioner._();

  const factory Practitioner({
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
    List<HumanName>? name,
    List<ContactPoint>? telecom,
    List<Address>? address,
    AdministrativeGender? gender,
    FhirDate? birthDate,
    List<PractitionerQualification>? qualification,
    List<CodeableConcept>? communication,
  }) = _Practitioner;

  @override
  FhirType get fhirType => FhirType.Practitioner;

  factory Practitioner.fromLocalData(FhirResourceLocalDto data) {
    final resourceJson = jsonDecode(data.resourceRaw);
    final fhirPractitioner = fhir_r4.Practitioner.fromJson(resourceJson);

    return Practitioner(
      id: data.id,
      sourceId: data.sourceId ?? '',
      resourceId: data.resourceId ?? '',
      title: data.title ?? '',
      date: data.date,
      rawResource: resourceJson,
      encounterId: data.encounterId ?? '',
      subjectId: data.subjectId ?? '',
      text: fhirPractitioner.text,
      identifier: fhirPractitioner.identifier,
      active: fhirPractitioner.active,
      name: fhirPractitioner.name,
      telecom: fhirPractitioner.telecom,
      address: fhirPractitioner.address,
      gender: fhirPractitioner.gender,
      birthDate: fhirPractitioner.birthDate,
      qualification: fhirPractitioner.qualification,
      communication: fhirPractitioner.communication,
    );
  }

  @override
  FhirResourceDto toDto() => FhirResourceDto(
        id: id,
        sourceId: sourceId,
        resourceType: 'Practitioner',
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
      final practitionerName = name!.first;
      final humanName = FhirFieldExtractor.extractHumanName(practitionerName);
      if (humanName != null) return humanName;
    }

    return fhirType.display;
  }

  @override
  List<RecordInfoLine> get additionalInfo {
    List<RecordInfoLine> infoLines = [];
    final professionalInfoStartIndex = infoLines.length;

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

    // Qualification
    if (qualification != null && qualification!.isNotEmpty) {
      for (final qual in qualification!) {
        final qualCode = FhirFieldExtractor.extractCodeableConceptText(qual.code);
        final issuer = FhirFieldExtractor.extractReferenceDisplay(qual.issuer);
        final period = FhirFieldExtractor.extractPeriodFormatted(qual.period);
        
        String? qualDisplay = qualCode;
        if (issuer != null && qualCode != null) {
          qualDisplay = '$qualCode (issued by $issuer)';
        }
        if (period != null && qualDisplay != null) {
          qualDisplay = '$qualDisplay - Valid: $period';
        }
        
        ResourceFieldMapper.addIfNotNull(
          infoLines,
          ResourceFieldMapper.createStatusLine(qualDisplay, prefix: 'Qualification'),
        );
      }
    }

    // Gender
    final genderDisplay = gender?.display?.valueString;
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createStatusLine(genderDisplay, prefix: 'Gender'),
    );

    // Communication/Languages
    if (communication != null && communication!.isNotEmpty) {
      final languages = communication!
          .map((c) => FhirFieldExtractor.extractCodeableConceptText(c))
          .where((l) => l != null && l.isNotEmpty)
          .join(', ');
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createStatusLine(
            languages.isNotEmpty ? languages : null,
            prefix: 'Languages'),
      );
    }

    // Add section header only if we added content
    if (infoLines.length > professionalInfoStartIndex) {
      infoLines.insert(professionalInfoStartIndex,
        ResourceFieldMapper.createSectionHeader('Professional Information'));
    }

    final contactInfoStartIndex = infoLines.length;

    // Address
    final addressDisplay =
        FhirFieldExtractor.formatAddress(address?.firstOrNull);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createLocationLine(addressDisplay, prefix: 'Address'),
    );

    // Telecom (phone/email)
    if (telecom != null && telecom!.isNotEmpty) {
      // Phone
      final phone = telecom!
          .where((t) => t.system?.valueString == 'phone')
          .firstOrNull
          ?.value
          ?.toString();
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createStatusLine(phone, prefix: 'Phone'),
      );

      // Email
      final email = telecom!
          .where((t) => t.system?.valueString == 'email')
          .firstOrNull
          ?.value
          ?.toString();
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createStatusLine(email, prefix: 'Email'),
      );

      // Fax
      final fax = telecom!
          .where((t) => t.system?.valueString == 'fax')
          .firstOrNull
          ?.value
          ?.toString();
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createStatusLine(fax, prefix: 'Fax'),
      );
    }

    // Add section header only if we added content
    if (infoLines.length > contactInfoStartIndex) {
      infoLines.insert(contactInfoStartIndex,
        ResourceFieldMapper.createSectionHeader('Contact Information'));
    }

    final additionalInfoStartIndex = infoLines.length;

    // Birth Date
    final birthDateDisplay = birthDate?.valueString;
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createDateLine(birthDateDisplay, prefix: 'Birth Date'),
    );

    // Date
    if (date != null) {
      infoLines.add(RecordInfoLine(
        icon: Assets.icons.calendar,
        info: DateFormat.yMMMMd().format(date!),
      ));
    }

    // Add section header only if we added content
    if (infoLines.length > additionalInfoStartIndex) {
      infoLines.insert(additionalInfoStartIndex,
        ResourceFieldMapper.createSectionHeader('Additional Information'));
    }

    return infoLines;
  }

  @override
  List<String> get resourceReferences => [];

  @override
  String get statusDisplay =>
      active?.valueBoolean == true ? 'Active' : 'Inactive';
}
