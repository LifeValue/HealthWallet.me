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

part 'patient.freezed.dart';

@freezed
class Patient with _$Patient implements IFhirResource {
  const Patient._();

  const factory Patient({
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
    AdministrativeGender? gender,
    FhirDate? birthDate,
    DeceasedXPatient? deceasedX,
    List<Address>? address,
    CodeableConcept? maritalStatus,
    MultipleBirthXPatient? multipleBirthX,
    List<Attachment>? photo,
    List<PatientContact>? contact,
    List<PatientCommunication>? communication,
    List<Reference>? generalPractitioner,
    Reference? managingOrganization,
    List<PatientLink>? link,
  }) = _Patient;

  @override
  FhirType get fhirType => FhirType.Patient;

  factory Patient.fromLocalData(FhirResourceLocalDto data) {
    final resourceJson = jsonDecode(data.resourceRaw);

    // Clean up problematic Epic-specific fields that cause parsing errors
    _cleanEpicExtensions(resourceJson);

    final fhirPatient = fhir_r4.Patient.fromJson(resourceJson);

    return Patient(
      id: data.id,
      sourceId: data.sourceId ?? '',
      resourceId: data.resourceId ?? '',
      title: data.title ?? '',
      date: data.date,
      rawResource: resourceJson,
      encounterId: data.encounterId ?? '',
      subjectId: data.subjectId ?? '',
      text: fhirPatient.text,
      identifier: fhirPatient.identifier,
      active: fhirPatient.active,
      name: fhirPatient.name,
      telecom: fhirPatient.telecom,
      gender: fhirPatient.gender,
      birthDate: fhirPatient.birthDate,
      deceasedX: fhirPatient.deceasedX,
      address: fhirPatient.address,
      maritalStatus: fhirPatient.maritalStatus,
      multipleBirthX: fhirPatient.multipleBirthX,
      photo: fhirPatient.photo,
      contact: fhirPatient.contact,
      communication: fhirPatient.communication,
      generalPractitioner: fhirPatient.generalPractitioner,
      managingOrganization: fhirPatient.managingOrganization,
      link: fhirPatient.link,
    );
  }

  @override
  FhirResourceDto toDto() => FhirResourceDto(
        id: id,
        sourceId: sourceId,
        resourceType: 'Patient',
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
      final patientName = name!.first;
      final humanName = FhirFieldExtractor.extractHumanName(patientName);
      if (humanName != null) return humanName;
    }

    return fhirType.display;
  }

  @override
  List<RecordInfoLine> get additionalInfo {
    List<RecordInfoLine> infoLines = [];

    // ============================================
    // BASIC INFORMATION SECTION
    // ============================================
    infoLines.add(ResourceFieldMapper.createSectionHeader('Basic Information'));

    // Date of Birth
    final parsedBirthDate = FhirFieldExtractor.extractPatientBirthDate(this);
    if (parsedBirthDate != null) {
      infoLines.add(RecordInfoLine(
        icon: Assets.icons.calendar,
        info: 'Date of Birth: ${DateFormat.yMMMd().format(parsedBirthDate)}',
      ));
    }

    // Age (calculated from birth date)
    final age = FhirFieldExtractor.calculateAge(parsedBirthDate);
    if (age != null) {
      infoLines.add(RecordInfoLine(
        icon: Assets.icons.information,
        info: 'Age: $age',
      ));
    }

    // Gender
    final genderDisplay = FhirFieldExtractor.extractPatientGender(this);
    if (genderDisplay != 'Unknown') {
      infoLines.add(RecordInfoLine(
        icon: genderDisplay.toLowerCase() == 'male'
            ? Assets.icons.genderMale
            : genderDisplay.toLowerCase() == 'female'
                ? Assets.icons.genderFemale
                : Assets.icons.user,
        info: 'Gender: $genderDisplay',
      ));
    }

    // Birth Sex (from US Core extension)
    final birthSex = FhirFieldExtractor.extractExtensionValue(rawResource,
        'http://hl7.org/fhir/us/core/StructureDefinition/us-core-birthsex');
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createStatusLine(birthSex, prefix: 'Birth Sex'),
    );

    // Marital Status
    final maritalStatusDisplay =
        FhirFieldExtractor.extractCodeableConceptText(maritalStatus);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createStatusLine(maritalStatusDisplay,
          prefix: 'Marital Status'),
    );

    // Race (from US Core extension)
    final race = FhirFieldExtractor.extractRaceOrEthnicity(rawResource,
        'http://hl7.org/fhir/us/core/StructureDefinition/us-core-race');
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createStatusLine(race, prefix: 'Race'),
    );

    // Ethnicity (from US Core extension)
    final ethnicity = FhirFieldExtractor.extractRaceOrEthnicity(rawResource,
        'http://hl7.org/fhir/us/core/StructureDefinition/us-core-ethnicity');
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createStatusLine(ethnicity, prefix: 'Ethnicity'),
    );

    // ============================================
    // CONTACT INFORMATION SECTION
    // ============================================
    infoLines
        .add(ResourceFieldMapper.createSectionHeader('Contact Information'));

    // Full Address
    final fullAddress =
        FhirFieldExtractor.formatFullAddress(address?.firstOrNull);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createLocationLine(fullAddress, prefix: 'Address'),
    );

    // Phone numbers (with use type)
    final phones =
        FhirFieldExtractor.extractAllTelecomBySystem(telecom, 'phone');
    for (final phone in phones) {
      final useLabel = phone['use']!.isNotEmpty ? ' (${phone['use']})' : '';
      infoLines.add(RecordInfoLine(
        icon: Assets.icons.information,
        info: 'Phone: ${phone['value']}$useLabel',
      ));
    }

    // Email
    final email = FhirFieldExtractor.extractTelecomBySystem(telecom, 'email');
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createStatusLine(email, prefix: 'Email'),
    );

    // Communication/Languages
    final languages =
        FhirFieldExtractor.extractCommunicationLanguages(communication);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createStatusLine(languages, prefix: 'Language'),
    );

    // ============================================
    // ADDITIONAL INFORMATION SECTION
    // ============================================
    infoLines
        .add(ResourceFieldMapper.createSectionHeader('Additional Information'));

    // Mother's Maiden Name (from extension)
    final mothersMaidenName = FhirFieldExtractor.extractExtensionValue(
        rawResource,
        'http://hl7.org/fhir/StructureDefinition/patient-mothersMaidenName');
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createStatusLine(mothersMaidenName,
          prefix: "Mother's Maiden Name"),
    );

    // Birth Place (from extension)
    final birthPlace = FhirFieldExtractor.extractBirthPlace(rawResource);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createLocationLine(birthPlace, prefix: 'Birth Place'),
    );

    // Multiple Birth
    final multipleBirthDisplay =
        FhirFieldExtractor.extractMultipleBirth(multipleBirthX);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createStatusLine(multipleBirthDisplay,
          prefix: 'Multiple Birth'),
    );

    // ============================================
    // IDENTIFIERS SECTION
    // ============================================
    infoLines.add(ResourceFieldMapper.createSectionHeader('Identifiers'));

    // Medical Record Number (MR)
    final mrn = FhirFieldExtractor.extractIdentifierByType(identifier, 'MR');
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createIdentificationLine(mrn,
          prefix: 'Medical Record Number'),
    );

    // SSN
    final ssn = FhirFieldExtractor.extractIdentifierByType(identifier, 'SS') ??
        FhirFieldExtractor.extractIdentifierByType(identifier, 'SSN');
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createIdentificationLine(ssn, prefix: 'SSN'),
    );

    // Driver's License
    final driversLicense =
        FhirFieldExtractor.extractIdentifierByType(identifier, 'DL');
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createIdentificationLine(driversLicense,
          prefix: "Driver's License Number"),
    );

    // Passport Number
    final passport =
        FhirFieldExtractor.extractIdentifierByType(identifier, 'PPN');
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createIdentificationLine(passport,
          prefix: 'Passport Number'),
    );

    // Other Identifiers (show remaining ones)
    if (identifier != null) {
      final displayedTypes = {'MR', 'SS', 'SSN', 'DL', 'PPN'};
      for (final id in identifier!) {
        final typeCode = id.type?.coding?.firstOrNull?.code?.valueString;
        if (typeCode != null && !displayedTypes.contains(typeCode)) {
          final typeDisplay = id.type?.text?.valueString ??
              id.type?.coding?.firstOrNull?.display?.valueString ??
              typeCode;
          final value = id.value?.valueString;
          if (value != null) {
            infoLines.add(RecordInfoLine(
              icon: Assets.icons.identification,
              info: '$typeDisplay: $value',
            ));
          }
        }
      }
    }

    // ============================================
    // CARE TEAM SECTION
    // ============================================
    // General Practitioner
    if (generalPractitioner != null && generalPractitioner!.isNotEmpty) {
      final gpDisplay = FhirFieldExtractor.extractMultipleReferenceDisplays(
          generalPractitioner);
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createUserLine(gpDisplay,
            prefix: 'General Practitioner'),
      );
    }

    // Managing Organization
    final managingOrgDisplay =
        FhirFieldExtractor.extractReferenceDisplay(managingOrganization);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createOrganizationLine(managingOrgDisplay,
          prefix: 'Managing Organization'),
    );

    return infoLines;
  }

  @override
  List<String?> get resourceReferences {
    return {
      managingOrganization?.reference?.valueString,
      ...?generalPractitioner
          ?.map((reference) => reference.reference?.valueString),
    }.where((reference) => reference != null).toList();
  }

  @override
  String get statusDisplay =>
      active?.valueBoolean == true ? 'Active' : 'Inactive';

  /// Clean up Epic-specific extensions that cause FHIR parsing errors
  static void _cleanEpicExtensions(Map<String, dynamic> resourceJson) {
    // Remove problematic _given fields from name entries
    if (resourceJson['name'] is List) {
      final nameList = resourceJson['name'] as List;
      for (final name in nameList) {
        if (name is Map<String, dynamic>) {
          name.remove('_given');
        }
      }
    }
  }
}
