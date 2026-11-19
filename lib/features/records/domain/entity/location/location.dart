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

part 'location.freezed.dart';

@freezed
abstract class Location with _$Location implements IFhirResource {
  const Location._();

  const factory Location({
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
    LocationStatus? status,
    Coding? operationalStatus,
    FhirString? name,
    List<FhirString>? alias,
    FhirString? description,
    LocationMode? mode,
    List<CodeableConcept>? type,
    List<ContactPoint>? telecom,
    Address? address,
    CodeableConcept? physicalType,
    LocationPosition? position,
    Reference? managingOrganization,
    Reference? partOf,
    List<LocationHoursOfOperation>? hoursOfOperation,
    FhirString? availabilityExceptions,
    List<Reference>? endpoint,
  }) = _Location;

  @override
  FhirType get fhirType => FhirType.Location;

  factory Location.fromLocalData(FhirResourceLocalDto data) {
    final resourceJson = jsonDecode(data.resourceRaw);
    final fhirLocation = fhir_r4.Location.fromJson(resourceJson);

    return Location(
      id: data.id,
      sourceId: data.sourceId ?? '',
      resourceId: data.resourceId ?? '',
      title: data.title ?? '',
      date: data.date,
      rawResource: resourceJson,
      encounterId: data.encounterId ?? '',
      subjectId: data.subjectId ?? '',
      specialtyOverride: data.specialtyOverride,
      text: fhirLocation.text,
      identifier: fhirLocation.identifier,
      status: fhirLocation.status,
      operationalStatus: fhirLocation.operationalStatus,
      name: fhirLocation.name,
      alias: fhirLocation.alias,
      description: fhirLocation.description,
      mode: fhirLocation.mode,
      type: fhirLocation.type,
      telecom: fhirLocation.telecom,
      address: fhirLocation.address,
      physicalType: fhirLocation.physicalType,
      position: fhirLocation.position,
      managingOrganization: fhirLocation.managingOrganization,
      partOf: fhirLocation.partOf,
      hoursOfOperation: fhirLocation.hoursOfOperation,
      availabilityExceptions: fhirLocation.availabilityExceptions,
      endpoint: fhirLocation.endpoint,
    );
  }

  @override
  FhirResourceDto toDto() => FhirResourceDto(
    id: id,
    sourceId: sourceId,
    resourceType: 'Location',
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

    final locationName = name?.toString();
    if (locationName != null && locationName.isNotEmpty) return locationName;

    return fhirType.display;
  }

  @override
  List<RecordInfoLine> additionalInfo(AppLocalizations l10n) {
    final List<RecordInfoLine> infoLines = [];
    final facilityDetailsStartIndex = infoLines.length;

    // Type (Hospital, Clinic, etc. - CRITICAL)
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

    // Status (Active, Suspended, Inactive)
    final statusText = status?.valueString;
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createStatusLine(
        statusText,
        prefix: l10n.fieldStatus,
      ),
    );

    // Address (CRITICAL for patients)
    final addressDisplay = FhirFieldExtractor.formatFullAddress(address);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createLocationLine(
        addressDisplay,
        prefix: l10n.fieldAddress,
      ),
    );

    // Telecom - Phone (Main)
    if (telecom != null && telecom!.isNotEmpty) {
      // Main Phone
      final mainPhone = telecom!
          .where(
            (t) =>
                t.system?.valueString == 'phone' &&
                (t.use == null || t.use?.valueString != 'fax'),
          )
          .firstOrNull
          ?.value
          ?.valueString;
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createStatusLine(
          mainPhone,
          prefix: l10n.fieldPhone,
        ),
      );

      // Emergency Phone
      final emergencyPhone = telecom!
          .where(
            (t) =>
                t.system?.valueString == 'phone' &&
                t.use?.valueString == 'emergency',
          )
          .firstOrNull
          ?.value
          ?.valueString;
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createWarningLine(
          emergencyPhone,
          prefix: l10n.fieldEmergency,
        ),
      );
    }

    // Add section header only if we added content
    if (infoLines.length > facilityDetailsStartIndex) {
      infoLines.insert(
        facilityDetailsStartIndex,
        ResourceFieldMapper.createSectionHeader(l10n.fieldFacilityDetails),
      );
    }

    final basicInfoStartIndex = infoLines.length;

    // Operational Status (Operational, Closed, etc.)
    final operationalStatusDisplay = FhirFieldExtractor.extractCodingDisplay(
      operationalStatus,
    );
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createStatusLine(
        operationalStatusDisplay,
        prefix: l10n.fieldOperationalStatus,
      ),
    );

    // Mode (Instance, Kind)
    final modeDisplay = mode?.valueString;
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createStatusLine(modeDisplay, prefix: l10n.fieldMode),
    );

    // Physical Type (Building, Wing, Room, Bed, etc.)
    final physicalTypeDisplay = FhirFieldExtractor.extractCodeableConceptText(
      physicalType,
    );
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createCategoryLine(
        physicalTypeDisplay,
        prefix: l10n.fieldPhysicalType,
      ),
    );

    // Managing Organization
    final organizationDisplay = FhirFieldExtractor.extractReferenceDisplay(
      managingOrganization,
    );
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createOrganizationLine(
        organizationDisplay,
        prefix: l10n.fieldManagingOrganization,
      ),
    );

    // Part Of (parent location)
    final partOfDisplay = FhirFieldExtractor.extractReferenceDisplay(partOf);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createLocationLine(
        partOfDisplay,
        prefix: l10n.fieldPartOf,
      ),
    );

    // Add section header only if we added content
    if (infoLines.length > basicInfoStartIndex) {
      infoLines.insert(
        basicInfoStartIndex,
        ResourceFieldMapper.createSectionHeader(l10n.fieldBasicInformation),
      );
    }

    final additionalInfoStartIndex = infoLines.length;

    // Also Known As (Aliases)
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

    // Description
    final descriptionText = description?.valueString;
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createNotesLine(
        descriptionText,
        prefix: l10n.fieldDescription,
      ),
    );

    // Hours of Operation
    if (hoursOfOperation != null && hoursOfOperation!.isNotEmpty) {
      for (final hours in hoursOfOperation!) {
        final daysOfWeek = hours.daysOfWeek
            ?.map((d) => d.valueString)
            .where((d) => d != null)
            .join(', ');

        final allDay = hours.allDay?.valueBoolean;
        String? hoursDisplay;

        if (allDay == true) {
          hoursDisplay = '24/7';
        } else {
          final openingTime = hours.openingTime?.valueString;
          final closingTime = hours.closingTime?.valueString;
          if (openingTime != null && closingTime != null) {
            hoursDisplay = '$openingTime - $closingTime';
          }
        }

        final fullDisplay = daysOfWeek != null && hoursDisplay != null
            ? '$daysOfWeek: $hoursDisplay'
            : hoursDisplay ?? daysOfWeek;

        ResourceFieldMapper.addIfNotNull(
          infoLines,
          ResourceFieldMapper.createTimeLine(
            fullDisplay,
            prefix: l10n.fieldHours,
          ),
        );
      }
    }

    // GPS Coordinates
    if (position != null) {
      final latitude = position!.latitude.valueString;
      final longitude = position!.longitude.valueString;

      if (latitude != null && longitude != null) {
        // Parse to format as needed
        final latDouble = double.tryParse(latitude);
        final lonDouble = double.tryParse(longitude);

        final latDisplay = latDouble != null
            ? latDouble.toStringAsFixed(4)
            : latitude;
        final lonDisplay = lonDouble != null
            ? lonDouble.toStringAsFixed(4)
            : longitude;

        ResourceFieldMapper.addIfNotNull(
          infoLines,
          ResourceFieldMapper.createLocationLine(
            '$latDisplay° N, $lonDisplay° W',
            prefix: l10n.fieldGpsCoordinates,
          ),
        );
      }
    }

    // Additional Telecom
    if (telecom != null && telecom!.isNotEmpty) {
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

    // Availability Exceptions (e.g., holiday hours)
    final availabilityExceptionsText = availabilityExceptions?.valueString;
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createNotesLine(
        availabilityExceptionsText,
        prefix: l10n.fieldAvailabilityExceptions,
      ),
    );

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
      managingOrganization?.reference?.valueString,
      partOf?.reference?.valueString,
      ...?endpoint?.map((reference) => reference.reference?.valueString),
    }.where((reference) => reference != null).toList();
  }

  @override
  String get statusDisplay => status?.valueString ?? '';
}
