import 'dart:async';
import 'dart:io';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:collection/collection.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:health_wallet/core/config/constants/shared_prefs_constants.dart';
import 'package:health_wallet/core/l10n/app_strings_provider.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/core/utils/logger.dart';
import 'package:health_wallet/features/notifications/domain/entities/notification.dart';
import 'package:health_wallet/features/processing/domain/ai_settings_reset.dart';
import 'package:health_wallet/features/processing/domain/deep_scan_defaults.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapped_property.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_diagnostic_report.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_encounter.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_patient.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_resource.dart';
import 'package:health_wallet/features/processing/domain/entity/model_not_found_exception.dart';
import 'package:health_wallet/features/processing/domain/entity/processing_session.dart';
import 'package:health_wallet/features/processing/domain/entity/staged_resource.dart';
import 'package:health_wallet/features/processing/domain/repository/processing_repository.dart';
import 'package:health_wallet/features/processing/domain/services/document_reference_service.dart';
import 'package:health_wallet/features/processing/domain/services/ocr_processing_service.dart';
import 'package:health_wallet/features/processing/presentation/bloc/handlers/processing_handler.dart';
import 'package:health_wallet/features/processing/presentation/bloc/handlers/session_handler.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/records/domain/repository/records_repository.dart';
import 'package:health_wallet/features/sync/domain/repository/sync_repository.dart';
import 'package:health_wallet/features/sync/domain/services/source_type_service.dart';
import 'package:health_wallet/features/user/domain/services/patient_deduplication_service.dart';
import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'processing_bloc.freezed.dart';
part 'processing_event.dart';
part 'processing_state.dart';

@LazySingleton()
class ProcessingBloc extends Bloc<ProcessingEvent, ProcessingState>
    with SessionHandler, ProcessingHandler {
  final ProcessingRepository _repository;
  final OcrProcessingHelper _ocrProcessingHelper;
  final SyncRepository _syncRepository;
  final DocumentReferenceService _documentReferenceService;
  final PatientDeduplicationService _deduplicationService;
  final SourceTypeService _sourceTypeService;
  final RecordsRepository _recordsRepository;
  final SharedPreferences _prefs;
  final AppStringsProvider _strings;

  @override
  ProcessingRepository get processingRepository => _repository;

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
  PatientDeduplicationService get deduplicationService => _deduplicationService;

  @override
  SourceTypeService get sourceTypeService => _sourceTypeService;

  @override
  SharedPreferences get prefs => _prefs;

  @override
  AppStringsProvider get strings => _strings;

  ProcessingBloc(
    this._repository,
    this._ocrProcessingHelper,
    this._syncRepository,
    this._documentReferenceService,
    this._deduplicationService,
    this._sourceTypeService,
    this._recordsRepository,
    this._prefs,
    this._strings,
  ) : super(const ProcessingState()) {
    on<ProcessingInitialised>(
      onProcessingInitialised,
      transformer: sequential(),
    );
    on<CaptureButtonPressed>(onCaptureButtonPressed);
    on<DocumentImported>(onDocumentImported);
    on<SessionChangedProgress>(onSessionChangedProgress);
    // Concurrent: opening one session must not wait for another's pages.
    on<SessionCleared>(onSessionCleared, transformer: concurrent());
    on<SessionActivated>(onSessionActivated, transformer: concurrent());
    on<MappingInitiated>(onMappingInitiated, transformer: restartable());
    on<ResourceChanged>(onResourceChanged);
    on<PatientReverted>(onPatientReverted);
    on<ResourceRemoved>(onResourceRemoved);
    on<ResourceCreationInitiated>(onResourceCreationInitiated);
    on<NotificationAcknowledged>(onNotificationAcknowledged);
    on<MappingCancelled>(onMappingCancelled);
    on<ResourcesAdded>(onResourcesAdded);
    on<EncounterAttached>(onEncounterAttached);
    on<ProcessRemainingResources>(
      onProcessRemainingResources,
      transformer: concurrent(),
    );
    on<DocumentAttached>(onDocumentAttached);
    on<TokenCapacityUpdated>(
      onTokenCapacityUpdated,
      transformer: sequential(),
    );
    on<VisionToggled>(onVisionToggled, transformer: sequential());
    on<PagesReordered>(onPagesReordered);
    on<ContainerTypeSwitched>(_onContainerTypeSwitched);
    on<PageRotated>(onPageRotated, transformer: sequential());
    on<OcrPagesReleased>(onOcrPagesReleased, transformer: sequential());
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
      add(SessionActivated(sessionId: pendingSession.id));
    }
  }

  @override
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

    emit(
      state.copyWith(
        sessions: newSessions,
      ),
    );
  }

  Future<void> onProcessingInitialised(
    ProcessingInitialised event,
    Emitter<ProcessingState> emit,
  ) async {
    emit(state.copyWith(status: const PipelineStatus.loading()));

    final isDesktop =
        Platform.isMacOS || Platform.isLinux || Platform.isWindows;
    await _resetMistakenAiSettingsOnce(isDesktop: isDesktop);

    try {
      final sessions = await _repository.getProcessingSessions();

      final useVision =
          _prefs.getBool(SharedPrefsConstants.aiUseVision) ??
          defaultDeepScan(isDesktop);
      emit(
        state.copyWith(
          sessions: sessions,
          status: const PipelineStatus.initial(),
          useVision: useVision,
        ),
      );
    } on Exception catch (e, s) {
      logger.e('Loading the processing sessions failed', e, s);
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

  void onNotificationAcknowledged(
    NotificationAcknowledged event,
    Emitter<ProcessingState> emit,
  ) {
    emit(state.copyWith(notification: null));
  }

  Future<void> onTokenCapacityUpdated(
    TokenCapacityUpdated event,
    Emitter<ProcessingState> emit,
  ) async {
    final newMaxTokens = event.newMaxTokens;
    if (newMaxTokens != null) {
      await _prefs.setInt(SharedPrefsConstants.aiMaxTokens, newMaxTokens);
    }
    await _repository.disposeModel();
    add(MappingInitiated(sessionId: event.sessionId));
  }

  /// Sent by both AI settings screens, so a running Processing screen
  /// follows a change made in Preferences.
  Future<void> onVisionToggled(
    VisionToggled event,
    Emitter<ProcessingState> emit,
  ) async {
    emit(state.copyWith(useVision: event.useVision));
    await _prefs.setBool(SharedPrefsConstants.aiUseVision, event.useVision);
  }

  /// Removes, once, the AI settings that earlier versions saved by mistake
  /// (see [mistakenAiSettings]). A failure is logged and retried on the next
  /// start; it never stops the sessions from loading.
  Future<void> _resetMistakenAiSettingsOnce({required bool isDesktop}) async {
    if (_prefs.getBool(SharedPrefsConstants.aiMistakenSettingsReset) ?? false) {
      return;
    }
    try {
      final keys = mistakenAiSettings(
        savedMaxTokens: _prefs.getInt(SharedPrefsConstants.aiMaxTokens),
        savedUseVision: _prefs.getBool(SharedPrefsConstants.aiUseVision),
        isDesktop: isDesktop,
      );
      for (final key in keys) {
        await _prefs.remove(key);
      }
      await _prefs.setBool(SharedPrefsConstants.aiMistakenSettingsReset, true);
      if (keys.isNotEmpty) {
        logger.i('Reset mistakenly saved AI settings: $keys');
      }
    } on Exception catch (e, s) {
      logger.e('Resetting the mistakenly saved AI settings failed', e, s);
    }
  }

  void _onContainerTypeSwitched(
    ContainerTypeSwitched event,
    Emitter<ProcessingState> emit,
  ) {
    final session = state.sessions.firstWhereOrNull(
      (s) => s.id == event.sessionId,
    );
    if (session == null) return;

    if (session.diagnosticReport?.draft != null) {
      final dr = session.diagnosticReport!.draft!;
      final encounter = MappingEncounter(
        id: dr.id,
        encounterType: MappedProperty(
          value: dr.reportName.value,
          confidenceLevel: dr.reportName.confidenceLevel,
        ),
        periodStart: MappedProperty(
          value: dr.issuedDate.value,
          confidenceLevel: dr.issuedDate.confidenceLevel,
        ),
      );
      updateSession(
        emit,
        sessionId: event.sessionId,
        encounter: StagedEncounter(draft: encounter),
        diagnosticReport: const StagedDiagnosticReport(),
        updateDb: true,
      );
    } else if (session.encounter.draft != null ||
        session.encounter.existing != null) {
      final enc =
          session.encounter.draft ??
          MappingEncounter.fromFhirResource(session.encounter.existing!);
      final report = MappingDiagnosticReport(
        id: enc.id,
        reportName: MappedProperty(
          value: enc.encounterType.value,
          confidenceLevel: enc.encounterType.confidenceLevel,
        ),
        issuedDate: MappedProperty(
          value: enc.periodStart.value,
          confidenceLevel: enc.periodStart.confidenceLevel,
        ),
      );
      updateSession(
        emit,
        sessionId: event.sessionId,
        encounter: const StagedEncounter(),
        diagnosticReport: StagedDiagnosticReport(draft: report),
        updateDb: true,
      );
    }
  }
}
