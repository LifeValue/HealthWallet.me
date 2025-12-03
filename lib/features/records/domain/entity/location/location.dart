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

part 'location.freezed.dart';

@freezed
class Location with _$Location implements IFhirResource {
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
  List<RecordInfoLine> get additionalInfo {
    List<RecordInfoLine> infoLines = [];

    // Status
    final statusText = status?.valueString;
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createStatusLine(statusText, prefix: 'Status'),
    );

    // Operational Status
    final operationalStatusDisplay =
        FhirFieldExtractor.extractCodingDisplay(operationalStatus);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createStatusLine(operationalStatusDisplay,
          prefix: 'Operational Status'),
    );

    // Mode
    final modeDisplay = mode?.valueString;
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createStatusLine(modeDisplay, prefix: 'Mode'),
    );

    // Type
    final typeDisplay =
        FhirFieldExtractor.extractFirstCodeableConceptFromArray(type);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createCategoryLine(typeDisplay, prefix: 'Type'),
    );

    // Physical Type
    final physicalTypeDisplay =
        FhirFieldExtractor.extractCodeableConceptText(physicalType);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createCategoryLine(physicalTypeDisplay,
          prefix: 'Physical Type'),
    );

    // Managing Organization
    final organizationDisplay =
        FhirFieldExtractor.extractReferenceDisplay(managingOrganization);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createOrganizationLine(organizationDisplay,
          prefix: 'Organization'),
    );

    // Address
    final addressDisplay = FhirFieldExtractor.formatAddress(address);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createLocationLine(addressDisplay, prefix: 'Address'),
    );

    // Description
    final descriptionText = description?.valueString;
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createNotesLine(descriptionText,
          prefix: 'Description'),
    );

    // Part Of (parent location)
    final partOfDisplay = FhirFieldExtractor.extractReferenceDisplay(partOf);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createLocationLine(partOfDisplay, prefix: 'Part Of'),
    );

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
      managingOrganization?.reference?.valueString,
      partOf?.reference?.valueString,
      ...?endpoint?.map((reference) => reference.reference?.valueString),
    }.where((reference) => reference != null).toList();
  }

  @override
  String get statusDisplay => status?.valueString ?? '';
}
