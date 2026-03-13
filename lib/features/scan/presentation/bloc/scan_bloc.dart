import 'dart:async';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:collection/collection.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_wallet/core/navigation/app_router.dart';
import 'package:health_wallet/core/services/pdf_storage_service.dart';
import 'package:health_wallet/features/notifications/domain/entities/notification.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/records/domain/repository/records_repository.dart';
import 'package:health_wallet/features/scan/domain/entity/mapping_resources/mapping_resource.dart';
import 'package:health_wallet/features/scan/domain/entity/processing_session.dart';
import 'package:health_wallet/features/scan/domain/entity/staged_resource.dart';
import 'package:health_wallet/features/scan/domain/repository/scan_repository.dart';
import 'package:health_wallet/features/scan/domain/services/document_reference_service.dart';
import 'package:health_wallet/features/scan/domain/services/ocr_processing_service.dart';
import 'package:health_wallet/features/scan/presentation/bloc/handlers/scan_processing_handler.dart';
import 'package:health_wallet/features/scan/presentation/bloc/handlers/scan_session_handler.dart';
import 'package:health_wallet/features/sync/domain/repository/sync_repository.dart';
import 'package:health_wallet/features/sync/domain/services/source_type_service.dart';
import 'package:health_wallet/features/user/domain/services/patient_deduplication_service.dart';
import 'package:injectable/injectable.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'scan_state.dart';
part 'scan_event.dart';
part 'scan_bloc.freezed.dart';

@LazySingleton()
class ScanBloc extends Bloc<ScanEvent, ScanState>
    with ScanSessionHandler, ScanProcessingHandler {
  final PdfStorageService _pdfStorageService;
  final ScanRepository _repository;
  final OcrProcessingHelper _ocrProcessingHelper;
  final SyncRepository _syncRepository;
  final DocumentReferenceService _documentReferenceService;
  final PatientDeduplicationService _deduplicationService;
  final SourceTypeService _sourceTypeService;
  final RecordsRepository _recordsRepository;
  final SharedPreferences _prefs;

  @override
  ScanRepository get scanRepository => _repository;

  @override
  OcrProcessingHelper get ocrProcessingHelper => _ocrProcessingHelper;

  @override
  PdfStorageService get pdfStorageService => _pdfStorageService;

  @override
  RecordsRepository get recordsRepository => _recordsRepository;

  @override
  SyncRepository get syncRepository => _syncRepository;

  @override
  DocumentReferenceService get documentReferenceService =>
      _documentReferenceService;

  @override
  PatientDeduplicationService get deduplicationService =>
      _deduplicationService;

  @override
  SourceTypeService get sourceTypeService => _sourceTypeService;

  @override
  SharedPreferences get prefs => _prefs;

  ScanBloc(
    this._pdfStorageService,
    this._repository,
    this._ocrProcessingHelper,
    this._syncRepository,
    this._documentReferenceService,
    this._deduplicationService,
    this._sourceTypeService,
    this._recordsRepository,
    this._prefs,
  ) : super(const ScanState()) {
    on<ScanInitialised>(onScanInitialised);
    on<ScanButtonPressed>(onScanButtonPressed);
    on<DocumentImported>(onDocumentImported);
    on<ScanSessionChangedProgress>(onScanSessionChangedProgress);
    on<ScanSessionCleared>(onScanSessionCleared);
    on<ScanSessionActivated>(onScanSessionActivated);
    on<ScanMappingInitiated>(onScanMappingInitiated,
        transformer: restartable());
    on<ScanResourceChanged>(onScanResourceChanged);
    on<ScanResourceRemoved>(onScanResourceRemoved);
    on<ScanResourceCreationInitiated>(onScanResourceCreationInitiated);
    on<ScanNotificationAcknowledged>(onScanNotificationAcknowledged);
    on<ScanMappingCancelled>(onScanMappingCancelled);
    on<ScanResourcesAdded>(onScanResourcesAdded);
    on<ScanEncounterAttached>(onScanEncounterAttached);
    on<ScanProcessRemainingResources>(onScanProcessRemainingResources);
    on<ScanDocumentAttached>(onScanDocumentAttached);
    on<ScanTokenCapacityUpdated>(onScanTokenCapacityUpdated);
    on<ScanVisionToggled>(onScanVisionToggled);
    on<ScanPagesReordered>(onScanPagesReordered);
  }

  @override
  bool isCapacityError(String errorString) {
    final lower = errorString.toLowerCase();
    return lower.contains('maxtokens') ||
        lower.contains('input is too long') ||
        lower.contains('input_size') ||
        lower.contains('tokenization') ||
        lower.contains('prompt too long');
  }

  @override
  void startNextPendingSession() {
    final pendingSession = state.sessions.firstWhereOrNull(
      (s) => s.status == ProcessingStatus.pending,
    );
    if (pendingSession != null) {
      add(ScanSessionActivated(sessionId: pendingSession.id));
    }
  }

  @override
  void updateSession(
    Emitter<ScanState> emit, {
    required String sessionId,
    double? progress,
    ProcessingStatus? status,
    List<MappingResource>? resources,
    StagedPatient? patient,
    StagedEncounter? encounter,
    StagedDiagnosticReport? diagnosticReport,
    bool? isDocumentAttached,
    bool updateDb = false,
  }) {
    final sessionIndex = state.sessions.indexWhere((s) => s.id == sessionId);
    if (sessionIndex == -1) return;

    final activeSession = state.sessions[sessionIndex];

    final updatedSession = activeSession.copyWith(
      progress: progress ?? activeSession.progress,
      status: status ?? activeSession.status,
      resources: resources ?? activeSession.resources,
      patient: patient ?? activeSession.patient,
      encounter: encounter ?? activeSession.encounter,
      diagnosticReport: diagnosticReport ?? activeSession.diagnosticReport,
      isDocumentAttached:
          isDocumentAttached ?? activeSession.isDocumentAttached,
    );

    if (updateDb) {
      _repository.editProcessingSession(updatedSession);
    }

    final newSessions = List<ProcessingSession>.from(state.sessions);
    newSessions[sessionIndex] = updatedSession;

    emit(state.copyWith(
      sessions: newSessions,
    ));
  }
}
