import 'dart:async';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:collection/collection.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_doc_scanner/flutter_doc_scanner.dart';
import 'package:health_wallet/core/config/constants/shared_prefs_constants.dart';
import 'package:health_wallet/core/navigation/app_router.dart';
import 'package:health_wallet/core/services/pdf_storage_service.dart';
import 'package:health_wallet/features/notifications/domain/entities/notification.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/records/domain/repository/records_repository.dart';
import 'package:health_wallet/features/scan/domain/entity/mapping_resources/mapping_diagnostic_report.dart';
import 'package:health_wallet/features/scan/domain/entity/mapping_resources/mapping_encounter.dart';
import 'package:health_wallet/features/scan/domain/entity/mapping_resources/mapping_patient.dart';
import 'package:health_wallet/features/scan/domain/entity/mapping_resources/mapping_resource.dart';
import 'package:health_wallet/features/scan/domain/entity/processing_session.dart';
import 'package:health_wallet/features/scan/domain/entity/staged_resource.dart';
import 'package:health_wallet/features/scan/domain/repository/scan_repository.dart';
import 'package:health_wallet/features/scan/domain/services/document_reference_service.dart';
import 'package:health_wallet/features/scan/domain/services/ocr_processing_service.dart';
import 'package:health_wallet/features/scan/presentation/bloc/handlers/scan_processing_handler.dart';
import 'package:health_wallet/features/scan/presentation/bloc/handlers/scan_session_handler.dart';
import 'package:health_wallet/features/scan/presentation/helpers/scan_path_helper.dart';
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

  Future<void> onScanInitialised(
    ScanInitialised event,
    Emitter<ScanState> emit,
  ) async {
    emit(state.copyWith(status: const ScanStatus.loading()));

    try {
      final sessions = await _repository.getProcessingSessions();

      final useVision =
          _prefs.getBool(SharedPrefsConstants.aiUseVision) ?? false;
      emit(state.copyWith(
        sessions: sessions,
        status: const ScanStatus.initial(),
        useVision: useVision,
      ));
    } on Exception catch (e) {
      emit(state.copyWith(status: ScanStatus.failure(error: e.toString())));
    }
  }

  Future<void> onScanButtonPressed(
    ScanButtonPressed event,
    Emitter<ScanState> emit,
  ) async {
    emit(state.copyWith(status: const ScanStatus.loading()));

    try {
      if (event.mode == ScanMode.pdf) {
        await _handlePdfScan(emit);
      } else {
        await _handleImageScan(event.maxPages, emit);
      }
    } on PlatformException catch (e) {
      final errorMessage = _parsePlatformError(e);
      emit(state.copyWith(
        status: ScanStatus.failure(error: errorMessage),
      ));
    } catch (e) {
      final errorMessage = _parseGeneralError(e);
      emit(state.copyWith(
        status: ScanStatus.failure(error: errorMessage),
      ));
    }
  }

  void onScanNotificationAcknowledged(
    ScanNotificationAcknowledged event,
    Emitter<ScanState> emit,
  ) {
    emit(state.copyWith(notification: null));
  }

  void onScanTokenCapacityUpdated(
    ScanTokenCapacityUpdated event,
    Emitter<ScanState> emit,
  ) async {
    await _prefs.setInt(
        SharedPrefsConstants.aiMaxTokens, event.newMaxTokens);
    await _repository.disposeModel();
    add(ScanMappingInitiated(sessionId: event.sessionId));
  }

  void onScanVisionToggled(
    ScanVisionToggled event,
    Emitter<ScanState> emit,
  ) {
    _prefs.setBool(SharedPrefsConstants.aiUseVision, event.useVision);
    emit(state.copyWith(useVision: event.useVision));
  }

  Future<void> _handlePdfScan(Emitter<ScanState> emit) async {
    final scannedResult = await FlutterDocScanner().getScannedDocumentAsPdf();

    if (scannedResult == null) {
      emit(state.copyWith(status: const ScanStatus.initial()));
      return;
    }

    final pdfPath = scannedResult.pdfUri;
    if (pdfPath.isEmpty || !_isValidScanResult(pdfPath)) {
      emit(state.copyWith(status: const ScanStatus.initial()));
      return;
    }

    final savedPath = await _pdfStorageService.savePdfToStorage(
      sourcePdfPath: pdfPath,
      customFileName:
          'health_scan_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );

    if (savedPath != null) {
      await createSession(emit,
          filePaths: [savedPath], origin: ProcessingOrigin.scan);
    } else {
      emit(state.copyWith(
        status: const ScanStatus.failure(error: 'Failed to save PDF'),
      ));
    }
  }

  Future<void> _handleImageScan(int maxPages, Emitter<ScanState> emit) async {
    final scannedResult =
        await FlutterDocScanner().getScannedDocumentAsImages(
      page: maxPages,
    );

    if (scannedResult == null) {
      emit(state.copyWith(status: const ScanStatus.initial()));
      return;
    }

    final imagePaths = scannedResult.images
        .where((path) => path.isNotEmpty)
        .toList();

    if (imagePaths.isEmpty || !_isValidScanResult(imagePaths.first)) {
      emit(state.copyWith(status: const ScanStatus.initial()));
      return;
    }

    final persistedPaths = await ScanPathHelper.persistScanFiles(
      sourcePaths: imagePaths,
      repository: _repository,
    );
    final sessionPaths =
        persistedPaths.isNotEmpty ? persistedPaths : imagePaths;

    await createSession(emit,
        filePaths: sessionPaths, origin: ProcessingOrigin.scan);
  }

  bool _isValidScanResult(String path) {
    return !path.contains('Failed') && !path.contains('Unknown');
  }

  String _parsePlatformError(PlatformException error) {
    final code = error.code.toLowerCase();
    final message = error.message?.toLowerCase() ?? '';

    if (code.contains('permission') || message.contains('permission')) {
      return 'Camera permission is required. Please allow camera access when prompted.';
    } else if (code.contains('cancel') || message.contains('cancel')) {
      return 'Document scanning was cancelled';
    } else if (code.contains('unavailable') ||
        message.contains('unavailable')) {
      return 'Document scanner is not available on this device';
    } else {
      return 'Scanner error: ${error.message ?? "Unknown error occurred"}';
    }
  }

  String _parseGeneralError(dynamic error) {
    final errorString = error.toString().toLowerCase();

    if (errorString.contains('user') && errorString.contains('cancel')) {
      return 'Document scanning was cancelled';
    } else if (errorString.contains('permission')) {
      return 'Camera permission is required. Please allow camera access.';
    } else if (errorString.contains('camera')) {
      return 'Unable to access camera. Please ensure your camera is working.';
    } else {
      return 'Failed to scan. Please try again.';
    }
  }
}
