import 'dart:io';

import 'package:collection/collection.dart';
import 'package:fhir_r4/fhir_r4.dart' as fhir_r4;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_wallet/core/config/constants/shared_prefs_constants.dart';
import 'package:health_wallet/core/l10n/app_strings_provider.dart';
import 'package:health_wallet/core/l10n/display_names.dart';
import 'package:health_wallet/core/navigation/app_router.dart';
import 'package:health_wallet/core/utils/logger.dart';
import 'package:health_wallet/features/holders/domain/services/holder_matcher.dart';
import 'package:health_wallet/features/holders/domain/services/holder_service.dart';
import 'package:health_wallet/features/home/domain/entities/medical_specialty.dart';
import 'package:health_wallet/features/notifications/domain/entities/notification.dart';
import 'package:health_wallet/features/processing/domain/entity/extraction_output_mode.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_diagnostic_report.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_encounter.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_patient.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_resource.dart';
import 'package:health_wallet/features/processing/domain/entity/processing_session.dart';
import 'package:health_wallet/features/processing/domain/entity/staged_resource.dart';
import 'package:health_wallet/features/processing/domain/repository/processing_repository.dart';
import 'package:health_wallet/features/processing/domain/services/document_reference_service.dart';
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
  SharedPreferences get prefs;
  AppStringsProvider get strings;

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
        session.status == ProcessingStatus.patientExtracted) {
      return;
    }
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
      final sessionImages =
          state.sessionImagePaths[event.sessionId] ?? state.allImagePathsForOCR;
      if (sessionImages.isEmpty) {
        updateSession(
          emit,
          sessionId: event.sessionId,
          status: ProcessingStatus.pending,
          progress: 0.0,
        );
        emit(
          state.copyWith(
            status: const PipelineStatus.failure(
              error: 'No images were generated from the document',
              reason: PipelineFailureReason.noImagesGenerated,
            ),
          ),
        );
        return;
      }
      final medicalText = await ocrProcessingHelper.processOcrForImages(
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
      final ocrPreMatch = await _tryMatchPatientFromOcr(medicalText);
      if (ocrPreMatch != null) {
        ProcessingLogBuffer.instance.log(
          '[${DateTime.now().toIso8601String().substring(11, 23)}][ScanAI] OCR pre-match: ${ocrPreMatch.displayTitle}, running container-only AI',
        );
        final stagedPatient = StagedPatient(
          existing: ocrPreMatch,
          mode: ImportMode.linkExisting,
        );
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
              ),
            ),
          );
        }
      }
    }
  }

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
        return StagedPatient(
          existing: holder.representativePatient,
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
    emit(state.copyWith(status: const PipelineStatus.loading()));
    final session = state.sessions.firstWhereOrNull(
      (s) => s.id == event.sessionId,
    );
    if (session == null) return;
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
      final sessionImages =
          state.sessionImagePaths[event.sessionId] ?? state.allImagePathsForOCR;
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
      final useVision =
          prefs.getBool(SharedPrefsConstants.aiUseVision) ?? isDesktop;
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
    updateSession(
      emit,
      sessionId: event.sessionId,
      status: newStatus,
      resources: [],
      progress: 0.0,
    );
    await processingRepository.disposeModel();
  }

  void onResourceCreationInitiated(
    ResourceCreationInitiated event,
    Emitter<ProcessingState> emit,
  ) async {
    emit(state.copyWith(status: const PipelineStatus.savingResources()));
    final activeSession = state.sessions.firstWhere(
      (s) => s.id == event.sessionId,
    );
    try {
      final (subjectId, sourceId, finalContainer, _) =
          await _persistPrimaryResources(activeSession);
      await prefs.setString('selected_patient_id', subjectId);
      final otherResources = activeSession.resources
          .where(
            (r) =>
                r is! MappingPatient &&
                r is! MappingEncounter &&
                r is! MappingDiagnosticReport,
          )
          .toList();
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
      final List<IFhirResource> fhirResources = otherResources
          .map(
            (resource) => resource.toFhirResource(
              sourceId: sourceId,
              subjectId: subjectId,
              encounterId: finalContainer.id,
              meta: specialtyMeta,
            ),
          )
          .toList();
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
      emit(state.copyWith(status: const PipelineStatus.success()));
    } catch (e, s) {
      logger.e('[ProcessingBloc] resource creation failed', e, s);
      emit(
        state.copyWith(
          status: PipelineStatus.failure(
            error: e.toString(),
            reason: PipelineFailureReason.of(e),
          ),
        ),
      );
    }
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

  Future<(String, String, IFhirResource, Patient)> _persistPrimaryResources(
    ProcessingSession activeSession,
  ) async {
    String subjectId;
    String sourceId;
    final List<IFhirResource> resourcesToSave = [];
    if (activeSession.patient.mode == ImportMode.linkExisting &&
        activeSession.patient.existing != null) {
      final Patient existingPatient = activeSession.patient.existing!;
      final walletSource = await holderService.walletSourceForPatient(
        existingPatient.id,
        patientName: existingPatient.displayTitle,
      );
      subjectId = existingPatient.id;
      sourceId = walletSource.id;

      if (activeSession.patient.draft != null) {
        final draftWithExistingId = activeSession.patient.draft!.copyWith(
          id: existingPatient.id,
        );
        resourcesToSave.add(
          draftWithExistingId.toFhirResource(
            sourceId: existingPatient.sourceId,
            subjectId: '',
            encounterId: '',
          ),
        );
      }
    } else {
      // Someone new: a holder of their own, named after their Patient row.
      final MappingPatient draftPatient = activeSession.patient.draft!;
      final walletSource = await holderService.walletSourceOf(
        draftPatient.id,
        patientName:
            '${draftPatient.givenName.value} ${draftPatient.familyName.value}',
      );
      subjectId = draftPatient.id;
      sourceId = walletSource.id;
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
      finalContainer = activeSession.encounter.existing!;
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

    final Patient finalPatient;
    final savedPatient = resourcesToSave.whereType<Patient>().firstOrNull;
    if (savedPatient != null) {
      finalPatient = savedPatient;
    } else if (activeSession.patient.existing != null) {
      finalPatient = activeSession.patient.existing!;
    } else {
      finalPatient = resourcesToSave.firstWhere((r) => r is Patient) as Patient;
    }

    return (subjectId, sourceId, finalContainer, finalPatient);
  }
}
