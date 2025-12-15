import 'dart:async';
import 'dart:io';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:collection/collection.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:flutter_doc_scanner/flutter_doc_scanner.dart';
import 'package:health_wallet/core/navigation/app_router.dart';
import 'package:health_wallet/core/services/pdf_storage_service.dart';
import 'package:health_wallet/features/notifications/domain/entities/notification.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/scan/domain/entity/mapping_resources/mapping_encounter.dart';
import 'package:health_wallet/features/scan/domain/entity/mapping_resources/mapping_patient.dart';
import 'package:health_wallet/features/scan/domain/entity/mapping_resources/mapping_resource.dart';
import 'package:health_wallet/features/scan/domain/entity/processing_session.dart';
import 'package:health_wallet/features/scan/domain/entity/staged_resource.dart';
import 'package:health_wallet/features/scan/domain/repository/scan_repository.dart';
import 'package:health_wallet/features/scan/domain/services/document_reference_service.dart';
import 'package:health_wallet/features/scan/presentation/helpers/ocr_processing_helper.dart';
import 'package:health_wallet/features/scan/presentation/helpers/scan_path_helper.dart';
import 'package:health_wallet/features/sync/domain/entities/source.dart';
import 'package:health_wallet/features/sync/domain/repository/sync_repository.dart';
import 'package:health_wallet/features/sync/domain/services/wallet_patient_service.dart';
import 'package:health_wallet/features/user/domain/services/patient_deduplication_service.dart';
import 'package:injectable/injectable.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'scan_state.dart';
part 'scan_event.dart';
part 'scan_bloc.freezed.dart';

@LazySingleton()
class ScanBloc extends Bloc<ScanEvent, ScanState> {
  final PdfStorageService _pdfStorageService;
  final ScanRepository _repository;
  final OcrProcessingHelper _ocrProcessingHelper;
  final WalletPatientService _walletPatientService;
  final SyncRepository _syncRepository;
  final DocumentReferenceService _documentReferenceService;
  final PatientDeduplicationService _deduplicationService;

  ScanBloc(
    this._pdfStorageService,
    this._repository,
    this._ocrProcessingHelper,
    this._walletPatientService,
    this._syncRepository,
    this._documentReferenceService,
    this._deduplicationService,
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
    on<ScanProcessingRestartRequested>(_onScanProcessingRestartRequested);
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

      emit(state.copyWith(
        sessions: sessions,
        status: const ScanStatus.initial(),
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
      final file = File(event.filePath);
      final exists = await file.exists();

      if (!exists) {
        emit(state.copyWith(
          status: const ScanStatus.failure(error: 'File does not exist'),
        ));
        return;
      }

      await _createSession(emit,
          filePaths: [event.filePath], origin: ProcessingOrigin.import);
    } catch (e) {
      emit(state.copyWith(
        status: ScanStatus.failure(error: 'Failed to import document: $e'),
      ));
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
      final newSessions = [...state.sessions]
        ..removeWhere((session) => session.id == event.session.id);
      final updatedImageMap =
          Map<String, List<String>>.from(state.sessionImagePaths)
            ..remove(event.session.id);

      emit(state.copyWith(
        sessions: newSessions,
        sessionImagePaths: updatedImageMap,
        status: const ScanStatus.initial(),
      ));

      await _repository.deleteProcessingSession(event.session);
    } on Exception catch (e) {
      emit(state.copyWith(status: ScanStatus.failure(error: e.toString())));
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
      (s) => s.id != event.sessionId && s.status == ProcessingStatus.processing,
    );

    try {
      final session = state.sessions.firstWhere((s) => s.id == event.sessionId);
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
            emit(state.copyWith(status: const ScanStatus.mapping()));
            add(ScanMappingInitiated(sessionId: event.sessionId));
          } else {
            emit(state.copyWith(status: const ScanStatus.initial()));
          }
        } catch (e) {
          emit(state.copyWith(status: const ScanStatus.initial()));
        }
      } else if (session.status == ProcessingStatus.processing) {
        emit(state.copyWith(status: const ScanStatus.mapping()));
      } else if (session.status == ProcessingStatus.draft) {
        emit(state.copyWith(status: const ScanStatus.editingResources()));
      }
    } catch (e) {
      emit(state.copyWith(status: ScanStatus.failure(error: e.toString())));
    }
  }

  void _onScanProcessingRestartRequested(
    ScanProcessingRestartRequested event,
    Emitter<ScanState> emit,
  ) {
    final session =
        state.sessions.firstWhereOrNull((s) => s.id == event.sessionId);
    if (session == null) {
      return;
    }

    _updateSession(
      emit,
      sessionId: event.sessionId,
      status: ProcessingStatus.pending,
      progress: 0.0,
      updateDb: true,
    );

    final cachedImages =
        state.sessionImagePaths[event.sessionId] ?? const <String>[];

    if (cachedImages.isEmpty) {
      add(ScanSessionActivated(sessionId: event.sessionId));
      return;
    }

    add(ScanMappingInitiated(sessionId: event.sessionId));
  }

  void _updateSession(
    Emitter<ScanState> emit, {
    required String sessionId,
    double? progress,
    ProcessingStatus? status,
    List<MappingResource>? resources,
    StagedPatient? patient,
    StagedEncounter? encounter,
    // since we don't have a continue/resume functionality in place
    // we only update the session in the db after the processing is done
    // so we don't have weird behaviour when closing and re-opening the app
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
    // Check if session exists and is in a valid state
    final session =
        state.sessions.firstWhereOrNull((s) => s.id == event.sessionId);
    if (session == null) {
      return;
    }

    // If session is already processing or draft, don't restart
    if (session.status == ProcessingStatus.processing) {
      return;
    }

    if (session.status == ProcessingStatus.draft) {
      emit(state.copyWith(status: const ScanStatus.editingResources()));
      return;
    }

    try {
      _updateSession(
        emit,
        sessionId: event.sessionId,
        status: ProcessingStatus.processing,
      );
      emit(state.copyWith(status: const ScanStatus.mapping()));

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
        emit(state.copyWith(status: const ScanStatus.editingResources()));
        return;
      }

      Stream<MappingResourcesWithProgress> stream =
          _repository.mapResources(medicalText);
      try {
        await for (final (resources, progress) in stream) {
          if (emit.isDone || state.status == const ScanStatus.cancelled()) {
            return;
          }
          final currentSession =
              state.sessions.firstWhereOrNull((s) => s.id == event.sessionId);
          if (currentSession == null) {
            return;
          }
          _updateSession(
            emit,
            sessionId: event.sessionId,
            resources: [...currentSession.resources, ...resources],
            progress: progress,
          );
        }
      } catch (e) {
        rethrow;
      }

      // All resources are now in the state. Get the final session object.
      final finalSession =
          state.sessions.firstWhere((s) => s.id == event.sessionId);
      List<MappingResource> updatedResources =
          List.from(finalSession.resources);

      // Stage patient and encounter
      final patient = updatedResources
          .firstWhereOrNull((resource) => resource is MappingPatient);
      if (patient != null) {
        updatedResources.removeWhere((resource) => resource is MappingPatient);
      }

      final encounter = updatedResources
          .firstWhereOrNull((resource) => resource is MappingEncounter);
      if (encounter != null) {
        updatedResources
            .removeWhere((resource) => resource is MappingEncounter);
      }
      // Update the session a final time with the cleaned resources and new status
      _updateSession(
        emit,
        sessionId: event.sessionId,
        resources: updatedResources,
        status: ProcessingStatus.draft,
        patient: StagedPatient(draft: patient as MappingPatient?),
        encounter: StagedEncounter(draft: encounter as MappingEncounter?),
        updateDb: true,
      );

      final notification = Notification(
        text: "${finalSession.origin} processing finished",
        route: ProcessingRoute(sessionId: event.sessionId),
        time: DateTime.now(),
      );

      emit(state.copyWith(
        status: const ScanStatus.editingResources(),
        notification: notification,
      ));

      _startNextPendingSession();
    } on Exception catch (e) {
      _updateSession(
        emit,
        sessionId: event.sessionId,
        status: ProcessingStatus.pending,
        updateDb: true,
      );
      if (!emit.isDone) {
        emit(state.copyWith(status: ScanStatus.failure(error: e.toString())));
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

    String encounterId;
    String subjectId;
    String sourceId;
    final activeSession =
        state.sessions.firstWhere((s) => s.id == event.sessionId);
    final draftResources = [...activeSession.resources];

    try {
      // If the patient / encounter is not an existing one, it will always be a draft
      // because of the guard we set when adding this event

      if (activeSession.patient.existing != null) {
        Patient existingPatient = activeSession.patient.existing!;
        List<String> patientSourceIds = await _deduplicationService
            .getSourceIdsForPatient(existingPatient.id);

        List<Source> sources = await _syncRepository.getSources();

        String? writableSourceId =
            patientSourceIds.firstWhereOrNull((sourceId) {
          final source = sources.firstWhere(
            (s) => s.id == sourceId,
            orElse: () => const Source(
                id: '', platformName: null, logo: null, labelSource: null),
          );
          return source.platformType == 'wallet';
        });

        if (writableSourceId == null) {
          final walletSource =
              await _walletPatientService.createWalletSourceForPatient(
            existingPatient.id,
            existingPatient.displayTitle,
          );

          await _syncRepository.cacheSources([walletSource]);

          writableSourceId = walletSource.id;
        }

        subjectId = existingPatient.id;
        sourceId = writableSourceId;
      } else {
        MappingPatient draftPatient = activeSession.patient.draft!;

        final walletSource =
            await _walletPatientService.createWalletSourceForPatient(
          draftPatient.id,
          "${draftPatient.givenName.value} ${draftPatient.familyName.value}",
        );

        await _syncRepository.cacheSources([walletSource]);

        draftResources.add(draftPatient);

        subjectId = draftPatient.id;
        sourceId = walletSource.id;
      }

      if (activeSession.encounter.existing != null) {
        encounterId = activeSession.encounter.existing!.id;
      } else {
        draftResources.add(activeSession.encounter.draft!);
        encounterId = activeSession.encounter.draft!.id;
      }

      List<IFhirResource> fhirResources = draftResources
          .map((resource) => resource.toFhirResource(
                sourceId: sourceId,
                subjectId: (resource is MappingPatient) ? '' : subjectId,
                encounterId: (resource is MappingEncounter) ? '' : encounterId,
              ))
          .toList();

      await _syncRepository.saveResources(fhirResources);

      Encounter finalEncounter = activeSession.encounter.existing ??
          fhirResources.firstWhere((resource) => resource is Encounter)
              as Encounter;
      await _documentReferenceService.saveGroupedDocumentsAsFhirRecords(
        filePaths: activeSession.filePaths,
        patientId: subjectId,
        encounter: finalEncounter,
        sourceId: sourceId,
        title: finalEncounter.displayTitle,
      );

      emit(state.copyWith(status: const ScanStatus.success()));
    } catch (e) {
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
    _updateSession(
      emit,
      sessionId: event.sessionId,
      status: ProcessingStatus.pending,
      resources: [],
      progress: 0.0,
    );
    await _repository.disposeModel();
    emit(state.copyWith(status: const ScanStatus.cancelled()));
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
}
