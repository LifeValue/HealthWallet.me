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

part 'claim.freezed.dart';

@freezed
class Claim with _$Claim implements IFhirResource {
  const Claim._();

  const factory Claim({
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
    FinancialResourceStatusCodes? status,
    CodeableConcept? type,
    CodeableConcept? subType,
    Use? use,
    Reference? patient,
    Period? billablePeriod,
    FhirDateTime? created,
    Reference? enterer,
    Reference? insurer,
    Reference? provider,
    CodeableConcept? priority,
    CodeableConcept? fundsReserve,
    List<ClaimRelated>? related,
    ClaimPayee? payee,
    Reference? referral,
    Reference? facility,
    List<ClaimCareTeam>? careTeam,
    List<ClaimSupportingInfo>? supportingInfo,
    List<ClaimDiagnosis>? diagnosis,
    List<ClaimProcedure>? procedure,
    List<ClaimInsurance>? insurance,
    ClaimAccident? accident,
    List<ClaimItem>? item,
    Money? total,
  }) = _Claim;

  @override
  FhirType get fhirType => FhirType.Claim;

  factory Claim.fromLocalData(FhirResourceLocalDto data) {
    final resourceJson = jsonDecode(data.resourceRaw);
    final fhirClaim = fhir_r4.Claim.fromJson(resourceJson);

    return Claim(
      id: data.id,
      sourceId: data.sourceId ?? '',
      resourceId: data.resourceId ?? '',
      title: data.title ?? '',
      date: data.date,
      rawResource: resourceJson,
      encounterId: data.encounterId ?? '',
      subjectId: data.subjectId ?? '',
      text: fhirClaim.text,
      identifier: fhirClaim.identifier,
      status: fhirClaim.status,
      type: fhirClaim.type,
      subType: fhirClaim.subType,
      use: fhirClaim.use,
      patient: fhirClaim.patient,
      billablePeriod: fhirClaim.billablePeriod,
      created: fhirClaim.created,
      enterer: fhirClaim.enterer,
      insurer: fhirClaim.insurer,
      provider: fhirClaim.provider,
      priority: fhirClaim.priority,
      fundsReserve: fhirClaim.fundsReserve,
      related: fhirClaim.related,
      payee: fhirClaim.payee,
      referral: fhirClaim.referral,
      facility: fhirClaim.facility,
      careTeam: fhirClaim.careTeam,
      supportingInfo: fhirClaim.supportingInfo,
      diagnosis: fhirClaim.diagnosis,
      procedure: fhirClaim.procedure,
      insurance: fhirClaim.insurance,
      accident: fhirClaim.accident,
      item: fhirClaim.item,
      total: fhirClaim.total,
    );
  }

  @override
  FhirResourceDto toDto() => FhirResourceDto(
        id: id,
        sourceId: sourceId,
        resourceType: 'Claim',
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
    final statusText = status?.valueString;
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createStatusLine(statusText, prefix: 'Status'),
    );

    // Type
    final typeDisplay = FhirFieldExtractor.extractCodeableConceptText(type);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createCategoryLine(typeDisplay, prefix: 'Type'),
    );

    // Use
    final useDisplay = use?.valueString;
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createStatusLine(useDisplay, prefix: 'Use'),
    );

    // Provider
    final providerDisplay =
        FhirFieldExtractor.extractReferenceDisplay(provider);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createOrganizationLine(providerDisplay,
          prefix: 'Provider'),
    );

    // Insurer
    final insurerDisplay = FhirFieldExtractor.extractReferenceDisplay(insurer);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createOrganizationLine(insurerDisplay,
          prefix: 'Insurer'),
    );

    // Insurance/Coverage
    final coverageDisplay =
        insurance?.firstOrNull?.coverage.display?.valueString;
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createStatusLine(coverageDisplay, prefix: 'Coverage'),
    );

    // Priority
    final priorityDisplay =
        FhirFieldExtractor.extractCodeableConceptText(priority);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createWarningLine(priorityDisplay, prefix: 'Priority'),
    );

    // Billable Period
    final billablePeriodDisplay =
        FhirFieldExtractor.extractPeriodFormatted(billablePeriod);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createTimelineLine(billablePeriodDisplay,
          prefix: 'Billable Period'),
    );

    // Total
    if (total != null) {
      final totalValue = total!.value?.valueDouble?.toStringAsFixed(2);
      final currency = total!.currency?.toString() ?? '';
      if (totalValue != null) {
        ResourceFieldMapper.addIfNotNull(
          infoLines,
          ResourceFieldMapper.createValueLine('$currency $totalValue',
              prefix: 'Total'),
        );
      }
    }

    // Facility
    final facilityDisplay =
        FhirFieldExtractor.extractReferenceDisplay(facility);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createLocationLine(facilityDisplay,
          prefix: 'Facility'),
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
      patient?.reference?.valueString,
      enterer?.reference?.valueString,
      insurer?.reference?.valueString,
      provider?.reference?.valueString,
      referral?.reference?.valueString,
      facility?.reference?.valueString,
    }.where((reference) => reference != null).toList();
  }

  @override
  String get statusDisplay => status?.valueString ?? '';
}
