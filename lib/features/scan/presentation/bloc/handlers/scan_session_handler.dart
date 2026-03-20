import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_wallet/features/scan/domain/entity/mapping_resources/mapping_diagnostic_report.dart';
import 'package:health_wallet/features/scan/domain/entity/mapping_resources/mapping_encounter.dart';
import 'package:health_wallet/features/scan/domain/entity/mapping_resources/mapping_patient.dart';
import 'package:health_wallet/features/scan/domain/entity/mapping_resources/mapping_resource.dart';
import 'package:health_wallet/features/scan/domain/entity/processing_session.dart';
import 'package:health_wallet/features/scan/domain/entity/staged_resource.dart';
import 'package:health_wallet/features/scan/domain/repository/scan_repository.dart';
import 'package:health_wallet/features/scan/domain/services/ocr_processing_service.dart';
import 'package:health_wallet/features/scan/presentation/bloc/scan_bloc.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

mixin ScanSessionHandler on Bloc<ScanEvent, ScanState> {
  OcrProcessingHelper get ocrProcessingHelper;
  ScanRepository get scanRepository;

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
  });

  void startNextPendingSession();

  Future<void> onDocumentImported(
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

      await createSession(emit,
          filePaths: orderedPaths, origin: ProcessingOrigin.import);
    } catch (e) {
      emit(state.copyWith(
        status: ScanStatus.failure(error: 'Failed to import document: $e'),
      ));
    }
  }

  Future createSession(
    Emitter<ScanState> emit, {
    required List<String> filePaths,
    required ProcessingOrigin origin,
  }) async {
    final session = await scanRepository.createProcessingSession(
        filePaths: filePaths, origin: origin);

    emit(state.copyWith(
      status: ScanStatus.sessionCreated(session: session),
      sessions: [session, ...state.sessions],
    ));
  }

  void onScanSessionChangedProgress(
    ScanSessionChangedProgress event,
    Emitter<ScanState> emit,
  ) {
    final newSessions = [...state.sessions]
      ..removeWhere((session) => session.id == event.session.id);

    emit(state.copyWith(sessions: [event.session, ...newSessions]));

    if (event.session.status == ProcessingStatus.draft) {
      scanRepository.editProcessingSession(event.session);
    }
  }

  void onScanSessionCleared(
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
          await scanRepository.cancelGeneration();
          await scanRepository.waitForStreamCompletion();
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

      await scanRepository.deleteProcessingSession(event.session);

      final hasPendingSessions = newSessions.any(
        (s) => s.status == ProcessingStatus.pending,
      );

      if (hasPendingSessions) {
        await Future.delayed(const Duration(milliseconds: 100));
        startNextPendingSession();
      }
    } on Exception catch (e) {
      emit(state.copyWith(
        status: ScanStatus.failure(error: e.toString()),
        deletingSessionId: null,
      ));
    }
  }

  Future<void> onScanSessionActivated(
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
        allImages = await ocrProcessingHelper.prepareAllImages(
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
          final isModelLoaded = await scanRepository.checkModelExistence();

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

  Future<void> onScanPagesReordered(
    ScanPagesReordered event,
    Emitter<ScanState> emit,
  ) async {
    final sessionIndex =
        state.sessions.indexWhere((s) => s.id == event.sessionId);
    if (sessionIndex == -1) return;

    final updatedSession = state.sessions[sessionIndex]
        .copyWith(filePaths: event.reorderedPaths);
    final updatedSessions = [...state.sessions];
    updatedSessions[sessionIndex] = updatedSession;

    final updatedImageMap =
        Map<String, List<String>>.from(state.sessionImagePaths)
          ..[event.sessionId] = event.reorderedPaths;

    emit(state.copyWith(
      sessions: updatedSessions,
      sessionImagePaths: updatedImageMap,
    ));

    await scanRepository.editProcessingSession(updatedSession);
  }

  void onScanResourceChanged(
    ScanResourceChanged event,
    Emitter<ScanState> emit,
  ) {
    final activeSession =
        state.sessions.firstWhere((s) => s.id == event.sessionId);

    if (event.isDraftPatient == true) {
      MappingPatient draftPatient;
      ImportMode newMode;

      if (activeSession.patient.mode == ImportMode.linkExisting &&
          activeSession.patient.existing != null) {
        draftPatient = activeSession.patient.draft ??
            MappingPatient.fromFhirResource(activeSession.patient.existing!);
        newMode = ImportMode.createNew;
      } else {
        draftPatient = activeSession.patient.draft ?? const MappingPatient();
        newMode = activeSession.patient.mode;
      }

      updateSession(
        emit,
        sessionId: event.sessionId,
        patient: StagedPatient(
          draft: draftPatient
                  .copyWithMap({event.propertyKey: event.newValue})
              as MappingPatient,
          existing: activeSession.patient.existing,
          mode: newMode,
        ),
        updateDb: true,
      );
      return;
    }

    if (event.isDraftDiagnosticReport == true) {
      MappingDiagnosticReport draftReport =
          activeSession.diagnosticReport?.draft ??
              const MappingDiagnosticReport();

      updateSession(
        emit,
        sessionId: event.sessionId,
        diagnosticReport: (activeSession.diagnosticReport ??
                const StagedDiagnosticReport())
            .copyWith(
                draft: draftReport.copyWithMap(
                        {event.propertyKey: event.newValue})
                    as MappingDiagnosticReport),
      );
      return;
    }

    if (event.isDraftEncounter == true) {
      MappingEncounter draftEncounter =
          activeSession.encounter.draft ?? const MappingEncounter();

      updateSession(
        emit,
        sessionId: event.sessionId,
        encounter: activeSession.encounter.copyWith(
            draft: draftEncounter
                    .copyWithMap({event.propertyKey: event.newValue})
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

    updateSession(emit,
        sessionId: event.sessionId,
        resources: newResources,
        updateDb: true);
  }

  void onScanResourceRemoved(
    ScanResourceRemoved event,
    Emitter<ScanState> emit,
  ) {
    final activeSession =
        state.sessions.firstWhere((s) => s.id == event.sessionId);
    final newResources = [...activeSession.resources];
    newResources.removeAt(event.index);

    updateSession(emit,
        sessionId: event.sessionId,
        resources: newResources,
        updateDb: true);
  }

  void onScanResourcesAdded(
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
    updateSession(
      emit,
      sessionId: event.sessionId,
      resources: updatedResources,
      updateDb: true,
    );
  }

  void onScanEncounterAttached(
    ScanEncounterAttached event,
    Emitter<ScanState> emit,
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
        final text =
            await ocrProcessingHelper.processOcrForImages([paths[i]]);
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

      final detected =
          entries.where((e) => e.pageNumber != null).toList();
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
