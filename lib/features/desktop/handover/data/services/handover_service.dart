import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:injectable/injectable.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:health_wallet/features/desktop/communication/data/services/chunk_transfer_service.dart';
import 'package:health_wallet/features/desktop/communication/data/services/message_router.dart';
import 'package:health_wallet/features/desktop/communication/data/services/tcp_service.dart';
import 'package:health_wallet/features/desktop/handover/domain/entity/handover_session.dart';
import 'package:health_wallet/features/processing/domain/entity/processing_session.dart';
import 'package:health_wallet/features/processing/domain/entity/staged_resource.dart';
import 'package:health_wallet/features/processing/presentation/bloc/processing_bloc.dart';

@lazySingleton
class HandoverService {
  final MessageRouter _messageRouter;
  final ChunkTransferService _chunkTransferService;
  final TcpService _tcpService;
  final ProcessingBloc _processingBloc;

  final Map<String, HandoverSession> _sessions = {};
  final Map<String, List<String>> _receivedFiles = {};
  final Map<String, Map<String, dynamic>?> _phase1Data = {};
  final _sessionUpdateController = StreamController<HandoverSession>.broadcast();
  final Map<String, ({String type, Map<String, dynamic> payload})> _pendingResults = {};

  StreamSubscription? _offerSub;
  StreamSubscription? _fileSub;
  StreamSubscription? _processingBlocSub;

  Stream<HandoverSession> get sessionUpdates => _sessionUpdateController.stream;

  HandoverService(
    this._messageRouter,
    this._chunkTransferService,
    this._tcpService,
    this._processingBloc,
  );

  void startListening({
    required void Function(HandoverSession session) onOfferReceived,
    required void Function(String sessionId) onFileReceived,
    required void Function(String sessionId) onProcessingComplete,
  }) {
    _offerSub = _messageRouter.on('handover.offer').listen((payload) {
      _handleOffer(payload, onOfferReceived);
    });

    _fileSub = _messageRouter.on('handover.file').listen((payload) {
      _handleFileChunk(payload, onFileReceived, onProcessingComplete);
    });
  }

  void _handleOffer(
    Map<String, dynamic> payload,
    void Function(HandoverSession session) onOfferReceived,
  ) {
    final sessionId = payload['session_id'] as String;
    final fileCount = payload['file_count'] as int;
    final totalBytes = payload['total_bytes'] as int;

    final session = HandoverSession(
      sessionId: sessionId,
      status: HandoverStatus.receiving,
      fileCount: fileCount,
    );

    _sessions[sessionId] = session;
    _receivedFiles[sessionId] = [];
    _phase1Data[sessionId] = payload['phase1_data'] as Map<String, dynamic>?;

    _tcpService.sendData('handover.accept', {
      'session_id': sessionId,
    });

    onOfferReceived(session);
    _sessionUpdateController.add(session);
  }

  Future<void> _handleFileChunk(
    Map<String, dynamic> payload,
    void Function(String sessionId) onFileReceived,
    void Function(String sessionId) onProcessingComplete,
  ) async {
    final sessionId = payload['session_id'] as String;
    final fileIndex = payload['file_index'] as int;
    final fileName = payload['file_name'] as String;
    final data = payload['data'] as String;

    final session = _sessions[sessionId];
    if (session == null) return;

    try {
      final directory = await _getSessionDirectory(sessionId);
      final filePath = p.join(directory.path, fileName);
      final fileBytes = base64Decode(data);
      await File(filePath).writeAsBytes(fileBytes);

      _receivedFiles[sessionId]!.add(filePath);

      final updatedSession = session.copyWith(
        receivedCount: _receivedFiles[sessionId]!.length,
        progress: _receivedFiles[sessionId]!.length / session.fileCount * 0.5,
      );
      _sessions[sessionId] = updatedSession;

      onFileReceived(sessionId);
      _sessionUpdateController.add(updatedSession);

      if (updatedSession.receivedCount >= session.fileCount) {
        await _startProcessing(sessionId, onProcessingComplete);
      }
    } catch (e) {
      _updateSessionError(sessionId, e.toString());
    }
  }

  Future<void> _startProcessing(
    String sessionId,
    void Function(String sessionId) onProcessingComplete,
  ) async {
    final processingSession = _sessions[sessionId]!.copyWith(
      status: HandoverStatus.processing,
      progress: 0.5,
    );
    _sessions[sessionId] = processingSession;
    _sessionUpdateController.add(processingSession);

    _step1Notified = false;

    final filePaths = _receivedFiles[sessionId]!;
    final phase1 = _phase1Data[sessionId];
    _hasPhase1Data = phase1 != null && phase1['patient'] != null;

    StagedPatient? phase1Patient;
    StagedEncounter? phase1Encounter;
    StagedDiagnosticReport? phase1DiagnosticReport;

    if (_hasPhase1Data) {
      phase1Patient = stagedPatientFromJson(
          phase1['patient'] as Map<String, dynamic>);
      if (phase1['encounter'] != null) {
        phase1Encounter = stagedEncounterFromJson(
            phase1['encounter'] as Map<String, dynamic>);
      }
      if (phase1['diagnosticReport'] != null) {
        phase1DiagnosticReport = stagedDiagnosticReportFromJson(
            phase1['diagnosticReport'] as Map<String, dynamic>);
      }
    }

    _processingBloc.add(DocumentImported(
      filePaths: filePaths,
      origin: ProcessingOrigin.handover,
      phase1Patient: phase1Patient,
      phase1Encounter: phase1Encounter,
      phase1DiagnosticReport: phase1DiagnosticReport,
    ));

    var sessionActivated = false;
    var phase2Triggered = false;

    _processingBlocSub?.cancel();
    _processingBlocSub = _processingBloc.stream.listen((processingState) {
      final newSession = processingState.sessions.firstWhereOrNull(
        (s) => s.origin == ProcessingOrigin.handover,
      );
      if (newSession == null) return;

      if (!sessionActivated && processingState.status is SessionCreated) {
        sessionActivated = true;
        if (!_hasPhase1Data) {
          _processingBloc.add(SessionActivated(sessionId: newSession.id));
        }
      }

      if (_hasPhase1Data &&
          !phase2Triggered &&
          newSession.status == ProcessingStatus.patientExtracted) {
        phase2Triggered = true;
        _processingBloc.add(SessionActivated(sessionId: newSession.id));
        Future.delayed(const Duration(milliseconds: 300), () {
          _processingBloc.add(
            ProcessRemainingResources(sessionId: newSession.id),
          );
        });
      }

      _handleProcessingStateChange(
        sessionId,
        processingState,
        onProcessingComplete,
      );
    });
  }

  bool _step1Notified = false;
  bool _hasPhase1Data = false;

  void _handleProcessingStateChange(
    String sessionId,
    ProcessingState processingState,
    void Function(String sessionId) onProcessingComplete,
  ) {
    final session = _sessions[sessionId];
    if (session == null || session.status == HandoverStatus.complete) return;

    final activeProcessingSession = processingState.sessions.firstWhereOrNull(
      (s) => s.origin == ProcessingOrigin.handover,
    );
    if (activeProcessingSession == null) return;

    if (activeProcessingSession.status == ProcessingStatus.processing ||
        activeProcessingSession.status == ProcessingStatus.processingPatient) {
      final progress = 0.5 + (activeProcessingSession.progress * 0.3);
      final updated = session.copyWith(progress: progress);
      _sessions[sessionId] = updated;
      _sessionUpdateController.add(updated);

      _tcpService.sendData('handover.progress', {
        'session_id': sessionId,
        'progress': progress,
        'status': 'processing',
      });
    }

    if (activeProcessingSession.status == ProcessingStatus.patientExtracted &&
        !_step1Notified &&
        !_hasPhase1Data) {
      _step1Notified = true;
      final updated = session.copyWith(
        status: HandoverStatus.complete,
        progress: 1.0,
      );
      _sessions[sessionId] = updated;
      _sessionUpdateController.add(updated);

      final step1Payload = {'session_id': sessionId};
      _pendingResults[sessionId] = (type: 'handover.step1_complete', payload: step1Payload);
      _tcpService.sendData('handover.step1_complete', step1Payload);

      _processingBlocSub?.cancel();
      _processingBlocSub = null;
      onProcessingComplete(sessionId);
    }

    if (activeProcessingSession.status == ProcessingStatus.draft) {
      final sendingSession = session.copyWith(
        status: HandoverStatus.sendingResults,
        progress: 0.85,
      );
      _sessions[sessionId] = sendingSession;
      _sessionUpdateController.add(sendingSession);

      _sendResults(sessionId, activeProcessingSession, onProcessingComplete);
    }

    if (processingState.status is Failure) {
      final failure = processingState.status as Failure;
      _updateSessionError(sessionId, failure.error);
    }
  }

  Future<void> _sendResults(
    String sessionId,
    ProcessingSession processingSession,
    void Function(String sessionId) onProcessingComplete,
  ) async {
    try {
      final resources = processingSession.resources
          .map((r) => r.toJson())
          .toList();

      final patientJson = processingSession.patient.draft?.toJson();
      final encounterJson = processingSession.encounter.draft?.toJson();

      final resultPayload = {
        'session_id': sessionId,
        'resources': resources,
        if (patientJson != null) 'patient': patientJson,
        if (encounterJson != null) 'encounter': encounterJson,
      };

      _pendingResults[sessionId] = (type: 'handover.result', payload: resultPayload);

      await _tcpService.sendData('handover.result', resultPayload);

      final completedSession = HandoverSession(
        sessionId: sessionId,
        status: HandoverStatus.complete,
        fileCount: _sessions[sessionId]!.fileCount,
        receivedCount: _sessions[sessionId]!.receivedCount,
        progress: 1.0,
      );
      _sessions[sessionId] = completedSession;
      _sessionUpdateController.add(completedSession);

      _processingBlocSub?.cancel();
      _processingBlocSub = null;

      onProcessingComplete(sessionId);

      await _cleanupSessionDirectory(sessionId);
    } catch (e) {
      _updateSessionError(sessionId, e.toString());
    }
  }

  void _updateSessionError(String sessionId, String error) {
    final session = _sessions[sessionId];
    if (session == null) return;

    final errorSession = session.copyWith(
      status: HandoverStatus.error,
      error: error,
    );
    _sessions[sessionId] = errorSession;
    _sessionUpdateController.add(errorSession);

    _tcpService.sendData('handover.progress', {
      'session_id': sessionId,
      'progress': session.progress,
      'status': 'error',
      'error': error,
    });
  }

  Future<Directory> _getSessionDirectory(String sessionId) async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory(
      p.join(appDir.path, 'HealthWallet', 'handover', sessionId),
    );
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<void> _cleanupSessionDirectory(String sessionId) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final dir = Directory(
        p.join(appDir.path, 'HealthWallet', 'handover', sessionId),
      );
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } catch (_) {}
  }

  Future<void> resendPendingResults() async {
    for (final entry in _pendingResults.entries) {
      try {
        await _tcpService.sendData(entry.value.type, entry.value.payload);
      } catch (_) {}
    }
  }

  void stopListening() {
    _offerSub?.cancel();
    _offerSub = null;
    _fileSub?.cancel();
    _fileSub = null;
    _processingBlocSub?.cancel();
    _processingBlocSub = null;
  }

  void dispose() {
    stopListening();
    _sessionUpdateController.close();
  }
}
