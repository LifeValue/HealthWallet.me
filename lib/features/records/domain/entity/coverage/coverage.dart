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
    final coverageDetailsStartIndex = infoLines.length;

    // Subscriber ID / Member ID (MOST CRITICAL)
    final subscriberIdText = subscriberId?.valueString;
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createIdentificationLine(subscriberIdText,
          prefix: 'Member ID'),
    );

    // Group Number (from class)
    if (class_ != null && class_!.isNotEmpty) {
      for (final coverageClass in class_!) {
        final classType = FhirFieldExtractor.extractCodeableConceptText(
            coverageClass.type);
        final classValue = coverageClass.value?.valueString;
        final className = coverageClass.name?.valueString;
        
        if (classType == 'group' || classType?.toLowerCase() == 'group') {
          ResourceFieldMapper.addIfNotNull(
            infoLines,
            ResourceFieldMapper.createIdentificationLine(classValue,
                prefix: 'Group Number'),
          );
        }
      }
    }

    // Plan Type
    final typeDisplay = FhirFieldExtractor.extractCodeableConceptText(type);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createCategoryLine(typeDisplay, prefix: 'Plan Type'),
    );

    // Status
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createStatusLine(status, prefix: 'Status'),
    );

    // Effective Dates / Period
    final periodDisplay = FhirFieldExtractor.extractPeriodFormatted(period);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createTimelineLine(periodDisplay, prefix: 'Effective Dates'),
    );

    // Add section header only if we added content
    if (infoLines.length > coverageDetailsStartIndex) {
      infoLines.insert(coverageDetailsStartIndex,
        ResourceFieldMapper.createSectionHeader('Coverage Details'));
    }

    final basicInfoStartIndex = infoLines.length;

    // Insurance Company / Payor
    if (payor != null && payor!.isNotEmpty) {
      final payorDisplay = payor!
          .map((p) => FhirFieldExtractor.extractReferenceDisplay(p))
          .where((p) => p != null && p.isNotEmpty)
          .join(', ');
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createOrganizationLine(
            payorDisplay.isNotEmpty ? payorDisplay : null,
            prefix: 'Insurance Company'),
      );
    }

    // Plan Name (from class)
    if (class_ != null && class_!.isNotEmpty) {
      for (final coverageClass in class_!) {
        final classType = FhirFieldExtractor.extractCodeableConceptText(
            coverageClass.type);
        final className = coverageClass.name?.valueString;
        
        if ((classType == 'plan' || classType?.toLowerCase() == 'plan') && 
            className != null) {
          ResourceFieldMapper.addIfNotNull(
            infoLines,
            ResourceFieldMapper.createStatusLine(className, prefix: 'Plan Name'),
          );
        }
      }
    }

    // Subscriber
    final subscriberDisplay =
        FhirFieldExtractor.extractReferenceDisplay(subscriber);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createUserLine(subscriberDisplay,
          prefix: 'Subscriber'),
    );

    // Relationship to Subscriber
    final relationshipDisplay =
        FhirFieldExtractor.extractCodeableConceptText(relationship);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createStatusLine(relationshipDisplay,
          prefix: 'Relationship to Subscriber'),
    );

    // Beneficiary
    final beneficiaryDisplay =
        FhirFieldExtractor.extractReferenceDisplay(beneficiary);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createUserLine(beneficiaryDisplay,
          prefix: 'Beneficiary'),
    );

    // Network
    final networkText = network?.valueString;
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createStatusLine(networkText, prefix: 'Network'),
    );

    // Add section header only if we added content
    if (infoLines.length > basicInfoStartIndex) {
      infoLines.insert(basicInfoStartIndex,
        ResourceFieldMapper.createSectionHeader('Basic Information'));
    }

    final additionalInfoStartIndex = infoLines.length;

    // Policy Holder (if different from subscriber)
    final policyHolderDisplay =
        FhirFieldExtractor.extractReferenceDisplay(policyHolder);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createUserLine(policyHolderDisplay,
          prefix: 'Policy Holder'),
    );

    // Dependent (sequence number)
    final dependentText = dependent?.valueString;
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createStatusLine(dependentText, prefix: 'Dependent'),
    );

    // Order (Primary, Secondary, etc.)
    if (order != null) {
      final orderValue = int.tryParse(order!.valueString ?? '');
      String? orderDisplay;
      if (orderValue != null) {
        switch (orderValue) {
          case 1:
            orderDisplay = 'Primary (1)';
            break;
          case 2:
            orderDisplay = 'Secondary (2)';
            break;
          case 3:
            orderDisplay = 'Tertiary (3)';
            break;
          default:
            orderDisplay = 'Order $orderValue';
        }
      }
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createStatusLine(orderDisplay, prefix: 'Order'),
      );
    }

    // Cost to Beneficiary (Copays, Deductibles, etc.)
    if (costToBeneficiary != null && costToBeneficiary!.isNotEmpty) {
      for (final cost in costToBeneficiary!) {
        final costType = FhirFieldExtractor.extractCodeableConceptText(
            cost.type);
        
        // Get value from valueMoney or valueQuantity
        String? costValue;
        if (cost.valueX != null) {
          final valueMoney = cost.valueX!.isAs<fhir_r4.Money>();
          if (valueMoney != null) {
            final amount = valueMoney.value?.valueString;
            final currency = valueMoney.currency?.toString() ?? 'USD';
            if (amount != null) {
              costValue = '\$$amount $currency';
            }
          } else {
            final valueQuantity = cost.valueX!.isAs<fhir_r4.Quantity>();
            if (valueQuantity != null) {
              costValue = FhirFieldExtractor.extractQuantity(valueQuantity);
            }
          }
        }
        
        final costDisplay = costType != null && costValue != null
            ? '$costType: $costValue'
            : costValue ?? costType;
        
        ResourceFieldMapper.addIfNotNull(
          infoLines,
          ResourceFieldMapper.createStatusLine(costDisplay,
              prefix: 'Cost Sharing'),
        );
      }
    }

    // Additional Class Information (employer, subgroup, etc.)
    if (class_ != null && class_!.isNotEmpty) {
      for (final coverageClass in class_!) {
        final classType = FhirFieldExtractor.extractCodeableConceptText(
            coverageClass.type);
        final classValue = coverageClass.value?.valueString;
        final className = coverageClass.name?.valueString;
        
        // Skip if already displayed (group, plan)
        if (classType == 'group' || classType == 'plan') continue;
        
        String? classDisplay = className ?? classValue;
        if (classType != null && classDisplay != null) {
          classDisplay = '$classType: $classDisplay';
        }
        
        ResourceFieldMapper.addIfNotNull(
          infoLines,
          ResourceFieldMapper.createStatusLine(classDisplay,
              prefix: 'Coverage Class'),
        );
      }
    }

    // Subrogation
    final subrogationValue = subrogation?.valueBoolean;
    if (subrogationValue != null) {
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createStatusLine(
            subrogationValue ? 'Yes' : 'No',
            prefix: 'Subrogation'),
      );
    }

    // Contract References
    if (contract != null && contract!.isNotEmpty) {
      final contractDisplay = contract!
          .map((c) => FhirFieldExtractor.extractReferenceDisplay(c))
          .where((c) => c != null && c.isNotEmpty)
          .take(3)
          .join(', ');
      
      if (contractDisplay.isNotEmpty) {
        final suffix = contract!.length > 3 ? ' (${contract!.length - 3} more)' : '';
        ResourceFieldMapper.addIfNotNull(
          infoLines,
          ResourceFieldMapper.createDocumentLine(contractDisplay + suffix,
              prefix: 'Contract'),
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
