import 'dart:convert';
import 'dart:developer';
import 'dart:ui';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:health_wallet/core/data/local/app_database.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/features/scan/domain/entity/mapping_resources/mapping_resource.dart';

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
    DateTime? createdAt,
  }) = _ProcessingSession;

  factory ProcessingSession.fromDto(ProcessingSessionDto dto) {
    final filePaths = (jsonDecode(dto.filePaths ?? '') as List<dynamic>)
        .cast<String>()
        .toList();

    final resources = (jsonDecode(dto.resources ?? '') as List<dynamic>)
        .map((json) => MappingResource.fromJson(json))
        .toList();

    return ProcessingSession(
      id: dto.id,
      filePaths: filePaths,
      resources: resources,
      status: ProcessingStatus.fromString(dto.status ?? ''),
      origin: ProcessingOrigin.fromString(dto.origin ?? ''),
      createdAt: dto.createdAt,
    );
  }

  ProcessingSessionsCompanion toDbCompanion() => ProcessingSessionsCompanion(
        id: drift.Value(id),
        filePaths: drift.Value(jsonEncode(filePaths)),
        status: drift.Value(status.toString()),
        origin: drift.Value(origin.toString()),
        resources: drift.Value(jsonEncode(
            resources.map((resource) => resource.toJson()).toList())),
        createdAt: drift.Value(createdAt!),
      );

  @override
  int compareTo(ProcessingSession other) {
    if (status == ProcessingStatus.processing &&
        other.status != ProcessingStatus.processing) {
      return -1;
    }

    if (status != ProcessingStatus.processing &&
        other.status == ProcessingStatus.processing) {
      return 1;
    }

    return other.createdAt!.compareTo(createdAt!);
  }
}

enum ProcessingStatus {
  pending,
  processing,
  draft;

  factory ProcessingStatus.fromString(String string) {
    switch (string) {
      case "Processing":
        return ProcessingStatus.processing;
      case "Draft":
        return ProcessingStatus.draft;
      default:
        return ProcessingStatus.pending;
    }
  }

  @override
  String toString() {
    switch (this) {
      case ProcessingStatus.pending:
        return "Pending";
      case ProcessingStatus.processing:
        return "Processing";
      case ProcessingStatus.draft:
        return "Draft";
    }
  }

  Color getColor(BuildContext context) {
    switch (this) {
      case ProcessingStatus.pending:
        return context.colorScheme.secondary;
      case ProcessingStatus.processing:
        return context.colorScheme.primary;
      case ProcessingStatus.draft:
        return context.colorScheme.primary;
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
