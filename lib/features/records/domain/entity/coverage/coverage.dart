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

part 'coverage.freezed.dart';

@freezed
class Coverage with _$Coverage implements IFhirResource {
  const Coverage._();

  const factory Coverage({
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
    String? status,
    CodeableConcept? type,
    Reference? policyHolder,
    Reference? subscriber,
    FhirString? subscriberId,
    Reference? beneficiary,
    FhirString? dependent,
    CodeableConcept? relationship,
    Period? period,
    List<Reference>? payor,
    List<fhir_r4.CoverageClass>? class_,
    FhirPositiveInt? order,
    FhirString? network,
    List<fhir_r4.CoverageCostToBeneficiary>? costToBeneficiary,
    FhirBoolean? subrogation,
    List<Reference>? contract,
  }) = _Coverage;

  @override
  FhirType get fhirType => FhirType.Coverage;

  factory Coverage.fromLocalData(FhirResourceLocalDto data) {
    final resourceJson = jsonDecode(data.resourceRaw);
    final fhirCoverage = fhir_r4.Coverage.fromJson(resourceJson);

    return Coverage(
      id: data.id,
      sourceId: data.sourceId ?? '',
      resourceId: data.resourceId ?? '',
      title: data.title ?? '',
      date: data.date,
      rawResource: resourceJson,
      encounterId: data.encounterId ?? '',
      subjectId: data.subjectId ?? '',
      text: fhirCoverage.text,
      identifier: fhirCoverage.identifier,
      status: fhirCoverage.status.toString(),
      type: fhirCoverage.type,
      policyHolder: fhirCoverage.policyHolder,
      subscriber: fhirCoverage.subscriber,
      subscriberId: fhirCoverage.subscriberId,
      beneficiary: fhirCoverage.beneficiary,
      dependent: fhirCoverage.dependent,
      relationship: fhirCoverage.relationship,
      period: fhirCoverage.period,
      payor: fhirCoverage.payor,
      class_: fhirCoverage.class_,
      order: fhirCoverage.order,
      network: fhirCoverage.network,
      costToBeneficiary: fhirCoverage.costToBeneficiary,
      subrogation: fhirCoverage.subrogation,
      contract: fhirCoverage.contract,
    );
  }

  @override
  FhirResourceDto toDto() => FhirResourceDto(
        id: id,
        sourceId: sourceId,
        resourceType: 'Coverage',
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

    final displayText = FhirFieldExtractor.extractCodeableConceptText(type);
    if (displayText != null) return displayText;

    return fhirType.display;
  }

  @override
  List<RecordInfoLine> get additionalInfo {
    List<RecordInfoLine> infoLines = [];

    // Status
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createStatusLine(status, prefix: 'Status'),
    );

    // Type
    final typeDisplay = FhirFieldExtractor.extractCodeableConceptText(type);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createCategoryLine(typeDisplay, prefix: 'Type'),
    );

    // Payor
    final payorDisplay =
        FhirFieldExtractor.extractMultipleReferenceDisplays(payor);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createOrganizationLine(payorDisplay, prefix: 'Payor'),
    );

    // Policy Holder
    final policyHolderDisplay =
        FhirFieldExtractor.extractReferenceDisplay(policyHolder);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createUserLine(policyHolderDisplay,
          prefix: 'Policy Holder'),
    );

    // Subscriber
    final subscriberDisplay =
        FhirFieldExtractor.extractReferenceDisplay(subscriber);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createUserLine(subscriberDisplay,
          prefix: 'Subscriber'),
    );

    // Subscriber ID
    final subscriberIdText = subscriberId?.valueString;
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createIdentificationLine(subscriberIdText,
          prefix: 'Subscriber ID'),
    );

    // Beneficiary
    final beneficiaryDisplay =
        FhirFieldExtractor.extractReferenceDisplay(beneficiary);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createUserLine(beneficiaryDisplay,
          prefix: 'Beneficiary'),
    );

    // Relationship
    final relationshipDisplay =
        FhirFieldExtractor.extractCodeableConceptText(relationship);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createStatusLine(relationshipDisplay,
          prefix: 'Relationship'),
    );

    // Period
    final periodDisplay = FhirFieldExtractor.extractPeriod(period);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createTimelineLine(periodDisplay, prefix: 'Period'),
    );

    // Network
    final networkText = network?.valueString;
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createStatusLine(networkText, prefix: 'Network'),
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
      policyHolder?.reference?.valueString,
      subscriber?.reference?.valueString,
      beneficiary?.reference?.valueString,
      ...?payor?.map((reference) => reference.reference?.valueString),
      ...?contract?.map((reference) => reference.reference?.valueString),
    }.where((reference) => reference != null).toList();
  }

  @override
  String get statusDisplay => status ?? '';
}
