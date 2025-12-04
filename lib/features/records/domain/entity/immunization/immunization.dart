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

part 'immunization.freezed.dart';

@freezed
class Immunization with _$Immunization implements IFhirResource {
  const Immunization._();

  const factory Immunization({
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
    ImmunizationStatusCodes? status,
    CodeableConcept? statusReason,
    CodeableConcept? vaccineCode,
    Reference? patient,
    Reference? encounter,
    OccurrenceXImmunization? occurrenceX,
    FhirDateTime? recorded,
    FhirBoolean? primarySource,
    CodeableConcept? reportOrigin,
    Reference? location,
    Reference? manufacturer,
    FhirString? lotNumber,
    FhirDate? expirationDate,
    CodeableConcept? site,
    CodeableConcept? route,
    Quantity? doseQuantity,
    List<ImmunizationPerformer>? performer,
    List<Annotation>? note,
    List<CodeableConcept>? reasonCode,
    List<Reference>? reasonReference,
    FhirBoolean? isSubpotent,
    List<CodeableConcept>? subpotentReason,
    List<ImmunizationEducation>? education,
    List<CodeableConcept>? programEligibility,
    CodeableConcept? fundingSource,
    List<ImmunizationReaction>? reaction,
    List<ImmunizationProtocolApplied>? protocolApplied,
  }) = _Immunization;

  @override
  FhirType get fhirType => FhirType.Immunization;

  factory Immunization.fromLocalData(FhirResourceLocalDto data) {
    final resourceJson = jsonDecode(data.resourceRaw);
    final fhirImmunization = fhir_r4.Immunization.fromJson(resourceJson);

    return Immunization(
      id: data.id,
      sourceId: data.sourceId ?? '',
      resourceId: data.resourceId ?? '',
      title: data.title ?? '',
      date: data.date,
      rawResource: resourceJson,
      encounterId: data.encounterId ?? '',
      subjectId: data.subjectId ?? '',
      text: fhirImmunization.text,
      identifier: fhirImmunization.identifier,
      status: fhirImmunization.status,
      statusReason: fhirImmunization.statusReason,
      vaccineCode: fhirImmunization.vaccineCode,
      patient: fhirImmunization.patient,
      encounter: fhirImmunization.encounter,
      recorded: fhirImmunization.recorded,
      primarySource: fhirImmunization.primarySource,
      reportOrigin: fhirImmunization.reportOrigin,
      location: fhirImmunization.location,
      manufacturer: fhirImmunization.manufacturer,
      lotNumber: fhirImmunization.lotNumber,
      expirationDate: fhirImmunization.expirationDate,
      site: fhirImmunization.site,
      route: fhirImmunization.route,
      doseQuantity: fhirImmunization.doseQuantity,
      performer: fhirImmunization.performer,
      note: fhirImmunization.note,
      reasonCode: fhirImmunization.reasonCode,
      reasonReference: fhirImmunization.reasonReference,
      isSubpotent: fhirImmunization.isSubpotent,
      subpotentReason: fhirImmunization.subpotentReason,
      education: fhirImmunization.education,
      programEligibility: fhirImmunization.programEligibility,
      fundingSource: fhirImmunization.fundingSource,
      reaction: fhirImmunization.reaction,
      protocolApplied: fhirImmunization.protocolApplied,
    );
  }

  @override
  FhirResourceDto toDto() => FhirResourceDto(
        id: id,
        sourceId: sourceId,
        resourceType: 'Immunization',
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

    final displayText =
        FhirFieldExtractor.extractCodeableConceptText(vaccineCode);
    if (displayText != null) return displayText;

    return fhirType.display;
  }

  @override
  List<RecordInfoLine> get additionalInfo {
    List<RecordInfoLine> infoLines = [];
    infoLines.add(ResourceFieldMapper.createSectionHeader('Vaccination Details'));

    // Vaccine Name (already in title via vaccineCode)
    final vaccineDisplay =
        FhirFieldExtractor.extractCodeableConceptText(vaccineCode);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createImmunizationLine(vaccineDisplay, prefix: 'Vaccine'),
    );

    // Dose/Series Information (from protocolApplied)
    if (protocolApplied != null && protocolApplied!.isNotEmpty) {
      final protocol = protocolApplied!.first;
      
      // Parse doseNumber from either PositiveInt or String
      final doseNumberInt = protocol.doseNumberPositiveInt?.valueString != null
          ? int.tryParse(protocol.doseNumberPositiveInt!.valueString!)
          : null;
      final doseNumberStr = protocol.doseNumberString?.valueString;
      final doseNumber = doseNumberInt?.toString() ?? doseNumberStr;
      
      // Parse seriesDoses from either PositiveInt or String
      final seriesDosesInt = protocol.seriesDosesPositiveInt?.valueString != null
          ? int.tryParse(protocol.seriesDosesPositiveInt!.valueString!)
          : null;
      final seriesDosesStr = protocol.seriesDosesString?.valueString;
      final seriesDoses = seriesDosesInt?.toString() ?? seriesDosesStr;
      
      if (doseNumber != null && seriesDoses != null) {
        ResourceFieldMapper.addIfNotNull(
          infoLines,
          ResourceFieldMapper.createImmunizationLine(
              'Dose $doseNumber of $seriesDoses',
              prefix: 'Dose'),
        );
      } else if (doseNumber != null) {
        ResourceFieldMapper.addIfNotNull(
          infoLines,
          ResourceFieldMapper.createImmunizationLine(
              'Dose $doseNumber',
              prefix: 'Dose'),
        );
      }

      // Series (e.g., "Primary Series", "Booster")
      final series = FhirFieldExtractor.extractCodeableConceptText(protocol.series);
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createTimelineLine(series, prefix: 'Series'),
      );
    }

    // Date Given (Occurrence)
    final occurrenceDisplay =
        FhirFieldExtractor.extractOccurrenceX(occurrenceX);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createDateLine(occurrenceDisplay,
          prefix: 'Date Given'),
    );

    // Administered By (Performer)
    if (performer != null && performer!.isNotEmpty) {
      final performerDisplay = performer!
          .map((p) => FhirFieldExtractor.extractReferenceDisplay(p.actor))
          .where((d) => d != null && d.isNotEmpty)
          .join(', ');
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createUserLine(
            performerDisplay.isNotEmpty ? performerDisplay : null,
            prefix: 'Administered By'),
      );
    }

    // Site (Body Location - e.g., "Left deltoid muscle")
    final siteDisplay = FhirFieldExtractor.extractCodeableConceptText(site);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createBodySiteLine(siteDisplay, prefix: 'Site'),
    );

    // Route (Administration Method - e.g., "Intramuscular injection")
    final routeDisplay = FhirFieldExtractor.extractCodeableConceptText(route);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createActivityLine(routeDisplay, prefix: 'Route'),
    );

    infoLines.add(ResourceFieldMapper.createSectionHeader('Basic Information'));

    // Status
    final statusText = status?.valueString;
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createStatusLine(statusText, prefix: 'Status'),
    );

    // Lot Number
    final lotNumberDisplay = lotNumber?.valueString;
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createIdentificationLine(lotNumberDisplay,
          prefix: 'Lot Number'),
    );

    // Expiration Date
    final expirationDisplay = expirationDate?.valueString;
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createDateLine(expirationDisplay,
          prefix: 'Expiration Date'),
    );

    // Manufacturer
    final manufacturerDisplay =
        FhirFieldExtractor.extractReferenceDisplay(manufacturer);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createOrganizationLine(manufacturerDisplay,
          prefix: 'Manufacturer'),
    );

    // Dose Quantity
    final doseDisplay = FhirFieldExtractor.extractQuantity(doseQuantity);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createValueLine(doseDisplay, prefix: 'Dose Quantity'),
    );

    // Location (Where given)
    final locationDisplay =
        FhirFieldExtractor.extractReferenceDisplay(location);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createLocationLine(locationDisplay,
          prefix: 'Location'),
    );

    infoLines.add(ResourceFieldMapper.createSectionHeader('Additional Information'));

    // Reason
    final reasonCodeDisplay =
        FhirFieldExtractor.extractReasonCodes(reasonCode);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createNotesLine(reasonCodeDisplay, prefix: 'Reason'),
    );

    // Funding Source
    final fundingDisplay =
        FhirFieldExtractor.extractCodeableConceptText(fundingSource);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createStatusLine(fundingDisplay,
          prefix: 'Funding Source'),
    );

    // Primary Source (directly administered vs reported)
    final primarySourceValue = primarySource?.valueBoolean;
    if (primarySourceValue != null) {
      final primarySourceDisplay = primarySourceValue
          ? 'Yes (directly administered)'
          : 'No (reported by patient or other source)';
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createStatusLine(primarySourceDisplay,
            prefix: 'Primary Source'),
      );
    }

    // Report Origin (if not primary source)
    if (primarySourceValue == false) {
      final reportOriginDisplay =
          FhirFieldExtractor.extractCodeableConceptText(reportOrigin);
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createStatusLine(reportOriginDisplay,
            prefix: 'Reported By'),
      );
    }

    // Reaction (Adverse reactions)
    if (reaction != null && reaction!.isNotEmpty) {
      final hasReaction = reaction!.any((r) => r.detail != null || r.reported?.valueBoolean == true);
      if (hasReaction) {
        final reactionDetails = reaction!
            .map((r) {
              final detail = FhirFieldExtractor.extractReferenceDisplay(r.detail);
              return detail;
            })
            .where((d) => d != null && d.isNotEmpty)
            .join(', ');
        
        if (reactionDetails.isNotEmpty) {
          ResourceFieldMapper.addIfNotNull(
            infoLines,
            ResourceFieldMapper.createWarningLine(reactionDetails,
                prefix: 'Reaction'),
          );
        } else {
          ResourceFieldMapper.addIfNotNull(
            infoLines,
            ResourceFieldMapper.createStatusLine('Reaction reported',
                prefix: 'Reaction'),
          );
        }
      } else {
        ResourceFieldMapper.addIfNotNull(
          infoLines,
          ResourceFieldMapper.createStatusLine('No adverse reactions reported',
              prefix: 'Reaction'),
        );
      }
    }

    // Next Dose (from protocolApplied)
    if (protocolApplied != null && protocolApplied!.isNotEmpty) {
      final protocol = protocolApplied!.first;
      
      // Parse integers from valueString
      final doseNumberInt = protocol.doseNumberPositiveInt?.valueString != null
          ? int.tryParse(protocol.doseNumberPositiveInt!.valueString!)
          : null;
      final seriesDosesInt = protocol.seriesDosesPositiveInt?.valueString != null
          ? int.tryParse(protocol.seriesDosesPositiveInt!.valueString!)
          : null;
      
      if (doseNumberInt != null && seriesDosesInt != null) {
        if (doseNumberInt >= seriesDosesInt) {
          ResourceFieldMapper.addIfNotNull(
            infoLines,
            ResourceFieldMapper.createStatusLine('Not scheduled (series complete)',
                prefix: 'Next Dose'),
          );
        } else {
          ResourceFieldMapper.addIfNotNull(
            infoLines,
            ResourceFieldMapper.createTimelineLine('Dose ${doseNumberInt + 1} of $seriesDosesInt',
                prefix: 'Next Dose'),
          );
        }
      }
    }

    // Program Eligibility
    if (programEligibility != null && programEligibility!.isNotEmpty) {
      final eligibilityDisplay = programEligibility!
          .map((e) => FhirFieldExtractor.extractCodeableConceptText(e))
          .where((e) => e != null && e.isNotEmpty)
          .join(', ');
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createStatusLine(
            eligibilityDisplay.isNotEmpty ? eligibilityDisplay : null,
            prefix: 'Program Eligibility'),
      );
    }

    // Education Provided
    if (education != null && education!.isNotEmpty) {
      final educationDisplay = education!
          .map((e) {
            final docType = e.documentType?.valueString;
            final pubDate = e.publicationDate?.valueString;
            return docType != null && pubDate != null
                ? '$docType (published $pubDate)'
                : docType ?? pubDate;
          })
          .where((e) => e != null && e.isNotEmpty)
          .join('; ');
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createNotesLine(
            educationDisplay.isNotEmpty ? educationDisplay : null,
            prefix: 'Education Provided'),
      );
    }

    // Is Subpotent (reduced efficacy)
    final isSubpotentValue = isSubpotent?.valueBoolean;
    if (isSubpotentValue == true) {
      final subpotentReasonDisplay = subpotentReason != null
          ? subpotentReason!
              .map((r) => FhirFieldExtractor.extractCodeableConceptText(r))
              .where((r) => r != null && r.isNotEmpty)
              .join(', ')
          : null;
      
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createWarningLine(
            subpotentReasonDisplay ?? 'Vaccine is subpotent',
            prefix: 'Subpotent'),
      );
    }

    // Status Reason (why not completed, etc.)
    final statusReasonDisplay =
        FhirFieldExtractor.extractCodeableConceptText(statusReason);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createStatusLine(statusReasonDisplay,
          prefix: 'Status Reason'),
    );

    // Recorded Date
    final recordedDisplay = recorded?.valueString;
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createDateLine(recordedDisplay, prefix: 'Recorded'),
    );

    // Date
    if (date != null) {
      infoLines.add(RecordInfoLine(
        icon: Assets.icons.calendar,
        info: DateFormat.yMMMMd().format(date!),
      ));
    }

    // Notes
    final notesDisplay = FhirFieldExtractor.extractAnnotations(note);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createNotesLine(notesDisplay, prefix: 'Notes'),
    );

    return infoLines;
  }

  @override
  List<String?> get resourceReferences {
    return {
      patient?.reference?.valueString,
      encounter?.reference?.valueString,
      location?.reference?.valueString,
      manufacturer?.reference?.valueString,
      ...?reasonReference?.map((reference) => reference.reference?.valueString),
    }.where((reference) => reference != null).toList();
  }

  @override
  String get statusDisplay => status?.valueString ?? '';
}
