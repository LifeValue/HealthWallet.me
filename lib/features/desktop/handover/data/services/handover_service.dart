import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:injectable/injectable.dart';
import 'package:path/path.dart' as p;

import 'package:health_wallet/features/desktop/communication/data/services/chunk_transfer_service.dart';
import 'package:health_wallet/features/desktop/communication/data/services/message_router.dart';
import 'package:health_wallet/features/desktop/communication/data/services/tcp_service.dart';
import 'package:health_wallet/features/desktop/handover/domain/entity/handover_session.dart';
import 'package:health_wallet/features/processing/domain/entity/processing_session.dart';
import 'package:health_wallet/features/processing/presentation/bloc/processing_bloc.dart';

@lazySingleton
class HandoverService {
  final MessageRouter _messageRouter;
  final ChunkTransferService _chunkTransferService;
  final TcpService _tcpService;
  final ProcessingBloc _processingBloc;

  final Map<String, HandoverSession> _sessions = {};
  final Map<String, List<String>> _receivedFiles = {};
  final _sessionUpdateController = StreamController<HandoverSession>.broadcast();

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

    final filePaths = _receivedFiles[sessionId]!;
    _processingBloc.add(DocumentImported(filePaths: filePaths));

    _processingBlocSub?.cancel();
    _processingBlocSub = _processingBloc.stream.listen((processingState) {
      _handleProcessingStateChange(
        sessionId,
        processingState,
        onProcessingComplete,
      );
    });
  }

  void _handleProcessingStateChange(
    String sessionId,
    ProcessingState processingState,
    void Function(String sessionId) onProcessingComplete,
  ) {
    final session = _sessions[sessionId];
    if (session == null || session.status == HandoverStatus.complete) return;

    final activeProcessingSession = processingState.sessions.lastOrNull;
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

      await _tcpService.sendData('handover.result', {
        'session_id': sessionId,
        'resources': resources,
        if (patientJson != null) 'patient': patientJson,
        if (encounterJson != null) 'encounter': encounterJson,
      });

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
    final home = Platform.environment['HOME'] ?? '';
    final dir = Directory(
      p.join(home, 'Library', 'Application Support', 'HealthWallet', 'handover', sessionId),
    );
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<void> _cleanupSessionDirectory(String sessionId) async {
    try {
      final home = Platform.environment['HOME'] ?? '';
      final dir = Directory(
        p.join(home, 'Library', 'Application Support', 'HealthWallet', 'handover', sessionId),
      );
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } catch (_) {}
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
