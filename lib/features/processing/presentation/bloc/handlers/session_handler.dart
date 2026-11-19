import 'dart:io';

import 'package:collection/collection.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_doc_scanner/flutter_doc_scanner.dart';
import 'package:health_wallet/core/l10n/app_strings_provider.dart';
import 'package:health_wallet/core/services/temp_file_sweeper.dart';
import 'package:health_wallet/core/utils/logger.dart';
import 'package:health_wallet/core/utils/stored_file_name.dart';
import 'package:health_wallet/features/notifications/domain/entities/notification.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_diagnostic_report.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_encounter.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_patient.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_resource.dart';
import 'package:health_wallet/features/processing/domain/entity/model_not_found_exception.dart';
import 'package:health_wallet/features/processing/domain/entity/processing_session.dart';
import 'package:health_wallet/features/processing/domain/entity/staged_resource.dart';
import 'package:health_wallet/features/processing/domain/repository/processing_repository.dart';
import 'package:health_wallet/features/processing/domain/services/layout_extraction/layout_extraction_service.dart';
import 'package:health_wallet/features/processing/domain/services/ocr_processing_service.dart';
import 'package:health_wallet/features/processing/domain/services/processing_log_buffer.dart';
import 'package:health_wallet/features/processing/presentation/bloc/processing_bloc.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

mixin SessionHandler on Bloc<ProcessingEvent, ProcessingState> {
  OcrProcessingHelper get ocrProcessingHelper;
  ProcessingRepository get processingRepository;
  AppStringsProvider get strings;
  LayoutExtractionService get layoutExtraction;

  void updateSession(
    Emitter<ProcessingState> emit, {
    required String sessionId,
    double? progress,
    ProcessingStatus? status,
    List<MappingResource>? resources,
    StagedPatient? patient,
    StagedEncounter? encounter,
    StagedDiagnosticReport? diagnosticReport,
    bool? isDocumentAttached,
    bool updateDb = false,
  });

  void startNextPendingSession();

  /// Removes [session] with its row, pages and files, once the AI has
  /// stopped on it; [notification] says why when this device's user didn't
  /// delete it.
  Future<void> removeSession(
    Emitter<ProcessingState> emit,
    ProcessingSession session, {
    Notification? notification,
  });

  Future<void> onCaptureButtonPressed(
    CaptureButtonPressed event,
    Emitter<ProcessingState> emit,
  ) async {
    emit(state.copyWith(status: const PipelineStatus.loading()));

    try {
      final scannedResult = await FlutterDocScanner()
          .getScannedDocumentAsImages(
            page: event.maxPages,
          );

      if (scannedResult == null) {
        emit(state.copyWith(status: const PipelineStatus.initial()));
        return;
      }

      final imagePaths = scannedResult.images
          .where((path) => path.isNotEmpty)
          .map(
            (path) => path.startsWith('file:///')
                ? Uri.parse(path).toFilePath()
                : path,
          )
          .toList();

      if (imagePaths.isEmpty) {
        emit(state.copyWith(status: const PipelineStatus.initial()));
        return;
      }

      final persistedPaths = <String>[];
      for (final path in imagePaths) {
        final file = File(path);
        if (await file.exists()) {
          final persisted = await _persistImportedFile(file);
          persistedPaths.add(persisted);
        }
      }

      final sessionPaths = persistedPaths.isNotEmpty
          ? persistedPaths
          : imagePaths;

      await createSession(
        emit,
        filePaths: sessionPaths,
        origin: ProcessingOrigin.scan,
      );
    } catch (e, s) {
      logger.e('[ProcessingBloc] scan failed', e, s);
      emit(
        state.copyWith(
          status: PipelineStatus.failure(
            error: 'Scan failed: $e',
            reason: PipelineFailureReason.scanFailed,
          ),
        ),
      );
    }
  }

  Future<void> onDocumentImported(
    DocumentImported event,
    Emitter<ProcessingState> emit,
  ) async {
    emit(state.copyWith(status: const PipelineStatus.loading()));
    try {
      // The same document sent again (a handover retried after a failure)
      // replaces the earlier attempt and its files.
      final previous = state.sessions.firstWhereOrNull(
        (s) => event.sessionId != null && s.id == event.sessionId,
      );
      if (previous != null) {
        if (previous.isProcessing) {
          await processingRepository.cancelGeneration();
          await processingRepository.waitForStreamCompletion();
        }
        layoutExtraction.forget(previous.id);
        emit(
          state.copyWith(
            sessions: [...state.sessions]..remove(previous),
            sessionImagePaths: {...state.sessionImagePaths}
              ..remove(previous.id),
          ),
        );
        await processingRepository.deleteProcessingSession(previous);
      }

      final persistedPaths = <String>[];

      for (final filePath in event.filePaths) {
        final file = File(filePath);
        if (await file.exists()) {
          final persisted = await _persistImportedFile(file);
          persistedPaths.add(persisted);
        }
      }

      if (persistedPaths.isEmpty) {
        emit(
          state.copyWith(
            status: PipelineStatus.failure(
              error: 'No valid files found',
              reason: PipelineFailureReason.noValidFiles,
              sessionId: event.sessionId,
            ),
          ),
        );
        return;
      }

      final orderedPaths = persistedPaths.length > 1
          ? await _autoReorderByPageNumber(persistedPaths)
          : persistedPaths;

      await createSession(
        emit,
        filePaths: orderedPaths,
        origin: event.origin,
        id: event.sessionId,
      );

      if (event.phase1Patient != null) {
        final session = state.sessions.first;
        updateSession(
          emit,
          sessionId: session.id,
          status: ProcessingStatus.patientExtracted,
          patient: event.phase1Patient!,
          encounter: event.phase1Encounter,
          diagnosticReport: event.phase1DiagnosticReport,
          updateDb: true,
        );
      }

      // A handover is processed through to its draft without anyone at the
      // desktop; when another session is running it waits its turn.
      if (event.origin == ProcessingOrigin.handover &&
          !state.sessions.any((s) => s.isProcessing)) {
        startNextPendingSession();
      }
    } catch (e, s) {
      logger.e('[ProcessingBloc] import failed', e, s);
      emit(
        state.copyWith(
          status: PipelineStatus.failure(
            error: 'Failed to import document: $e',
            reason: PipelineFailureReason.importFailed,
            sessionId: event.sessionId,
          ),
        ),
      );
    }
  }

  Future createSession(
    Emitter<ProcessingState> emit, {
    required List<String> filePaths,
    required ProcessingOrigin origin,
    String? id,
  }) async {
    final session = await processingRepository.createProcessingSession(
      filePaths: filePaths,
      origin: origin,
      id: id,
    );

    emit(
      state.copyWith(
        status: PipelineStatus.sessionCreated(session: session),
        sessions: [
          session,
          ...state.sessions.where((s) => s.id != session.id),
        ],
      ),
    );
  }

  void onSessionChangedProgress(
    SessionChangedProgress event,
    Emitter<ProcessingState> emit,
  ) {
    final newSessions = [...state.sessions]
      ..removeWhere((session) => session.id == event.session.id);

    emit(state.copyWith(sessions: [event.session, ...newSessions]));

    if (event.session.status == ProcessingStatus.draft) {
      processingRepository.editProcessingSession(event.session);
    }
  }

  void onSessionCleared(
    SessionCleared event,
    Emitter<ProcessingState> emit,
  ) async {
    // As it is now: it may have started processing since the list was shown.
    final session =
        state.sessions.firstWhereOrNull((s) => s.id == event.session.id) ??
        event.session;
    final wasProcessing = session.isProcessing;
    try {
      if (wasProcessing) {
        emit(
          state.copyWith(
            status: const PipelineStatus.loading(),
            deletingSessionId: session.id,
          ),
        );
      }
      await removeSession(emit, session);
      emit(
        state.copyWith(
          status: const PipelineStatus.initial(),
          deletingSessionId: null,
        ),
      );
      // It held the queue, or the queue waits: the next document goes on.
      if (wasProcessing ||
          state.sessions.any((s) => s.status == ProcessingStatus.pending)) {
        startNextPendingSession();
      }
    } on Exception catch (e, s) {
      logger.e('[ProcessingBloc] deleting the session failed', e, s);
      emit(
        state.copyWith(
          status: PipelineStatus.failure(
            error: e.toString(),
            reason: PipelineFailureReason.of(e),
          ),
          deletingSessionId: null,
        ),
      );
    }
  }

  Future<void> onSessionActivated(
    SessionActivated event,
    Emitter<ProcessingState> emit,
  ) async {
    final anotherSessionProcessing = state.sessions.any(
      (s) => s.id != event.sessionId && s.isProcessing,
    );

    try {
      final session = state.sessions.firstWhere((s) => s.id == event.sessionId);
      final cachedImages = state.sessionImagePaths[event.sessionId];

      List<String> allImages;
      final cachedValid =
          cachedImages != null &&
          cachedImages.isNotEmpty &&
          await File(cachedImages.first).exists();
      if (cachedValid) {
        allImages = cachedImages;
      } else {
        if (!anotherSessionProcessing) {
          emit(state.copyWith(status: const PipelineStatus.convertingPdfs()));
        }
        allImages = await ocrProcessingHelper.prepareAllImages(
          filePaths: session.filePaths,
        );
        // Deleted while its pages rendered: its delete found none of them.
        if (_isGone(session.id)) {
          await _discardSessionPages(session, pages: allImages);
          return;
        }
      }

      final updatedImageMap = Map<String, List<String>>.from(
        state.sessionImagePaths,
      )..[event.sessionId] = allImages;

      emit(state.copyWith(sessionImagePaths: updatedImageMap));

      if (anotherSessionProcessing &&
          session.status != ProcessingStatus.draft) {
        return;
      }

      emit(
        state.copyWith(
          displayedSessionId: event.sessionId,
        ),
      );

      // A draft is never read again; every other session may be.
      if (session.status != ProcessingStatus.draft) {
        await _prepareOcrPages(emit, session, allImages);
      }

      if (session.status == ProcessingStatus.pending) {
        try {
          // A document of a known layout is read without the model.
          final canProcess = await layoutExtraction.canProcess(
            event.sessionId,
            filePaths: session.filePaths,
            imagePaths: state.ocrPagesFor(event.sessionId),
          );

          if (canProcess) {
            add(MappingInitiated(sessionId: event.sessionId));
          } else {
            emit(
              state.copyWith(
                status: PipelineStatus.failure(
                  // Shown localized through the reason; the English text is
                  // what a desktop sends to the phone as the handover error.
                  error: const ModelNotFoundException().toString(),
                  reason: PipelineFailureReason.modelNotFound,
                  sessionId: event.sessionId,
                ),
              ),
            );
          }
        } catch (e, s) {
          // The session stays pending and is shown as queued.
          logger.w('[ProcessingBloc] checking for the AI model failed', e, s);
          emit(state.copyWith(status: const PipelineStatus.initial()));
        }
      }
    } catch (e, s) {
      logger.e('[ProcessingBloc] opening the session failed', e, s);
      emit(
        state.copyWith(
          status: PipelineStatus.failure(
            error: e.toString(),
            reason: PipelineFailureReason.of(e),
            sessionId: event.sessionId,
          ),
        ),
      );
    }
  }

  Future<void> onPagesReordered(
    PagesReordered event,
    Emitter<ProcessingState> emit,
  ) async {
    final sessionIndex = state.sessions.indexWhere(
      (s) => s.id == event.sessionId,
    );
    if (sessionIndex == -1) return;

    final filePathsBefore = state.sessions[sessionIndex].filePaths;
    final updatedSession = state.sessions[sessionIndex].copyWith(
      filePaths: event.reorderedPaths,
    );
    layoutExtraction.forget(event.sessionId);
    final updatedSessions = [...state.sessions];
    updatedSessions[sessionIndex] = updatedSession;

    final updatedImageMap = Map<String, List<String>>.from(
      state.sessionImagePaths,
    )..[event.sessionId] = event.reorderedPaths;

    emit(
      state.copyWith(
        sessions: updatedSessions,
        sessionImagePaths: updatedImageMap,
      ),
    );

    await processingRepository.editProcessingSession(updatedSession);

    // The OCR pages follow by preview page; only deleted pages leave the map.
    try {
      await ocrProcessingHelper.keepOcrPages(
        sessionId: event.sessionId,
        filePaths: filePathsBefore,
        previewPaths: event.reorderedPaths,
      );
    } catch (e, s) {
      logger.w('[ProcessingBloc] updating the page map failed', e, s);
    }
  }

  Future<void> onPageRotated(
    PageRotated event,
    Emitter<ProcessingState> emit,
  ) async {
    final sessionIndex = state.sessions.indexWhere(
      (s) => s.id == event.sessionId,
    );
    if (sessionIndex == -1) return;
    String? ocrPage;
    try {
      ocrPage = await ocrProcessingHelper.rotateOcrPage(
        sessionId: event.sessionId,
        filePaths: state.sessions[sessionIndex].filePaths,
        previewPath: event.previewPath,
        quarterTurns: event.quarterTurns,
      );
    } catch (e, s) {
      // The preview page is turned already: OCR reads that one instead.
      logger.w('[ProcessingBloc] turning the OCR page failed', e, s);
    }
    final pages = Map<String, String>.from(state.ocrPageByPreviewPath);
    if (ocrPage == null) {
      pages.remove(event.previewPath);
    } else {
      pages[event.previewPath] = ocrPage;
    }
    emit(state.copyWith(ocrPageByPreviewPath: pages));
  }

  Future<void> onOcrPagesReleased(
    OcrPagesReleased event,
    Emitter<ProcessingState> emit,
  ) async {
    final previews = state.sessionImagePaths[event.sessionId] ?? const [];
    final ocrPages = _ocrPagesOf(previews);
    emit(state.copyWith(ocrPageByPreviewPath: _withoutOcrPages(previews)));
    try {
      await ocrProcessingHelper.discardOcrPages(
        sessionId: event.sessionId,
        ocrPages: ocrPages,
      );
    } catch (e, s) {
      logger.w('[ProcessingBloc] deleting the saved OCR pages failed', e, s);
    }
  }

  @override
  void onTransition(Transition<ProcessingEvent, ProcessingState> transition) {
    super.onTransition(transition);
    final event = transition.event;
    if (event is ResourceCreationInitiated &&
        transition.nextState.status is Success &&
        transition.currentState.status is! Success) {
      add(OcrPagesReleased(sessionId: event.sessionId));
    }
  }

  /// Renders the 200 dpi OCR pages of [session]'s PDF pages after its
  /// [previews] are shown. Any failure leaves OCR on the 72 dpi previews.
  Future<void> _prepareOcrPages(
    Emitter<ProcessingState> emit,
    ProcessingSession session,
    List<String> previews,
  ) async {
    try {
      final ocrPages = await ocrProcessingHelper.prepareOcrPages(
        sessionId: session.id,
        filePaths: session.filePaths,
        previewPaths: previews,
      );
      if (_isGone(session.id)) {
        await _discardSessionPages(
          session,
          pages: [...previews, ...ocrPages.values],
        );
        return;
      }
      if (emit.isDone) return;
      emit(
        state.copyWith(
          ocrPageByPreviewPath: {...state.ocrPageByPreviewPath, ...ocrPages},
        ),
      );
    } catch (e, s) {
      logger.w(
        '[ProcessingBloc] rendering the 200 dpi pages failed; OCR reads the '
        'preview pages',
        e,
        s,
      );
    }
  }

  /// Renders the 200 dpi pages of [sessionId] when its mapping starts, if
  /// opening it didn't (another session was processing then).
  Future<void> ensureOcrPages(
    Emitter<ProcessingState> emit,
    String sessionId,
  ) async {
    final index = state.sessions.indexWhere((s) => s.id == sessionId);
    if (index == -1) return;
    final previews = state.sessionImagePaths[sessionId] ?? const <String>[];
    final missing = previews.any(
      (preview) =>
          TempFileSweeper.ocrCachePagePattern.hasMatch(p.basename(preview)) &&
          !state.ocrPageByPreviewPath.containsKey(preview),
    );
    if (missing) await _prepareOcrPages(emit, state.sessions[index], previews);
  }

  /// Takes the pages of [session], already removed, out of the state, then
  /// deletes them and its files, as deleting it here does.
  Future<void> discardPagesOf(
    Emitter<ProcessingState> emit,
    ProcessingSession session,
  ) async {
    final previews = state.sessionImagePaths[session.id] ?? const <String>[];
    final ocrPages = _ocrPagesOf(previews);
    emit(
      state.copyWith(
        sessionImagePaths: {...state.sessionImagePaths}..remove(session.id),
        ocrPageByPreviewPath: _withoutOcrPages(previews),
      ),
    );
    await _discardSessionPages(session, pages: [...previews, ...ocrPages]);
  }

  bool _isGone(String sessionId) =>
      state.sessions.every((s) => s.id != sessionId);

  Future<void> _discardSessionPages(
    ProcessingSession session, {
    required List<String> pages,
  }) async {
    try {
      await ocrProcessingHelper.discardSessionPages(
        sessionId: session.id,
        pages: [...pages, ...session.filePaths],
      );
    } catch (e, s) {
      logger.w('[ProcessingBloc] deleting the session pages failed', e, s);
    }
  }

  List<String> _ocrPagesOf(List<String> previews) => [
    for (final preview in previews) ?state.ocrPageByPreviewPath[preview],
  ];

  Map<String, String> _withoutOcrPages(List<String> previews) =>
      Map<String, String>.from(state.ocrPageByPreviewPath)
        ..removeWhere((preview, _) => previews.contains(preview));

  void onResourceChanged(
    ResourceChanged event,
    Emitter<ProcessingState> emit,
  ) {
    final activeSession = state.sessions.firstWhere(
      (s) => s.id == event.sessionId,
    );

    if (event.isDraftPatient == true) {
      MappingPatient draftPatient;
      ImportMode newMode;

      if (activeSession.patient.mode == ImportMode.linkExisting &&
          activeSession.patient.existing != null) {
        draftPatient =
            activeSession.patient.draft ??
            MappingPatient.fromFhirResource(activeSession.patient.existing!);
        newMode = ImportMode.linkExisting;
        ProcessingLogBuffer.instance.log(
          '[${DateTime.now().toIso8601String().substring(11, 23)}][ScanAI] patient modified: ${event.propertyKey} changed, will create new patient',
        );
      } else {
        draftPatient = activeSession.patient.draft ?? const MappingPatient();
        newMode = activeSession.patient.mode;
      }

      updateSession(
        emit,
        sessionId: event.sessionId,
        patient: StagedPatient(
          draft: draftPatient.copyWithMap({
            event.propertyKey: event.newValue,
          }) as MappingPatient,
          existing: activeSession.patient.existing,
          mode: newMode,
        ),
        updateDb: true,
      );
      return;
    }

    if (event.isDraftDiagnosticReport == true) {
      final MappingDiagnosticReport draftReport =
          activeSession.diagnosticReport?.draft ??
          const MappingDiagnosticReport();

      updateSession(
        emit,
        sessionId: event.sessionId,
        diagnosticReport:
            (activeSession.diagnosticReport ?? const StagedDiagnosticReport())
                .copyWith(
                  draft: draftReport.copyWithMap({
                    event.propertyKey: event.newValue,
                  }) as MappingDiagnosticReport,
                ),
      );
      return;
    }

    if (event.isDraftEncounter == true) {
      final MappingEncounter draftEncounter =
          activeSession.encounter.draft ?? const MappingEncounter();

      updateSession(
        emit,
        sessionId: event.sessionId,
        encounter: activeSession.encounter.copyWith(
          draft: draftEncounter.copyWithMap({
            event.propertyKey: event.newValue,
          }) as MappingEncounter,
        ),
      );
      return;
    }

    final MappingResource updatedResource = activeSession.resources[event.index]
        .copyWithMap({
          event.propertyKey: event.newValue,
        });

    final newResources = [...activeSession.resources];
    newResources[event.index] = updatedResource;

    updateSession(
      emit,
      sessionId: event.sessionId,
      resources: newResources,
      updateDb: true,
    );
  }

  void onPatientReverted(
    PatientReverted event,
    Emitter<ProcessingState> emit,
  ) {
    final activeSession = state.sessions.firstWhere(
      (s) => s.id == event.sessionId,
    );
    if (activeSession.patient.existing == null) return;

    updateSession(
      emit,
      sessionId: event.sessionId,
      patient: StagedPatient(
        existing: activeSession.patient.existing,
        mode: ImportMode.linkExisting,
      ),
      updateDb: true,
    );
  }

  void onResourceRemoved(
    ResourceRemoved event,
    Emitter<ProcessingState> emit,
  ) {
    final activeSession = state.sessions.firstWhere(
      (s) => s.id == event.sessionId,
    );
    final newResources = [...activeSession.resources];
    newResources.removeAt(event.index);

    updateSession(
      emit,
      sessionId: event.sessionId,
      resources: newResources,
      updateDb: true,
    );
  }

  void onResourcesAdded(
    ResourcesAdded event,
    Emitter<ProcessingState> emit,
  ) {
    final activeSession = state.sessions.firstWhere(
      (s) => s.id == event.sessionId,
    );

    final List<MappingResource> newResources = [];

    for (final resourceType in event.resourceTypes) {
      final MappingResource newResource = MappingResource.empty(resourceType);
      newResources.add(newResource);
    }

    final updatedResources = [...activeSession.resources, ...newResources];
    updateSession(
      emit,
      sessionId: event.sessionId,
      resources: updatedResources,
      updateDb: true,
    );
  }

  void onEncounterAttached(
    EncounterAttached event,
    Emitter<ProcessingState> emit,
  ) {
    updateSession(
      emit,
      sessionId: event.sessionId,
      patient: event.patient,
      encounter: event.encounter,
      updateDb: true,
    );
  }

  Future<String> _persistImportedFile(File sourceFile) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final importsDir = Directory('${docsDir.path}/imports');
    if (!await importsDir.exists()) {
      await importsDir.create(recursive: true);
    }

    final fileName = await uniqueStoredFileName(
      importsDir.path,
      p.basename(sourceFile.path),
    );
    final destPath = '${importsDir.path}/$fileName';

    await copyAsNewFile(sourceFile, destPath);
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
        final text = await ocrProcessingHelper.processOcrForImages([paths[i]]);
        final match = pagePattern.firstMatch(text);

        if (match != null) {
          final pageNum = int.tryParse(match.group(1)!);
          final totalPages = int.tryParse(match.group(2)!);
          if (pageNum != null && totalPages != null) {
            entries.add(
              _PageEntry(
                path: paths[i],
                pageNumber: pageNum,
                totalPages: totalPages,
                originalIndex: i,
              ),
            );
            continue;
          }
        }
        entries.add(
          _PageEntry(
            path: paths[i],
            pageNumber: null,
            totalPages: null,
            originalIndex: i,
          ),
        );
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
