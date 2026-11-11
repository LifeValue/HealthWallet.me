import 'dart:io';

import 'package:collection/collection.dart';
import 'package:fhir_r4/fhir_r4.dart' as fhir_r4;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_wallet/core/config/constants/shared_prefs_constants.dart';
import 'package:health_wallet/core/l10n/app_strings_provider.dart';
import 'package:health_wallet/core/l10n/display_names.dart';
import 'package:health_wallet/core/navigation/app_router.dart';
import 'package:health_wallet/core/services/device_capability_service.dart';
import 'package:health_wallet/core/utils/logger.dart';
import 'package:health_wallet/features/holders/domain/services/holder_matcher.dart';
import 'package:health_wallet/features/holders/domain/services/holder_selection.dart';
import 'package:health_wallet/features/holders/domain/services/holder_service.dart';
import 'package:health_wallet/features/home/domain/entities/medical_specialty.dart';
import 'package:health_wallet/features/notifications/domain/entities/notification.dart';
import 'package:health_wallet/features/processing/domain/deep_scan_defaults.dart';
import 'package:health_wallet/features/processing/domain/entity/extraction_output_mode.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_diagnostic_report.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_encounter.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_patient.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_resource.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_vision_prescription.dart';
import 'package:health_wallet/features/processing/domain/entity/processing_session.dart';
import 'package:health_wallet/features/processing/domain/entity/staged_resource.dart';
import 'package:health_wallet/features/processing/domain/repository/processing_repository.dart';
import 'package:health_wallet/features/processing/domain/services/document_reference_service.dart';
import 'package:health_wallet/features/processing/domain/services/layout_extraction/layout_extraction_service.dart';
import 'package:health_wallet/features/processing/domain/services/layout_extraction/record_completion.dart';
import 'package:health_wallet/features/processing/domain/services/ocr_processing_service.dart';
import 'package:health_wallet/features/processing/domain/services/processing_log_buffer.dart';
import 'package:health_wallet/features/processing/presentation/bloc/processing_bloc.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/records/domain/repository/records_repository.dart';
import 'package:health_wallet/features/sync/domain/repository/sync_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

mixin ProcessingHandler on Bloc<ProcessingEvent, ProcessingState> {
  ProcessingRepository get processingRepository;
  OcrProcessingHelper get ocrProcessingHelper;
  RecordsRepository get recordsRepository;
  SyncRepository get syncRepository;
  DocumentReferenceService get documentReferenceService;
  HolderService get holderService;
  HolderSelection get holderSelection;
  SharedPreferences get prefs;
  AppStringsProvider get strings;
  LayoutExtractionService get layoutExtraction;
  DeviceCapabilityService get deviceCapabilityService;

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

  bool isCapacityError(String errorString);
  void startNextPendingSession();
  Future<void> ensureOcrPages(Emitter<ProcessingState> emit, String sessionId);

  /// Handovers whose extraction failed: the queue leaves them alone until
  /// the user retries, so a failure isn't repeated after every other
  /// document.
  Set<String> get haltedHandovers;

  /// The pages of [sessionId] itself, prepared when no step has prepared them
  /// yet. Never another session's pages: a step that starts before the
  /// session was opened (a handover's phase 2) would read the wrong document.
  Future<List<String>> sessionImagesFor(
    String sessionId,
    Emitter<ProcessingState> emit,
  ) async {
    final cached = state.sessionImagePaths[sessionId];
    if (cached != null && cached.isNotEmpty) return cached;
    final session = state.sessions.firstWhereOrNull((s) => s.id == sessionId);
    if (session == null) return const [];
    final images = await ocrProcessingHelper.prepareAllImages(
      filePaths: session.filePaths,
    );
    if (!emit.isDone) {
      emit(
        state.copyWith(
          sessionImagePaths: {...state.sessionImagePaths, sessionId: images},
        ),
      );
    }
    return images;
  }

  void onMappingInitiated(
    MappingInitiated event,
    Emitter<ProcessingState> emit,
  ) async {
    final session = state.sessions.firstWhereOrNull(
      (s) => s.id == event.sessionId,
    );
    if (session == null) return;
    if (session.isProcessing ||
        session.status == ProcessingStatus.draft ||
        session.status == ProcessingStatus.patientExtracted ||
        session.status == ProcessingStatus.handedOver) {
      return;
    }
    haltedHandovers.remove(event.sessionId);
    emit(state.copyWith(status: const PipelineStatus.loading()));
    final anotherSessionProcessing = state.sessions.any(
      (s) => s.id != event.sessionId && s.isProcessing,
    );
    if (anotherSessionProcessing) return;

    try {
      updateSession(
        emit,
        sessionId: event.sessionId,
        status: ProcessingStatus.processingPatient,
      );
      final isDesktop =
          Platform.isMacOS || Platform.isLinux || Platform.isWindows;
      // Its own previews (never another session's), then their 200 dpi pages.
      await sessionImagesFor(event.sessionId, emit);
      await ensureOcrPages(emit, event.sessionId);
      final sessionImages = state.ocrPagesFor(event.sessionId);
      if (sessionImages.isEmpty) {
        updateSession(
          emit,
          sessionId: event.sessionId,
          status: ProcessingStatus.pending,
          progress: 0.0,
        );
        emit(
          state.copyWith(
            status: PipelineStatus.failure(
              error: 'No images were generated from the document',
              reason: PipelineFailureReason.noImagesGenerated,
              sessionId: event.sessionId,
            ),
          ),
        );
        return;
      }
      final medicalText = await layoutExtraction.ocrText(
        event.sessionId,
        sessionImages,
      );
      if (medicalText.isEmpty || medicalText.trim().isEmpty) {
        updateSession(
          emit,
          sessionId: event.sessionId,
          status: ProcessingStatus.draft,
        );
        return;
      }
      // A document of a known layout is read by its extractor, without the
      // AI, and goes straight to the review.
      final layout = layoutExtraction.extract(medicalText);
      if (layout != null) {
        final stagedPatient = await _matchOrCreatePatient(layout.patient);
        final staging = await layoutExtraction.stage(
          layout,
          holderPatient: stagedPatient.existing,
        );
        // Cancelled while reading: nothing is staged.
        if (_leftStep(
          event.sessionId,
          ProcessingStatus.processingPatient,
          emit,
        )) {
          return;
        }
        updateSession(
          emit,
          sessionId: event.sessionId,
          status: ProcessingStatus.draft,
          patient: stagedPatient,
          encounter: staging.encounter,
          resources: staging.resources,
          updateDb: true,
        );
        emit(
          state.copyWith(
            notification: Notification(
              text: strings.l10n.processingFinished(_originName(session)),
              route: ProcessingRoute(sessionId: event.sessionId),
              time: DateTime.now(),
            ),
          ),
        );
        startNextPendingSession();
        return;
      }
      final ocrPreMatch = await _tryMatchPatientFromOcr(medicalText);
      if (ocrPreMatch != null) {
        ProcessingLogBuffer.instance.log(
          '[${DateTime.now().toIso8601String().substring(11, 23)}][ScanAI] OCR pre-match: ${ocrPreMatch.displayTitle}, running container-only AI',
        );
        final stagedPatient = StagedPatient(
          existing: ocrPreMatch,
          mode: ImportMode.linkExisting,
        );
        if (_leftStep(
          event.sessionId,
          ProcessingStatus.processingPatient,
          emit,
        )) {
          return;
        }
        final container = await processingRepository.mapContainerOnly(
          medicalText,
          maxTokens: isDesktop
              ? null
              : prefs.getInt(SharedPrefsConstants.aiMaxTokens),
          gpuLayers: isDesktop
              ? null
              : prefs.getInt(SharedPrefsConstants.aiGpuLayers),
          threads: isDesktop
              ? null
              : prefs.getInt(SharedPrefsConstants.aiThreads),
          contextSize: isDesktop
              ? null
              : prefs.getInt(SharedPrefsConstants.aiContextSize),
          outputMode: ExtractionOutputMode.fromPref(
            prefs.getString(SharedPrefsConstants.aiOutputMode),
          ),
        );
        if (_leftStep(
          event.sessionId,
          ProcessingStatus.processingPatient,
          emit,
        )) {
          return;
        }
        final finalSession = state.sessions.firstWhereOrNull(
          (s) => s.id == event.sessionId,
        );
        if (container is MappingDiagnosticReport) {
          updateSession(
            emit,
            sessionId: event.sessionId,
            status: ProcessingStatus.patientExtracted,
            patient: stagedPatient,
            diagnosticReport: StagedDiagnosticReport(draft: container),
            updateDb: true,
          );
        } else {
          updateSession(
            emit,
            sessionId: event.sessionId,
            status: ProcessingStatus.patientExtracted,
            patient: stagedPatient,
            encounter: StagedEncounter(draft: container as MappingEncounter),
            updateDb: true,
          );
        }
        if (!processingRepository.shouldCancelGeneration) {
          emit(
            state.copyWith(
              notification: Notification(
                text: strings.l10n.processingPatientMatched(
                  _originName(finalSession),
                ),
                route: ProcessingRoute(sessionId: event.sessionId),
                time: DateTime.now(),
              ),
            ),
          );
        }
        startNextPendingSession();
        return;
      }

      if (_leftStep(
        event.sessionId,
        ProcessingStatus.processingPatient,
        emit,
      )) {
        return;
      }
      final (patient, container) = await processingRepository.mapBasicInfo(
        sessionImages,
        maxTokens: isDesktop
            ? null
            : prefs.getInt(SharedPrefsConstants.aiMaxTokens),
        gpuLayers: isDesktop
            ? null
            : prefs.getInt(SharedPrefsConstants.aiGpuLayers),
        threads: isDesktop
            ? null
            : prefs.getInt(SharedPrefsConstants.aiThreads),
        contextSize: isDesktop
            ? null
            : prefs.getInt(SharedPrefsConstants.aiContextSize),
        outputMode: ExtractionOutputMode.fromPref(
          prefs.getString(SharedPrefsConstants.aiOutputMode),
        ),
      );
      if (_leftStep(
        event.sessionId,
        ProcessingStatus.processingPatient,
        emit,
      )) {
        return;
      }
      final stagedPatient = await _matchOrCreatePatient(patient);
      final finalSession = state.sessions.firstWhereOrNull(
        (s) => s.id == event.sessionId,
      );
      if (container is MappingDiagnosticReport) {
        updateSession(
          emit,
          sessionId: event.sessionId,
          status: ProcessingStatus.patientExtracted,
          patient: stagedPatient,
          diagnosticReport: StagedDiagnosticReport(draft: container),
          updateDb: true,
        );
      } else {
        updateSession(
          emit,
          sessionId: event.sessionId,
          status: ProcessingStatus.patientExtracted,
          patient: stagedPatient,
          encounter: StagedEncounter(draft: container as MappingEncounter),
          updateDb: true,
        );
      }
      if (!processingRepository.shouldCancelGeneration) {
        emit(
          state.copyWith(
            notification: Notification(
              text: strings.l10n.processingPatientInfoExtracted(
                _originName(finalSession),
              ),
              route: ProcessingRoute(sessionId: event.sessionId),
              time: DateTime.now(),
            ),
          ),
        );
      }

      startNextPendingSession();
    } on Exception catch (e, s) {
      logger.e('[ProcessingBloc] patient extraction failed', e, s);
      if (session.origin == ProcessingOrigin.handover) {
        haltedHandovers.add(event.sessionId);
      }
      updateSession(
        emit,
        sessionId: event.sessionId,
        status: ProcessingStatus.pending,
        updateDb: true,
      );
      if (!emit.isDone) {
        if (isCapacityError(e.toString())) {
          emit(
            state.copyWith(
              status: PipelineStatus.capacityFailure(
                sessionId: event.sessionId,
              ),
            ),
          );
        } else {
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
    }
  }

  /// Whether [sessionId] is no longer in the [step] it started (cancelled,
  /// handed over, removed or started again): the step stages nothing more.
  bool _leftStep(
    String sessionId,
    ProcessingStatus step,
    Emitter<ProcessingState> emit,
  ) =>
      emit.isDone ||
      state.sessions.firstWhereOrNull((s) => s.id == sessionId)?.status != step;

  String _originName(ProcessingSession? session) =>
      session?.origin.localizedName(strings.l10n) ??
      strings.l10n.fhirTypeDocumentReference;

  /// The person whose identifier appears in the scanned text, before the AI
  /// reads the patient.
  Future<Patient?> _tryMatchPatientFromOcr(String ocrText) async {
    if (ocrText.isEmpty) return null;
    try {
      final directory = await holderService.load();
      for (final holder in directory.holders) {
        for (final patient in holder.allPatientInstances) {
          for (final id in patient.identifier ?? const <fhir_r4.Identifier>[]) {
            final value = id.value?.valueString;
            if (value == null || value.length < 6) continue;
            // A clinic's own patient number says nothing outside it.
            if (id.system?.valueString?.startsWith(
                  HolderMatcher.clinicSystemPrefix,
                ) ??
                false) {
              continue;
            }
            if (HolderMatcher.appearsIn(value, ocrText)) {
              ProcessingLogBuffer.instance.log(
                '[${DateTime.now().toIso8601String().substring(11, 23)}][ScanAI] OCR pre-match: found identifier $value',
              );
              return holder.representativePatient;
            }
          }
        }
      }
    } catch (e) {
      // No pre-match: the AI extraction below still finds the patient.
      logger.w('OCR patient pre-match failed: $e');
    }
    return null;
  }

  Future<StagedPatient> _matchOrCreatePatient(MappingPatient patient) async {
    try {
      final directory = await holderService.load();
      final holder = holderService.matchScanned(patient, directory);
      if (holder != null) {
        // The unnamed default holder is proposed, not matched: the scan's
        // details are kept to name them.
        return StagedPatient(
          existing: holder.representativePatient,
          draft: holderService.isUnnamed(holder) ? patient : null,
          mode: ImportMode.linkExisting,
        );
      }
      return StagedPatient(draft: patient, mode: ImportMode.createNew);
    } catch (e) {
      logger.e('Error matching patient: $e');
      return StagedPatient(draft: patient, mode: ImportMode.createNew);
    }
  }

  void onProcessRemainingResources(
    ProcessRemainingResources event,
    Emitter<ProcessingState> emit,
  ) async {
    final session = state.sessions.firstWhereOrNull(
      (s) => s.id == event.sessionId,
    );
    if (event.automatic) {
      // The queue continues a handover only from its patient step, once.
      if (session?.status != ProcessingStatus.patientExtracted ||
          haltedHandovers.contains(event.sessionId)) {
        return;
      }
    } else {
      haltedHandovers.remove(event.sessionId);
    }
    emit(state.copyWith(status: const PipelineStatus.loading()));
    // Already running: a second run would extract the records twice.
    if (session == null ||
        session.isProcessing ||
        session.status == ProcessingStatus.handedOver) {
      return;
    }
    final anotherSessionProcessing = state.sessions.any(
      (s) => s.id != event.sessionId && s.isProcessing,
    );
    if (anotherSessionProcessing) return;

    try {
      updateSession(
        emit,
        sessionId: event.sessionId,
        status: ProcessingStatus.processing,
      );
      // Its own previews (never another session's), then their 200 dpi pages.
      await sessionImagesFor(event.sessionId, emit);
      await ensureOcrPages(emit, event.sessionId);
      final sessionImages = state.ocrPagesFor(event.sessionId);
      // Cancelled while the pages were prepared: the AI does not start.
      if (_leftStep(event.sessionId, ProcessingStatus.processing, emit)) {
        return;
      }
      final activeSession = state.sessions.firstWhereOrNull(
        (s) => s.id == event.sessionId,
      );
      final docCategory = activeSession?.isDiagnosticReportContainer == true
          ? 'lab_report'
          : 'visit';
      final isDesktop =
          Platform.isMacOS || Platform.isLinux || Platform.isWindows;
      final savedMaxTokens = isDesktop
          ? null
          : prefs.getInt(SharedPrefsConstants.aiMaxTokens);
      final savedGpuLayers = isDesktop
          ? null
          : prefs.getInt(SharedPrefsConstants.aiGpuLayers);
      final savedThreads = isDesktop
          ? null
          : prefs.getInt(SharedPrefsConstants.aiThreads);
      final savedContextSize = isDesktop
          ? null
          : prefs.getInt(SharedPrefsConstants.aiContextSize);
      // Deep Scan on a device without the memory for it reads the text.
      final useVision = deepScanRuns(
        deepScanOn:
            prefs.getBool(SharedPrefsConstants.aiUseVision) ??
            defaultDeepScan(isDesktop),
        capability: await deviceCapabilityService.getCapability(),
      );
      final Stream<MappingResourcesWithProgress> stream = processingRepository
          .mapRemainingResources(
            sessionImages,
            documentCategory: docCategory,
            useVision: useVision,
            maxTokens: savedMaxTokens,
            gpuLayers: savedGpuLayers,
            threads: savedThreads,
            contextSize: savedContextSize,
            outputMode: ExtractionOutputMode.fromPref(
              prefs.getString(SharedPrefsConstants.aiOutputMode),
            ),
          );

      // Each yield is every phase-2 resource so far, not a delta: it replaces
      // the previous yield on top of the resources the session started with.
      final baseResources =
          state.sessions
              .firstWhereOrNull((s) => s.id == event.sessionId)
              ?.resources ??
          const <MappingResource>[];
      await for (final (resources, progress) in stream) {
        final currentSession = state.sessions.firstWhereOrNull(
          (s) => s.id == event.sessionId,
        );
        if (emit.isDone ||
            currentSession?.status != ProcessingStatus.processing) {
          return;
        }
        updateSession(
          emit,
          sessionId: event.sessionId,
          resources: [...baseResources, ...resources],
          progress: progress,
          updateDb: true,
        );
      }
      // A cancel (or clear) ends the stream too: the session stays as the
      // cancel left it, neither a draft nor announced.
      if (emit.isDone ||
          state.sessions
                  .firstWhereOrNull((s) => s.id == event.sessionId)
                  ?.status !=
              ProcessingStatus.processing) {
        return;
      }
      updateSession(
        emit,
        sessionId: event.sessionId,
        status: ProcessingStatus.draft,
        updateDb: true,
      );
      emit(
        state.copyWith(
          notification: Notification(
            text: strings.l10n.processingFinished(_originName(session)),
            route: ProcessingRoute(sessionId: event.sessionId),
            time: DateTime.now(),
          ),
        ),
      );
      startNextPendingSession();
    } catch (e, s) {
      logger.e('[ProcessingBloc] resource extraction failed', e, s);
      final failedSession = state.sessions.firstWhereOrNull(
        (s) => s.id == event.sessionId,
      );
      if (failedSession?.origin == ProcessingOrigin.handover) {
        haltedHandovers.add(event.sessionId);
      }
      updateSession(
        emit,
        sessionId: event.sessionId,
        status: ProcessingStatus.patientExtracted,
        resources: failedSession?.resources,
        updateDb: true,
      );
      if (!emit.isDone) {
        if (isCapacityError(e.toString())) {
          emit(
            state.copyWith(
              status: PipelineStatus.capacityFailure(
                sessionId: event.sessionId,
              ),
            ),
          );
        } else {
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
    }
  }

  void onMappingCancelled(
    MappingCancelled event,
    Emitter<ProcessingState> emit,
  ) async {
    final session = state.sessions.firstWhereOrNull(
      (s) => s.id == event.sessionId,
    );
    if (session == null) return;
    final hasPatientData = session.patient.hasSelection;
    final newStatus =
        (session.status == ProcessingStatus.processing || hasPatientData)
        ? ProcessingStatus.patientExtracted
        : ProcessingStatus.cancelled;
    // Saved too: step 2 already wrote its results to the session, and they
    // would come back with the next start.
    updateSession(
      emit,
      sessionId: event.sessionId,
      status: newStatus,
      resources: [],
      progress: 0.0,
      updateDb: true,
    );
    // The AI really stops before the session can be processed again; until
    // then the screen says it is stopping.
    final stopping = session.isProcessing;
    if (stopping) {
      emit(
        state.copyWith(
          stoppingSessionIds: {...state.stoppingSessionIds, event.sessionId},
        ),
      );
    }
    try {
      if (stopping) {
        await processingRepository.cancelGeneration();
        await processingRepository.waitForStreamCompletion();
      }
      await processingRepository.disposeModel();
    } catch (e, s) {
      logger.e('[ProcessingBloc] stopping the AI after a cancel failed', e, s);
    } finally {
      if (stopping) {
        emit(
          state.copyWith(
            stoppingSessionIds: {...state.stoppingSessionIds}
              ..remove(event.sessionId),
          ),
        );
      }
    }
  }

  void onResourceCreationInitiated(
    ResourceCreationInitiated event,
    Emitter<ProcessingState> emit,
  ) async {
    final activeSession = state.sessions.firstWhereOrNull(
      (s) => s.id == event.sessionId,
    );
    if (activeSession == null) {
      // Cleared before Done: nothing to save, and the status stays as it was
      // so Done is not left disabled by savingResources.
      logger.w(
        '[ProcessingBloc] resource creation skipped: session '
        '${event.sessionId} no longer exists',
      );
      return;
    }
    emit(state.copyWith(status: const PipelineStatus.savingResources()));
    try {
      final encounterDraft = activeSession.encounter.draft;
      final specialtyValue = encounterDraft?.specialty.value ?? '';
      String specialtyEnumName = '';
      if (specialtyValue.isNotEmpty) {
        final match = MedicalSpecialty.values
            .where((s) => s.displayName == specialtyValue)
            .firstOrNull;
        specialtyEnumName = match?.name ?? 'generalCare';
      }
      final specialtyMeta = specialtyValue.isNotEmpty
          ? fhir_r4.FhirMeta(
              tag: [
                fhir_r4.Coding(
                  system: fhir_r4.FhirUri('http://healthwallet.me/specialty'),
                  code: fhir_r4.FhirCode(specialtyEnumName),
                  display: fhir_r4.FhirString(specialtyValue),
                ),
              ],
            )
          : null;

      // Records a layout document found already in the wallet are completed
      // (empty fields only), never saved again.
      final otherResources = activeSession.resources
          .where(
            (r) =>
                r is! MappingPatient &&
                r is! MappingEncounter &&
                r is! MappingDiagnosticReport &&
                !(r is MappingVisionPrescription && r.existingId.isNotEmpty),
          )
          .toList();
      final completions = await _completedPrescriptions(
        activeSession,
        meta: specialtyMeta,
      );
      final visitFill = _completedVisit(activeSession);
      // The review's own test, with what saving would really complete.
      final completed = {for (final c in completions) c.id};
      final checked = activeSession.copyWith(
        resources: [
          for (final r in activeSession.resources)
            r is MappingVisionPrescription && r.existingId.isNotEmpty
                ? r.copyWith(
                    completesExisting: completed.contains(r.existingId),
                  )
                : r,
        ],
      );
      if (checked.isAlreadyInWallet) {
        // Everything the document holds is in the wallet: nothing to write,
        // not even the document.
        final holder = (await holderService.load()).ofPatientId(
          activeSession.patient.existing!.id,
        );
        if (holder != null) await holderSelection.select(holder.id);
        emit(
          state.copyWith(
            status: PipelineStatus.success(sessionId: activeSession.id),
          ),
        );
        return;
      }

      final (subjectId, sourceId, finalContainer, holderId) =
          await _persistPrimaryResources(activeSession, visitFill: visitFill);
      final List<IFhirResource> fhirResources = [
        ...otherResources.map(
          (resource) => resource.toFhirResource(
            sourceId: sourceId,
            subjectId: subjectId,
            encounterId: finalContainer.id,
            meta: specialtyMeta,
          ),
        ),
        ...completions,
      ];
      if (fhirResources.isNotEmpty) {
        await syncRepository.saveResources(fhirResources);
      }
      final encounterForDoc = finalContainer is Encounter
          ? finalContainer
          : null;
      await documentReferenceService.replaceSessionDocuments(
        sessionId: activeSession.id,
        filePaths: activeSession.filePaths,
        patientId: subjectId,
        encounter: encounterForDoc,
        sourceId: sourceId,
        title: finalContainer.displayTitle,
      );
      // Shows the person the scan was filed under, once it is all saved.
      await holderSelection.select(holderId);
      emit(
        state.copyWith(
          status: PipelineStatus.success(sessionId: activeSession.id),
        ),
      );
    } catch (e, s) {
      logger.e('[ProcessingBloc] resource creation failed', e, s);
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

  /// The stored prescriptions the session's twins complete, with only the
  /// fields they leave empty filled; a twin that adds nothing is left out.
  Future<List<IFhirResource>> _completedPrescriptions(
    ProcessingSession session, {
    fhir_r4.FhirMeta? meta,
  }) async {
    final twins = session.resources
        .whereType<MappingVisionPrescription>()
        .where((r) => r.existingId.isNotEmpty)
        .toList();
    if (twins.isEmpty) return const [];
    final stored = {
      for (final r in await recordsRepository.getResources(
        resourceTypes: const [FhirType.VisionPrescription],
        limit: LayoutExtractionService.allRecords,
      ))
        if (r is VisionPrescription) r.id: r,
    };
    final encounterId =
        session.encounter.existing?.id ?? session.encounter.draft?.id;
    return [
      for (final twin in twins)
        if (stored[twin.existingId] case final row?)
          if (RecordCompletion.visionPrescription(
                row.rawResource,
                twin
                    .toFhirResource(
                      sourceId: row.sourceId,
                      subjectId: row.subjectId,
                      encounterId: encounterId,
                      meta: meta,
                    )
                    .rawResource,
                provenance: twin.provenance,
              )
              case final completed?)
            row.copyWith(
              rawResource: completed,
              encounterId: row.encounterId.isNotEmpty
                  ? row.encounterId
                  : _referenceId(completed['encounter']),
            ),
    ];
  }

  static String _referenceId(Object? reference) =>
      reference is Map && reference['reference'] is String
      ? (reference['reference'] as String).split('/').last
      : '';

  /// The existing visit with the identifiers the document adds (its serial),
  /// or null when it has them all or the visit is new.
  Encounter? _completedVisit(ProcessingSession session) {
    final existing = session.encounter.existing;
    final draft = session.encounter.draft;
    if (session.encounter.mode != ImportMode.linkExisting ||
        existing == null ||
        draft == null) {
      return null;
    }
    final completed = RecordCompletion.addIdentifiers(
      existing.rawResource,
      draft,
    );
    return completed == null ? null : existing.copyWith(rawResource: completed);
  }

  void onDocumentAttached(
    DocumentAttached event,
    Emitter<ProcessingState> emit,
  ) {
    final session = state.sessions.firstWhereOrNull(
      (s) => s.id == event.sessionId,
    );
    if (session == null) return;

    updateSession(
      emit,
      sessionId: event.sessionId,
      isDocumentAttached: true,
      updateDb: true,
    );
  }

  /// The patient, source, container and holder the scan is filed under.
  Future<(String, String, IFhirResource, String)> _persistPrimaryResources(
    ProcessingSession activeSession, {
    Encounter? visitFill,
  }) async {
    String subjectId;
    String sourceId;
    String holderId;
    final List<IFhirResource> resourcesToSave = [];
    if (activeSession.patient.mode == ImportMode.linkExisting &&
        activeSession.patient.existing != null) {
      // The person's own wallet Patient, never the row the match found
      // (it may be a provider's); the scanned fields fill only what it
      // leaves empty.
      final written = await holderService.walletPatientOf(
        activeSession.patient.existing!.id,
        scanned: activeSession.patient.draft,
      );
      subjectId = written.patient.id;
      sourceId = written.patient.sourceId;
      holderId = written.holderId;
    } else {
      // Someone new: a holder of their own, named after their Patient row.
      final MappingPatient draftPatient = activeSession.patient.draft!;
      final walletSource = await holderService.walletSourceOf(draftPatient.id);
      subjectId = draftPatient.id;
      sourceId = walletSource.id;
      holderId = walletSource.holderId ?? draftPatient.id;
      resourcesToSave.add(
        draftPatient.toFhirResource(
          sourceId: sourceId,
          subjectId: '',
          encounterId: '',
        ),
      );
    }
    IFhirResource finalContainer;
    if (activeSession.isDiagnosticReportContainer) {
      final MappingDiagnosticReport draftReport =
          activeSession.diagnosticReport!.draft!;
      finalContainer = draftReport.toFhirResource(
        sourceId: sourceId,
        subjectId: subjectId,
        encounterId: draftReport.id,
      );
      resourcesToSave.add(finalContainer);
    } else if (activeSession.encounter.existing != null) {
      finalContainer = visitFill ?? activeSession.encounter.existing!;
      if (visitFill != null) resourcesToSave.add(visitFill);
    } else {
      final MappingEncounter draftEncounter = activeSession.encounter.draft!;
      finalContainer = draftEncounter.toFhirResource(
        sourceId: sourceId,
        subjectId: subjectId,
        encounterId: draftEncounter.id,
      );
      resourcesToSave.add(finalContainer);
    }
    if (resourcesToSave.isNotEmpty) {
      await syncRepository.saveResources(resourcesToSave);
    }

    return (subjectId, sourceId, finalContainer, holderId);
  }
}
