import 'dart:convert';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:fhir_r4/fhir_r4.dart' as fhir_r4;
import 'package:fhir_r4/fhir_r4.dart';
import 'package:health_wallet/core/config/constants/region_preset.dart';
import 'package:health_wallet/core/utils/date_format_utils.dart';
import 'package:health_wallet/features/records/domain/entity/i_fhir_resource.dart';
import 'package:health_wallet/core/data/local/app_database.dart';
import 'package:health_wallet/features/records/domain/utils/fhir_field_extractor.dart';
import 'package:health_wallet/features/records/domain/utils/resource_field_mapper.dart';
import 'package:health_wallet/features/records/presentation/models/record_info_line.dart';
import 'package:health_wallet/features/sync/data/dto/fhir_resource_dto.dart';
import 'package:health_wallet/gen/assets.gen.dart';
import 'package:intl/intl.dart';

part 'observation.freezed.dart';

@freezed
class Observation with _$Observation implements IFhirResource {
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
  List<RecordInfoLine> get additionalInfo {
    List<RecordInfoLine> infoLines = [];
    infoLines.add(ResourceFieldMapper.createSectionHeader('Result'));

    final valueDisplay = FhirFieldExtractor.extractObservationValue(valueX);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createValueLine(valueDisplay, prefix: 'Value'),
    );

    if (component != null && component!.isNotEmpty) {
      for (final comp in component!) {
        final componentCode = FhirFieldExtractor.extractCodeableConceptText(comp.code);
        final componentValue = FhirFieldExtractor.extractObservationValue(comp.valueX);
        
        if (componentCode != null && componentValue != null) {
          ResourceFieldMapper.addIfNotNull(
            infoLines,
            ResourceFieldMapper.createValueLine(componentValue, prefix: componentCode),
          );
        }
      }
    }

    final interpretationDisplay =
        FhirFieldExtractor.extractInterpretation(interpretation);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createWarningLine(interpretationDisplay,
          prefix: 'Status'),
    );

    if (referenceRange != null && referenceRange!.isNotEmpty) {
      final range = referenceRange!.first;
      final lowValue = range.low?.value?.valueDouble?.toStringAsFixed(2);
      final highValue = range.high?.value?.valueDouble?.toStringAsFixed(2);
      final unit = range.low?.unit ?? range.high?.unit ?? '';

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
        ResourceFieldMapper.createLabLine(rangeDisplay,
            prefix: 'Reference Range'),
      );
    }

    if (valueDisplay == null || valueDisplay.isEmpty) {
      final absentReason = FhirFieldExtractor.extractCodeableConceptText(dataAbsentReason);
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createWarningLine(absentReason,
            prefix: 'Data Absent Reason'),
      );
    }

    infoLines.add(ResourceFieldMapper.createSectionHeader('Basic Information'));

    final categoryDisplay =
        FhirFieldExtractor.extractFirstCodeableConceptFromArray(category);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createCategoryLine(categoryDisplay,
          prefix: 'Category'),
    );

    final effectiveDisplay = FhirFieldExtractor.extractEffectiveXFormatted(effectiveX);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createDateLine(effectiveDisplay,
          prefix: 'Test Date'),
    );

    final issuedDisplay = FhirFieldExtractor.formatFhirInstant(issued);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createDateLine(issuedDisplay,
          prefix: 'Result Date'),
    );

    final performerDisplay = FhirFieldExtractor.extractPerformers(performer);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createUserLine(performerDisplay, prefix: 'Performed By'),
    );

    final methodDisplay = FhirFieldExtractor.extractCodeableConceptText(method);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createProcedureLine(methodDisplay, prefix: 'Method'),
    );

    infoLines.add(ResourceFieldMapper.createSectionHeader('Additional Information'));

    final statusText = status?.valueString;
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createStatusLine(statusText, prefix: 'Status'),
    );

    final specimenDisplay = FhirFieldExtractor.extractReferenceDisplay(specimen);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createLabLine(specimenDisplay,
          prefix: 'Specimen Type'),
    );

    final bodySiteDisplay =
        FhirFieldExtractor.extractCodeableConceptText(bodySite);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createBodySiteLine(bodySiteDisplay,
          prefix: 'Body Site'),
    );

    final deviceDisplay = FhirFieldExtractor.extractReferenceDisplay(device);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createProcedureLine(deviceDisplay,
          prefix: 'Device'),
    );

    if (hasMember != null && hasMember!.isNotEmpty) {
      final memberDisplay = hasMember!
          .map((m) => FhirFieldExtractor.extractReferenceDisplay(m))
          .where((m) => m != null && m.isNotEmpty)
          .take(3)
          .join(', ');
      
      if (memberDisplay.isNotEmpty) {
        final suffix = hasMember!.length > 3 ? ' (${hasMember!.length - 3} more)' : '';
        ResourceFieldMapper.addIfNotNull(
          infoLines,
          ResourceFieldMapper.createLabLine(memberDisplay + suffix,
              prefix: 'Panel Components'),
        );
      }
    }

    if (derivedFrom != null && derivedFrom!.isNotEmpty) {
      final derivedDisplay = derivedFrom!
          .map((d) => FhirFieldExtractor.extractReferenceDisplay(d))
          .where((d) => d != null && d.isNotEmpty)
          .join(', ');
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createLabLine(
            derivedDisplay.isNotEmpty ? derivedDisplay : null,
            prefix: 'Derived From'),
      );
    }

    if (basedOn != null && basedOn!.isNotEmpty) {
      final basedOnDisplay = basedOn!
          .map((b) => FhirFieldExtractor.extractReferenceDisplay(b))
          .where((b) => b != null && b.isNotEmpty)
          .join(', ');
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createDocumentLine(
            basedOnDisplay.isNotEmpty ? basedOnDisplay : null,
            prefix: 'Ordered By'),
      );
    }

    if (referenceRange != null && referenceRange!.isNotEmpty) {
      final range = referenceRange!.first;
      final rangeText = range.text?.valueString;
      if (rangeText != null && rangeText.isNotEmpty) {
        ResourceFieldMapper.addIfNotNull(
          infoLines,
          ResourceFieldMapper.createNotesLine(rangeText,
              prefix: 'Range Notes'),
        );
      }

      if (range.appliesTo != null && range.appliesTo!.isNotEmpty) {
        final appliesDisplay = range.appliesTo!
            .map((a) => FhirFieldExtractor.extractCodeableConceptText(a))
            .where((a) => a != null && a.isNotEmpty)
            .join(', ');
        ResourceFieldMapper.addIfNotNull(
          infoLines,
          ResourceFieldMapper.createNotesLine(
              appliesDisplay.isNotEmpty ? appliesDisplay : null,
              prefix: 'Range Applies To'),
        );
      }
    }

    if (date != null) {
      infoLines.add(RecordInfoLine(
        icon: Assets.icons.calendar,
        info: DateFormat.yMMMMd().format(date!),
      ));
    }

    final notesDisplay = FhirFieldExtractor.extractAnnotations(note);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createNotesLine(notesDisplay, prefix: 'Clinical Notes'),
    );

    return infoLines;
  }

  List<RecordInfoLine> additionalInfoForRegion(RegionPreset region) {
    List<RecordInfoLine> infoLines = [];
    infoLines.add(ResourceFieldMapper.createSectionHeader('Result'));

    final valueDisplay =
        FhirFieldExtractor.extractObservationValueForRegion(valueX, region);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createValueLine(valueDisplay, prefix: 'Value'),
    );

    if (component != null && component!.isNotEmpty) {
      for (final comp in component!) {
        final componentCode =
            FhirFieldExtractor.extractCodeableConceptText(comp.code);
        final componentValue =
            FhirFieldExtractor.extractObservationValueForRegion(
                comp.valueX, region);

        if (componentCode != null && componentValue != null) {
          ResourceFieldMapper.addIfNotNull(
            infoLines,
            ResourceFieldMapper.createValueLine(componentValue,
                prefix: componentCode),
          );
        }
      }
    }

    final interpretationDisplay =
        FhirFieldExtractor.extractInterpretation(interpretation);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createWarningLine(interpretationDisplay,
          prefix: 'Status'),
    );

    if (referenceRange != null && referenceRange!.isNotEmpty) {
      final range = referenceRange!.first;
      final rawLow = range.low?.value?.valueDouble;
      final rawHigh = range.high?.value?.valueDouble;
      final rawUnit = range.low?.unit ?? range.high?.unit ?? '';

      double? displayLow = rawLow;
      double? displayHigh = rawHigh;
      String displayUnit = rawUnit.toString();

      if (rawLow != null) {
        final converted = FhirFieldExtractor.convertQuantityForRegion(
            rawLow, displayUnit, region);
        displayLow = converted.value;
        displayUnit = converted.unit;
      }
      if (rawHigh != null) {
        final converted = FhirFieldExtractor.convertQuantityForRegion(
            rawHigh, displayUnit, region);
        displayHigh = converted.value;
        displayUnit = converted.unit;
      }

      String? rangeDisplay;
      if (displayLow != null && displayHigh != null) {
        rangeDisplay =
            '${displayLow.toStringAsFixed(2)} - ${displayHigh.toStringAsFixed(2)} $displayUnit';
      } else if (displayLow != null) {
        rangeDisplay = '> ${displayLow.toStringAsFixed(2)} $displayUnit';
      } else if (displayHigh != null) {
        rangeDisplay = '< ${displayHigh.toStringAsFixed(2)} $displayUnit';
      }

      final rangeType =
          FhirFieldExtractor.extractCodeableConceptText(range);
      if (rangeType != null && rangeDisplay != null) {
        rangeDisplay = '$rangeDisplay ($rangeType)';
      }

      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createLabLine(rangeDisplay,
            prefix: 'Reference Range'),
      );
    }

    if (valueDisplay == null || valueDisplay.isEmpty) {
      final absentReason =
          FhirFieldExtractor.extractCodeableConceptText(dataAbsentReason);
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createWarningLine(absentReason,
            prefix: 'Data Absent Reason'),
      );
    }

    infoLines
        .add(ResourceFieldMapper.createSectionHeader('Basic Information'));

    final categoryDisplay =
        FhirFieldExtractor.extractFirstCodeableConceptFromArray(category);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createCategoryLine(categoryDisplay,
          prefix: 'Category'),
    );

    final effectiveDisplay =
        FhirFieldExtractor.extractEffectiveXFormatted(effectiveX);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createDateLine(effectiveDisplay,
          prefix: 'Test Date'),
    );

    final issuedDisplay = FhirFieldExtractor.formatFhirInstant(issued);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createDateLine(issuedDisplay,
          prefix: 'Result Date'),
    );

    final performerDisplay =
        FhirFieldExtractor.extractPerformers(performer);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createUserLine(performerDisplay,
          prefix: 'Performed By'),
    );

    final methodDisplay =
        FhirFieldExtractor.extractCodeableConceptText(method);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createProcedureLine(methodDisplay,
          prefix: 'Method'),
    );

    infoLines.add(
        ResourceFieldMapper.createSectionHeader('Additional Information'));

    final statusText = status?.valueString;
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createStatusLine(statusText, prefix: 'Status'),
    );

    final specimenDisplay =
        FhirFieldExtractor.extractReferenceDisplay(specimen);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createLabLine(specimenDisplay,
          prefix: 'Specimen Type'),
    );

    final bodySiteDisplay =
        FhirFieldExtractor.extractCodeableConceptText(bodySite);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createBodySiteLine(bodySiteDisplay,
          prefix: 'Body Site'),
    );

    final deviceDisplay =
        FhirFieldExtractor.extractReferenceDisplay(device);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createProcedureLine(deviceDisplay,
          prefix: 'Device'),
    );

    if (hasMember != null && hasMember!.isNotEmpty) {
      final memberDisplay = hasMember!
          .map((m) => FhirFieldExtractor.extractReferenceDisplay(m))
          .where((m) => m != null && m.isNotEmpty)
          .take(3)
          .join(', ');

      if (memberDisplay.isNotEmpty) {
        final suffix = hasMember!.length > 3
            ? ' (${hasMember!.length - 3} more)'
            : '';
        ResourceFieldMapper.addIfNotNull(
          infoLines,
          ResourceFieldMapper.createLabLine(memberDisplay + suffix,
              prefix: 'Panel Components'),
        );
      }
    }

    if (derivedFrom != null && derivedFrom!.isNotEmpty) {
      final derivedDisplay = derivedFrom!
          .map((d) => FhirFieldExtractor.extractReferenceDisplay(d))
          .where((d) => d != null && d.isNotEmpty)
          .join(', ');
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createLabLine(
            derivedDisplay.isNotEmpty ? derivedDisplay : null,
            prefix: 'Derived From'),
      );
    }

    if (basedOn != null && basedOn!.isNotEmpty) {
      final basedOnDisplay = basedOn!
          .map((b) => FhirFieldExtractor.extractReferenceDisplay(b))
          .where((b) => b != null && b.isNotEmpty)
          .join(', ');
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createDocumentLine(
            basedOnDisplay.isNotEmpty ? basedOnDisplay : null,
            prefix: 'Ordered By'),
      );
    }

    if (referenceRange != null && referenceRange!.isNotEmpty) {
      final range = referenceRange!.first;
      final rangeText = range.text?.valueString;
      if (rangeText != null && rangeText.isNotEmpty) {
        ResourceFieldMapper.addIfNotNull(
          infoLines,
          ResourceFieldMapper.createNotesLine(rangeText,
              prefix: 'Range Notes'),
        );
      }

      if (range.appliesTo != null && range.appliesTo!.isNotEmpty) {
        final appliesDisplay = range.appliesTo!
            .map((a) => FhirFieldExtractor.extractCodeableConceptText(a))
            .where((a) => a != null && a.isNotEmpty)
            .join(', ');
        ResourceFieldMapper.addIfNotNull(
          infoLines,
          ResourceFieldMapper.createNotesLine(
              appliesDisplay.isNotEmpty ? appliesDisplay : null,
              prefix: 'Range Applies To'),
        );
      }
    }

    if (date != null) {
      infoLines.add(RecordInfoLine(
        icon: Assets.icons.calendar,
        info: DateFormatUtils.formatDate(date!, region),
      ));
    }

    final notesDisplay = FhirFieldExtractor.extractAnnotations(note);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createNotesLine(notesDisplay,
          prefix: 'Clinical Notes'),
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
