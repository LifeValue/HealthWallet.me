import 'dart:async';
import 'dart:io';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:collection/collection.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_wallet/core/config/constants/shared_prefs_constants.dart';
import 'package:health_wallet/core/navigation/app_router.dart';
import 'package:health_wallet/core/services/pdf_storage_service.dart';
import 'package:health_wallet/features/notifications/domain/entities/notification.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/records/domain/repository/records_repository.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapped_property.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_diagnostic_report.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_encounter.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_patient.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_resource.dart';
import 'package:health_wallet/features/processing/domain/entity/processing_session.dart';
import 'package:health_wallet/features/processing/domain/entity/staged_resource.dart';
import 'package:health_wallet/features/processing/domain/repository/scan_repository.dart';
import 'package:health_wallet/features/processing/domain/services/document_reference_service.dart';
import 'package:health_wallet/features/processing/domain/services/ocr_processing_service.dart';
import 'package:health_wallet/features/processing/presentation/bloc/handlers/processing_handler.dart';
import 'package:health_wallet/features/processing/presentation/bloc/handlers/session_handler.dart';
import 'package:health_wallet/features/processing/presentation/helpers/scan_path_helper.dart';
import 'package:health_wallet/features/sync/domain/repository/sync_repository.dart';
import 'package:health_wallet/features/sync/domain/services/source_type_service.dart';
import 'package:health_wallet/features/user/domain/services/patient_deduplication_service.dart';
import 'package:injectable/injectable.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'processing_state.dart';
part 'processing_event.dart';
part 'processing_bloc.freezed.dart';

@LazySingleton()
class ProcessingBloc extends Bloc<ProcessingEvent, ProcessingState>
    with SessionHandler, ProcessingHandler {
  final PdfStorageService _pdfStorageService;
  final ScanRepository _repository;
  final OcrProcessingHelper _ocrProcessingHelper;
  final SyncRepository _syncRepository;
  final DocumentReferenceService _documentReferenceService;
  final PatientDeduplicationService _deduplicationService;
  final SourceTypeService _sourceTypeService;
  final RecordsRepository _recordsRepository;
  final SharedPreferences _prefs;

  @override
  ScanRepository get scanRepository => _repository;

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
  PatientDeduplicationService get deduplicationService =>
      _deduplicationService;

  @override
  SourceTypeService get sourceTypeService => _sourceTypeService;

  @override
  SharedPreferences get prefs => _prefs;

  ProcessingBloc(
    this._pdfStorageService,
    this._repository,
    this._ocrProcessingHelper,
    this._syncRepository,
    this._documentReferenceService,
    this._deduplicationService,
    this._sourceTypeService,
    this._recordsRepository,
    this._prefs,
  ) : super(const ProcessingState()) {
    on<ProcessingInitialised>(onProcessingInitialised);
    on<DocumentImported>(onDocumentImported);
    on<SessionChangedProgress>(onSessionChangedProgress);
    on<SessionCleared>(onSessionCleared);
    on<SessionActivated>(onSessionActivated);
    on<MappingInitiated>(onMappingInitiated,
        transformer: restartable());
    on<ResourceChanged>(onResourceChanged);
    on<PatientReverted>(onPatientReverted);
    on<ResourceRemoved>(onResourceRemoved);
    on<ResourceCreationInitiated>(onResourceCreationInitiated);
    on<NotificationAcknowledged>(onNotificationAcknowledged);
    on<MappingCancelled>(onMappingCancelled);
    on<ResourcesAdded>(onResourcesAdded);
    on<EncounterAttached>(onEncounterAttached);
    on<ProcessRemainingResources>(onProcessRemainingResources);
    on<DocumentAttached>(onDocumentAttached);
    on<TokenCapacityUpdated>(onTokenCapacityUpdated);
    on<VisionToggled>(onVisionToggled);
    on<PagesReordered>(onPagesReordered);
    on<ContainerTypeSwitched>(_onContainerTypeSwitched);
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

    emit(state.copyWith(
      sessions: newSessions,
    ));
  }

  Future<void> onProcessingInitialised(
    ProcessingInitialised event,
    Emitter<ProcessingState> emit,
  ) async {
    emit(state.copyWith(status: const PipelineStatus.loading()));

    try {
      final sessions = await _repository.getProcessingSessions();

      final isDesktop = Platform.isMacOS || Platform.isLinux || Platform.isWindows;
      final useVision =
          _prefs.getBool(SharedPrefsConstants.aiUseVision) ?? isDesktop;
      emit(state.copyWith(
        sessions: sessions,
        status: const PipelineStatus.initial(),
        useVision: useVision,
      ));
    } on Exception catch (e) {
      emit(state.copyWith(status: PipelineStatus.failure(error: e.toString())));
    }
  }


  void onNotificationAcknowledged(
    NotificationAcknowledged event,
    Emitter<ProcessingState> emit,
  ) {
    emit(state.copyWith(notification: null));
  }

  void onTokenCapacityUpdated(
    TokenCapacityUpdated event,
    Emitter<ProcessingState> emit,
  ) async {
    await _prefs.setInt(
        SharedPrefsConstants.aiMaxTokens, event.newMaxTokens);
    await _repository.disposeModel();
    add(MappingInitiated(sessionId: event.sessionId));
  }

  void onVisionToggled(
    VisionToggled event,
    Emitter<ProcessingState> emit,
  ) {
    _prefs.setBool(SharedPrefsConstants.aiUseVision, event.useVision);
    emit(state.copyWith(useVision: event.useVision));
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
      updateSession(emit,
        sessionId: event.sessionId,
        encounter: StagedEncounter(draft: encounter),
        diagnosticReport: const StagedDiagnosticReport(),
        updateDb: true,
      );
    } else if (session.encounter?.draft != null ||
        session.encounter?.existing != null) {
      final enc = session.encounter!.draft ??
          MappingEncounter.fromFhirResource(session.encounter!.existing!);
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
      updateSession(emit,
        sessionId: event.sessionId,
        encounter: const StagedEncounter(),
        diagnosticReport: StagedDiagnosticReport(draft: report),
        updateDb: true,
      );
    }
  }
}
