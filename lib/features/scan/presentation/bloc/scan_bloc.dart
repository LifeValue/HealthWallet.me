import 'dart:async';
import 'dart:io';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:collection/collection.dart';
import 'package:flutter/widgets.dart' hide Notification;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:flutter_doc_scanner/flutter_doc_scanner.dart';
import 'package:health_wallet/core/config/constants/shared_prefs_constants.dart';
import 'package:health_wallet/core/navigation/app_router.dart';
import 'package:health_wallet/core/services/pdf_storage_service.dart';
import 'package:health_wallet/core/utils/logger.dart';
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
import 'package:health_wallet/features/scan/presentation/helpers/ocr_processing_helper.dart';
import 'package:health_wallet/features/scan/presentation/helpers/scan_path_helper.dart';
import 'package:health_wallet/features/sync/domain/repository/sync_repository.dart';
import 'package:health_wallet/features/sync/domain/services/source_type_service.dart';
import 'package:health_wallet/features/user/domain/services/patient_deduplication_service.dart';
import 'package:injectable/injectable.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

part 'scan_state.dart';
part 'scan_event.dart';
part 'scan_bloc.freezed.dart';

@LazySingleton()
class ScanBloc extends Bloc<ScanEvent, ScanState> {
  final PdfStorageService _pdfStorageService;
  final ScanRepository _repository;
  final OcrProcessingHelper _ocrProcessingHelper;
  final SyncRepository _syncRepository;
  final DocumentReferenceService _documentReferenceService;
  final PatientDeduplicationService _deduplicationService;
  final SourceTypeService _sourceTypeService;
  final RecordsRepository _recordsRepository;
  final SharedPreferences _prefs;

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
    on<ScanInitialised>(_onScanInitialised);
    on<ScanButtonPressed>(_onScanButtonPressed);
    on<DocumentImported>(_onDocumentImported);
    on<ScanSessionChangedProgress>(_onScanSessionChangedProgress);
    on<ScanSessionCleared>(_onScanSessionCleared);
    on<ScanSessionActivated>(_onScanSessionActivated);
    on<ScanMappingInitiated>(_onScanMappingInitiated,
        transformer: restartable());
    on<ScanResourceChanged>(_onScanResourceChanged);
    on<ScanResourceRemoved>(_onScanResourceRemoved);
    on<ScanResourceCreationInitiated>(_onScanResourceCreationInitiated);
    on<ScanNotificationAcknowledged>(_onScanNotificationAcknowledged);
    on<ScanMappingCancelled>(_onScanMappingCancelled);
    on<ScanResourcesAdded>(_onScanResourcesAdded);
    on<ScanEncounterAttached>(_onScanEncounterAttached);
    on<ScanProcessRemainingResources>(_onScanProcessRemainingResources);
    on<ScanDocumentAttached>(_onScanDocumentAttached);
    on<ScanTokenCapacityUpdated>(_onScanTokenCapacityUpdated);
    on<ScanVisionToggled>(_onScanVisionToggled);
    on<ScanPagesReordered>(_onScanPagesReordered);
  }

  bool _isCapacityError(String errorString) {
    final lower = errorString.toLowerCase();
    return lower.contains('maxtokens') ||
        lower.contains('input is too long') ||
        lower.contains('input_size') ||
        lower.contains('tokenization') ||
        lower.contains('prompt too long');
  }

  void _startNextPendingSession() {
    final pendingSession = state.sessions.firstWhereOrNull(
      (s) => s.status == ProcessingStatus.pending,
    );
    if (pendingSession != null) {
      add(ScanSessionActivated(sessionId: pendingSession.id));
    }
  }

  Future<void> _onScanInitialised(
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

  Future<void> _onScanButtonPressed(
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

  Future _createSession(
    Emitter<ScanState> emit, {
    required List<String> filePaths,
    required ProcessingOrigin origin,
  }) async {
    final session = await _repository.createProcessingSession(
        filePaths: filePaths, origin: origin);

    emit(state.copyWith(
      status: ScanStatus.sessionCreated(session: session),
      sessions: [session, ...state.sessions],
    ));
  }

  Future<void> _handlePdfScan(Emitter<ScanState> emit) async {
    final scannedPdf = await FlutterDocScanner().getScannedDocumentAsPdf();

    if (scannedPdf == null) {
      emit(state.copyWith(status: const ScanStatus.initial()));
      return;
    }

    final pdfPath = ScanPathHelper.extractPdfPath(scannedPdf);

    if (pdfPath == null || !_isValidScanResult(pdfPath)) {
      emit(state.copyWith(status: const ScanStatus.initial()));
      return;
    }
    final savedPath = await _pdfStorageService.savePdfToStorage(
      sourcePdfPath: pdfPath,
      customFileName:
          'health_scan_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );

    if (savedPath != null) {
      await _createSession(emit,
          filePaths: [savedPath], origin: ProcessingOrigin.scan);
    } else {
      emit(state.copyWith(
        status: const ScanStatus.failure(error: 'Failed to save PDF'),
      ));
    }
  }

  Future<void> _handleImageScan(int maxPages, Emitter<ScanState> emit) async {
    final scannedDocuments =
        await FlutterDocScanner().getScannedDocumentAsImages(
      page: maxPages,
    );

    if (scannedDocuments == null) {
      emit(state.copyWith(status: const ScanStatus.initial()));
      return;
    }

    final imagePaths = ScanPathHelper.normalizePaths(scannedDocuments);

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

    await _createSession(emit,
        filePaths: sessionPaths, origin: ProcessingOrigin.scan);
  }

  Future<void> _onDocumentImported(
    DocumentImported event,
    Emitter<ScanState> emit,
  ) async {
    emit(state.copyWith(status: const ScanStatus.loading()));
    try {
      final persistedPaths = <String>[];

      for (final filePath in event.filePaths) {
        final file = File(filePath);
        if (await file.exists()) {
          final persisted = await _persistImportedFile(file);
          persistedPaths.add(persisted);
        }
      }

      if (persistedPaths.isEmpty) {
        emit(state.copyWith(
          status: const ScanStatus.failure(error: 'No valid files found'),
        ));
        return;
      }

      final orderedPaths = persistedPaths.length > 1
          ? await _autoReorderByPageNumber(persistedPaths)
          : persistedPaths;

      await _createSession(emit,
          filePaths: orderedPaths, origin: ProcessingOrigin.import);
    } catch (e) {
      emit(state.copyWith(
        status: ScanStatus.failure(error: 'Failed to import document: $e'),
      ));
    }
  }

  Future<String> _persistImportedFile(File sourceFile) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final importsDir = Directory('${docsDir.path}/imports');
    if (!await importsDir.exists()) {
      await importsDir.create(recursive: true);
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final extension = p.extension(sourceFile.path);
    final baseName = p.basenameWithoutExtension(sourceFile.path);
    final fileName = '${baseName}_$timestamp$extension';
    final destPath = '${importsDir.path}/$fileName';

    await sourceFile.copy(destPath);
    return destPath;
  }

  Future<List<String>> _autoReorderByPageNumber(List<String> paths) async {
    try {
      final pagePattern = RegExp(
        r'(?:page|pagina|seite|p\.?)\s*(\d+)\s*(?:of|von|de|/)\s*(\d+)',
        caseSensitive: false,
      );

      final entries = <_PageEntry>[];

      for (int i = 0; i < paths.length; i++) {
        final text = await _ocrProcessingHelper
            .processOcrForImages([paths[i]]);
        final match = pagePattern.firstMatch(text);

        if (match != null) {
          final pageNum = int.tryParse(match.group(1)!);
          final totalPages = int.tryParse(match.group(2)!);
          if (pageNum != null && totalPages != null) {
            entries.add(_PageEntry(
              path: paths[i],
              pageNumber: pageNum,
              totalPages: totalPages,
              originalIndex: i,
            ));
            continue;
          }
        }
        entries.add(_PageEntry(
          path: paths[i],
          pageNumber: null,
          totalPages: null,
          originalIndex: i,
        ));
      }

      final detected = entries.where((e) => e.pageNumber != null).toList();
      if (detected.length < 2) return paths;

      final totals = detected.map((e) => e.totalPages).toSet();
      if (totals.length != 1) return paths;

      final expectedTotal = totals.first!;
      if (expectedTotal != paths.length) return paths;

      final pageNumbers = detected.map((e) => e.pageNumber!).toSet();
      if (pageNumbers.length != detected.length) return paths;

      if (pageNumbers.any((n) => n < 1 || n > expectedTotal)) return paths;

      entries.sort((a, b) {
        if (a.pageNumber != null && b.pageNumber != null) {
          return a.pageNumber!.compareTo(b.pageNumber!);
        }
        if (a.pageNumber != null) return -1;
        if (b.pageNumber != null) return 1;
        return a.originalIndex.compareTo(b.originalIndex);
      });

      return entries.map((e) => e.path).toList();
    } catch (_) {
      return paths;
    }
  }

  void _onScanSessionChangedProgress(
    ScanSessionChangedProgress event,
    Emitter<ScanState> emit,
  ) {
    final newSessions = [...state.sessions]
      ..removeWhere((session) => session.id == event.session.id);

    emit(state.copyWith(sessions: [event.session, ...newSessions]));

    if (event.session.status == ProcessingStatus.draft) {
      _repository.editProcessingSession(event.session);
    }
  }

  void _onScanSessionCleared(
    ScanSessionCleared event,
    Emitter<ScanState> emit,
  ) async {
    try {
      if (event.session.isProcessing) {
        emit(state.copyWith(
          status: const ScanStatus.loading(),
          deletingSessionId: event.session.id,
        ));

        try {
          await _repository.cancelGeneration();
          await _repository.waitForStreamCompletion();
        } catch (e) {
        }
      }

      final newSessions = [...state.sessions]
        ..removeWhere((session) => session.id == event.session.id);

      final updatedImageMap =
          Map<String, List<String>>.from(state.sessionImagePaths)
            ..remove(event.session.id);

      emit(state.copyWith(
        sessions: newSessions,
        sessionImagePaths: updatedImageMap,
        status: const ScanStatus.initial(),
        deletingSessionId: null,
      ));

      await _repository.deleteProcessingSession(event.session);

      final hasPendingSessions = newSessions.any(
        (s) => s.status == ProcessingStatus.pending,
      );

      if (hasPendingSessions) {
        await Future.delayed(const Duration(milliseconds: 100));
        _startNextPendingSession();
      }
    } on Exception catch (e) {
      emit(state.copyWith(
        status: ScanStatus.failure(error: e.toString()),
        deletingSessionId: null,
      ));
    }
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
      return 'Scanner error: ${error.message ?? 'Unknown error occurred'}';
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

  Future<void> _onScanSessionActivated(
    ScanSessionActivated event,
    Emitter<ScanState> emit,
  ) async {
    final anotherSessionProcessing = state.sessions.any(
      (s) => s.id != event.sessionId && s.isProcessing,
    );

    try {
      final session =
          state.sessions.firstWhere((s) => s.id == event.sessionId);
      final cachedImages = state.sessionImagePaths[event.sessionId];

      List<String> allImages;
      if (cachedImages != null && cachedImages.isNotEmpty) {
        allImages = cachedImages;
      } else {
        if (!anotherSessionProcessing) {
          emit(state.copyWith(status: const ScanStatus.convertingPdfs()));
        }
        allImages = await _ocrProcessingHelper.prepareAllImages(
          filePaths: session.filePaths,
        );
      }

      final updatedImageMap = Map<String, List<String>>.from(
        state.sessionImagePaths,
      )..[event.sessionId] = allImages;

      emit(state.copyWith(
        allImagePathsForOCR: allImages,
        sessionImagePaths: updatedImageMap,
      ));

      if (anotherSessionProcessing &&
          session.status != ProcessingStatus.draft) {
        return;
      }

      emit(state.copyWith(
        displayedSessionId: event.sessionId,
      ));

      if (session.status == ProcessingStatus.pending) {
        try {
          final isModelLoaded = await _repository.checkModelExistence();

          if (isModelLoaded) {
            add(ScanMappingInitiated(sessionId: event.sessionId));
          } else {
            emit(state.copyWith(status: const ScanStatus.initial()));
          }
        } catch (e) {
          emit(state.copyWith(status: const ScanStatus.initial()));
        }
      }
    } catch (e) {
      emit(state.copyWith(status: ScanStatus.failure(error: e.toString())));
    }
  }

  void _updateSession(
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

  void _onScanMappingInitiated(
    ScanMappingInitiated event,
    Emitter<ScanState> emit,
  ) async {
    emit(state.copyWith(status: const ScanStatus.loading()));
    final session =
        state.sessions.firstWhereOrNull((s) => s.id == event.sessionId);
    if (session == null) {
      return;
    }

    if (session.isProcessing || session.status == ProcessingStatus.draft) {
      return;
    }

    final anotherSessionProcessing = state.sessions.any(
      (s) => s.id != event.sessionId && s.isProcessing,
    );

    if (anotherSessionProcessing) return;

    try {
      _updateSession(
        emit,
        sessionId: event.sessionId,
        status: ProcessingStatus.processingPatient,
      );

      final sessionImages =
          state.sessionImagePaths[event.sessionId] ?? state.allImagePathsForOCR;

      if (sessionImages.isEmpty) {
        _updateSession(
          emit,
          sessionId: event.sessionId,
          status: ProcessingStatus.pending,
          progress: 0.0,
        );
        emit(state.copyWith(
          status: const ScanStatus.failure(
            error:
                'No images were generated from the scan. Please try scanning again.',
          ),
        ));
        return;
      }

      final medicalText =
          await _ocrProcessingHelper.processOcrForImages(sessionImages);

      if (medicalText.isEmpty || medicalText.trim().isEmpty) {
        _updateSession(
          emit,
          sessionId: event.sessionId,
          status: ProcessingStatus.draft,
        );
        return;
      }

      final savedMaxTokens = _prefs.getInt(SharedPrefsConstants.aiMaxTokens);
      final savedGpuLayers = _prefs.getInt(SharedPrefsConstants.aiGpuLayers);
      final savedThreads = _prefs.getInt(SharedPrefsConstants.aiThreads);
      final savedContextSize = _prefs.getInt(SharedPrefsConstants.aiContextSize);
      final (patient, container) = await _repository.mapBasicInfo(
        sessionImages,
        maxTokens: savedMaxTokens,
        gpuLayers: savedGpuLayers,
        threads: savedThreads,
        contextSize: savedContextSize,
      );
      debugPrint('[ScanAI] bloc: container type=${container.runtimeType}, isDiagnosticReport=${container is MappingDiagnosticReport}');

      StagedPatient stagedPatient;
      try {
        final allPatientsResources = await _recordsRepository.getResources(
          resourceTypes: [FhirType.Patient],
          limit: 1000,
        );
        final allPatients = allPatientsResources.whereType<Patient>().toList();

        final matchedPatient = _deduplicationService.findMatchingPatient(
          patient,
          allPatients,
        );

        if (matchedPatient != null) {
          stagedPatient = StagedPatient(
            existing: matchedPatient,
            mode: ImportMode.linkExisting,
          );
        } else {
          stagedPatient = StagedPatient(
            draft: patient,
            mode: ImportMode.createNew,
          );
        }
      } catch (e) {
        logger.e('Error matching patient: $e');
        stagedPatient = StagedPatient(
          draft: patient,
          mode: ImportMode.createNew,
        );
      }

      final finalSession =
          state.sessions.firstWhereOrNull((s) => s.id == event.sessionId);

      if (container is MappingDiagnosticReport) {
        _updateSession(
          emit,
          sessionId: event.sessionId,
          status: ProcessingStatus.patientExtracted,
          patient: stagedPatient,
          diagnosticReport: StagedDiagnosticReport(draft: container),
          updateDb: true,
        );
      } else {
        _updateSession(
          emit,
          sessionId: event.sessionId,
          status: ProcessingStatus.patientExtracted,
          patient: stagedPatient,
          encounter: StagedEncounter(draft: container as MappingEncounter),
          updateDb: true,
        );
      }

      final notification = Notification(
        text: "${finalSession?.origin ?? 'Document'} patient info extracted",
        route: ProcessingRoute(sessionId: event.sessionId),
        time: DateTime.now(),
      );

      emit(state.copyWith(
        notification: notification,
      ));

      _startNextPendingSession();
    } on Exception catch (e) {
      debugPrint('[ScanAI] _onScanMappingInitiated ERROR: $e');
      debugPrint('[ScanAI] isCapacityError: ${_isCapacityError(e.toString())}');
      debugPrint('[ScanAI] emit.isDone: ${emit.isDone}');
      _updateSession(
        emit,
        sessionId: event.sessionId,
        status: ProcessingStatus.pending,
        updateDb: true,
      );
      if (!emit.isDone) {
        if (_isCapacityError(e.toString())) {
          debugPrint('[ScanAI] emitting capacityFailure');
          emit(state.copyWith(
            status: ScanStatus.capacityFailure(sessionId: event.sessionId),
          ));
        } else {
          debugPrint('[ScanAI] emitting generic failure');
          emit(
              state.copyWith(status: ScanStatus.failure(error: e.toString())));
        }
      }
    }
  }

  void _onScanResourceRemoved(
    ScanResourceRemoved event,
    Emitter<ScanState> emit,
  ) {
    final activeSession =
        state.sessions.firstWhere((s) => s.id == event.sessionId);
    final newResources = [...activeSession.resources];
    newResources.removeAt(event.index);

    _updateSession(emit,
        sessionId: event.sessionId, resources: newResources, updateDb: true);
  }

  void _onScanResourceChanged(
    ScanResourceChanged event,
    Emitter<ScanState> emit,
  ) {
    final activeSession =
        state.sessions.firstWhere((s) => s.id == event.sessionId);

    if (event.isDraftPatient == true) {
      MappingPatient draftPatient =
          activeSession.patient.draft ?? const MappingPatient();

      _updateSession(
        emit,
        sessionId: event.sessionId,
        patient: activeSession.patient.copyWith(
            draft: draftPatient.copyWithMap({event.propertyKey: event.newValue})
                as MappingPatient),
      );
      return;
    }

    if (event.isDraftDiagnosticReport == true) {
      MappingDiagnosticReport draftReport =
          activeSession.diagnosticReport?.draft ??
              const MappingDiagnosticReport();

      _updateSession(
        emit,
        sessionId: event.sessionId,
        diagnosticReport: (activeSession.diagnosticReport ??
                const StagedDiagnosticReport())
            .copyWith(
                draft: draftReport
                        .copyWithMap({event.propertyKey: event.newValue})
                    as MappingDiagnosticReport),
      );
      return;
    }

    if (event.isDraftEncounter == true) {
      MappingEncounter draftEncounter =
          activeSession.encounter.draft ?? const MappingEncounter();

      _updateSession(
        emit,
        sessionId: event.sessionId,
        encounter: activeSession.encounter.copyWith(
            draft:
                draftEncounter.copyWithMap({event.propertyKey: event.newValue})
                    as MappingEncounter),
      );
      return;
    }

    MappingResource updatedResource =
        activeSession.resources[event.index].copyWithMap({
      event.propertyKey: event.newValue,
    });

    final newResources = [...activeSession.resources];
    newResources[event.index] = updatedResource;

    _updateSession(emit,
        sessionId: event.sessionId, resources: newResources, updateDb: true);
  }

  void _onScanResourceCreationInitiated(
    ScanResourceCreationInitiated event,
    Emitter<ScanState> emit,
  ) async {
    emit(state.copyWith(status: const ScanStatus.savingResources()));

    final activeSession =
        state.sessions.firstWhere((s) => s.id == event.sessionId);

    try {
      final (subjectId, sourceId, finalContainer, _) =
          await _persistPrimaryResources(activeSession);

      await _prefs.setString('selected_patient_id', subjectId);

      final otherResources = activeSession.resources
          .where((r) =>
              r is! MappingPatient &&
              r is! MappingEncounter &&
              r is! MappingDiagnosticReport)
          .toList();

      List<IFhirResource> fhirResources = otherResources
          .map((resource) => resource.toFhirResource(
                sourceId: sourceId,
                subjectId: subjectId,
                encounterId: finalContainer.id,
              ))
          .toList();

      if (fhirResources.isNotEmpty) {
        await _syncRepository.saveResources(fhirResources);
      }

      if (!activeSession.isDocumentAttached) {
        final encounterForDoc =
            finalContainer is Encounter ? finalContainer : null;
        await _documentReferenceService.saveGroupedDocumentsAsFhirRecords(
          filePaths: activeSession.filePaths,
          patientId: subjectId,
          encounter: encounterForDoc,
          sourceId: sourceId,
          title: finalContainer.displayTitle,
        );
      }

      emit(state.copyWith(status: const ScanStatus.success()));
    } catch (e) {
      logger.e('[ScanBloc] resource creation failed: $e');
      emit(state.copyWith(status: ScanStatus.failure(error: e.toString())));
    }
  }

  void _onScanNotificationAcknowledged(
    ScanNotificationAcknowledged event,
    Emitter<ScanState> emit,
  ) {
    emit(state.copyWith(notification: null));
  }

  void _onScanMappingCancelled(
    ScanMappingCancelled event,
    Emitter<ScanState> emit,
  ) async {
    final session =
        state.sessions.firstWhereOrNull((s) => s.id == event.sessionId);
    if (session == null) return;

    _updateSession(
      emit,
      sessionId: event.sessionId,
      status: session.status == ProcessingStatus.processing
          ? ProcessingStatus.patientExtracted
          : ProcessingStatus.cancelled,
      resources: [],
      progress: 0.0,
    );
    await _repository.disposeModel();
  }

  void _onScanResourcesAdded(
    ScanResourcesAdded event,
    Emitter<ScanState> emit,
  ) {
    final activeSession =
        state.sessions.firstWhere((s) => s.id == event.sessionId);

    final List<MappingResource> newResources = [];

    for (final resourceType in event.resourceTypes) {
      MappingResource newResource = MappingResource.empty(resourceType);

      newResources.add(newResource);
    }

    final updatedResources = [...activeSession.resources, ...newResources];
    _updateSession(
      emit,
      sessionId: event.sessionId,
      resources: updatedResources,
      updateDb: true,
    );
  }

  void _onScanEncounterAttached(
    ScanEncounterAttached event,
    Emitter<ScanState> emit,
  ) {
    _updateSession(
      emit,
      sessionId: event.sessionId,
      patient: event.patient,
      encounter: event.encounter,
      updateDb: true,
    );
  }

  void _onScanDocumentAttached(
    ScanDocumentAttached event,
    Emitter<ScanState> emit,
  ) async {
    final session =
        state.sessions.firstWhereOrNull((s) => s.id == event.sessionId);
    if (session == null) return;

    try {
      final (subjectId, sourceId, finalContainer, finalPatient) =
          await _persistPrimaryResources(session);

      final encounterForDoc =
          finalContainer is Encounter ? finalContainer : null;
      await _documentReferenceService.saveGroupedDocumentsAsFhirRecords(
        filePaths: session.filePaths,
        patientId: subjectId,
        encounter: encounterForDoc,
        sourceId: sourceId,
        title: finalContainer.displayTitle,
      );

      _updateSession(
        emit,
        sessionId: event.sessionId,
        isDocumentAttached: true,
        patient: StagedPatient(
            existing: finalPatient, mode: ImportMode.linkExisting),
        encounter: finalContainer is Encounter
            ? StagedEncounter(
                existing: finalContainer, mode: ImportMode.linkExisting)
            : null,
        updateDb: true,
      );
    } catch (e) {
      if (!emit.isDone) {
        emit(state.copyWith(status: ScanStatus.failure(error: e.toString())));
      }
    }
  }

  void _onScanProcessRemainingResources(
    ScanProcessRemainingResources event,
    Emitter<ScanState> emit,
  ) async {
    emit(state.copyWith(status: const ScanStatus.loading()));

    final session =
        state.sessions.firstWhereOrNull((s) => s.id == event.sessionId);
    if (session == null) return;

    final anotherSessionProcessing = state.sessions.any(
      (s) => s.id != event.sessionId && s.isProcessing,
    );

    if (anotherSessionProcessing) return;

    try {
      _updateSession(
        emit,
        sessionId: event.sessionId,
        status: ProcessingStatus.processing,
      );

      final sessionImages =
          state.sessionImagePaths[event.sessionId] ?? state.allImagePathsForOCR;

      final activeSession =
          state.sessions.firstWhereOrNull((s) => s.id == event.sessionId);
      final docCategory =
          activeSession?.isDiagnosticReportContainer == true
              ? 'lab_report'
              : 'visit';

      final savedMaxTokens = _prefs.getInt(SharedPrefsConstants.aiMaxTokens);
      final savedGpuLayers = _prefs.getInt(SharedPrefsConstants.aiGpuLayers);
      final savedThreads = _prefs.getInt(SharedPrefsConstants.aiThreads);
      final savedContextSize = _prefs.getInt(SharedPrefsConstants.aiContextSize);
      final useVision =
          _prefs.getBool(SharedPrefsConstants.aiUseVision) ?? false;
      Stream<MappingResourcesWithProgress> stream =
          _repository.mapRemainingResources(
        sessionImages,
        documentCategory: docCategory,
        useVision: useVision,
        maxTokens: savedMaxTokens,
        gpuLayers: savedGpuLayers,
        threads: savedThreads,
        contextSize: savedContextSize,
      );

      await for (final (resources, progress) in stream) {
        final currentSession =
            state.sessions.firstWhereOrNull((s) => s.id == event.sessionId);

        if (emit.isDone ||
            currentSession?.status != ProcessingStatus.processing) {
          return;
        }

        _updateSession(
          emit,
          sessionId: event.sessionId,
          resources: [...currentSession!.resources, ...resources],
          progress: progress,
          updateDb: true,
        );
      }

      _updateSession(
        emit,
        sessionId: event.sessionId,
        status: ProcessingStatus.draft,
        updateDb: true,
      );

      final notification = Notification(
        text: "${session.origin} processing finished",
        route: ProcessingRoute(sessionId: event.sessionId),
        time: DateTime.now(),
      );

      emit(state.copyWith(
        notification: notification,
      ));

      _startNextPendingSession();
    } catch (e) {
      final failedSession = state.sessions.firstWhereOrNull(
        (s) => s.id == event.sessionId,
      );
      _updateSession(
        emit,
        sessionId: event.sessionId,
        status: ProcessingStatus.patientExtracted,
        resources: failedSession?.resources,
        updateDb: true,
      );
      if (!emit.isDone) {
        if (_isCapacityError(e.toString())) {
          emit(state.copyWith(
            status: ScanStatus.capacityFailure(sessionId: event.sessionId),
          ));
        } else {
          emit(
              state.copyWith(status: ScanStatus.failure(error: e.toString())));
        }
      }
    }
  }

  void _onScanTokenCapacityUpdated(
    ScanTokenCapacityUpdated event,
    Emitter<ScanState> emit,
  ) async {
    await _prefs.setInt(
        SharedPrefsConstants.aiMaxTokens, event.newMaxTokens);
    await _repository.disposeModel();
    add(ScanMappingInitiated(sessionId: event.sessionId));
  }

  void _onScanVisionToggled(
    ScanVisionToggled event,
    Emitter<ScanState> emit,
  ) {
    _prefs.setBool(SharedPrefsConstants.aiUseVision, event.useVision);
    emit(state.copyWith(useVision: event.useVision));
  }

  Future<void> _onScanPagesReordered(
    ScanPagesReordered event,
    Emitter<ScanState> emit,
  ) async {
    final sessionIndex =
        state.sessions.indexWhere((s) => s.id == event.sessionId);
    if (sessionIndex == -1) return;

    final updatedSession =
        state.sessions[sessionIndex].copyWith(filePaths: event.reorderedPaths);
    final updatedSessions = [...state.sessions];
    updatedSessions[sessionIndex] = updatedSession;

    final updatedImageMap =
        Map<String, List<String>>.from(state.sessionImagePaths)
          ..[event.sessionId] = event.reorderedPaths;

    emit(state.copyWith(
      sessions: updatedSessions,
      sessionImagePaths: updatedImageMap,
    ));

    await _repository.editProcessingSession(updatedSession);
  }

  Future<(String, String, IFhirResource, Patient)> _persistPrimaryResources(
    ProcessingSession activeSession,
  ) async {
    String subjectId;
    String sourceId;
    List<IFhirResource> resourcesToSave = [];

    final availableSources = await _syncRepository.getSources();

    if (activeSession.patient.existing != null) {
      Patient existingPatient = activeSession.patient.existing!;

      final walletSource =
          await _sourceTypeService.ensureWalletSourceForPatient(
        patientId: existingPatient.id,
        patientName: existingPatient.displayTitle,
        availableSources: availableSources,
      );

      subjectId = existingPatient.id;
      sourceId = walletSource.id;
    } else {
      MappingPatient draftPatient = activeSession.patient.draft!;

      final walletSource =
          await _sourceTypeService.ensureWalletSourceForPatient(
        patientId: draftPatient.id,
        patientName:
            "${draftPatient.givenName.value} ${draftPatient.familyName.value}",
        availableSources: availableSources,
      );

      subjectId = draftPatient.id;
      sourceId = walletSource.id;

      resourcesToSave.add(draftPatient.toFhirResource(
        sourceId: sourceId,
        subjectId: '',
        encounterId: '',
      ));
    }

    IFhirResource finalContainer;
    if (activeSession.isDiagnosticReportContainer) {
      MappingDiagnosticReport draftReport =
          activeSession.diagnosticReport!.draft!;
      finalContainer = draftReport.toFhirResource(
        sourceId: sourceId,
        subjectId: subjectId,
        encounterId: draftReport.id,
      );
      resourcesToSave.add(finalContainer);
    } else if (activeSession.encounter.existing != null) {
      finalContainer = activeSession.encounter.existing!;
    } else {
      MappingEncounter draftEncounter = activeSession.encounter.draft!;
      finalContainer = draftEncounter.toFhirResource(
        sourceId: sourceId,
        subjectId: subjectId,
        encounterId: draftEncounter.id,
      );
      resourcesToSave.add(finalContainer);
    }

    if (resourcesToSave.isNotEmpty) {
      await _syncRepository.saveResources(resourcesToSave);
    }

    return (
      subjectId,
      sourceId,
      finalContainer,
      activeSession.patient.existing ??
          (resourcesToSave.firstWhere((r) => r is Patient) as Patient)
    );
  }
}

class _PageEntry {
  final String path;
  final int? pageNumber;
  final int? totalPages;
  final int originalIndex;

  _PageEntry({
    required this.path,
    required this.pageNumber,
    required this.totalPages,
    required this.originalIndex,
  });
}
