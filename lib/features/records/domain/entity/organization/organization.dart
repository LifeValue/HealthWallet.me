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

part 'organization.freezed.dart';

@freezed
class Organization with _$Organization implements IFhirResource {
  const Organization._();

  const factory Organization({
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
    List<CodeableConcept>? type,
    FhirString? name,
    List<FhirString>? alias,
    List<ContactPoint>? telecom,
    List<Address>? address,
    Reference? partOf,
    List<OrganizationContact>? contact,
    List<Reference>? endpoint,
  }) = _Organization;

  @override
  FhirType get fhirType => FhirType.Organization;

  factory Organization.fromLocalData(FhirResourceLocalDto data) {
    final resourceJson = jsonDecode(data.resourceRaw);
    final fhirOrganization = fhir_r4.Organization.fromJson(resourceJson);

    return Organization(
      id: data.id,
      sourceId: data.sourceId ?? '',
      resourceId: data.resourceId ?? '',
      title: data.title ?? '',
      date: data.date,
      rawResource: resourceJson,
      encounterId: data.encounterId ?? '',
      subjectId: data.subjectId ?? '',
      text: fhirOrganization.text,
      identifier: fhirOrganization.identifier,
      active: fhirOrganization.active,
      type: fhirOrganization.type,
      name: fhirOrganization.name,
      alias: fhirOrganization.alias,
      telecom: fhirOrganization.telecom,
      address: fhirOrganization.address,
      partOf: fhirOrganization.partOf,
      contact: fhirOrganization.contact,
      endpoint: fhirOrganization.endpoint,
    );
  }

  @override
  FhirResourceDto toDto() => FhirResourceDto(
        id: id,
        sourceId: sourceId,
        resourceType: 'Organization',
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

    final organizationName = name?.toString();
    if (organizationName != null && organizationName.isNotEmpty) {
      return organizationName;
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

    // Type
    final typeDisplay =
        FhirFieldExtractor.extractFirstCodeableConceptFromArray(type);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createCategoryLine(typeDisplay, prefix: 'Type'),
    );

    // Address
    final addressDisplay =
        FhirFieldExtractor.formatAddress(address?.firstOrNull);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createLocationLine(addressDisplay, prefix: 'Address'),
    );

    // Part Of (parent organization)
    final partOfDisplay = FhirFieldExtractor.extractReferenceDisplay(partOf);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createOrganizationLine(partOfDisplay,
          prefix: 'Part Of'),
    );

    // Telecom (phone/email)
    if (telecom != null && telecom!.isNotEmpty) {
      final phone = telecom!
          .where((t) => t.system?.valueString == 'phone')
          .firstOrNull
          ?.value
          ?.toString();
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createStatusLine(phone, prefix: 'Phone'),
      );

      final email = telecom!
          .where((t) => t.system?.valueString == 'email')
          .firstOrNull
          ?.value
          ?.toString();
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createStatusLine(email, prefix: 'Email'),
      );
    }

    // Alias
    if (alias != null && alias!.isNotEmpty) {
      final aliasText = alias!.map((a) => a.toString()).join(', ');
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createStatusLine(aliasText, prefix: 'Alias'),
      );
    }

    // Date
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
      partOf?.reference?.valueString,
      ...?endpoint?.map((reference) => reference.reference?.valueString),
    }.where((reference) => reference != null).toList();
  }

  @override
  String get statusDisplay =>
      active?.valueBoolean == true ? 'Active' : 'Inactive';
}
