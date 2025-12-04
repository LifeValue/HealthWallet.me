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

part 'medication_request.freezed.dart';

@freezed
class MedicationRequest with _$MedicationRequest implements IFhirResource {
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
    final fhirMedicationRequest =
        fhir_r4.MedicationRequest.fromJson(resourceJson);

    return MedicationRequest(
      id: data.id,
      sourceId: data.sourceId ?? '',
      resourceId: data.resourceId ?? '',
      title: data.title ?? '',
      date: data.date,
      rawResource: resourceJson,
      encounterId: data.encounterId ?? '',
      subjectId: data.subjectId ?? '',
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

    final displayText = FhirFieldExtractor.extractCodeableConceptText(category);
    if (displayText != null) return displayText;

    return fhirType.display;
  }

  @override
  List<RecordInfoLine> get additionalInfo {
    List<RecordInfoLine> infoLines = [];
    infoLines.add(ResourceFieldMapper.createSectionHeader('How to Take'));

    // Medication Name
    final medicationDisplay = FhirFieldExtractor.extractCodeableConceptText(
        medicationX?.isAs<CodeableConcept>());
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createMedicationLine(medicationDisplay, prefix: 'Medication'),
    );

    // Dosage Instructions (CRITICAL - How to Take)
    final dosageDisplay =
        FhirFieldExtractor.extractDosageInstructions(dosageInstruction);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createNotesLine(dosageDisplay, prefix: 'Dosage'),
    );

    // Dispense Request Details (Refills, Quantity, Days Supply)
    if (dispenseRequest != null) {
      // Refills
      final numberOfRepeatsAllowed = dispenseRequest!.numberOfRepeatsAllowed?.element;
      if (numberOfRepeatsAllowed != null) {
        ResourceFieldMapper.addIfNotNull(
          infoLines,
          ResourceFieldMapper.createValueLine(
              '$numberOfRepeatsAllowed refills remaining',
              prefix: 'Refills'),
        );
      }

      // Quantity
      final quantity = FhirFieldExtractor.extractQuantity(dispenseRequest!.quantity);
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createValueLine(quantity, prefix: 'Quantity'),
      );

      // Days Supply
      final expectedSupplyDuration = FhirFieldExtractor.extractQuantity(
          dispenseRequest!.expectedSupplyDuration);
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createValueLine(expectedSupplyDuration,
            prefix: 'Days Supply'),
      );

      // Validity Period (Duration)
      if (dispenseRequest!.validityPeriod != null) {
        final validityStart = dispenseRequest!.validityPeriod!.start?.valueString;
        final validityEnd = dispenseRequest!.validityPeriod!.end?.valueString;
        if (validityStart != null || validityEnd != null) {
          final validityDisplay = validityEnd != null
              ? 'Valid until $validityEnd'
              : 'Valid from $validityStart';
          ResourceFieldMapper.addIfNotNull(
            infoLines,
            ResourceFieldMapper.createTimelineLine(validityDisplay,
                prefix: 'Duration'),
          );
        }
      }
    }

    infoLines.add(ResourceFieldMapper.createSectionHeader('Basic Information'));

    // Status
    final statusDisplay = status?.display?.valueString;
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createStatusLine(statusDisplay, prefix: 'Status'),
    );

    // Prescribed Date (Authored On)
    final authoredOnDisplay = FhirFieldExtractor.formatFhirDateTime(authoredOn);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createDateLine(authoredOnDisplay, prefix: 'Prescribed'),
    );

    // Prescribed By (Requester)
    final requesterDisplay =
        FhirFieldExtractor.extractReferenceDisplay(requester);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createUserLine(requesterDisplay, prefix: 'Prescribed By'),
    );

    // Reason
    final reasonCodeDisplay =
        FhirFieldExtractor.extractReasonCodes(reasonCode);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createNotesLine(reasonCodeDisplay, prefix: 'Reason'),
    );

    // Priority
    final priorityDisplay = FhirFieldExtractor.extractPriority(priority);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createWarningLine(priorityDisplay, prefix: 'Priority'),
    );

    // Category
    final categoryDisplay =
        FhirFieldExtractor.extractFirstCodeableConceptFromArray(category);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createCategoryLine(categoryDisplay,
          prefix: 'Category'),
    );

    infoLines.add(ResourceFieldMapper.createSectionHeader('Additional Information'));

    // Intent
    final intentDisplay = FhirFieldExtractor.extractIntent(intent);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createStatusLine(intentDisplay, prefix: 'Intent'),
    );

    // Performer (Intended Dispenser)
    final performerDisplay =
        FhirFieldExtractor.extractReferenceDisplay(performer);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createUserLine(performerDisplay, prefix: 'Performer'),
    );

    // Substitution (Generic Allowed?)
    if (substitution != null) {
      final substitutionAllowed = substitution!.allowedBoolean?.valueBoolean;
      if (substitutionAllowed != null) {
        final substitutionDisplay = substitutionAllowed
            ? 'Generic substitution allowed'
            : 'Brand name required - no substitution';
        ResourceFieldMapper.addIfNotNull(
          infoLines,
          ResourceFieldMapper.createStatusLine(substitutionDisplay,
              prefix: 'Substitution'),
        );
      } else {
        // Check CodeableConcept
        final substitutionCodeDisplay =
            FhirFieldExtractor.extractCodeableConceptText(
                substitution!.allowedCodeableConcept);
        ResourceFieldMapper.addIfNotNull(
          infoLines,
          ResourceFieldMapper.createStatusLine(substitutionCodeDisplay,
              prefix: 'Substitution'),
        );
      }
    }

    // Course of Therapy Type
    final courseDisplay =
        FhirFieldExtractor.extractCodeableConceptText(courseOfTherapyType);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createTimelineLine(courseDisplay,
          prefix: 'Course of Therapy'),
    );

    // Do Not Perform
    final doNotPerformValue = doNotPerform?.valueBoolean;
    if (doNotPerformValue == true) {
      ResourceFieldMapper.addIfNotNull(
        infoLines,
        ResourceFieldMapper.createWarningLine('Do NOT perform this request',
            prefix: '⚠️ Alert'),
      );
    }

    // Recorder
    final recorderDisplay =
        FhirFieldExtractor.extractReferenceDisplay(recorder);
    ResourceFieldMapper.addIfNotNull(
      infoLines,
      ResourceFieldMapper.createUserLine(recorderDisplay, prefix: 'Recorder'),
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
      subject?.reference?.valueString,
      encounter?.reference?.valueString,
      requester?.reference?.valueString,
      performer?.reference?.valueString,
      recorder?.reference?.valueString,
      priorPrescription?.reference?.valueString,
      ...?supportingInformation
          ?.map((reference) => reference.reference?.valueString),
      ...?reasonReference?.map((reference) => reference.reference?.valueString),
      ...?basedOn?.map((reference) => reference.reference?.valueString),
      ...?detectedIssue?.map((reference) => reference.reference?.valueString),
      ...?eventHistory?.map((reference) => reference.reference?.valueString),
    }.where((reference) => reference != null).toList();
  }

  @override
  String get statusDisplay => status?.valueString ?? '';
}
