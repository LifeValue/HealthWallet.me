import 'dart:convert';

import 'package:fhir_r4/fhir_r4.dart' as fhir_r4;
import 'package:fhir_r4/fhir_r4.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:health_wallet/core/config/constants/region_preset.dart';
import 'package:health_wallet/core/data/local/app_database.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/core/l10n/display_names.dart';
import 'package:health_wallet/core/utils/date_format_utils.dart';
import 'package:health_wallet/features/records/domain/entity/i_fhir_resource.dart';
import 'package:health_wallet/features/records/domain/utils/extractors/fhir_common_extractor.dart';
import 'package:health_wallet/features/records/domain/utils/fhir_field_extractor.dart';
import 'package:health_wallet/features/records/domain/utils/resource_field_mapper.dart';
import 'package:health_wallet/features/records/presentation/models/record_info_line.dart';
import 'package:health_wallet/features/sync/data/dto/fhir_resource_dto.dart';
import 'package:health_wallet/gen/assets.gen.dart';
import 'package:intl/intl.dart';

part 'observation.freezed.dart';

@freezed
abstract class Observation with _$Observation implements IFhirResource {
  const Observation._();

  const factory Observation({
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
    List<Reference>? basedOn,
    List<Reference>? partOf,
    ObservationStatus? status,
    List<CodeableConcept>? category,
    CodeableConcept? code,
    Reference? subject,
    List<Reference>? focus,
    Reference? encounter,
    EffectiveXObservation? effectiveX,
    FhirInstant? issued,
    List<Reference>? performer,
    ValueXObservation? valueX,
    CodeableConcept? dataAbsentReason,
    List<CodeableConcept>? interpretation,
    List<Annotation>? note,
    CodeableConcept? bodySite,
    CodeableConcept? method,
    Reference? specimen,
    Reference? device,
    List<ObservationReferenceRange>? referenceRange,
    List<Reference>? hasMember,
    List<Reference>? derivedFrom,
    List<ObservationComponent>? component,
  }) = _Observation;

  @override
  FhirType get fhirType => FhirType.Observation;

  factory Observation.fromLocalData(FhirResourceLocalDto data) {
    final resourceJson = jsonDecode(data.resourceRaw);
    final fhirObservation = fhir_r4.Observation.fromJson(resourceJson);

    return Observation(
      id: data.id,
      sourceId: data.sourceId ?? '',
      resourceId: data.resourceId ?? '',
      title: data.title ?? '',
      date: data.date,
      rawResource: resourceJson,
      encounterId: data.encounterId ?? '',
      subjectId: data.subjectId ?? '',
      specialtyOverride: data.specialtyOverride,
      text: fhirObservation.text,
      identifier: fhirObservation.identifier,
      basedOn: fhirObservation.basedOn,
      partOf: fhirObservation.partOf,
      status: fhirObservation.status,
      category: fhirObservation.category,
      code: fhirObservation.code,
      subject: fhirObservation.subject,
      focus: fhirObservation.focus,
      encounter: fhirObservation.encounter,
      effectiveX: fhirObservation.effectiveX,
      issued: fhirObservation.issued,
      performer: fhirObservation.performer,
      valueX: fhirObservation.valueX,
      dataAbsentReason: fhirObservation.dataAbsentReason,
      interpretation: fhirObservation.interpretation,
      note: fhirObservation.note,
      bodySite: fhirObservation.bodySite,
      method: fhirObservation.method,
      specimen: fhirObservation.specimen,
      device: fhirObservation.device,
      referenceRange: fhirObservation.referenceRange,
      hasMember: fhirObservation.hasMember,
      derivedFrom: fhirObservation.derivedFrom,
      component: fhirObservation.component,
    );
  }

  @override
  FhirResourceDto toDto() => FhirResourceDto(
    id: id,
    sourceId: sourceId,
    resourceType: 'Observation',
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
    infoLines.add(ResourceFieldMapper.createSectionHeader(l10n.fieldResult));

    final valueDisplay = FhirFieldExtractor.extractObservationValue(
      valueX,
      l10n: l10n,
    );
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createValueLine(
        valueDisplay,
        prefix: l10n.fieldValue,
      ),
    );

    if (component != null && component!.isNotEmpty) {
      for (final comp in component!) {
        final componentCode = FhirFieldExtractor.extractCodeableConceptText(
          comp.code,
        );
        final componentValue = FhirFieldExtractor.extractObservationValue(
          comp.valueX,
          l10n: l10n,
        );

        if (componentCode != null && componentValue != null) {
          ResourceFieldMapper.addIfNotNull(
            infoLines,
            ResourceFieldMapper.createValueLine(
              componentValue,
              prefix: componentCode,
            ),
          );
        }
      }
    }

    final interpretationDisplay = FhirFieldExtractor.extractInterpretation(
      interpretation,
    );
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createWarningLine(
        interpretationDisplay,
        prefix: l10n.fieldStatus,
      ),
    );

    if (referenceRange != null && referenceRange!.isNotEmpty) {
      final range = referenceRange!.first;
      final lowValue = FhirCommonExtractor.quantityValue(range.low);
      final highValue = FhirCommonExtractor.quantityValue(range.high);
      final unit = localizedUnit(
        (range.low?.unit ?? range.high?.unit ?? '').toString(),
        l10n,
      );

      String? rangeDisplay;
      if (lowValue != null && highValue != null) {
        rangeDisplay = '$lowValue - $highValue $unit';
      } else if (lowValue != null) {
        rangeDisplay = '> $lowValue $unit';
      } else if (highValue != null) {
        rangeDisplay = '< $highValue $unit';
      }

      final rangeType = FhirFieldExtractor.extractCodeableConceptText(range);
      if (rangeType != null && rangeDisplay != null) {
        rangeDisplay = '$rangeDisplay ($rangeType)';
      }

      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createLabLine(
          rangeDisplay,
          prefix: l10n.fieldReferenceRange,
        ),
      );
    }

    if (valueDisplay == null || valueDisplay.isEmpty) {
      final absentReason = FhirFieldExtractor.extractCodeableConceptText(
        dataAbsentReason,
      );
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createWarningLine(
          absentReason,
          prefix: l10n.fieldDataAbsentReason,
        ),
      );
    }

    infoLines.add(
      ResourceFieldMapper.createSectionHeader(l10n.fieldBasicInformation),
    );

    final categoryDisplay =
        FhirFieldExtractor.extractFirstCodeableConceptFromArray(category);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createCategoryLine(
        categoryDisplay,
        prefix: l10n.fieldCategory,
      ),
    );

    final effectiveDisplay = FhirFieldExtractor.extractEffectiveXFormatted(
      effectiveX,
      l10n: l10n,
    );
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createDateLine(
        effectiveDisplay,
        prefix: l10n.fieldTestDate,
      ),
    );

    final issuedDisplay = FhirFieldExtractor.formatFhirInstant(issued);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createDateLine(
        issuedDisplay,
        prefix: l10n.fieldResultDate,
      ),
    );

    final performerDisplay = FhirFieldExtractor.extractPerformers(performer);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createUserLine(
        performerDisplay,
        prefix: l10n.fieldPerformedBy,
      ),
    );

    final methodDisplay = FhirFieldExtractor.extractCodeableConceptText(method);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createProcedureLine(
        methodDisplay,
        prefix: l10n.fieldMethod,
      ),
    );

    infoLines.add(
      ResourceFieldMapper.createSectionHeader(l10n.fieldAdditionalInformation),
    );

    final statusText = status?.valueString;
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createStatusLine(
        statusText,
        prefix: l10n.fieldStatus,
      ),
    );

    final specimenDisplay = FhirFieldExtractor.extractReferenceDisplay(
      specimen,
    );
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createLabLine(
        specimenDisplay,
        prefix: l10n.fieldSpecimenType,
      ),
    );

    final bodySiteDisplay = FhirFieldExtractor.extractCodeableConceptText(
      bodySite,
    );
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createBodySiteLine(
        bodySiteDisplay,
        prefix: l10n.fieldBodySite,
      ),
    );

    final deviceDisplay = FhirFieldExtractor.extractReferenceDisplay(device);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createProcedureLine(
        deviceDisplay,
        prefix: l10n.fieldDevice,
      ),
    );

    if (hasMember != null && hasMember!.isNotEmpty) {
      final memberDisplay = hasMember!
          .map(FhirFieldExtractor.extractReferenceDisplay)
          .where((m) => m != null && m.isNotEmpty)
          .take(3)
          .join(', ');

      if (memberDisplay.isNotEmpty) {
        final suffix = hasMember!.length > 3
            ? ' (${l10n.moreCount(hasMember!.length - 3)})'
            : '';
        ResourceFieldMapper.addIfNotNull(
          infoLines,
          ResourceFieldMapper.createLabLine(
            memberDisplay + suffix,
            prefix: l10n.fieldPanelComponents,
          ),
        );
      }
    }

    if (derivedFrom != null && derivedFrom!.isNotEmpty) {
      final derivedDisplay = derivedFrom!
          .map(FhirFieldExtractor.extractReferenceDisplay)
          .where((d) => d != null && d.isNotEmpty)
          .join(', ');
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createLabLine(
          derivedDisplay.isNotEmpty ? derivedDisplay : null,
          prefix: l10n.fieldDerivedFrom,
        ),
      );
    }

    if (basedOn != null && basedOn!.isNotEmpty) {
      final basedOnDisplay = basedOn!
          .map(FhirFieldExtractor.extractReferenceDisplay)
          .where((b) => b != null && b.isNotEmpty)
          .join(', ');
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createDocumentLine(
          basedOnDisplay.isNotEmpty ? basedOnDisplay : null,
          prefix: l10n.fieldOrderedBy,
        ),
      );
    }

    if (referenceRange != null && referenceRange!.isNotEmpty) {
      final range = referenceRange!.first;
      final rangeText = range.text?.valueString;
      if (rangeText != null && rangeText.isNotEmpty) {
        ResourceFieldMapper.addIfNotNull(
          infoLines,
          ResourceFieldMapper.createNotesLine(
            rangeText,
            prefix: l10n.fieldRangeNotes,
          ),
        );
      }

      if (range.appliesTo != null && range.appliesTo!.isNotEmpty) {
        final appliesDisplay = range.appliesTo!
            .map(FhirFieldExtractor.extractCodeableConceptText)
            .where((a) => a != null && a.isNotEmpty)
            .join(', ');
        ResourceFieldMapper.addIfNotNull(
          infoLines,
          ResourceFieldMapper.createNotesLine(
            appliesDisplay.isNotEmpty ? appliesDisplay : null,
            prefix: l10n.fieldRangeAppliesTo,
          ),
        );
      }
    }

    if (date != null) {
      infoLines.add(
        RecordInfoLine(
          icon: Assets.icons.calendar,
          info: DateFormat.yMMMMd(l10n.localeName).format(date!),
        ),
      );
    }

    final notesDisplay = FhirFieldExtractor.extractAnnotations(note);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createNotesLine(
        notesDisplay,
        prefix: l10n.fieldClinicalNotes,
      ),
    );

    return infoLines;
  }

  List<RecordInfoLine> additionalInfoForRegion(
    RegionPreset region,
    AppLocalizations l10n,
  ) {
    final List<RecordInfoLine> infoLines = [];
    infoLines.add(ResourceFieldMapper.createSectionHeader(l10n.fieldResult));

    final measured = FhirFieldExtractor.regionUnitVitalOf(code);
    final valueDisplay = FhirFieldExtractor.extractObservationValueForRegion(
      valueX,
      region,
      l10n: l10n,
      measured: measured,
    );
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createValueLine(
        valueDisplay,
        prefix: l10n.fieldValue,
      ),
    );

    if (component != null && component!.isNotEmpty) {
      for (final comp in component!) {
        final componentCode = FhirFieldExtractor.extractCodeableConceptText(
          comp.code,
        );
        final componentValue =
            FhirFieldExtractor.extractObservationValueForRegion(
              comp.valueX,
              region,
              l10n: l10n,
              measured: FhirFieldExtractor.regionUnitVitalOf(comp.code),
            );

        if (componentCode != null && componentValue != null) {
          ResourceFieldMapper.addIfNotNull(
            infoLines,
            ResourceFieldMapper.createValueLine(
              componentValue,
              prefix: componentCode,
            ),
          );
        }
      }
    }

    final interpretationDisplay = FhirFieldExtractor.extractInterpretation(
      interpretation,
    );
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createWarningLine(
        interpretationDisplay,
        prefix: l10n.fieldStatus,
      ),
    );

    if (referenceRange != null && referenceRange!.isNotEmpty) {
      final range = referenceRange!.first;
      final rawLow = range.low?.value?.valueDouble;
      final rawHigh = range.high?.value?.valueDouble;

      // Each bound is converted from its own unit.
      ({double value, String unit})? convert(Quantity? bound, double? value) =>
          value == null
          ? null
          : FhirFieldExtractor.convertQuantityForRegion(
              value,
              FhirCommonExtractor.quantityUnit(bound) ?? '',
              region,
              measured: measured,
              ucumCode: bound?.code?.valueString,
            );
      final low = convert(range.low, rawLow);
      final high = convert(range.high, rawHigh);
      final double? displayLow = low?.value;
      final double? displayHigh = high?.value;
      String displayUnit = low?.unit ?? high?.unit ?? '';

      displayUnit = localizedUnit(displayUnit, l10n);

      final lowValue = displayLow == null
          ? null
          : FhirCommonExtractor.formatQuantityValue(displayLow, source: rawLow);
      final highValue = displayHigh == null
          ? null
          : FhirCommonExtractor.formatQuantityValue(
              displayHigh,
              source: rawHigh,
            );

      String? rangeDisplay;
      if (lowValue != null && highValue != null) {
        rangeDisplay = '$lowValue - $highValue $displayUnit';
      } else if (lowValue != null) {
        rangeDisplay = '> $lowValue $displayUnit';
      } else if (highValue != null) {
        rangeDisplay = '< $highValue $displayUnit';
      }

      final rangeType = FhirFieldExtractor.extractCodeableConceptText(range);
      if (rangeType != null && rangeDisplay != null) {
        rangeDisplay = '$rangeDisplay ($rangeType)';
      }

      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createLabLine(
          rangeDisplay,
          prefix: l10n.fieldReferenceRange,
        ),
      );
    }

    if (valueDisplay == null || valueDisplay.isEmpty) {
      final absentReason = FhirFieldExtractor.extractCodeableConceptText(
        dataAbsentReason,
      );
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createWarningLine(
          absentReason,
          prefix: l10n.fieldDataAbsentReason,
        ),
      );
    }

    infoLines.add(
      ResourceFieldMapper.createSectionHeader(l10n.fieldBasicInformation),
    );

    final categoryDisplay =
        FhirFieldExtractor.extractFirstCodeableConceptFromArray(category);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createCategoryLine(
        categoryDisplay,
        prefix: l10n.fieldCategory,
      ),
    );

    final effectiveDisplay = FhirFieldExtractor.extractEffectiveXFormatted(
      effectiveX,
      l10n: l10n,
    );
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createDateLine(
        effectiveDisplay,
        prefix: l10n.fieldTestDate,
      ),
    );

    final issuedDisplay = FhirFieldExtractor.formatFhirInstant(issued);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createDateLine(
        issuedDisplay,
        prefix: l10n.fieldResultDate,
      ),
    );

    final performerDisplay = FhirFieldExtractor.extractPerformers(performer);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createUserLine(
        performerDisplay,
        prefix: l10n.fieldPerformedBy,
      ),
    );

    final methodDisplay = FhirFieldExtractor.extractCodeableConceptText(method);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createProcedureLine(
        methodDisplay,
        prefix: l10n.fieldMethod,
      ),
    );

    infoLines.add(
      ResourceFieldMapper.createSectionHeader(l10n.fieldAdditionalInformation),
    );

    final statusText = status?.valueString;
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createStatusLine(
        statusText,
        prefix: l10n.fieldStatus,
      ),
    );

    final specimenDisplay = FhirFieldExtractor.extractReferenceDisplay(
      specimen,
    );
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createLabLine(
        specimenDisplay,
        prefix: l10n.fieldSpecimenType,
      ),
    );

    final bodySiteDisplay = FhirFieldExtractor.extractCodeableConceptText(
      bodySite,
    );
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createBodySiteLine(
        bodySiteDisplay,
        prefix: l10n.fieldBodySite,
      ),
    );

    final deviceDisplay = FhirFieldExtractor.extractReferenceDisplay(device);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createProcedureLine(
        deviceDisplay,
        prefix: l10n.fieldDevice,
      ),
    );

    if (hasMember != null && hasMember!.isNotEmpty) {
      final memberDisplay = hasMember!
          .map(FhirFieldExtractor.extractReferenceDisplay)
          .where((m) => m != null && m.isNotEmpty)
          .take(3)
          .join(', ');

      if (memberDisplay.isNotEmpty) {
        final suffix = hasMember!.length > 3
            ? ' (${l10n.moreCount(hasMember!.length - 3)})'
            : '';
        ResourceFieldMapper.addIfNotNull(
          infoLines,
          ResourceFieldMapper.createLabLine(
            memberDisplay + suffix,
            prefix: l10n.fieldPanelComponents,
          ),
        );
      }
    }

    if (derivedFrom != null && derivedFrom!.isNotEmpty) {
      final derivedDisplay = derivedFrom!
          .map(FhirFieldExtractor.extractReferenceDisplay)
          .where((d) => d != null && d.isNotEmpty)
          .join(', ');
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createLabLine(
          derivedDisplay.isNotEmpty ? derivedDisplay : null,
          prefix: l10n.fieldDerivedFrom,
        ),
      );
    }

    if (basedOn != null && basedOn!.isNotEmpty) {
      final basedOnDisplay = basedOn!
          .map(FhirFieldExtractor.extractReferenceDisplay)
          .where((b) => b != null && b.isNotEmpty)
          .join(', ');
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createDocumentLine(
          basedOnDisplay.isNotEmpty ? basedOnDisplay : null,
          prefix: l10n.fieldOrderedBy,
        ),
      );
    }

    if (referenceRange != null && referenceRange!.isNotEmpty) {
      final range = referenceRange!.first;
      final rangeText = range.text?.valueString;
      if (rangeText != null && rangeText.isNotEmpty) {
        ResourceFieldMapper.addIfNotNull(
          infoLines,
          ResourceFieldMapper.createNotesLine(
            rangeText,
            prefix: l10n.fieldRangeNotes,
          ),
        );
      }

      if (range.appliesTo != null && range.appliesTo!.isNotEmpty) {
        final appliesDisplay = range.appliesTo!
            .map(FhirFieldExtractor.extractCodeableConceptText)
            .where((a) => a != null && a.isNotEmpty)
            .join(', ');
        ResourceFieldMapper.addIfNotNull(
          infoLines,
          ResourceFieldMapper.createNotesLine(
            appliesDisplay.isNotEmpty ? appliesDisplay : null,
            prefix: l10n.fieldRangeAppliesTo,
          ),
        );
      }
    }

    if (date != null) {
      infoLines.add(
        RecordInfoLine(
          icon: Assets.icons.calendar,
          info: DateFormatUtils.formatDate(date!, region),
        ),
      );
    }

    final notesDisplay = FhirFieldExtractor.extractAnnotations(note);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createNotesLine(
        notesDisplay,
        prefix: l10n.fieldClinicalNotes,
      ),
    );

    return infoLines;
  }

  @override
  List<String?> get resourceReferences {
    return {
      subject?.reference?.valueString,
      encounter?.reference?.valueString,
      specimen?.reference?.valueString,
      device?.reference?.valueString,
      ...?basedOn?.map((reference) => reference.reference?.valueString),
      ...?partOf?.map((reference) => reference.reference?.valueString),
      ...?focus?.map((reference) => reference.reference?.valueString),
      ...?performer?.map((reference) => reference.reference?.valueString),
      ...?hasMember?.map((reference) => reference.reference?.valueString),
      ...?derivedFrom?.map((reference) => reference.reference?.valueString),
    }.where((reference) => reference != null).toList();
  }

  @override
  String get statusDisplay => status?.valueString ?? '';
}
