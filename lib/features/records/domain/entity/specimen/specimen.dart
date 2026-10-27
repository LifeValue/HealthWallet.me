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

part 'specimen.freezed.dart';

@freezed
abstract class Specimen with _$Specimen implements IFhirResource {
  const Specimen._();

  const factory Specimen({
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
    Identifier? accessionIdentifier,
    SpecimenStatus? status,
    CodeableConcept? type,
    Reference? subject,
    FhirDateTime? receivedTime,
    List<Reference>? parent,
    List<Reference>? request,
    SpecimenCollection? collection,
    List<SpecimenProcessing>? processing,
    List<SpecimenContainer>? container,
    List<CodeableConcept>? condition,
    List<Annotation>? note,
  }) = _Specimen;

  @override
  FhirType get fhirType => FhirType.Specimen;

  factory Specimen.fromLocalData(FhirResourceLocalDto data) {
    final resourceJson = jsonDecode(data.resourceRaw);
    final fhirSpecimen = fhir_r4.Specimen.fromJson(resourceJson);

    return Specimen(
      id: data.id,
      sourceId: data.sourceId ?? '',
      resourceId: data.resourceId ?? '',
      title: data.title ?? '',
      date: data.date,
      rawResource: resourceJson,
      encounterId: data.encounterId ?? '',
      subjectId: data.subjectId ?? '',
      specialtyOverride: data.specialtyOverride,
      text: fhirSpecimen.text,
      identifier: fhirSpecimen.identifier,
      accessionIdentifier: fhirSpecimen.accessionIdentifier,
      status: fhirSpecimen.status,
      type: fhirSpecimen.type,
      subject: fhirSpecimen.subject,
      receivedTime: fhirSpecimen.receivedTime,
      parent: fhirSpecimen.parent,
      request: fhirSpecimen.request,
      collection: fhirSpecimen.collection,
      processing: fhirSpecimen.processing,
      container: fhirSpecimen.container,
      condition: fhirSpecimen.condition,
      note: fhirSpecimen.note,
    );
  }

  @override
  FhirResourceDto toDto() => FhirResourceDto(
    id: id,
    sourceId: sourceId,
    resourceType: 'Specimen',
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
    infoLines.add(
      ResourceFieldMapper.createSectionHeader(l10n.fieldSpecimenDetails),
    );

    // Type (What kind of specimen - CRITICAL)
    final typeDisplay = FhirFieldExtractor.extractCodeableConceptText(type);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createLabLine(
        typeDisplay,
        prefix: l10n.fieldSpecimenType,
      ),
    );

    // Status (available, unavailable, unsatisfactory)
    final statusText = status?.valueString;
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createStatusLine(
        statusText,
        prefix: l10n.fieldStatus,
      ),
    );

    // Accession Identifier (Lab tracking number)
    final accessionId = accessionIdentifier?.value?.valueString;
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createIdentificationLine(
        accessionId,
        prefix: l10n.fieldAccessionNumber,
      ),
    );

    // Condition (Hemolyzed, clotted, etc. - important for lab quality)
    if (condition != null && condition!.isNotEmpty) {
      final conditionDisplay = condition!
          .map(FhirFieldExtractor.extractCodeableConceptText)
          .where((c) => c != null && c.isNotEmpty)
          .join(', ');
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createWarningLine(
          conditionDisplay.isNotEmpty ? conditionDisplay : null,
          prefix: l10n.fieldCondition,
        ),
      );
    }

    infoLines.add(
      ResourceFieldMapper.createSectionHeader(l10n.fieldCollectionInformation),
    );

    // Collection details
    if (collection != null) {
      // Collected Time/Period
      final collectedDateTime = collection!.collectedX
          ?.isAs<fhir_r4.FhirDateTime>();
      final collectedPeriod = collection!.collectedX?.isAs<fhir_r4.Period>();

      if (collectedDateTime != null) {
        ResourceFieldMapper.addIfNotNull(
          infoLines,
          ResourceFieldMapper.createDateLine(
            collectedDateTime.valueString,
            prefix: l10n.fieldCollectionDate,
          ),
        );
      } else if (collectedPeriod != null) {
        final periodDisplay = FhirFieldExtractor.extractPeriodFormatted(
          collectedPeriod,
          l10n: l10n,
        );
        ResourceFieldMapper.addIfNotNull(
          infoLines,
          ResourceFieldMapper.createTimelineLine(
            periodDisplay,
            prefix: l10n.fieldCollectionPeriod,
          ),
        );
      }

      // Collector (Person who collected)
      final collector = FhirFieldExtractor.extractReferenceDisplay(
        collection!.collector,
      );
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createUserLine(
          collector,
          prefix: l10n.fieldCollectedBy,
        ),
      );

      // Body Site (Where sample was taken from)
      final bodySite = FhirFieldExtractor.extractCodeableConceptText(
        collection!.bodySite,
      );
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createBodySiteLine(
          bodySite,
          prefix: l10n.fieldBodySite,
        ),
      );

      // Method (How it was collected)
      final method = FhirFieldExtractor.extractCodeableConceptText(
        collection!.method,
      );
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createProcedureLine(
          method,
          prefix: l10n.fieldCollectionMethod,
        ),
      );

      // Quantity
      if (collection!.quantity != null) {
        final quantityValue = collection!.quantity!.value?.valueDouble
            ?.toStringAsFixed(2);
        final quantityUnit =
            collection!.quantity!.unit ?? collection!.quantity!.code ?? '';
        if (quantityValue != null) {
          ResourceFieldMapper.addIfNotNull(
            infoLines,
            ResourceFieldMapper.createValueLine(
              '$quantityValue $quantityUnit',
              prefix: l10n.fieldQuantityCollected,
            ),
          );
        }
      }

      // Duration (time taken to collect)
      if (collection!.duration != null) {
        final durationValue = collection!.duration!.value?.valueDouble
            ?.toStringAsFixed(1);
        final durationUnit = collection!.duration!.unit ?? 'minutes';
        if (durationValue != null) {
          ResourceFieldMapper.addIfNotNull(
            infoLines,
            ResourceFieldMapper.createTimeLine(
              '$durationValue $durationUnit',
              prefix: l10n.fieldCollectionDuration,
            ),
          );
        }
      }

      // Fasting Status
      if (collection!.fastingStatusCodeableConcept != null) {
        final fastingDisplay = FhirFieldExtractor.extractCodeableConceptText(
          collection!.fastingStatusCodeableConcept,
        );
        ResourceFieldMapper.addIfNotNull(
          infoLines,
          ResourceFieldMapper.createStatusLine(
            fastingDisplay,
            prefix: l10n.fieldFastingStatus,
          ),
        );
      } else if (collection!.fastingStatusDuration != null) {
        final fastingDuration = collection!
            .fastingStatusDuration!
            .value
            ?.valueDouble
            ?.toStringAsFixed(1);
        final fastingUnit = collection!.fastingStatusDuration!.unit ?? 'hours';
        if (fastingDuration != null) {
          ResourceFieldMapper.addIfNotNull(
            infoLines,
            ResourceFieldMapper.createStatusLine(
              l10n.fastedFor('$fastingDuration $fastingUnit'),
              prefix: l10n.fieldFastingStatus,
            ),
          );
        }
      }
    }

    // Received Time (When lab received it)
    final receivedTimeDisplay = receivedTime?.valueString;
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createDateLine(
        receivedTimeDisplay,
        prefix: l10n.fieldReceivedAtLab,
      ),
    );

    if ((processing != null && processing!.isNotEmpty) ||
        (container != null && container!.isNotEmpty)) {
      infoLines.add(
        ResourceFieldMapper.createSectionHeader(l10n.fieldProcessingStorage),
      );
    }

    // Processing
    if (processing != null && processing!.isNotEmpty) {
      for (int i = 0; i < processing!.length; i++) {
        final proc = processing![i];
        final description = proc.description?.valueString;
        final procedure = FhirFieldExtractor.extractCodeableConceptText(
          proc.procedure,
        );

        // Additive is just a list of References
        final additive = proc.additive != null && proc.additive!.isNotEmpty
            ? proc.additive!
                  .map(FhirFieldExtractor.extractReferenceDisplay)
                  .where((a) => a != null && a.isNotEmpty)
                  .join(', ')
            : null;

        final processingTime =
            FhirFieldExtractor.extractPeriodFormatted(
              proc.timeX?.isAs<fhir_r4.Period>(),
              l10n: l10n,
            ) ??
            proc.timeX?.isAs<fhir_r4.FhirDateTime>()?.valueString;

        final processingDisplay = [
          procedure,
          description,
          if (additive != null) '${l10n.fieldAdditive}: $additive',
          if (processingTime != null) '${l10n.fieldTime}: $processingTime',
        ].where((s) => s != null && s.isNotEmpty).join(' - ');

        if (processingDisplay.isNotEmpty) {
          ResourceFieldMapper.addIfNotNull(
            infoLines,
            ResourceFieldMapper.createProcedureLine(
              processingDisplay,
              prefix: l10n.fieldProcessingNumber(i + 1),
            ),
          );
        }
      }
    }

    // Container Information
    if (container != null && container!.isNotEmpty) {
      // Show container count
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createLabLine(
          l10n.containerCount(container!.length),
          prefix: l10n.fieldContainers,
        ),
      );

      // Show details of first container
      final firstContainer = container!.first;
      final containerType = FhirFieldExtractor.extractCodeableConceptText(
        firstContainer.type,
      );
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createLabLine(
          containerType,
          prefix: l10n.fieldContainerType,
        ),
      );

      final containerCapacity = firstContainer.capacity != null
          ? FhirFieldExtractor.extractQuantity(firstContainer.capacity)
          : null;
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createValueLine(
          containerCapacity,
          prefix: l10n.fieldContainerCapacity,
        ),
      );

      final specimenQuantity = firstContainer.specimenQuantity != null
          ? FhirFieldExtractor.extractQuantity(firstContainer.specimenQuantity)
          : null;
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createValueLine(
          specimenQuantity,
          prefix: l10n.fieldSpecimenQuantity,
        ),
      );

      // Additive in container
      if (firstContainer.additiveCodeableConcept != null) {
        final additiveDisplay = FhirFieldExtractor.extractCodeableConceptText(
          firstContainer.additiveCodeableConcept,
        );
        ResourceFieldMapper.addIfNotNull(
          infoLines,
          ResourceFieldMapper.createLabLine(
            additiveDisplay,
            prefix: l10n.fieldContainerAdditive,
          ),
        );
      } else if (firstContainer.additiveReference != null) {
        final additiveDisplay = FhirFieldExtractor.extractReferenceDisplay(
          firstContainer.additiveReference,
        );
        ResourceFieldMapper.addIfNotNull(
          infoLines,
          ResourceFieldMapper.createLabLine(
            additiveDisplay,
            prefix: l10n.fieldContainerAdditive,
          ),
        );
      }
    }

    infoLines.add(
      ResourceFieldMapper.createSectionHeader(l10n.fieldAdditionalInformation),
    );

    // Parent Specimen (if derived from another specimen)
    if (parent != null && parent!.isNotEmpty) {
      final parentDisplay = parent!
          .map(FhirFieldExtractor.extractReferenceDisplay)
          .where((p) => p != null && p.isNotEmpty)
          .join(', ');
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createLabLine(
          parentDisplay.isNotEmpty ? parentDisplay : null,
          prefix: l10n.fieldParentSpecimen,
        ),
      );
    }

    // Request (Orders that requested this specimen)
    if (request != null && request!.isNotEmpty) {
      final requestDisplay = request!
          .map(FhirFieldExtractor.extractReferenceDisplay)
          .where((r) => r != null && r.isNotEmpty)
          .join(', ');
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createDocumentLine(
          requestDisplay.isNotEmpty ? requestDisplay : null,
          prefix: l10n.fieldRequestedBy,
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

    // Notes
    final notesDisplay = FhirFieldExtractor.extractAnnotations(note);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createNotesLine(
        notesDisplay,
        prefix: l10n.fieldNotes,
      ),
    );

    return infoLines;
  }

  @override
  List<String?> get resourceReferences {
    return {
      subject?.reference?.valueString,
      ...?parent?.map((reference) => reference.reference?.valueString),
      ...?request?.map((reference) => reference.reference?.valueString),
    }.where((reference) => reference != null).toList();
  }

  @override
  String get statusDisplay => status?.valueString ?? '';
}
