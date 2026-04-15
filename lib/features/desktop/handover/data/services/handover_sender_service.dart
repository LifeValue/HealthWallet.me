import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import 'package:health_wallet/features/desktop/communication/data/services/message_router.dart';
import 'package:health_wallet/features/desktop/communication/data/services/tcp_service.dart';
import 'package:health_wallet/features/desktop/handover/domain/entity/handover_session.dart';

@lazySingleton
class HandoverSenderService {
  final TcpService _tcpService;
  final MessageRouter _messageRouter;

  final _sessionUpdateController = StreamController<HandoverSession>.broadcast();
  final Map<String, HandoverSession> _activeSessions = {};
  final Map<String, bool> _cancelled = {};

  StreamSubscription? _acceptSub;
  StreamSubscription? _progressSub;
  StreamSubscription? _resultSub;

  Stream<HandoverSession> get sessionUpdates => _sessionUpdateController.stream;

  HandoverSenderService(this._tcpService, this._messageRouter) {
    _progressSub = _messageRouter.on('handover.progress').listen(_handleProgress);
    _resultSub = _messageRouter.on('handover.result').listen(_handleResult);
  }

  Future<void> sendHandover(List<String> filePaths) async {
    final sessionId = const Uuid().v4();

    _cancelled[sessionId] = false;

    final session = HandoverSession(
      sessionId: sessionId,
      status: HandoverStatus.sending,
      fileCount: filePaths.length,
    );
    _activeSessions[sessionId] = session;
    _sessionUpdateController.add(session);

    int totalBytes = 0;
    for (final path in filePaths) {
      totalBytes += await File(path).length();
    }

    await _tcpService.sendData('handover.offer', {
      'session_id': sessionId,
      'file_count': filePaths.length,
      'total_bytes': totalBytes,
    });

    final acceptCompleter = Completer<void>();
    _acceptSub?.cancel();
    _acceptSub = _messageRouter.on('handover.accept').listen((payload) {
      final acceptedId = payload['session_id'] as String?;
      if (acceptedId == sessionId && !acceptCompleter.isCompleted) {
        acceptCompleter.complete();
      }
    });

    try {
      await acceptCompleter.future.timeout(const Duration(seconds: 30));
    } on TimeoutException {
      _updateSession(sessionId, HandoverStatus.error, error: 'Desktop did not accept');
      return;
    }

    if (_cancelled[sessionId] == true) return;

    for (var i = 0; i < filePaths.length; i++) {
      if (_cancelled[sessionId] == true) return;

      final file = File(filePaths[i]);
      final bytes = await file.readAsBytes();
      final data = base64Encode(bytes);
      final fileName = p.basename(filePaths[i]);

      await _tcpService.sendData('handover.file', {
        'session_id': sessionId,
        'file_index': i,
        'file_name': fileName,
        'data': data,
      });

      final progress = (i + 1) / filePaths.length * 0.5;
      final sending = _activeSessions[sessionId]!.copyWith(
        receivedCount: i + 1,
        progress: progress,
      );
      _activeSessions[sessionId] = sending;
      _sessionUpdateController.add(sending);
    }

    _updateSession(sessionId, HandoverStatus.waitingForResults, progress: 0.5);
  }

  void cancelHandover(String sessionId) {
    _cancelled[sessionId] = true;
    _updateSession(sessionId, HandoverStatus.error, error: 'Cancelled');
  }

  void _handleProgress(Map<String, dynamic> payload) {
    final sessionId = payload['session_id'] as String?;
    if (sessionId == null) return;

    final session = _activeSessions[sessionId];
    if (session == null) return;

    final status = payload['status'] as String?;
    final progress = (payload['progress'] as num?)?.toDouble() ?? session.progress;

    if (status == 'error') {
      final error = payload['error'] as String? ?? 'Processing failed';
      _updateSession(sessionId, HandoverStatus.error, progress: progress, error: error);
      return;
    }

    final updated = session.copyWith(
      status: HandoverStatus.waitingForResults,
      progress: progress,
    );
    _activeSessions[sessionId] = updated;
    _sessionUpdateController.add(updated);
  }

  void _handleResult(Map<String, dynamic> payload) {
    final sessionId = payload['session_id'] as String?;
    if (sessionId == null) return;

    _updateSession(sessionId, HandoverStatus.complete, progress: 1.0);
  }

  void _updateSession(
    String sessionId,
    HandoverStatus status, {
    double? progress,
    String? error,
  }) {
    final session = _activeSessions[sessionId];
    if (session == null) return;

    final updated = session.copyWith(
      status: status,
      progress: progress ?? session.progress,
      error: error,
    );
    _activeSessions[sessionId] = updated;
    _sessionUpdateController.add(updated);
  }

  void dispose() {
    _acceptSub?.cancel();
    _progressSub?.cancel();
    _resultSub?.cancel();
    _sessionUpdateController.close();
  }
}
