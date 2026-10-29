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

part 'organization.freezed.dart';

@freezed
abstract class Organization with _$Organization implements IFhirResource {
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
    String? specialtyOverride,
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
      specialtyOverride: data.specialtyOverride,
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
  List<RecordInfoLine> additionalInfo(AppLocalizations l10n) {
    final List<RecordInfoLine> infoLines = [];
    final orgDetailsStartIndex = infoLines.length;

    // Type (Hospital, Insurance Company, Government, etc.)
    if (type != null && type!.isNotEmpty) {
      final typeDisplay = type!
          .map(FhirFieldExtractor.extractCodeableConceptText)
          .where((t) => t != null && t.isNotEmpty)
          .join(', ');
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createCategoryLine(
          typeDisplay.isNotEmpty ? typeDisplay : null,
          prefix: l10n.fieldType,
        ),
      );
    }

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

    // Add section header only if we added content
    if (infoLines.length > orgDetailsStartIndex) {
      infoLines.insert(
        orgDetailsStartIndex,
        ResourceFieldMapper.createSectionHeader(l10n.fieldOrganizationDetails),
      );
    }

    final contactInfoStartIndex = infoLines.length;

    // Address
    final addressDisplay = FhirFieldExtractor.formatFullAddress(
      address?.firstOrNull,
    );
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createLocationLine(
        addressDisplay,
        prefix: l10n.fieldAddress,
      ),
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
        ResourceFieldMapper.createStatusLine(phone, prefix: l10n.fieldPhone),
      );

      // Email
      final email = telecom!
          .where((t) => t.system?.valueString == 'email')
          .firstOrNull
          ?.value
          ?.valueString;
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createStatusLine(email, prefix: l10n.fieldEmail),
      );

      // Fax
      final fax = telecom!
          .where((t) => t.system?.valueString == 'fax')
          .firstOrNull
          ?.value
          ?.valueString;
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createStatusLine(fax, prefix: l10n.fieldFax),
      );

      // Website
      final url = telecom!
          .where((t) => t.system?.valueString == 'url')
          .firstOrNull
          ?.value
          ?.valueString;
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createStatusLine(url, prefix: l10n.fieldWebsite),
      );
    }

    // Organization Contact Persons
    if (contact != null && contact!.isNotEmpty) {
      for (final contactPerson in contact!) {
        final name = FhirFieldExtractor.extractHumanName(contactPerson.name);
        final purpose = FhirFieldExtractor.extractCodeableConceptText(
          contactPerson.purpose,
        );

        String? contactDisplay = name;
        if (purpose != null && name != null) {
          contactDisplay = '$name ($purpose)';
        } else {
          contactDisplay = name ?? purpose;
        }

        ResourceFieldMapper.addIfNotNull(
          infoLines,
          ResourceFieldMapper.createUserLine(
            contactDisplay,
            prefix: l10n.fieldContactPerson,
          ),
        );

        // Contact person's telecom
        if (contactPerson.telecom != null &&
            contactPerson.telecom!.isNotEmpty) {
          final contactPhone = contactPerson.telecom!
              .where((t) => t.system?.valueString == 'phone')
              .firstOrNull
              ?.value
              ?.valueString;
          if (contactPhone != null) {
            ResourceFieldMapper.addIfNotNull(
              infoLines,
              ResourceFieldMapper.createStatusLine(
                contactPhone,
                prefix: '  ${l10n.fieldContactPhone}',
              ),
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
              ResourceFieldMapper.createStatusLine(
                contactEmail,
                prefix: '  ${l10n.fieldContactEmail}',
              ),
            );
          }
        }
      }
    }

    // Add section header only if we added content
    if (infoLines.length > contactInfoStartIndex) {
      infoLines.insert(
        contactInfoStartIndex,
        ResourceFieldMapper.createSectionHeader(l10n.fieldContactInformation),
      );
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
          prefix: l10n.fieldAlsoKnownAs,
        ),
      );
    }

    // Part Of (parent organization)
    final partOfDisplay = FhirFieldExtractor.extractReferenceDisplay(partOf);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createOrganizationLine(
        partOfDisplay,
        prefix: l10n.fieldPartOf,
      ),
    );

    // Endpoints (technical connections)
    if (endpoint != null && endpoint!.isNotEmpty) {
      final endpointDisplay = endpoint!
          .map(FhirFieldExtractor.extractReferenceDisplay)
          .where((e) => e != null && e.isNotEmpty)
          .take(3)
          .join(', ');

      if (endpointDisplay.isNotEmpty) {
        final suffix = endpoint!.length > 3
            ? ' (${l10n.moreCount(endpoint!.length - 3)})'
            : '';
        ResourceFieldMapper.addIfNotNull(
          infoLines,
          ResourceFieldMapper.createStatusLine(
            endpointDisplay + suffix,
            prefix: l10n.fieldEndpoints,
          ),
        );
      }
    }

    // Add section header only if we added content
    if (infoLines.length > additionalInfoStartIndex) {
      infoLines.insert(
        additionalInfoStartIndex,
        ResourceFieldMapper.createSectionHeader(
          l10n.fieldAdditionalInformation,
        ),
      );
    }

    // Date
    if (date != null) {
      infoLines.add(
        RecordInfoLine(
          icon: Assets.icons.calendar,
          info: FhirFieldExtractor.formatRecordDate(date!, l10n.localeName),
        ),
      );
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
