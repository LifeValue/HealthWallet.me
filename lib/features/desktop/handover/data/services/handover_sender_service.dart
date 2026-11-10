import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:health_wallet/core/utils/logger.dart';
import 'package:health_wallet/features/desktop/communication/data/services/message_router.dart';
import 'package:health_wallet/features/desktop/communication/data/services/tcp_service.dart';
import 'package:health_wallet/features/desktop/handover/data/services/handover_outbox.dart';
import 'package:health_wallet/features/desktop/handover/domain/entity/handover_protocol.dart';
import 'package:health_wallet/features/desktop/handover/domain/entity/handover_session.dart';
import 'package:injectable/injectable.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

part 'handover_sender_service.freezed.dart';

/// What the desktop said about a document this phone handed over.
@freezed
sealed class DesktopHandoverEvent with _$DesktopHandoverEvent {
  const factory DesktopHandoverEvent.progress({
    required String sessionId,
    required double progress,
  }) = DesktopHandoverProgress;

  /// The desktop's draft, to review on this phone.
  const factory DesktopHandoverEvent.result({
    required String sessionId,
    required HandoverDraft draft,
  }) = DesktopHandoverResult;

  const factory DesktopHandoverEvent.failed({
    required String sessionId,
    required HandoverFailure failure,
  }) = DesktopHandoverFailed;

  /// The desktop's user saved the records there.
  const factory DesktopHandoverEvent.saved({required String sessionId}) =
      DesktopHandoverSaved;

  /// The desktop's user deleted the document there.
  const factory DesktopHandoverEvent.cancelled({required String sessionId}) =
      DesktopHandoverCancelled;
}

/// The phone's end of a handover: sends a document's files to the desktop
/// and reports what the desktop says about it. Messages the desktop must
/// receive wait in an outbox until it acknowledges them.
@lazySingleton
class HandoverSenderService {
  HandoverSenderService(this._tcp, this._router, SharedPreferences prefs)
    : _outbox = HandoverOutbox(prefs, _tcp, key: outboxKey);

  static const outboxKey = 'handover_outbox_phone';

  final TcpService _tcp;
  final MessageRouter _router;
  final HandoverOutbox _outbox;

  /// How long to wait for the desktop's answer; shortened in tests.
  @visibleForTesting
  Duration acceptTimeout = HandoverProtocol.acceptTimeout;

  final _transfers = StreamController<HandoverSession>.broadcast();
  final _events = StreamController<DesktopHandoverEvent>.broadcast();
  final Map<String, Completer<HandoverFailure?>> _answers = {};
  final Set<String> _cancelled = {};
  final List<StreamSubscription<Object?>> _subscriptions = [];

  /// Progress of the transfers this phone is making.
  Stream<HandoverSession> get transfers => _transfers.stream;

  /// What the desktop reports, once per message; acknowledge each with
  /// [acknowledge] after handling it.
  Stream<DesktopHandoverEvent> get desktopEvents => _events.stream;

  void start() {
    if (_subscriptions.isNotEmpty) return;
    void on(String type, void Function(Map<String, dynamic>) handle) =>
        _subscriptions.add(_router.on(type).listen(handle));

    on(HandoverMessage.accept, (m) => _answer(m, null));
    on(
      HandoverMessage.reject,
      (m) => _answer(m, HandoverFailure.fromWire(m['reason'] as String?)),
    );
    on(HandoverMessage.progress, (m) {
      final id = m['session_id'];
      final progress = m['progress'];
      if (id is String && progress is num) {
        _events.add(
          DesktopHandoverEvent.progress(
            sessionId: id,
            progress: progress.toDouble().clamp(0, 1),
          ),
        );
      }
    });
    on(HandoverMessage.result, (m) {
      final id = m['session_id'];
      final draft = m['draft'];
      if (id is! String || draft is! Map<String, dynamic>) return;
      try {
        _events.add(
          DesktopHandoverEvent.result(
            sessionId: id,
            draft: HandoverDraft.fromJson(draft),
          ),
        );
      } on Object catch (e) {
        // Unreadable: acknowledged so the desktop stops sending it, and the
        // document comes back to this phone.
        logger.w('[HandoverSender] unreadable result for $id', e);
        _events.add(
          DesktopHandoverEvent.failed(
            sessionId: id,
            failure: HandoverFailure.failed,
          ),
        );
        unawaited(acknowledge(id, HandoverMessage.result));
      }
    });
    on(HandoverMessage.failed, (m) {
      final id = m['session_id'];
      if (id is! String) return;
      _events.add(
        DesktopHandoverEvent.failed(
          sessionId: id,
          failure: HandoverFailure.fromWire(m['reason'] as String?),
        ),
      );
    });
    on(HandoverMessage.saved, (m) {
      final id = m['session_id'];
      if (id is String) _events.add(DesktopHandoverEvent.saved(sessionId: id));
    });
    on(HandoverMessage.cancel, (m) {
      final id = m['session_id'];
      if (id is String) {
        _events.add(DesktopHandoverEvent.cancelled(sessionId: id));
      }
    });
    on(HandoverMessage.ack, (m) {
      final id = m['session_id'];
      final type = m['type'];
      if (id is String && type is String) {
        unawaited(_outbox.acknowledge(id, type));
      }
    });
    _subscriptions.add(
      _tcp.connectionState
          .where((s) => s == ConnectionState.connected)
          .listen((_) => unawaited(_outbox.flush())),
    );
    _outbox.retryEvery(HandoverProtocol.outboxRetry);
  }

  void _answer(Map<String, dynamic> message, HandoverFailure? failure) {
    final answer = _answers[message['session_id']];
    if (answer != null && !answer.isCompleted) answer.complete(failure);
  }

  /// Sends the files of processing session [sessionId] and completes with
  /// the transfer's end: [HandoverStatus.sent] once the desktop has every
  /// byte, or [HandoverStatus.error] with the reason. Never throws.
  Future<HandoverSession> send(
    String sessionId,
    List<String> filePaths, {
    Map<String, dynamic>? phase1Data,
  }) async {
    _cancelled.remove(sessionId);
    var session = HandoverSession(
      sessionId: sessionId,
      fileCount: filePaths.length,
    );
    void report(HandoverSession next) {
      session = next;
      _transfers.add(next);
    }

    HandoverSession fail(HandoverFailure failure) {
      report(session.copyWith(status: HandoverStatus.error, failure: failure));
      return session;
    }

    report(session);

    final sizes = <int>[];
    try {
      for (final path in filePaths) {
        sizes.add(await File(path).length());
      }
    } on FileSystemException catch (e) {
      logger.w('[HandoverSender] a file to send is missing', e);
      return fail(HandoverFailure.fileNotFound);
    }
    final total = sizes.fold<int>(0, (a, b) => a + b);
    if (filePaths.isEmpty) return fail(HandoverFailure.fileNotFound);
    if (total > HandoverProtocol.maxTotalBytes) {
      return fail(HandoverFailure.tooLarge);
    }

    // Listening before the offer goes out: over MPC the answer can arrive
    // before the send returns.
    final answer = Completer<HandoverFailure?>();
    _answers[sessionId] = answer;
    HandoverFailure? refused;
    try {
      await _tcp.sendData(HandoverMessage.offer, {
        'session_id': sessionId,
        'v': HandoverProtocol.version,
        'files': [
          for (var i = 0; i < filePaths.length; i++)
            {'name': p.basename(filePaths[i]), 'size': sizes[i]},
        ],
        'phase1_data': ?phase1Data,
      });
      refused = await answer.future.timeout(
        acceptTimeout,
        onTimeout: () => HandoverFailure.notAccepted,
      );
    } on Exception catch (e) {
      logger.w('[HandoverSender] offer not sent', e);
      return fail(HandoverFailure.connectionLost);
    } finally {
      _answers.remove(sessionId);
    }
    if (refused != null) return fail(refused);

    // The desktop accepted: from here on it holds partial files, so a
    // transfer that stops tells it to drop them.
    HandoverSession stop(HandoverFailure failure) {
      unawaited(withdraw(sessionId));
      return fail(failure);
    }

    if (_cancelled.contains(sessionId)) return stop(HandoverFailure.cancelled);

    var sent = 0;
    for (var i = 0; i < filePaths.length; i++) {
      RandomAccessFile? file;
      try {
        file = await File(filePaths[i]).open();
        var offset = 0;
        while (offset < sizes[i]) {
          if (_cancelled.contains(sessionId)) {
            return stop(HandoverFailure.cancelled);
          }
          final bytes = await file.read(HandoverProtocol.chunkBytes);
          if (bytes.isEmpty) throw const FileSystemException('File shrank');
          await _tcp.sendData(HandoverMessage.chunk, {
            'session_id': sessionId,
            'index': i,
            'offset': offset,
            'data': base64Encode(bytes),
          });
          offset += bytes.length;
          sent += bytes.length;
          report(
            session.copyWith(
              progress: total == 0 ? 1 : sent / total,
              receivedCount: offset >= sizes[i] ? i + 1 : i,
            ),
          );
        }
      } on FileSystemException catch (e) {
        logger.w('[HandoverSender] a file to send could not be read', e);
        return stop(HandoverFailure.fileNotFound);
      } on Exception catch (e) {
        // Told on the next connection; the desktop also drops partial files
        // once it hears nothing for a while.
        logger.w('[HandoverSender] the link dropped while sending', e);
        return stop(HandoverFailure.connectionLost);
      } finally {
        await file?.close();
      }
    }
    report(
      session.copyWith(
        status: HandoverStatus.sent,
        progress: 1,
        receivedCount: filePaths.length,
      ),
    );
    return session;
  }

  /// Stops a transfer in progress; [send] then ends as cancelled.
  void cancelTransfer(String sessionId) => _cancelled.add(sessionId);

  /// Tells the desktop to drop the document: the phone takes it back.
  Future<void> withdraw(String sessionId) =>
      _outbox.add(HandoverMessage.cancel, {'session_id': sessionId});

  /// Tells the desktop the records were saved on this phone.
  Future<void> reportSaved(String sessionId) =>
      _outbox.add(HandoverMessage.saved, {'session_id': sessionId});

  /// Confirms a message from the desktop was handled, so it isn't sent
  /// again. Lost confirmations only make the desktop repeat the message.
  Future<void> acknowledge(String sessionId, String type) async {
    try {
      await _tcp.sendData(HandoverMessage.ack, {
        'session_id': sessionId,
        'type': type,
      });
    } on Exception catch (e) {
      logger.w('[HandoverSender] $type acknowledgement not sent', e);
    }
  }

  void dispose() {
    _outbox.stopRetrying();
    for (final s in _subscriptions) {
      unawaited(s.cancel());
    }
    _subscriptions.clear();
    unawaited(_transfers.close());
    unawaited(_events.close());
  }
}
