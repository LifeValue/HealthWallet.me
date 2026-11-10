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
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'handover_service.freezed.dart';

/// What the paired phone did with a handover.
@freezed
sealed class IncomingHandoverEvent with _$IncomingHandoverEvent {
  /// Every file of the document arrived, in page order.
  const factory IncomingHandoverEvent.received({
    required String sessionId,
    required List<String> filePaths,
    Map<String, dynamic>? phase1Data,
  }) = IncomingHandoverReceived;

  /// The phone took the document back.
  const factory IncomingHandoverEvent.cancelled({required String sessionId}) =
      IncomingHandoverCancelled;

  /// The records were saved on the phone.
  const factory IncomingHandoverEvent.saved({required String sessionId}) =
      IncomingHandoverSaved;
}

class _File {
  _File(this.path, this.size);
  final String path;
  final int size;
  int received = 0;
}

class _Transfer {
  _Transfer(this.dir, this.files, this.phase1Data);
  final Directory dir;
  final List<_File> files;
  final Map<String, dynamic>? phase1Data;
  Timer? idle;

  int get total => files.fold(0, (a, f) => a + f.size);
  int get received => files.fold(0, (a, f) => a + f.received);
  int get completeFiles => files.where((f) => f.received == f.size).length;
}

/// The desktop's end of a handover: receives a document's files from the
/// phone and sends back what processing made of it. Messages the phone must
/// receive wait in an outbox until it acknowledges them.
@lazySingleton
class HandoverService {
  HandoverService(this._tcp, this._router, this._prefs)
    : _outbox = HandoverOutbox(_prefs, _tcp, key: outboxKey);

  static const outboxKey = 'handover_outbox_desktop';

  /// Sessions whose draft was already sent, so a restart or a second draft
  /// (the desktop's user retrying a step) doesn't send it again.
  static const reportedKey = 'handover_reported_desktop';

  final TcpService _tcp;
  final SharedPreferences _prefs;
  final MessageRouter _router;
  final HandoverOutbox _outbox;

  /// Where files are assembled; overridable in tests.
  @visibleForTesting
  Future<Directory> Function() temporaryDirectory = getTemporaryDirectory;

  /// How long a transfer may wait for its next chunk; shortened in tests.
  @visibleForTesting
  Duration idleTimeout = HandoverProtocol.idleTimeout;

  final _transfers = StreamController<HandoverSession>.broadcast();
  final _events = StreamController<IncomingHandoverEvent>.broadcast();
  final Map<String, _Transfer> _active = {};
  final List<StreamSubscription<Object?>> _subscriptions = [];

  // Messages are handled one at a time, so chunks are written in order.
  Future<void> _queue = Future.value();

  /// Transfers in progress and how they ended.
  Stream<HandoverSession> get transfers => _transfers.stream;

  Stream<IncomingHandoverEvent> get phoneEvents => _events.stream;

  void start() {
    if (_subscriptions.isNotEmpty) return;
    void on(String type, Future<void> Function(Map<String, dynamic>) handle) =>
        _subscriptions.add(
          _router.on(type).listen((m) {
            _queue = _queue.then((_) => handle(m)).catchError((Object e) {
              logger.w('[Handover] $type not handled', e);
            });
          }),
        );

    on(HandoverMessage.offer, _onOffer);
    on(HandoverMessage.chunk, _onChunk);
    on(HandoverMessage.cancel, (m) async {
      final id = m['session_id'];
      if (id is! String) return;
      await _drop(id);
      _events.add(IncomingHandoverEvent.cancelled(sessionId: id));
      await _acknowledge(id, HandoverMessage.cancel);
    });
    on(HandoverMessage.saved, (m) async {
      final id = m['session_id'];
      if (id is! String) return;
      _events.add(IncomingHandoverEvent.saved(sessionId: id));
      await _acknowledge(id, HandoverMessage.saved);
    });
    on(HandoverMessage.ack, (m) async {
      final id = m['session_id'];
      final type = m['type'];
      if (id is String && type is String) {
        await _outbox.acknowledge(id, type);
      }
    });
    _subscriptions.add(
      _tcp.connectionState
          .where((s) => s == ConnectionState.connected)
          .listen((_) => unawaited(_outbox.flush())),
    );
    _outbox.retryEvery(HandoverProtocol.outboxRetry);
  }

  Future<void> _onOffer(Map<String, dynamic> m) async {
    final id = m['session_id'];
    if (id is! String || id.isEmpty) return;
    if (m['v'] != HandoverProtocol.version) {
      return _reject(id, HandoverFailure.desktopOutdated);
    }
    final files = <({String name, int size})>[];
    for (final f in m['files'] as List? ?? const []) {
      if (f is! Map || f['name'] is! String || f['size'] is! int) {
        return _reject(id, HandoverFailure.failed);
      }
      final size = f['size'] as int;
      if (size < 0) return _reject(id, HandoverFailure.failed);
      files.add((name: f['name'] as String, size: size));
    }
    if (files.isEmpty) return _reject(id, HandoverFailure.failed);
    final total = files.fold<int>(0, (a, f) => a + f.size);
    if (total > HandoverProtocol.maxTotalBytes) {
      return _reject(id, HandoverFailure.tooLarge);
    }

    // The phone sends the document again (after a failure or a drop): the
    // earlier attempt is replaced.
    await _drop(id);
    final dir = Directory(
      p.join((await temporaryDirectory()).path, 'handover', _safe(id)),
    );
    if (await dir.exists()) await dir.delete(recursive: true);
    await dir.create(recursive: true);
    final transfer = _Transfer(
      dir,
      [
        for (var i = 0; i < files.length; i++)
          // The index keeps pages in order and same-named pages apart.
          _File(
            p.join(dir.path, '${i}_${_safe(files[i].name)}'),
            files[i].size,
          ),
      ],
      (m['phase1_data'] as Map?)?.cast<String, dynamic>(),
    );
    for (final f in transfer.files) {
      await File(f.path).writeAsBytes(const [], flush: true);
    }
    _active[id] = transfer;
    _touch(id);
    await _sendQuietly(HandoverMessage.accept, {'session_id': id});
    _report(id, transfer);
    if (transfer.total == 0) await _complete(id);
  }

  Future<void> _onChunk(Map<String, dynamic> m) async {
    final id = m['session_id'];
    final transfer = _active[id];
    // A chunk of a transfer already dropped or finished.
    if (id is! String || transfer == null) return;
    final index = m['index'];
    final offset = m['offset'];
    final data = m['data'];
    if (index is! int ||
        index < 0 ||
        index >= transfer.files.length ||
        offset is! int ||
        data is! String) {
      return _fail(id, HandoverFailure.failed);
    }
    final file = transfer.files[index];
    final List<int> bytes;
    try {
      bytes = base64Decode(data);
    } on FormatException catch (e) {
      logger.w('[Handover] undecodable chunk for $id', e);
      return _fail(id, HandoverFailure.failed);
    }
    // Chunks come in order; a gap or a repeat means the file is corrupt.
    if (offset != file.received || file.received + bytes.length > file.size) {
      return _fail(id, HandoverFailure.failed);
    }
    await File(file.path).writeAsBytes(bytes, mode: FileMode.append);
    file.received += bytes.length;
    _touch(id);
    _report(id, transfer);
    if (transfer.received == transfer.total) await _complete(id);
  }

  Future<void> _complete(String id) async {
    final transfer = _active.remove(id);
    if (transfer == null) return;
    transfer.idle?.cancel();
    _transfers.add(
      HandoverSession(
        sessionId: id,
        status: HandoverStatus.sent,
        fileCount: transfer.files.length,
        receivedCount: transfer.files.length,
        progress: 1,
      ),
    );
    _events.add(
      IncomingHandoverEvent.received(
        sessionId: id,
        filePaths: [for (final f in transfer.files) f.path],
        phase1Data: transfer.phase1Data,
      ),
    );
  }

  void _report(String id, _Transfer transfer) => _transfers.add(
    HandoverSession(
      sessionId: id,
      status: HandoverStatus.receiving,
      fileCount: transfer.files.length,
      receivedCount: transfer.completeFiles,
      progress: transfer.total == 0 ? 1 : transfer.received / transfer.total,
    ),
  );

  void _touch(String id) {
    final transfer = _active[id];
    if (transfer == null) return;
    transfer.idle?.cancel();
    transfer.idle = Timer(idleTimeout, () {
      _queue = _queue.then((_) => _fail(id, HandoverFailure.timeout));
    });
  }

  /// Ends a transfer that can't finish and tells the phone why.
  Future<void> _fail(String id, HandoverFailure failure) async {
    final transfer = _active[id];
    if (transfer == null) return;
    await _drop(id);
    _transfers.add(
      HandoverSession(
        sessionId: id,
        status: HandoverStatus.error,
        fileCount: transfer.files.length,
        failure: failure,
      ),
    );
    await sendFailed(id, failure);
  }

  /// Forgets a transfer in progress and deletes what arrived of it.
  Future<void> _drop(String id) async {
    final transfer = _active.remove(id);
    if (transfer == null) return;
    transfer.idle?.cancel();
    await _deleteDir(transfer.dir);
  }

  Future<void> _reject(String id, HandoverFailure failure) =>
      _sendQuietly(HandoverMessage.reject, {
        'session_id': id,
        'reason': failure.wire,
      });

  /// Processing progress, 0 to 1; dropped when the phone isn't connected.
  Future<void> sendProgress(String id, double progress) => _sendQuietly(
    HandoverMessage.progress,
    {'session_id': id, 'progress': progress},
  );

  /// The draft for the phone to review, once per session.
  Future<void> sendResult(String id, HandoverDraft draft) async {
    final reported = _prefs.getStringList(reportedKey) ?? const [];
    if (reported.contains(id)) return;
    await _prefs.setStringList(reportedKey, [...reported, id]);
    await _outbox.add(HandoverMessage.result, {
      'session_id': id,
      'draft': draft.toJson(),
    });
  }

  /// The session is gone from the desktop: a later handover with its id
  /// gets its draft sent again.
  Future<void> forget(String id) async {
    final reported = _prefs.getStringList(reportedKey) ?? const [];
    if (!reported.contains(id)) return;
    await _prefs.setStringList(reportedKey, [
      for (final r in reported)
        if (r != id) r,
    ]);
  }

  Future<void> sendFailed(String id, HandoverFailure failure) =>
      _outbox.add(HandoverMessage.failed, {
        'session_id': id,
        'reason': (failure.wire ?? HandoverFailure.failed.wire)!,
      });

  /// The records were saved on the desktop.
  Future<void> sendSaved(String id) =>
      _outbox.add(HandoverMessage.saved, {'session_id': id});

  /// The desktop's user deleted the document.
  Future<void> sendCancelled(String id) =>
      _outbox.add(HandoverMessage.cancel, {'session_id': id});

  /// Deletes the received files once processing has its own copies.
  Future<void> discardFiles(String id) async => _deleteDir(
    Directory(p.join((await temporaryDirectory()).path, 'handover', _safe(id))),
  );

  Future<void> _acknowledge(String id, String type) =>
      _sendQuietly(HandoverMessage.ack, {'session_id': id, 'type': type});

  /// Sends a message nobody waits for; a dropped link is logged, not thrown.
  Future<void> _sendQuietly(String type, Map<String, dynamic> payload) async {
    try {
      await _tcp.sendData(type, payload);
    } on Exception catch (e) {
      logger.w('[Handover] $type not sent', e);
    }
  }

  Future<void> _deleteDir(Directory dir) async {
    try {
      if (await dir.exists()) await dir.delete(recursive: true);
    } on FileSystemException catch (e) {
      logger.w('[Handover] received files not deleted', e);
    }
  }

  /// A name the phone chose, reduced to one safe path segment.
  static String _safe(String name) {
    final base = p.basename(name).replaceAll(RegExp(r'[^\w.\-]'), '_');
    return base.isEmpty || base == '.' || base == '..' ? 'file' : base;
  }

  Future<void> stop() async {
    _outbox.stopRetrying();
    for (final s in _subscriptions) {
      await s.cancel();
    }
    _subscriptions.clear();
    for (final id in _active.keys.toList()) {
      await _drop(id);
    }
  }

  Future<void> dispose() async {
    await stop();
    await _transfers.close();
    await _events.close();
  }
}
