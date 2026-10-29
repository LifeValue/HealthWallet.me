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
import 'package:intl/intl.dart';

part 'coverage.freezed.dart';

@freezed
abstract class Coverage with _$Coverage implements IFhirResource {
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
    String? specialtyOverride,
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
      specialtyOverride: data.specialtyOverride,
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
  List<RecordInfoLine> additionalInfo(AppLocalizations l10n) {
    final List<RecordInfoLine> infoLines = [];
    final coverageDetailsStartIndex = infoLines.length;

    // Subscriber ID / Member ID (MOST CRITICAL)
    final subscriberIdText = subscriberId?.valueString;
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createIdentificationLine(
        subscriberIdText,
        prefix: l10n.fieldMemberId,
      ),
    );

    // Group Number (from class)
    if (class_ != null && class_!.isNotEmpty) {
      for (final coverageClass in class_!) {
        final classType = FhirFieldExtractor.extractCodeableConceptText(
          coverageClass.type,
        );
        final classValue = coverageClass.value.valueString;

        if (classType == 'group' || classType?.toLowerCase() == 'group') {
          ResourceFieldMapper.addIfNotNull(
            infoLines,
            ResourceFieldMapper.createIdentificationLine(
              classValue,
              prefix: l10n.fieldGroupNumber,
            ),
          );
        }
      }
    }

    // Plan Type
    final typeDisplay = FhirFieldExtractor.extractCodeableConceptText(type);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createCategoryLine(
        typeDisplay,
        prefix: l10n.fieldPlanType,
      ),
    );

    // Status
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createStatusLine(status, prefix: l10n.fieldStatus),
    );

    // Effective Dates / Period
    final periodDisplay = FhirFieldExtractor.extractPeriodFormatted(
      period,
      l10n: l10n,
    );
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createTimelineLine(
        periodDisplay,
        prefix: l10n.fieldEffectiveDates,
      ),
    );

    // Add section header only if we added content
    if (infoLines.length > coverageDetailsStartIndex) {
      infoLines.insert(
        coverageDetailsStartIndex,
        ResourceFieldMapper.createSectionHeader(l10n.fieldCoverageDetails),
      );
    }

    final basicInfoStartIndex = infoLines.length;

    // Insurance Company / Payor
    if (payor != null && payor!.isNotEmpty) {
      final payorDisplay = payor!
          .map(FhirFieldExtractor.extractReferenceDisplay)
          .where((p) => p != null && p.isNotEmpty)
          .join(', ');
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createOrganizationLine(
          payorDisplay.isNotEmpty ? payorDisplay : null,
          prefix: l10n.fieldInsuranceCompany,
        ),
      );
    }

    // Plan Name (from class)
    if (class_ != null && class_!.isNotEmpty) {
      for (final coverageClass in class_!) {
        final classType = FhirFieldExtractor.extractCodeableConceptText(
          coverageClass.type,
        );
        final className = coverageClass.name?.valueString;

        if ((classType == 'plan' || classType?.toLowerCase() == 'plan') &&
            className != null) {
          ResourceFieldMapper.addIfNotNull(
            infoLines,
            ResourceFieldMapper.createStatusLine(
              className,
              prefix: l10n.fieldPlanName,
            ),
          );
        }
      }
    }

    // Subscriber
    final subscriberDisplay = FhirFieldExtractor.extractReferenceDisplay(
      subscriber,
    );
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createUserLine(
        subscriberDisplay,
        prefix: l10n.fieldSubscriber,
      ),
    );

    // Relationship to Subscriber
    final relationshipDisplay = FhirFieldExtractor.extractCodeableConceptText(
      relationship,
    );
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createStatusLine(
        relationshipDisplay,
        prefix: l10n.fieldRelationshipToSubscriber,
      ),
    );

    // Beneficiary
    final beneficiaryDisplay = FhirFieldExtractor.extractReferenceDisplay(
      beneficiary,
    );
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createUserLine(
        beneficiaryDisplay,
        prefix: l10n.fieldBeneficiary,
      ),
    );

    // Network
    final networkText = network?.valueString;
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createStatusLine(
        networkText,
        prefix: l10n.fieldNetwork,
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

    // Policy Holder (if different from subscriber)
    final policyHolderDisplay = FhirFieldExtractor.extractReferenceDisplay(
      policyHolder,
    );
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createUserLine(
        policyHolderDisplay,
        prefix: l10n.fieldPolicyHolder,
      ),
    );

    // Dependent (sequence number)
    final dependentText = dependent?.valueString;
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createStatusLine(
        dependentText,
        prefix: l10n.fieldDependent,
      ),
    );

    // Order (Primary, Secondary, etc.)
    if (order != null) {
      final orderValue = int.tryParse(order!.valueString ?? '');
      String? orderDisplay;
      if (orderValue != null) {
        switch (orderValue) {
          case 1:
            orderDisplay = l10n.coverageOrderPrimary;
            break;
          case 2:
            orderDisplay = l10n.coverageOrderSecondary;
            break;
          case 3:
            orderDisplay = l10n.coverageOrderTertiary;
            break;
          default:
            orderDisplay = l10n.coverageOrderNumber(orderValue);
        }
      }
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createStatusLine(
          orderDisplay,
          prefix: l10n.fieldOrder,
        ),
      );
    }

    // Cost to Beneficiary (Copays, Deductibles, etc.)
    if (costToBeneficiary != null && costToBeneficiary!.isNotEmpty) {
      for (final cost in costToBeneficiary!) {
        final costType = FhirFieldExtractor.extractCodeableConceptText(
          cost.type,
        );

        // Get value from valueMoney or valueQuantity
        String? costValue;
        final valueMoney = cost.valueX.isAs<fhir_r4.Money>();
        if (valueMoney != null) {
          final amount = valueMoney.value?.valueString;
          final currency = valueMoney.currency?.toString() ?? 'USD';
          if (amount != null) {
            costValue = '\$$amount $currency';
          }
        } else {
          final valueQuantity = cost.valueX.isAs<fhir_r4.Quantity>();
          if (valueQuantity != null) {
            costValue = FhirFieldExtractor.extractQuantity(valueQuantity);
          }
        }

        final costDisplay = costType != null && costValue != null
            ? '$costType: $costValue'
            : costValue ?? costType;

        ResourceFieldMapper.addIfNotNull(
          infoLines,
          ResourceFieldMapper.createStatusLine(
            costDisplay,
            prefix: l10n.fieldCostSharing,
          ),
        );
      }
    }

    // Additional Class Information (employer, subgroup, etc.)
    if (class_ != null && class_!.isNotEmpty) {
      for (final coverageClass in class_!) {
        final classType = FhirFieldExtractor.extractCodeableConceptText(
          coverageClass.type,
        );
        final classValue = coverageClass.value.valueString;
        final className = coverageClass.name?.valueString;

        // Skip if already displayed (group, plan)
        if (classType == 'group' || classType == 'plan') continue;

        String? classDisplay = className ?? classValue;
        if (classType != null && classDisplay != null) {
          classDisplay = '$classType: $classDisplay';
        }

        ResourceFieldMapper.addIfNotNull(
          infoLines,
          ResourceFieldMapper.createStatusLine(
            classDisplay,
            prefix: l10n.fieldCoverageClass,
          ),
        );
      }
    }

    // Subrogation
    final subrogationValue = subrogation?.valueBoolean;
    if (subrogationValue != null) {
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createStatusLine(
          subrogationValue ? l10n.yes : l10n.no,
          prefix: l10n.fieldSubrogation,
        ),
      );
    }

    // Contract References
    if (contract != null && contract!.isNotEmpty) {
      final contractDisplay = contract!
          .map(FhirFieldExtractor.extractReferenceDisplay)
          .where((c) => c != null && c.isNotEmpty)
          .take(3)
          .join(', ');

      if (contractDisplay.isNotEmpty) {
        final suffix = contract!.length > 3
            ? ' (${l10n.moreCount(contract!.length - 3)})'
            : '';
        ResourceFieldMapper.addIfNotNull(
          infoLines,
          ResourceFieldMapper.createDocumentLine(
            contractDisplay + suffix,
            prefix: l10n.fieldContract,
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
          info: DateFormat.yMMMMd(l10n.localeName).format(date!),
        ),
      );
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
