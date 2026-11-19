import 'dart:convert';

import 'package:fhir_r4/fhir_r4.dart' as fhir_r4;
import 'package:fhir_r4/fhir_r4.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:health_wallet/core/data/local/app_database.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/features/records/domain/entity/i_fhir_resource.dart';
import 'package:health_wallet/features/records/domain/utils/fhir_code_labels.dart';
import 'package:health_wallet/features/records/domain/utils/fhir_field_extractor.dart';
import 'package:health_wallet/features/records/domain/utils/resource_field_mapper.dart';
import 'package:health_wallet/features/records/presentation/models/record_info_line.dart';
import 'package:health_wallet/features/sync/data/dto/fhir_resource_dto.dart';
import 'package:health_wallet/gen/assets.gen.dart';

part 'medication_request.freezed.dart';

@freezed
abstract class MedicationRequest
    with _$MedicationRequest
    implements IFhirResource {
  const MedicationRequest._();

  const factory MedicationRequest({
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
    MedicationrequestStatus? status,
    CodeableConcept? statusReason,
    MedicationRequestIntent? intent,
    List<CodeableConcept>? category,
    RequestPriority? priority,
    FhirBoolean? doNotPerform,
    ReportedXMedicationRequest? reportedX,
    MedicationXMedicationRequest? medicationX,
    Reference? subject,
    Reference? encounter,
    List<Reference>? supportingInformation,
    FhirDateTime? authoredOn,
    Reference? requester,
    Reference? performer,
    CodeableConcept? performerType,
    Reference? recorder,
    List<CodeableConcept>? reasonCode,
    List<Reference>? reasonReference,
    List<FhirCanonical>? instantiatesCanonical,
    List<FhirUri>? instantiatesUri,
    List<Reference>? basedOn,
    Identifier? groupIdentifier,
    CodeableConcept? courseOfTherapyType,
    List<Reference>? insurance,
    List<Annotation>? note,
    List<Dosage>? dosageInstruction,
    MedicationRequestDispenseRequest? dispenseRequest,
    MedicationRequestSubstitution? substitution,
    Reference? priorPrescription,
    List<Reference>? detectedIssue,
    List<Reference>? eventHistory,
  }) = _MedicationRequest;

  @override
  FhirType get fhirType => FhirType.MedicationRequest;

  factory MedicationRequest.fromLocalData(FhirResourceLocalDto data) {
    final resourceJson = jsonDecode(data.resourceRaw);
    final fhirMedicationRequest = fhir_r4.MedicationRequest.fromJson(
      resourceJson,
    );

    return MedicationRequest(
      id: data.id,
      sourceId: data.sourceId ?? '',
      resourceId: data.resourceId ?? '',
      title: data.title ?? '',
      date: data.date,
      rawResource: resourceJson,
      encounterId: data.encounterId ?? '',
      subjectId: data.subjectId ?? '',
      specialtyOverride: data.specialtyOverride,
      text: fhirMedicationRequest.text,
      identifier: fhirMedicationRequest.identifier,
      status: fhirMedicationRequest.status,
      statusReason: fhirMedicationRequest.statusReason,
      intent: fhirMedicationRequest.intent,
      category: fhirMedicationRequest.category,
      priority: fhirMedicationRequest.priority,
      doNotPerform: fhirMedicationRequest.doNotPerform,
      reportedX: fhirMedicationRequest.reportedX,
      medicationX: fhirMedicationRequest.medicationX,
      subject: fhirMedicationRequest.subject,
      encounter: fhirMedicationRequest.encounter,
      supportingInformation: fhirMedicationRequest.supportingInformation,
      authoredOn: fhirMedicationRequest.authoredOn,
      requester: fhirMedicationRequest.requester,
      performer: fhirMedicationRequest.performer,
      performerType: fhirMedicationRequest.performerType,
      recorder: fhirMedicationRequest.recorder,
      reasonCode: fhirMedicationRequest.reasonCode,
      reasonReference: fhirMedicationRequest.reasonReference,
      instantiatesCanonical: fhirMedicationRequest.instantiatesCanonical,
      instantiatesUri: fhirMedicationRequest.instantiatesUri,
      basedOn: fhirMedicationRequest.basedOn,
      groupIdentifier: fhirMedicationRequest.groupIdentifier,
      courseOfTherapyType: fhirMedicationRequest.courseOfTherapyType,
      insurance: fhirMedicationRequest.insurance,
      note: fhirMedicationRequest.note,
      dosageInstruction: fhirMedicationRequest.dosageInstruction,
      dispenseRequest: fhirMedicationRequest.dispenseRequest,
      substitution: fhirMedicationRequest.substitution,
      priorPrescription: fhirMedicationRequest.priorPrescription,
      detectedIssue: fhirMedicationRequest.detectedIssue,
      eventHistory: fhirMedicationRequest.eventHistory,
    );
  }

  @override
  FhirResourceDto toDto() => FhirResourceDto(
    id: id,
    sourceId: sourceId,
    resourceType: 'MedicationRequest',
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

    final medicationName = FhirFieldExtractor.extractMedicationName(
      medicationX,
      rawResource,
    );
    if (medicationName != null) return medicationName;

    final displayText = FhirFieldExtractor.extractCodeableConceptText(category);
    if (displayText != null) return displayText;

    return fhirType.display;
  }

  @override
  List<RecordInfoLine> additionalInfo(AppLocalizations l10n) {
    final List<RecordInfoLine> infoLines = [];
    infoLines.add(ResourceFieldMapper.createSectionHeader(l10n.fieldHowToTake));

    // Status first, so a stopped or cancelled medication can't be read as
    // a current one on the card.
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      FhirCodeLabels.statusLine(
        status?.valueString,
        l10n,
        prefix: l10n.fieldStatus,
      ),
    );

    // Medication Name
    final medicationDisplay = FhirFieldExtractor.extractMedicationName(
      medicationX,
      rawResource,
    );
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createMedicationLine(
        medicationDisplay,
        prefix: l10n.fieldMedication,
      ),
    );

    // Dosage Instructions (CRITICAL - How to Take)
    final dosageDisplay = FhirFieldExtractor.extractDosageInstructions(
      dosageInstruction,
    );
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createNotesLine(
        dosageDisplay,
        prefix: l10n.fieldDosage,
      ),
    );

    // Dispense Request Details (Refills, Quantity, Days Supply)
    if (dispenseRequest != null) {
      // Refills
      final numberOfRepeatsAllowed = int.tryParse(
        dispenseRequest!.numberOfRepeatsAllowed?.valueString ?? '',
      );
      if (numberOfRepeatsAllowed != null) {
        ResourceFieldMapper.addIfNotNull(
          infoLines,
          ResourceFieldMapper.createValueLine(
            l10n.refillsRemaining(numberOfRepeatsAllowed),
            prefix: l10n.fieldRefills,
          ),
        );
      }

      // Quantity
      final quantity = FhirFieldExtractor.extractQuantity(
        dispenseRequest!.quantity,
      );
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createValueLine(
          quantity,
          prefix: l10n.fieldQuantity,
        ),
      );

      // Days Supply
      final expectedSupplyDuration = FhirFieldExtractor.extractQuantity(
        dispenseRequest!.expectedSupplyDuration,
      );
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createValueLine(
          expectedSupplyDuration,
          prefix: l10n.fieldDaysSupply,
        ),
      );

      // Validity Period (Duration)
      if (dispenseRequest!.validityPeriod != null) {
        final validityStart =
            dispenseRequest!.validityPeriod!.start?.valueString;
        final validityEnd = dispenseRequest!.validityPeriod!.end?.valueString;
        if (validityStart != null || validityEnd != null) {
          final validityDisplay = validityEnd != null
              ? l10n.validUntil(validityEnd)
              : l10n.validFrom(validityStart ?? '');
          ResourceFieldMapper.addIfNotNull(
            infoLines,
            ResourceFieldMapper.createTimelineLine(
              validityDisplay,
              prefix: l10n.fieldDuration,
            ),
          );
        }
      }
    }

    infoLines.add(
      ResourceFieldMapper.createSectionHeader(l10n.fieldBasicInformation),
    );

    // Prescribed Date (Authored On)
    final authoredOnDisplay = FhirFieldExtractor.formatFhirDateTime(authoredOn);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createDateLine(
        authoredOnDisplay,
        prefix: l10n.fieldPrescribed,
      ),
    );

    // Prescribed By (Requester)
    final requesterDisplay = FhirFieldExtractor.extractReferenceDisplay(
      requester,
    );
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createUserLine(
        requesterDisplay,
        prefix: l10n.fieldPrescribedBy,
      ),
    );

    // Reason
    final reasonCodeDisplay = FhirFieldExtractor.extractReasonCodes(reasonCode);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createNotesLine(
        reasonCodeDisplay,
        prefix: l10n.fieldReason,
      ),
    );

    // Priority
    final priorityDisplay = FhirFieldExtractor.extractPriority(priority);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createWarningLine(
        priorityDisplay,
        prefix: l10n.fieldPriority,
      ),
    );

    // Category
    final categoryDisplay =
        FhirFieldExtractor.extractFirstCodeableConceptFromArray(category);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createCategoryLine(
        categoryDisplay,
        prefix: l10n.fieldCategory,
      ),
    );

    infoLines.add(
      ResourceFieldMapper.createSectionHeader(l10n.fieldAdditionalInformation),
    );

    // Intent
    final intentDisplay = FhirFieldExtractor.extractIntent(intent);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createStatusLine(
        intentDisplay,
        prefix: l10n.fieldIntent,
      ),
    );

    // Performer (Intended Dispenser)
    final performerDisplay = FhirFieldExtractor.extractReferenceDisplay(
      performer,
    );
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createUserLine(
        performerDisplay,
        prefix: l10n.fieldPerformer,
      ),
    );

    // Substitution (Generic Allowed?)
    if (substitution != null) {
      final substitutionAllowed = substitution!.allowedBoolean?.valueBoolean;
      if (substitutionAllowed != null) {
        final substitutionDisplay = substitutionAllowed
            ? l10n.substitutionAllowed
            : l10n.substitutionNotAllowed;
        ResourceFieldMapper.addIfNotNull(
          infoLines,
          ResourceFieldMapper.createStatusLine(
            substitutionDisplay,
            prefix: l10n.fieldSubstitution,
          ),
        );
      } else {
        // Check CodeableConcept
        final substitutionCodeDisplay =
            FhirFieldExtractor.extractCodeableConceptText(
              substitution!.allowedCodeableConcept,
            );
        ResourceFieldMapper.addIfNotNull(
          infoLines,
          ResourceFieldMapper.createStatusLine(
            substitutionCodeDisplay,
            prefix: l10n.fieldSubstitution,
          ),
        );
      }
    }

    // Course of Therapy Type
    final courseDisplay = FhirFieldExtractor.extractCodeableConceptText(
      courseOfTherapyType,
    );
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createTimelineLine(
        courseDisplay,
        prefix: l10n.fieldCourseOfTherapy,
      ),
    );

    // Do Not Perform
    final doNotPerformValue = doNotPerform?.valueBoolean;
    if (doNotPerformValue == true) {
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createWarningLine(
          l10n.doNotPerformRequest,
          prefix: '⚠️ ${l10n.fieldAlert}',
        ),
      );
    }

    // Recorder
    final recorderDisplay = FhirFieldExtractor.extractReferenceDisplay(
      recorder,
    );
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createUserLine(
        recorderDisplay,
        prefix: l10n.fieldRecorder,
      ),
    );

    // Date
    if (date != null) {
      infoLines.add(
        RecordInfoLine(
          icon: Assets.icons.calendar,
          info: FhirFieldExtractor.formatRecordDate(date!, l10n.localeName),
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
      encounter?.reference?.valueString,
      requester?.reference?.valueString,
      performer?.reference?.valueString,
      recorder?.reference?.valueString,
      priorPrescription?.reference?.valueString,
      ...?supportingInformation?.map(
        (reference) => reference.reference?.valueString,
      ),
      ...?reasonReference?.map((reference) => reference.reference?.valueString),
      ...?basedOn?.map((reference) => reference.reference?.valueString),
      ...?detectedIssue?.map((reference) => reference.reference?.valueString),
      ...?eventHistory?.map((reference) => reference.reference?.valueString),
    }.where((reference) => reference != null).toList();
  }

  @override
  String get statusDisplay => status?.valueString ?? '';
}
