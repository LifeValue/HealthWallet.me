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
    final orgDetailsStartIndex = infoLines.length;

    // Type (Hospital, Insurance Company, Government, etc.)
    if (type != null && type!.isNotEmpty) {
      final typeDisplay = type!
          .map((t) => FhirFieldExtractor.extractCodeableConceptText(t))
          .where((t) => t != null && t.isNotEmpty)
          .join(', ');
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createCategoryLine(
            typeDisplay.isNotEmpty ? typeDisplay : null,
            prefix: 'Type'),
      );
    }

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

    // Add section header only if we added content
    if (infoLines.length > orgDetailsStartIndex) {
      infoLines.insert(orgDetailsStartIndex,
        ResourceFieldMapper.createSectionHeader('Organization Details'));
    }

    final contactInfoStartIndex = infoLines.length;

    // Address
    final addressDisplay =
        FhirFieldExtractor.formatFullAddress(address?.firstOrNull);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createLocationLine(addressDisplay, prefix: 'Address'),
    );

    // Telecom (phone/email/fax/url)
    if (telecom != null && telecom!.isNotEmpty) {
      // Phone
      final phone = telecom!
          .where((t) => t.system?.valueString == 'phone')
          .firstOrNull
          ?.value
          ?.valueString;
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createStatusLine(phone, prefix: 'Phone'),
      );

      // Email
      final email = telecom!
          .where((t) => t.system?.valueString == 'email')
          .firstOrNull
          ?.value
          ?.valueString;
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createStatusLine(email, prefix: 'Email'),
      );

      // Fax
      final fax = telecom!
          .where((t) => t.system?.valueString == 'fax')
          .firstOrNull
          ?.value
          ?.valueString;
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createStatusLine(fax, prefix: 'Fax'),
      );

      // Website
      final url = telecom!
          .where((t) => t.system?.valueString == 'url')
          .firstOrNull
          ?.value
          ?.valueString;
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createStatusLine(url, prefix: 'Website'),
      );
    }

    // Organization Contact Persons
    if (contact != null && contact!.isNotEmpty) {
      for (final contactPerson in contact!) {
        final name = FhirFieldExtractor.extractHumanName(contactPerson.name);
        final purpose = FhirFieldExtractor.extractCodeableConceptText(
            contactPerson.purpose);
        
        String? contactDisplay = name;
        if (purpose != null && name != null) {
          contactDisplay = '$name ($purpose)';
        } else {
          contactDisplay = name ?? purpose;
        }
        
        ResourceFieldMapper.addIfNotNull(
          infoLines,
          ResourceFieldMapper.createUserLine(contactDisplay,
              prefix: 'Contact Person'),
        );

        // Contact person's telecom
        if (contactPerson.telecom != null && contactPerson.telecom!.isNotEmpty) {
          final contactPhone = contactPerson.telecom!
              .where((t) => t.system?.valueString == 'phone')
              .firstOrNull
              ?.value
              ?.valueString;
          if (contactPhone != null) {
            ResourceFieldMapper.addIfNotNull(
              infoLines,
              ResourceFieldMapper.createStatusLine(contactPhone,
                  prefix: '  Contact Phone'),
            );
          }

          final contactEmail = contactPerson.telecom!
              .where((t) => t.system?.valueString == 'email')
              .firstOrNull
              ?.value
              ?.valueString;
          if (contactEmail != null) {
            ResourceFieldMapper.addIfNotNull(
              infoLines,
              ResourceFieldMapper.createStatusLine(contactEmail,
                  prefix: '  Contact Email'),
            );
          }
        }
      }
    }

    // Add section header only if we added content
    if (infoLines.length > contactInfoStartIndex) {
      infoLines.insert(contactInfoStartIndex,
        ResourceFieldMapper.createSectionHeader('Contact Information'));
    }

    final additionalInfoStartIndex = infoLines.length;

    // Alias (Also Known As)
    if (alias != null && alias!.isNotEmpty) {
      final aliasText = alias!
          .map((a) => a.valueString)
          .where((a) => a != null && a.isNotEmpty)
          .join(', ');
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createStatusLine(
            aliasText.isNotEmpty ? aliasText : null,
            prefix: 'Also Known As'),
      );
    }

    // Part Of (parent organization)
    final partOfDisplay = FhirFieldExtractor.extractReferenceDisplay(partOf);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createOrganizationLine(partOfDisplay,
          prefix: 'Part Of'),
    );

    // Endpoints (technical connections)
    if (endpoint != null && endpoint!.isNotEmpty) {
      final endpointDisplay = endpoint!
          .map((e) => FhirFieldExtractor.extractReferenceDisplay(e))
          .where((e) => e != null && e.isNotEmpty)
          .take(3)
          .join(', ');
      
      if (endpointDisplay.isNotEmpty) {
        final suffix = endpoint!.length > 3 ? ' (${endpoint!.length - 3} more)' : '';
        ResourceFieldMapper.addIfNotNull(
          infoLines,
          ResourceFieldMapper.createStatusLine(endpointDisplay + suffix,
              prefix: 'Endpoints'),
        );
      }
    }

    // Add section header only if we added content
    if (infoLines.length > additionalInfoStartIndex) {
      infoLines.insert(additionalInfoStartIndex,
        ResourceFieldMapper.createSectionHeader('Additional Information'));
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
