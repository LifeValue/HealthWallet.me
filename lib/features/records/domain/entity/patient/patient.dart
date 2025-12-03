import 'dart:convert';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:fhir_r4/fhir_r4.dart' as fhir_r4;
import 'package:fhir_r4/fhir_r4.dart';
import 'package:health_wallet/features/records/domain/entity/i_fhir_resource.dart';
import 'package:health_wallet/core/data/local/app_database.dart';
import 'package:health_wallet/features/records/domain/utils/fhir_field_extractor.dart';
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

  factory Patient.fromDto(FhirResourceDto dto) {
    final resourceJson = dto.resourceRaw ?? {};

    // Clean up problematic Epic-specific fields that cause parsing errors
    _cleanEpicExtensions(resourceJson);

    final fhirPatient = fhir_r4.Patient.fromJson(resourceJson);

    return Patient(
      id: dto.id ?? '',
      sourceId: dto.sourceId ?? '',
      resourceId: dto.resourceId ?? '',
      title: dto.title ?? '',
      date: dto.date,
      rawResource: resourceJson,
      encounterId: dto.encounterId ?? '',
      subjectId: dto.subjectId ?? '',
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

    final genderDisplay = gender?.display?.valueString;
    if (genderDisplay != null) {
      infoLines.add(RecordInfoLine(
        icon: Assets.icons.information,
        info: genderDisplay,
      ));
    }

    final addressDisplay =
        FhirFieldExtractor.formatAddress(address?.firstOrNull);
    if (addressDisplay != null) {
      infoLines.add(RecordInfoLine(
        icon: Assets.icons.identification,
        info: addressDisplay,
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
