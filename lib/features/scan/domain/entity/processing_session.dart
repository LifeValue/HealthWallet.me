import 'dart:convert';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:health_wallet/core/data/local/app_database.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/features/records/domain/entity/encounter/encounter.dart';
import 'package:health_wallet/features/records/domain/entity/patient/patient.dart';
import 'package:health_wallet/features/scan/domain/entity/mapping_resources/mapping_encounter.dart';
import 'package:health_wallet/features/scan/domain/entity/mapping_resources/mapping_patient.dart';
import 'package:health_wallet/features/scan/domain/entity/mapping_resources/mapping_resource.dart';
import 'package:health_wallet/features/scan/domain/entity/staged_resource.dart';

part 'processing_session.freezed.dart';

@freezed
class ProcessingSession
    with _$ProcessingSession
    implements Comparable<ProcessingSession> {
  const ProcessingSession._();

  const factory ProcessingSession({
    @Default('') String id,
    @Default([]) List<String> filePaths,
    @Default(0) double progress,
    @Default([]) List<MappingResource> resources,
    @Default(ProcessingStatus.pending) ProcessingStatus status,
    @Default(ProcessingOrigin.scan) ProcessingOrigin origin,
    @Default(StagedPatient()) StagedPatient patient,
    @Default(StagedEncounter()) StagedEncounter encounter,
    @Default(false) bool isDocumentAttached,
    DateTime? createdAt,
  }) = _ProcessingSession;

  factory ProcessingSession.fromDto(ProcessingSessionDto dto) {
    final filePaths = (jsonDecode(dto.filePaths ?? '') as List<dynamic>)
        .cast<String>()
        .toList();

    final resources = (jsonDecode(dto.resources ?? '') as List<dynamic>)
        .map((json) => MappingResource.fromJson(json))
        .toList();

    final patient = stagedPatientFromJson(jsonDecode(dto.patient ?? ''));
    final encounter = stagedEncounterFromJson(jsonDecode(dto.encounter ?? ''));

    return ProcessingSession(
      id: dto.id,
      filePaths: filePaths,
      resources: resources,
      status: ProcessingStatus.fromString(dto.status ?? ''),
      origin: ProcessingOrigin.fromString(dto.origin ?? ''),
      isDocumentAttached: dto.isDocumentAttached ?? false,
      createdAt: dto.createdAt,
      patient: patient,
      encounter: encounter,
    );
  }

  ProcessingSessionsCompanion toDbCompanion() => ProcessingSessionsCompanion(
        id: drift.Value(id),
        filePaths: drift.Value(jsonEncode(filePaths)),
        status: drift.Value(status.toString()),
        origin: drift.Value(origin.toString()),
        isDocumentAttached: drift.Value(isDocumentAttached),
        resources: drift.Value(jsonEncode(
            resources.map((resource) => resource.toJson()).toList())),
        createdAt: drift.Value(createdAt!),
        patient: drift.Value(jsonEncode(stagedPatientToJson(patient))),
        encounter: drift.Value(jsonEncode(stagedEncounterToJson(encounter))),
      );

  @override
  int compareTo(ProcessingSession other) {
    if (isProcessing && !other.isProcessing) {
      return -1;
    }

    if (!isProcessing && other.isProcessing) {
      return 1;
    }

    return other.createdAt!.compareTo(createdAt!);
  }

  bool get isProcessing =>
      status == ProcessingStatus.processingPatient ||
      status == ProcessingStatus.processing;
}

enum ProcessingStatus {
  pending,
  processingPatient,
  patientExtracted,
  processing,
  draft,
  cancelled;

  factory ProcessingStatus.fromString(String string) {
    switch (string) {
      case "Processing":
        return ProcessingStatus.processing;
      case "Draft":
        return ProcessingStatus.draft;
      case "Cancelled":
        return ProcessingStatus.cancelled;
      case "Processing Patient":
        return ProcessingStatus.processingPatient;
      case "Patient Extracted":
        return ProcessingStatus.patientExtracted;
      default:
        return ProcessingStatus.pending;
    }
  }

  @override
  String toString() {
    switch (this) {
      case ProcessingStatus.pending:
        return "Pending";
      case ProcessingStatus.processingPatient:
        return "Processing Patient";
      case ProcessingStatus.patientExtracted:
        return "Patient Extracted";
      case ProcessingStatus.processing:
        return "Processing";
      case ProcessingStatus.draft:
        return "Draft";
      case ProcessingStatus.cancelled:
        return "Cancelled";
    }
  }

  Color getColor(BuildContext context) {
    switch (this) {
      case ProcessingStatus.pending:
        return context.colorScheme.secondary;
      case ProcessingStatus.processing:
      case ProcessingStatus.draft:
      case ProcessingStatus.processingPatient:
      case ProcessingStatus.patientExtracted:
        return context.colorScheme.primary;
      case ProcessingStatus.cancelled:
        return context.colorScheme.error;
    }
  }
}

enum ProcessingOrigin {
  scan,
  import;

  factory ProcessingOrigin.fromString(String string) {
    switch (string) {
      case "Import":
        return ProcessingOrigin.import;
      default:
        return ProcessingOrigin.scan;
    }
  }

  @override
  String toString() {
    switch (this) {
      case ProcessingOrigin.scan:
        return "Scan";
      case ProcessingOrigin.import:
        return "Import";
    }
  }
}
