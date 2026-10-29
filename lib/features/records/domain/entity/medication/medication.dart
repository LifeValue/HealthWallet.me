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

part 'medication.freezed.dart';

@freezed
abstract class Medication with _$Medication implements IFhirResource {
  const Medication._();

  const factory Medication({
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
    CodeableConcept? code,
    MedicationStatusCodes? status,
    Reference? manufacturer,
    CodeableConcept? form,
    Ratio? amount,
    List<MedicationIngredient>? ingredient,
    MedicationBatch? batch,
  }) = _Medication;

  @override
  FhirType get fhirType => FhirType.Medication;

  factory Medication.fromLocalData(FhirResourceLocalDto data) {
    final resourceJson = jsonDecode(data.resourceRaw);
    final fhirMedication = fhir_r4.Medication.fromJson(resourceJson);

    return Medication(
      id: data.id,
      sourceId: data.sourceId ?? '',
      resourceId: data.resourceId ?? '',
      title: data.title ?? '',
      date: data.date,
      rawResource: resourceJson,
      encounterId: data.encounterId ?? '',
      subjectId: data.subjectId ?? '',
      specialtyOverride: data.specialtyOverride,
      text: fhirMedication.text,
      identifier: fhirMedication.identifier,
      code: fhirMedication.code,
      status: fhirMedication.status,
      manufacturer: fhirMedication.manufacturer,
      form: fhirMedication.form,
      amount: fhirMedication.amount,
      ingredient: fhirMedication.ingredient,
      batch: fhirMedication.batch,
    );
  }

  @override
  FhirResourceDto toDto() => FhirResourceDto(
    id: id,
    sourceId: sourceId,
    resourceType: 'Medication',
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

    final displayText = FhirFieldExtractor.extractCodeableConceptText(code);
    if (displayText != null) return displayText;

    return fhirType.display;
  }

  @override
  List<RecordInfoLine> additionalInfo(AppLocalizations l10n) {
    final List<RecordInfoLine> infoLines = [];
    infoLines.add(
      ResourceFieldMapper.createSectionHeader(l10n.fieldMedicationDetails),
    );

    // Medication Code (already in title, but could show NDC or other codes here)
    final codeDisplay = FhirFieldExtractor.extractCodeableConceptText(code);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createMedicationLine(
        codeDisplay,
        prefix: l10n.fieldMedication,
      ),
    );

    // Form (Tablet, Capsule, Liquid, etc.) - CRITICAL for patients
    final formDisplay = FhirFieldExtractor.extractCodeableConceptText(form);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createMedicationLine(
        formDisplay,
        prefix: l10n.fieldForm,
      ),
    );

    // Amount/Strength
    if (amount != null) {
      final numerator = amount!.numerator?.value?.valueDouble;
      final numeratorUnit =
          amount!.numerator?.unit ?? amount!.numerator?.code ?? '';
      final denominator = amount!.denominator?.value?.valueDouble;
      final denominatorUnit =
          amount!.denominator?.unit ?? amount!.denominator?.code ?? '';

      String? amountDisplay;
      if (numerator != null && denominator != null) {
        amountDisplay =
            '$numerator$numeratorUnit / $denominator$denominatorUnit';
      } else if (numerator != null) {
        amountDisplay = '$numerator $numeratorUnit';
      }

      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createValueLine(
          amountDisplay,
          prefix: l10n.fieldStrength,
        ),
      );
    }

    infoLines.add(
      ResourceFieldMapper.createSectionHeader(l10n.fieldBasicInformation),
    );

    // Status
    final statusText = status?.valueString;
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createStatusLine(
        statusText,
        prefix: l10n.fieldStatus,
      ),
    );

    // Manufacturer
    final manufacturerDisplay = FhirFieldExtractor.extractReferenceDisplay(
      manufacturer,
    );
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createOrganizationLine(
        manufacturerDisplay,
        prefix: l10n.fieldManufacturer,
      ),
    );

    infoLines.add(
      ResourceFieldMapper.createSectionHeader(l10n.fieldAdditionalInformation),
    );

    // Ingredients
    if (ingredient != null && ingredient!.isNotEmpty) {
      // Show ingredient count
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createMedicationLine(
          l10n.ingredientCount(ingredient!.length),
          prefix: l10n.fieldIngredients,
        ),
      );
    }

    // Batch Information
    if (batch != null) {
      final lotNumber = batch!.lotNumber?.valueString;
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createIdentificationLine(
          lotNumber,
          prefix: l10n.fieldLotNumber,
        ),
      );

      final expirationDate = batch!.expirationDate?.valueString;
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createDateLine(
          expirationDate,
          prefix: l10n.fieldExpiration,
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
      manufacturer?.reference?.valueString,
    }.where((reference) => reference != null).toList();
  }

  @override
  String get statusDisplay => status?.valueString ?? '';
}
