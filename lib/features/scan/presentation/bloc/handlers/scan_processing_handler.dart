import 'package:collection/collection.dart';
import 'package:flutter/widgets.dart' hide Notification;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_wallet/core/config/constants/shared_prefs_constants.dart';
import 'package:health_wallet/core/navigation/app_router.dart';
import 'package:health_wallet/core/utils/logger.dart';
import 'package:health_wallet/features/scan/domain/services/scan_log_buffer.dart';
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
import 'package:health_wallet/features/scan/presentation/bloc/scan_bloc.dart';
import 'package:health_wallet/features/sync/domain/repository/sync_repository.dart';
import 'package:health_wallet/features/sync/domain/services/source_type_service.dart';
import 'package:health_wallet/features/user/domain/services/patient_deduplication_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

mixin ScanProcessingHandler on Bloc<ScanEvent, ScanState> {
  ScanRepository get scanRepository;
  OcrProcessingHelper get ocrProcessingHelper;
  RecordsRepository get recordsRepository;
  SyncRepository get syncRepository;
  DocumentReferenceService get documentReferenceService;
  PatientDeduplicationService get deduplicationService;
  SourceTypeService get sourceTypeService;
  SharedPreferences get prefs;

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

  bool isCapacityError(String errorString);
  void startNextPendingSession();

  void onScanMappingInitiated(
    ScanMappingInitiated event,
    Emitter<ScanState> emit,
  ) async {
    emit(state.copyWith(status: const ScanStatus.loading()));
    final session =
        state.sessions.firstWhereOrNull((s) => s.id == event.sessionId);
    if (session == null) return;
    if (session.isProcessing || session.status == ProcessingStatus.draft) {
      return;
    }
    if (session.status == ProcessingStatus.patientExtracted &&
        session.patient.hasSelection) {
      return;
    }
    final anotherSessionProcessing = state.sessions.any(
      (s) => s.id != event.sessionId && s.isProcessing,
    );
    if (anotherSessionProcessing) return;

    try {
      updateSession(emit,
          sessionId: event.sessionId,
          status: ProcessingStatus.processingPatient);
      final sessionImages =
          state.sessionImagePaths[event.sessionId] ?? state.allImagePathsForOCR;
      if (sessionImages.isEmpty) {
        updateSession(emit,
            sessionId: event.sessionId,
            status: ProcessingStatus.pending,
            progress: 0.0);
        emit(state.copyWith(
          status: const ScanStatus.failure(
            error: 'No images were generated from the scan. Please try scanning again.',
          ),
        ));
        return;
      }
      final medicalText =
          await ocrProcessingHelper.processOcrForImages(sessionImages);
      if (medicalText.isEmpty || medicalText.trim().isEmpty) {
        updateSession(emit,
            sessionId: event.sessionId, status: ProcessingStatus.draft);
        return;
      }
      final ocrPreMatch = await _tryMatchPatientFromOcr(medicalText);
      if (ocrPreMatch != null) {
        ScanLogBuffer.instance.log(
          '[${DateTime.now().toIso8601String().substring(11, 23)}][ScanAI] OCR pre-match: ${ocrPreMatch.displayTitle}, running container-only AI');
        final stagedPatient = StagedPatient(
          existing: ocrPreMatch,
          mode: ImportMode.linkExisting,
        );
        final savedMaxTokens = prefs.getInt(SharedPrefsConstants.aiMaxTokens);
        final savedThreads = prefs.getInt(SharedPrefsConstants.aiThreads);
        final savedContextSize = prefs.getInt(SharedPrefsConstants.aiContextSize);
        final container = await scanRepository.mapContainerOnly(
          medicalText,
          maxTokens: savedMaxTokens,
          threads: savedThreads,
          contextSize: savedContextSize,
        );
        final finalSession =
            state.sessions.firstWhereOrNull((s) => s.id == event.sessionId);
        if (container is MappingDiagnosticReport) {
          updateSession(emit,
              sessionId: event.sessionId,
              status: ProcessingStatus.patientExtracted,
              patient: stagedPatient,
              diagnosticReport: StagedDiagnosticReport(draft: container),
              updateDb: true);
        } else {
          updateSession(emit,
              sessionId: event.sessionId,
              status: ProcessingStatus.patientExtracted,
              patient: stagedPatient,
              encounter: StagedEncounter(draft: container as MappingEncounter),
              updateDb: true);
        }
        emit(state.copyWith(
          notification: Notification(
            text: "${finalSession?.origin ?? 'Document'} patient matched",
            route: ProcessingRoute(sessionId: event.sessionId),
            time: DateTime.now(),
          ),
        ));
        startNextPendingSession();
        return;
      }

      final savedMaxTokens = prefs.getInt(SharedPrefsConstants.aiMaxTokens);
      final savedGpuLayers = prefs.getInt(SharedPrefsConstants.aiGpuLayers);
      final savedThreads = prefs.getInt(SharedPrefsConstants.aiThreads);
      final savedContextSize = prefs.getInt(SharedPrefsConstants.aiContextSize);
      final (patient, container) = await scanRepository.mapBasicInfo(
        sessionImages,
        maxTokens: savedMaxTokens,
        gpuLayers: savedGpuLayers,
        threads: savedThreads,
        contextSize: savedContextSize,
      );
      final stagedPatient = await _matchOrCreatePatient(patient);
      final finalSession =
          state.sessions.firstWhereOrNull((s) => s.id == event.sessionId);
      if (container is MappingDiagnosticReport) {
        updateSession(emit,
            sessionId: event.sessionId,
            status: ProcessingStatus.patientExtracted,
            patient: stagedPatient,
            diagnosticReport: StagedDiagnosticReport(draft: container),
            updateDb: true);
      } else {
        updateSession(emit,
            sessionId: event.sessionId,
            status: ProcessingStatus.patientExtracted,
            patient: stagedPatient,
            encounter: StagedEncounter(draft: container as MappingEncounter),
            updateDb: true);
      }
      emit(state.copyWith(
        notification: Notification(
          text: "${finalSession?.origin ?? 'Document'} patient info extracted",
          route: ProcessingRoute(sessionId: event.sessionId),
          time: DateTime.now(),
        ),
      ));

      startNextPendingSession();
    } on Exception catch (e) {
      updateSession(emit,
          sessionId: event.sessionId,
          status: ProcessingStatus.pending,
          updateDb: true);
      if (!emit.isDone) {
        if (isCapacityError(e.toString())) {
          emit(state.copyWith(
            status: ScanStatus.capacityFailure(sessionId: event.sessionId),
          ));
        } else {
          emit(state.copyWith(status: ScanStatus.failure(error: e.toString())));
        }
      }
    }
  }

  Future<Patient?> _tryMatchPatientFromOcr(String ocrText) async {
    if (ocrText.isEmpty) return null;
    try {
      final allPatientsResources = await recordsRepository.getResources(
        resourceTypes: [FhirType.Patient],
        limit: 1000,
      );
      final allPatients = allPatientsResources.whereType<Patient>().toList();
      if (allPatients.isEmpty) return null;

      for (final patient in allPatients) {
        if (patient.identifier == null) continue;
        for (final id in patient.identifier!) {
          final value = id.value?.valueString;
          if (value == null || value.length < 5) continue;
          if (ocrText.contains(value) || _fuzzyIdentifierMatch(value, ocrText)) {
            ScanLogBuffer.instance.log(
              '[${DateTime.now().toIso8601String().substring(11, 23)}][ScanAI] OCR pre-match: found identifier $value');
            return patient;
          }
        }
      }
    } catch (_) {}
    return null;
  }

  bool _fuzzyIdentifierMatch(String identifier, String ocrText) {
    final digitsOnly = identifier.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.length < 5) return false;

    if (ocrText.contains(digitsOnly)) return true;

    if (digitsOnly.length > 10) {
      final trimmed = digitsOnly.substring(0, digitsOnly.length - 1);
      if (ocrText.contains(trimmed)) return true;
    }

    return false;
  }

  Future<StagedPatient> _matchOrCreatePatient(MappingPatient patient) async {
    try {
      final allPatientsResources = await recordsRepository.getResources(
        resourceTypes: [FhirType.Patient],
        limit: 1000,
      );
      final allPatients = allPatientsResources.whereType<Patient>().toList();
      final matchedPatient =
          deduplicationService.findMatchingPatient(patient, allPatients);
      if (matchedPatient != null) {
        return StagedPatient(
            existing: matchedPatient, mode: ImportMode.linkExisting);
      }
      return StagedPatient(draft: patient, mode: ImportMode.createNew);
    } catch (e) {
      logger.e('Error matching patient: $e');
      return StagedPatient(draft: patient, mode: ImportMode.createNew);
    }
  }

  void onScanProcessRemainingResources(
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
      updateSession(emit,
          sessionId: event.sessionId, status: ProcessingStatus.processing);
      final sessionImages = state.sessionImagePaths[event.sessionId] ??
          state.allImagePathsForOCR;
      final activeSession =
          state.sessions.firstWhereOrNull((s) => s.id == event.sessionId);
      final docCategory =
          activeSession?.isDiagnosticReportContainer == true
              ? 'lab_report' : 'visit';
      final savedMaxTokens = prefs.getInt(SharedPrefsConstants.aiMaxTokens);
      final savedGpuLayers = prefs.getInt(SharedPrefsConstants.aiGpuLayers);
      final savedThreads = prefs.getInt(SharedPrefsConstants.aiThreads);
      final savedContextSize = prefs.getInt(SharedPrefsConstants.aiContextSize);
      final useVision =
          prefs.getBool(SharedPrefsConstants.aiUseVision) ?? false;
      Stream<MappingResourcesWithProgress> stream =
          scanRepository.mapRemainingResources(sessionImages,
              documentCategory: docCategory,
              useVision: useVision,
              maxTokens: savedMaxTokens,
              gpuLayers: savedGpuLayers,
              threads: savedThreads,
              contextSize: savedContextSize);

      await for (final (resources, progress) in stream) {
        final currentSession = state.sessions
            .firstWhereOrNull((s) => s.id == event.sessionId);
        if (emit.isDone ||
            currentSession?.status != ProcessingStatus.processing) {
          return;
        }
        updateSession(emit,
            sessionId: event.sessionId,
            resources: [...currentSession!.resources, ...resources],
            progress: progress,
            updateDb: true);
      }
      updateSession(emit,
          sessionId: event.sessionId,
          status: ProcessingStatus.draft,
          updateDb: true);
      emit(state.copyWith(
        notification: Notification(
          text: "${session.origin} processing finished",
          route: ProcessingRoute(sessionId: event.sessionId),
          time: DateTime.now(),
        ),
      ));
      startNextPendingSession();
    } catch (e) {
      final failedSession = state.sessions.firstWhereOrNull(
        (s) => s.id == event.sessionId,
      );
      updateSession(emit,
          sessionId: event.sessionId,
          status: ProcessingStatus.patientExtracted,
          resources: failedSession?.resources,
          updateDb: true);
      if (!emit.isDone) {
        if (isCapacityError(e.toString())) {
          emit(state.copyWith(
            status: ScanStatus.capacityFailure(sessionId: event.sessionId),
          ));
        } else {
          emit(state.copyWith(status: ScanStatus.failure(error: e.toString())));
        }
      }
    }
  }

  void onScanMappingCancelled(
    ScanMappingCancelled event,
    Emitter<ScanState> emit,
  ) async {
    final session =
        state.sessions.firstWhereOrNull((s) => s.id == event.sessionId);
    if (session == null) return;
    final hasPatientData = session.patient.hasSelection;
    final newStatus = (session.status == ProcessingStatus.processing ||
            hasPatientData)
        ? ProcessingStatus.patientExtracted
        : ProcessingStatus.cancelled;
    updateSession(emit,
        sessionId: event.sessionId,
        status: newStatus, resources: [], progress: 0.0);
    await scanRepository.disposeModel();
  }

  void onScanResourceCreationInitiated(
    ScanResourceCreationInitiated event,
    Emitter<ScanState> emit,
  ) async {
    emit(state.copyWith(status: const ScanStatus.savingResources()));
    final activeSession =
        state.sessions.firstWhere((s) => s.id == event.sessionId);
    try {
      final (subjectId, sourceId, finalContainer, _) =
          await _persistPrimaryResources(activeSession);
      await prefs.setString('selected_patient_id', subjectId);
      final otherResources = activeSession.resources
          .where((r) => r is! MappingPatient &&
              r is! MappingEncounter && r is! MappingDiagnosticReport)
          .toList();
      List<IFhirResource> fhirResources = otherResources
          .map((resource) => resource.toFhirResource(
              sourceId: sourceId,
              subjectId: subjectId,
              encounterId: finalContainer.id))
          .toList();
      if (fhirResources.isNotEmpty) {
        await syncRepository.saveResources(fhirResources);
      }
      final encounterForDoc =
          finalContainer is Encounter ? finalContainer : null;
      await documentReferenceService.saveGroupedDocumentsAsFhirRecords(
        filePaths: activeSession.filePaths,
        patientId: subjectId,
        encounter: encounterForDoc,
        sourceId: sourceId,
        title: finalContainer.displayTitle,
      );
      emit(state.copyWith(status: const ScanStatus.success()));
    } catch (e) {
      logger.e('[ScanBloc] resource creation failed: $e');
      emit(state.copyWith(status: ScanStatus.failure(error: e.toString())));
    }
  }

  void onScanDocumentAttached(
    ScanDocumentAttached event,
    Emitter<ScanState> emit,
  ) {
    final session =
        state.sessions.firstWhereOrNull((s) => s.id == event.sessionId);
    if (session == null) return;

    updateSession(emit,
        sessionId: event.sessionId,
        isDocumentAttached: true,
        updateDb: true);
  }

  Future<(String, String, IFhirResource, Patient)> _persistPrimaryResources(
    ProcessingSession activeSession,
  ) async {
    String subjectId;
    String sourceId;
    List<IFhirResource> resourcesToSave = [];
    final availableSources = await syncRepository.getSources();
    if (activeSession.patient.mode == ImportMode.linkExisting &&
        activeSession.patient.existing != null) {
      Patient existingPatient = activeSession.patient.existing!;
      final walletSource =
          await sourceTypeService.ensureWalletSourceForPatient(
              patientId: existingPatient.id,
              patientName: existingPatient.displayTitle,
              availableSources: availableSources);
      subjectId = existingPatient.id;
      sourceId = walletSource.id;

      if (activeSession.patient.draft != null) {
        final draftWithExistingId = activeSession.patient.draft!
            .copyWith(id: existingPatient.id);
        resourcesToSave.add(draftWithExistingId.toFhirResource(
            sourceId: existingPatient.sourceId,
            subjectId: '',
            encounterId: ''));
      }
    } else {
      MappingPatient draftPatient = activeSession.patient.draft!;
      final walletSource =
          await sourceTypeService.ensureWalletSourceForPatient(
              patientId: draftPatient.id,
              patientName:
                  "${draftPatient.givenName.value} ${draftPatient.familyName.value}",
              availableSources: availableSources);
      subjectId = draftPatient.id;
      sourceId = walletSource.id;
      resourcesToSave.add(draftPatient.toFhirResource(
          sourceId: sourceId, subjectId: '', encounterId: ''));
    }
    IFhirResource finalContainer;
    if (activeSession.isDiagnosticReportContainer) {
      MappingDiagnosticReport draftReport =
          activeSession.diagnosticReport!.draft!;
      finalContainer = draftReport.toFhirResource(
          sourceId: sourceId,
          subjectId: subjectId,
          encounterId: draftReport.id);
      resourcesToSave.add(finalContainer);
    } else if (activeSession.encounter.existing != null) {
      finalContainer = activeSession.encounter.existing!;
    } else {
      MappingEncounter draftEncounter = activeSession.encounter.draft!;
      finalContainer = draftEncounter.toFhirResource(
          sourceId: sourceId,
          subjectId: subjectId,
          encounterId: draftEncounter.id);
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
      finalPatient =
          resourcesToSave.firstWhere((r) => r is Patient) as Patient;
    }

    return (subjectId, sourceId, finalContainer, finalPatient);
  }
}
