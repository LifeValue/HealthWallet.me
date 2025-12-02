import 'dart:async';
import 'dart:io';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:collection/collection.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:flutter_doc_scanner/flutter_doc_scanner.dart';
import 'package:health_wallet/core/navigation/app_router.dart';
import 'package:health_wallet/core/services/pdf_storage_service.dart';
import 'package:health_wallet/core/utils/logger.dart';
import 'package:health_wallet/features/home/domain/entities/wallet_notification.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/scan/domain/entity/mapping_resources/mapping_allergy_intolerance.dart';
import 'package:health_wallet/features/scan/domain/entity/mapping_resources/mapping_condition.dart';
import 'package:health_wallet/features/scan/domain/entity/mapping_resources/mapping_diagnostic_report.dart';
import 'package:health_wallet/features/scan/domain/entity/mapping_resources/mapping_encounter.dart';
import 'package:health_wallet/features/scan/domain/entity/mapping_resources/mapping_medication_statement.dart';
import 'package:health_wallet/features/scan/domain/entity/mapping_resources/mapping_observation.dart';
import 'package:health_wallet/features/scan/domain/entity/mapping_resources/mapping_organization.dart';
import 'package:health_wallet/features/scan/domain/entity/mapping_resources/mapping_patient.dart';
import 'package:health_wallet/features/scan/domain/entity/mapping_resources/mapping_practitioner.dart';
import 'package:health_wallet/features/scan/domain/entity/mapping_resources/mapping_procedure.dart';
import 'package:health_wallet/features/scan/domain/entity/mapping_resources/mapping_resource.dart';
import 'package:health_wallet/features/scan/domain/entity/processing_session.dart';
import 'package:health_wallet/features/scan/domain/repository/scan_repository.dart';
import 'package:health_wallet/features/scan/domain/services/document_reference_service.dart';
import 'package:health_wallet/features/scan/presentation/helpers/ocr_processing_helper.dart';
import 'package:health_wallet/features/sync/domain/entities/source.dart';
import 'package:health_wallet/features/sync/domain/repository/sync_repository.dart';
import 'package:health_wallet/features/sync/domain/services/wallet_patient_service.dart';
import 'package:health_wallet/features/user/domain/services/patient_deduplication_service.dart';
import 'package:injectable/injectable.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:uuid/uuid.dart';

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

  ScanBloc(
    this._pdfStorageService,
    this._repository,
    this._ocrProcessingHelper,
    this._walletPatientService,
    this._syncRepository,
    this._documentReferenceService,
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
    on<ScanPatientSelected>(_onScanPatientSelected);
    on<ScanResourceCreationInitiated>(_onScanResourceCreationInitiated);
    on<ScanNotificationAcknowledged>(_onScanNotificationAcknowledged);
    on<ScanMappingCancelled>(_onScanMappingCancelled);
    on<ScanResourceAdded>(_onScanResourceAdded);
    on<ResourcesAdded>(_onResourcesAdded);
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

    if (scannedPdf == null || !_isValidScanResult(scannedPdf)) {
      emit(state.copyWith(status: const ScanStatus.initial()));
      return;
    }
    final savedPath = await _pdfStorageService.savePdfToStorage(
      sourcePdfPath: scannedPdf,
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

    final imagePaths = _normalizeImagePaths(scannedDocuments);

    if (imagePaths.isEmpty || !_isValidScanResult(imagePaths.first)) {
      emit(state.copyWith(status: const ScanStatus.initial()));
      return;
    }

    await _createSession(emit,
        filePaths: imagePaths, origin: ProcessingOrigin.scan);
  }

  Future<void> _onDocumentImported(
    DocumentImported event,
    Emitter<ScanState> emit,
  ) async {
    logger.d('_onDocumentImported - START: ${event.filePath}');
    emit(state.copyWith(status: const ScanStatus.loading()));
    try {
      final file = File(event.filePath);
      final exists = await file.exists();
      logger.d('_onDocumentImported - File exists: $exists');

      if (!exists) {
        logger.d('_onDocumentImported - File does not exist, returning error');
        emit(state.copyWith(
          status: const ScanStatus.failure(error: 'File does not exist'),
        ));
        return;
      }

      final fileSize = await file.length();
      logger.d('_onDocumentImported - File size: $fileSize bytes');

      logger.d('_onDocumentImported - Creating session...');
      await _createSession(emit,
          filePaths: [event.filePath], origin: ProcessingOrigin.import);
      logger.d('_onDocumentImported - Session created successfully');
    } catch (e, stackTrace) {
      logger.e(
          '_onDocumentImported - Error importing document: ${event.filePath}',
          e,
          stackTrace);
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
        allImagePathsForOCR: state.activeSessionId == event.session.id
            ? []
            : state.allImagePathsForOCR,
      ));

      await _repository.deleteProcessingSession(event.session);
    } on Exception catch (e) {
      emit(state.copyWith(status: ScanStatus.failure(error: e.toString())));
    }
  }

  List<String> _normalizeImagePaths(dynamic scannedDocuments) {
    if (scannedDocuments is List) {
      return scannedDocuments.cast<String>();
    } else if (scannedDocuments is String) {
      return [scannedDocuments];
    } else {
      return [scannedDocuments.toString()];
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
    final isSameSession = state.activeSessionId == event.sessionId;
    final alreadyProcessing = state.status == const ScanStatus.mapping() ||
        state.status == const ScanStatus.editingResources();

    if (isSameSession && alreadyProcessing) {
      logger.d(
          '_onScanSessionActivated - Skipping re-activation: session already processing/editing');
      return;
    }

    logger.d('_onScanSessionActivated - START: sessionId=${event.sessionId}');
    try {
      logger.d('_onScanSessionActivated - Emitting convertingPdfs status');
      emit(state.copyWith(status: const ScanStatus.convertingPdfs()));

      logger.d('_onScanSessionActivated - Finding session...');
      final session = state.sessions.firstWhere((s) => s.id == event.sessionId);
      logger.d(
          '_onScanSessionActivated - Session found: filePaths=${session.filePaths}');

      final cachedImages = state.sessionImagePaths[event.sessionId];
      List<String> allImages;
      if (cachedImages != null && cachedImages.isNotEmpty) {
        logger.d(
            '_onScanSessionActivated - Using cached images for session ${event.sessionId}');
        allImages = cachedImages;
      } else {
        logger.d('_onScanSessionActivated - Preparing images...');
        allImages = await _ocrProcessingHelper.prepareAllImages(
          filePaths: session.filePaths,
        );
        logger.d(
            '_onScanSessionActivated - Images prepared: count=${allImages.length}');
      }

      final updatedImageMap = Map<String, List<String>>.from(
        state.sessionImagePaths,
      )..[event.sessionId] = allImages;

      emit(state.copyWith(
        allImagePathsForOCR: allImages,
        sessionImagePaths: updatedImageMap,
      ));
      logger.d(
          '_onScanSessionActivated - allImagePathsForOCR updated, sessionImagePaths stored');

      emit(state.copyWith(
        activeSessionId: event.sessionId,
        currentPatients: event.currentPatients,
        selectedPatient: event.currentPatients.first,
      ));
      logger.d('_onScanSessionActivated - State updated with session info');

      logger.d('_onScanSessionActivated - Session status: ${session.status}');
      if (session.status == ProcessingStatus.pending) {
        logger.d('_onScanSessionActivated - Auto-starting processing...');
        emit(state.copyWith(status: const ScanStatus.mapping()));
        await Future.delayed(const Duration(seconds: 1));
        if (!emit.isDone) {
          logger
              .d('_onScanSessionActivated - Adding ScanMappingInitiated event');
          add(ScanMappingInitiated(sessionId: event.sessionId));
        }
      } else if (session.status == ProcessingStatus.processing) {
        emit(state.copyWith(status: const ScanStatus.mapping()));
      } else if (session.status == ProcessingStatus.draft) {
        emit(state.copyWith(status: const ScanStatus.editingResources()));
      }
      logger.d('_onScanSessionActivated - COMPLETE');
    } catch (e, stackTrace) {
      logger.e('_onScanSessionActivated - ERROR: $e', e, stackTrace);
      emit(state.copyWith(status: ScanStatus.failure(error: e.toString())));
    }
  }

  void _updateSession(
    Emitter<ScanState> emit, {
    required String sessionId,
    double? progress,
    ProcessingStatus? status,
    List<MappingResource>? resources,
    bool updateDb = false,
  }) {
    final sessionIndex = state.sessions.indexWhere((s) => s.id == sessionId);
    if (sessionIndex == -1) return;

    final activeSession = state.sessions[sessionIndex];

    final updatedSession = activeSession.copyWith(
      progress: progress ?? activeSession.progress,
      status: status ?? activeSession.status,
      resources: resources ?? activeSession.resources,
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
    try {
      _updateSession(
        emit,
        sessionId: event.sessionId,
        status: ProcessingStatus.processing,
        updateDb: true,
      );
      emit(state.copyWith(status: const ScanStatus.mapping()));

      final sessionImages =
          state.sessionImagePaths[event.sessionId] ?? state.allImagePathsForOCR;
      final medicalText =
          await _ocrProcessingHelper.processOcrForImages(sessionImages);

      final stream = _repository.mapResources(medicalText);

      await for (final (resources, progress) in stream) {
        if (emit.isDone) return;
        final currentSession =
            state.sessions.firstWhere((s) => s.id == event.sessionId);
        _updateSession(
          emit,
          sessionId: event.sessionId,
          resources: [...currentSession.resources, ...resources],
          progress: progress,
        );
      }

      // All resources are now in the state. Get the final session object.
      final finalSession =
          state.sessions.firstWhere((s) => s.id == event.sessionId);
      List<MappingResource> updatedResources =
          List.from(finalSession.resources);

      // De-duplicate patients if necessary
      final patients = updatedResources.whereType<MappingPatient>().toList();
      if (patients.length > 1) {
        updatedResources.removeWhere((resource) => resource is MappingPatient);
        updatedResources.insert(0, patients.first);
      }

      // Ensure an encounter exists
      if (!updatedResources.any((resource) => resource is MappingEncounter)) {
        updatedResources.add(MappingEncounter(id: const Uuid().v4()));
      }

      // Update the session a final time with the cleaned resources and new status
      _updateSession(
        emit,
        sessionId: event.sessionId,
        resources: updatedResources,
        status: ProcessingStatus.draft,
        updateDb: true,
      );

      final notification = WalletNotification(
        text: "${finalSession.origin} processing finished",
        route: ProcessingRoute(sessionId: event.sessionId),
        time: DateTime.now(),
      );

      emit(state.copyWith(
        status: const ScanStatus.editingResources(),
        notification: notification,
      ));
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
    MappingResource updatedResource =
        activeSession.resources[event.index].copyWithMap({
      event.propertyKey: event.newValue,
    });

    final newResources = [...activeSession.resources];
    newResources[event.index] = updatedResource;

    _updateSession(emit,
        sessionId: event.sessionId, resources: newResources, updateDb: true);
  }

  void _onScanPatientSelected(
    ScanPatientSelected event,
    Emitter<ScanState> emit,
  ) {
    emit(state.copyWith(selectedPatient: event.patientGroup));
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

    try {
      MappingPatient? mappingPatient =
          activeSession.resources.whereType<MappingPatient>().firstOrNull;

      MappingEncounter mappingEncounter =
          activeSession.resources.whereType<MappingEncounter>().first;
      encounterId = mappingEncounter.id;

      if (mappingPatient != null) {
        subjectId = mappingPatient.id;
        final walletSource =
            await _walletPatientService.createWalletSourceForPatient(
          subjectId,
          "${mappingPatient.givenName.value} ${mappingPatient.familyName.value}",
        );

        await _syncRepository.cacheSources([walletSource]);

        sourceId = walletSource.id;
      } else {
        PatientGroup selectedPatientGroup = state.selectedPatient!;

        List<Source> sources = await _syncRepository.getSources();

        String? writableSourceId =
            selectedPatientGroup.sourceIds.firstWhereOrNull((sourceId) {
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
            selectedPatientGroup.patientId,
            selectedPatientGroup.representativePatient.title,
          );

          await _syncRepository.cacheSources([walletSource]);

          writableSourceId = walletSource.id;
        }

        sourceId = writableSourceId;
        subjectId = selectedPatientGroup.patientId;
      }

      List<IFhirResource> fhirResources = activeSession.resources
          .map((resource) => resource.toFhirResource(
                sourceId: sourceId,
                subjectId: (resource is MappingPatient) ? '' : subjectId,
                encounterId: (resource is MappingEncounter) ? '' : encounterId,
              ))
          .toList();

      await _syncRepository.saveResources(fhirResources);

      await _documentReferenceService.saveGroupedDocumentsAsFhirRecords(
        filePaths: activeSession.filePaths,
        patientId: subjectId,
        encounterId: encounterId,
        sourceId: sourceId,
        title: activeSession.resources
            .whereType<MappingEncounter>()
            .first
            .encounterType
            .value,
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
  ) {
    _updateSession(
      emit,
      sessionId: event.sessionId,
      status: ProcessingStatus.pending,
      progress: 0.0,
      updateDb: true,
    );
    emit(state.copyWith(status: const ScanStatus.cancelled()));
  }

  void _onScanResourceAdded(
    ScanResourceAdded event,
    Emitter<ScanState> emit,
  ) {
    final activeSession =
        state.sessions.firstWhere((s) => s.id == event.sessionId);

    MappingResource newResource;
    final newId = const Uuid().v4();

    switch (event.resourceType) {
      case 'AllergyIntolerance':
        newResource = MappingAllergyIntolerance(id: newId);
        break;
      case 'Condition':
        newResource = MappingCondition(id: newId);
        break;
      case 'DiagnosticReport':
        newResource = MappingDiagnosticReport(id: newId);
        break;
      case 'MedicationStatement':
        newResource = MappingMedicationStatement(id: newId);
        break;
      case 'Observation':
        newResource = MappingObservation(id: newId);
        break;
      case 'Organization':
        newResource = MappingOrganization(id: newId);
        break;
      case 'Practitioner':
        newResource = MappingPractitioner(id: newId);
        break;
      case 'Procedure':
        newResource = MappingProcedure(id: newId);
        break;
      default:
        return;
    }

    final newResources = [...activeSession.resources, newResource];
    _updateSession(
      emit,
      sessionId: event.sessionId,
      resources: newResources,
      updateDb: true,
    );
  }

  void _onResourcesAdded(
    ResourcesAdded event,
    Emitter<ScanState> emit,
  ) {
    final activeSession =
        state.sessions.firstWhere((s) => s.id == event.sessionId);

    final List<MappingResource> newResources = [];

    for (final resourceType in event.resourceTypes) {
      MappingResource? newResource;
      final newId = const Uuid().v4();

      switch (resourceType) {
        case 'AllergyIntolerance':
          newResource = MappingAllergyIntolerance(id: newId);
          break;
        case 'Condition':
          newResource = MappingCondition(id: newId);
          break;
        case 'DiagnosticReport':
          newResource = MappingDiagnosticReport(id: newId);
          break;
        case 'MedicationStatement':
          newResource = MappingMedicationStatement(id: newId);
          break;
        case 'Observation':
          newResource = MappingObservation(id: newId);
          break;
        case 'Organization':
          newResource = MappingOrganization(id: newId);
          break;
        case 'Practitioner':
          newResource = MappingPractitioner(id: newId);
          break;
        case 'Procedure':
          newResource = MappingProcedure(id: newId);
          break;
        default:
          continue;
      }

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
}
