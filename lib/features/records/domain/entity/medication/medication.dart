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

part 'medication.freezed.dart';

@freezed
class Medication with _$Medication implements IFhirResource {
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
  List<RecordInfoLine> get additionalInfo {
    List<RecordInfoLine> infoLines = [];
    infoLines.add(ResourceFieldMapper.createSectionHeader('Medication Details'));

    // Medication Code (already in title, but could show NDC or other codes here)
    final codeDisplay = FhirFieldExtractor.extractCodeableConceptText(code);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createMedicationLine(codeDisplay, prefix: 'Medication'),
    );

    // Form (Tablet, Capsule, Liquid, etc.) - CRITICAL for patients
    final formDisplay = FhirFieldExtractor.extractCodeableConceptText(form);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createMedicationLine(formDisplay, prefix: 'Form'),
    );

    // Amount/Strength
    if (amount != null) {
      final numerator = amount!.numerator?.value?.valueDouble;
      final numeratorUnit = amount!.numerator?.unit ?? amount!.numerator?.code ?? '';
      final denominator = amount!.denominator?.value?.valueDouble;
      final denominatorUnit = amount!.denominator?.unit ?? amount!.denominator?.code ?? '';
      
      String? amountDisplay;
      if (numerator != null && denominator != null) {
        amountDisplay = '$numerator$numeratorUnit / $denominator$denominatorUnit';
      } else if (numerator != null) {
        amountDisplay = '$numerator $numeratorUnit';
      }
      
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createValueLine(amountDisplay, prefix: 'Strength'),
      );
    }

    infoLines.add(ResourceFieldMapper.createSectionHeader('Basic Information'));

    // Status
    final statusText = status?.valueString;
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createStatusLine(statusText, prefix: 'Status'),
    );

    // Manufacturer
    final manufacturerDisplay =
        FhirFieldExtractor.extractReferenceDisplay(manufacturer);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createOrganizationLine(manufacturerDisplay,
          prefix: 'Manufacturer'),
    );

    infoLines.add(ResourceFieldMapper.createSectionHeader('Additional Information'));

    // Ingredients
    if (ingredient != null && ingredient!.isNotEmpty) {
      // Show ingredient count
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createMedicationLine(
            '${ingredient!.length} ingredient(s)',
            prefix: 'Ingredients'),
      );
    }

    // Batch Information
    if (batch != null) {
      final lotNumber = batch!.lotNumber?.valueString;
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createIdentificationLine(lotNumber,
            prefix: 'Lot Number'),
      );

      final expirationDate = batch!.expirationDate?.valueString;
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createDateLine(expirationDate,
            prefix: 'Expiration'),
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
      manufacturer?.reference?.valueString,
    }.where((reference) => reference != null).toList();
  }

  @override
  String get statusDisplay => status?.valueString ?? '';
}
