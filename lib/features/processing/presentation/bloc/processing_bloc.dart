import 'dart:async';
import 'dart:io';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:collection/collection.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:health_wallet/core/config/constants/shared_prefs_constants.dart';
import 'package:health_wallet/core/l10n/app_strings_provider.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/core/l10n/display_names.dart';
import 'package:health_wallet/core/navigation/app_router.dart';
import 'package:health_wallet/core/services/device_capability_service.dart';
import 'package:health_wallet/core/utils/logger.dart';
import 'package:health_wallet/features/holders/domain/services/holder_selection.dart';
import 'package:health_wallet/features/holders/domain/services/holder_service.dart';
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
import 'package:health_wallet/features/processing/domain/services/layout_extraction/layout_extraction_service.dart';
import 'package:health_wallet/features/processing/domain/services/ocr_processing_service.dart';
import 'package:health_wallet/features/processing/presentation/bloc/handlers/processing_handler.dart';
import 'package:health_wallet/features/processing/presentation/bloc/handlers/session_handler.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/records/domain/repository/records_repository.dart';
import 'package:health_wallet/features/sync/domain/repository/sync_repository.dart';
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
  final HolderService _holderService;
  final HolderSelection _holderSelection;
  final RecordsRepository _recordsRepository;
  final SharedPreferences _prefs;
  final AppStringsProvider _strings;
  final LayoutExtractionService _layoutExtraction;
  final DeviceCapabilityService _deviceCapabilityService;

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
  HolderService get holderService => _holderService;

  @override
  HolderSelection get holderSelection => _holderSelection;

  @override
  SharedPreferences get prefs => _prefs;

  @override
  AppStringsProvider get strings => _strings;

  @override
  LayoutExtractionService get layoutExtraction => _layoutExtraction;

  @override
  DeviceCapabilityService get deviceCapabilityService =>
      _deviceCapabilityService;

  final Set<String> _haltedHandovers = {};

  @override
  Set<String> get haltedHandovers => _haltedHandovers;

  ProcessingBloc(
    this._repository,
    this._ocrProcessingHelper,
    this._syncRepository,
    this._documentReferenceService,
    this._holderService,
    this._holderSelection,
    this._recordsRepository,
    this._prefs,
    this._strings,
    this._layoutExtraction,
    this._deviceCapabilityService,
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
    on<PagesReordered>(onPagesReordered, transformer: sequential());
    on<ContainerTypeSwitched>(_onContainerTypeSwitched);
    on<PageRotated>(onPageRotated, transformer: sequential());
    on<OcrPagesReleased>(onOcrPagesReleased, transformer: sequential());
    on<SessionHandedOver>(_onSessionHandedOver, transformer: sequential());
    on<HandoverDraftReceived>(
      _onHandoverDraftReceived,
      transformer: sequential(),
    );
    on<HandoverReturned>(_onHandoverReturned, transformer: sequential());
    on<SessionSavedElsewhere>(
      _onSessionSavedElsewhere,
      transformer: sequential(),
    );
    on<SessionTakenBack>(_onSessionTakenBack, transformer: sequential());
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
    // A handover past its patient step goes first: it is furthest along,
    // and the phone waits for it.
    if (_continueHandover()) return;
    final pendingSession = state.sessions.firstWhereOrNull(
      (s) =>
          s.status == ProcessingStatus.pending &&
          !_haltedHandovers.contains(s.id),
    );
    if (pendingSession != null) {
      add(SessionActivated(sessionId: pendingSession.id));
    }
  }

  /// Starts the records step of a handover waiting after its patient step;
  /// false when there is none.
  bool _continueHandover() {
    final handover = state.sessions.firstWhereOrNull(
      (s) =>
          s.origin == ProcessingOrigin.handover &&
          s.status == ProcessingStatus.patientExtracted &&
          !_haltedHandovers.contains(s.id),
    );
    if (handover == null) return false;
    add(ProcessRemainingResources(sessionId: handover.id, automatic: true));
    return true;
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
    // The desktop has it: a local step that ends after the handover (its
    // cancel, a late result) leaves it as it is.
    if (activeSession.status == ProcessingStatus.handedOver) return;

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
      final sessions = <ProcessingSession>[];
      for (final s in await _repository.getProcessingSessions()) {
        // A step the app was closed in the middle of starts again; left
        // "processing", the session would hold up every other one.
        switch (s.status) {
          case ProcessingStatus.processingPatient:
            sessions.add(
              s.copyWith(status: ProcessingStatus.pending, progress: 0),
            );
          case ProcessingStatus.processing:
            // As after a cancel: step two saved each result as it went, and
            // Done would save the partial ones, or its next run add to them.
            final restarted = s.copyWith(
              status: ProcessingStatus.patientExtracted,
              progress: 0,
              resources: const [],
            );
            sessions.add(restarted);
            await _saveRestarted(restarted);
          default:
            sessions.add(s);
        }
      }

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
      // A handover the app was closed before finishing carries on.
      if (sessions.any((s) => s.origin == ProcessingOrigin.handover)) {
        startNextPendingSessionOf(ProcessingOrigin.handover);
      }
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

  /// A failed save is logged: the session still loads at step one, and the
  /// next start clears its results again.
  Future<void> _saveRestarted(ProcessingSession session) async {
    try {
      await _repository.editProcessingSession(session);
    } on Exception catch (e, s) {
      logger.e('Saving a session restarted at step one failed', e, s);
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

  /// Starts the next waiting session of [origin] only.
  void startNextPendingSessionOf(ProcessingOrigin origin) {
    if (_continueHandover()) return;
    final next = state.sessions.firstWhereOrNull(
      (s) =>
          s.origin == origin &&
          s.status == ProcessingStatus.pending &&
          !_haltedHandovers.contains(s.id),
    );
    if (next != null) add(SessionActivated(sessionId: next.id));
  }

  /// The status, unless it is a failure of [sessionId].
  PipelineStatus _withoutFailureOf(String sessionId) => switch (state.status) {
    Failure(sessionId: final id) when id == sessionId =>
      const PipelineStatus.initial(),
    CapacityFailure(sessionId: final id) when id == sessionId =>
      const PipelineStatus.initial(),
    final other => other,
  };

  /// A draft dropped here may have had edits: the text says they weren't
  /// kept.
  String _savedElsewhereText(
    ProcessingSession session, {
    required bool byDesktop,
  }) {
    final name = session.origin.localizedName(_strings.l10n);
    final l10n = _strings.l10n;
    if (session.status == ProcessingStatus.draft) {
      return byDesktop
          ? l10n.handoverDraftSavedOnDesktop(name)
          : l10n.handoverDraftSavedOnPhone(name);
    }
    return byDesktop
        ? l10n.handoverSavedOnDesktop(name)
        : l10n.handoverSavedOnPhone(name);
  }

  void _replaceSession(Emitter<ProcessingState> emit, ProcessingSession next) {
    emit(
      state.copyWith(
        sessions: [
          for (final s in state.sessions) s.id == next.id ? next : s,
        ],
      ),
    );
    _repository.editProcessingSession(next);
  }

  Future<void> _stopLocalProcessing(ProcessingSession session) async {
    if (!session.isProcessing) return;
    await _repository.cancelGeneration();
    await _repository.waitForStreamCompletion();
    await _repository.disposeModel();
  }

  Future<void> _onSessionHandedOver(
    SessionHandedOver event,
    Emitter<ProcessingState> emit,
  ) async {
    final session = state.sessions.firstWhereOrNull(
      (s) => s.id == event.sessionId,
    );
    if (session == null || session.status == ProcessingStatus.handedOver) {
      return;
    }
    // Marked first, so the step being cancelled can't change it back.
    _replaceSession(
      emit,
      session.copyWith(status: ProcessingStatus.handedOver, progress: 0),
    );
    // The desktop processes it: a failure of this phone's attempt (no model)
    // no longer applies.
    emit(state.copyWith(status: _withoutFailureOf(session.id)));
    await _stopLocalProcessing(session);
    _layoutExtraction.forget(session.id);
  }

  Future<void> _onHandoverDraftReceived(
    HandoverDraftReceived event,
    Emitter<ProcessingState> emit,
  ) async {
    final session = state.sessions.firstWhereOrNull(
      (s) => s.id == event.sessionId,
    );
    // Taken back and processed here meanwhile: this device's own result
    // stands.
    if (session == null ||
        session.isProcessing ||
        session.status == ProcessingStatus.draft) {
      return;
    }
    _replaceSession(
      emit,
      session.copyWith(
        status: ProcessingStatus.draft,
        progress: 1,
        patient: event.patient,
        encounter: event.encounter,
        diagnosticReport: event.diagnosticReport,
        resources: event.resources,
      ),
    );
    emit(
      state.copyWith(
        status: _withoutFailureOf(session.id),
        notification: Notification(
          text: _strings.l10n.handoverReadyToReview(
            session.origin.localizedName(_strings.l10n),
          ),
          route: ProcessingRoute(sessionId: session.id),
          time: DateTime.now(),
        ),
      ),
    );
  }

  void _onHandoverReturned(
    HandoverReturned event,
    Emitter<ProcessingState> emit,
  ) {
    final session = state.sessions.firstWhereOrNull(
      (s) => s.id == event.sessionId,
    );
    if (session == null || session.status != ProcessingStatus.handedOver) {
      return;
    }
    _replaceSession(
      emit,
      session.copyWith(
        status: session.patient.hasSelection
            ? ProcessingStatus.patientExtracted
            : ProcessingStatus.pending,
        progress: 0,
      ),
    );
    final name = session.origin.localizedName(_strings.l10n);
    final text = switch (event.reason) {
      HandoverReturnReason.withdrawn => null,
      HandoverReturnReason.failedOnDesktop =>
        _strings.l10n.handoverFailedOnDesktop(name),
      HandoverReturnReason.noModelOnDesktop =>
        _strings.l10n.handoverNoModelOnDesktop(name),
      HandoverReturnReason.deletedOnDesktop =>
        _strings.l10n.handoverDeletedOnDesktop(name),
    };
    if (text == null) return;
    emit(
      state.copyWith(
        notification: Notification(
          text: text,
          route: ProcessingRoute(sessionId: session.id),
          time: DateTime.now(),
          type: NotificationType.error,
        ),
      ),
    );
  }

  Future<void> _onSessionTakenBack(
    SessionTakenBack event,
    Emitter<ProcessingState> emit,
  ) async {
    final session = state.sessions.firstWhereOrNull(
      (s) => s.id == event.sessionId,
    );
    if (session == null) return;
    await _removeForOtherDevice(
      emit,
      session,
      Notification(
        text: _strings.l10n.handoverTakenBack,
        time: DateTime.now(),
      ),
    );
  }

  Future<void> _onSessionSavedElsewhere(
    SessionSavedElsewhere event,
    Emitter<ProcessingState> emit,
  ) async {
    final session = state.sessions.firstWhereOrNull(
      (s) => s.id == event.sessionId,
    );
    if (session == null) return;
    // The records come through the sync; this copy and its files go.
    await _removeForOtherDevice(
      emit,
      session,
      Notification(
        text: _savedElsewhereText(session, byDesktop: event.byDesktop),
        time: DateTime.now(),
        type: NotificationType.success,
      ),
    );
  }

  /// Removes [session], which the other device took back or saved, and says
  /// so with [notification].
  Future<void> _removeForOtherDevice(
    Emitter<ProcessingState> emit,
    ProcessingSession session,
    Notification notification,
  ) async {
    final wasProcessing = session.isProcessing;
    await removeSession(emit, session, notification: notification);
    // It held the queue: the next document goes on.
    if (wasProcessing) startNextPendingSession();
  }

  @override
  Future<void> removeSession(
    Emitter<ProcessingState> emit,
    ProcessingSession session, {
    Notification? notification,
  }) async {
    if (session.isProcessing) {
      // Marked first, so the step being stopped stages, saves and announces
      // nothing; stopping, so it can't be retried meanwhile.
      _replaceSession(
        emit,
        session.copyWith(status: ProcessingStatus.cancelled, progress: 0),
      );
      emit(
        state.copyWith(
          stoppingSessionIds: {...state.stoppingSessionIds, session.id},
        ),
      );
    }
    try {
      await _stopLocalProcessing(session);
    } on Exception catch (e, s) {
      // The session goes anyway; the next run waits for the AI to end.
      logger.e('[ProcessingBloc] stopping the AI for a removal failed', e, s);
    }
    _layoutExtraction.forget(session.id);
    _haltedHandovers.remove(session.id);
    emit(
      state.copyWith(
        sessions: [
          for (final s in state.sessions)
            if (s.id != session.id) s,
        ],
        stoppingSessionIds: {...state.stoppingSessionIds}..remove(session.id),
        status: _withoutFailureOf(session.id),
        notification: notification ?? state.notification,
      ),
    );
    await _repository.deleteProcessingSession(session);
    await discardPagesOf(emit, session);
  }
}
