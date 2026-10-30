import 'dart:async';
import 'dart:convert';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:health_wallet/core/utils/logger.dart';
import 'package:health_wallet/features/desktop/communication/data/services/message_router.dart';
import 'package:health_wallet/features/desktop/communication/data/services/tcp_service.dart';
import 'package:health_wallet/features/desktop/lww_sync/data/services/change_watcher_service.dart';
import 'package:health_wallet/features/desktop/lww_sync/data/services/lww_sync_service.dart';
import 'package:health_wallet/features/desktop/lww_sync/domain/entity/sync_batch.dart';
import 'package:injectable/injectable.dart';

part 'lww_sync_event.dart';
part 'lww_sync_state.dart';
part 'lww_sync_bloc.freezed.dart';

/// Keeps `fhir_resource`, `sources` and `record_notes` the same on the phone
/// and the desktop.
///
/// Local writes are logged in the outbox; they are sent in batches, one at a
/// time, and the outbox position moves only when the peer acknowledged a
/// batch it applied, so nothing is lost to a dropped link or a failed write.
/// On connecting, both sides compare a digest of their tables and, where
/// they differ, exchange key/`updated_at` manifests and send each other the
/// rows the other lacks or holds older. Files follow on request, in chunks.
///
/// Every event runs in one queue, so a sync can't start in the middle of
/// another or be skipped because one is running.
@lazySingleton
class LwwSyncBloc extends Bloc<LwwSyncEvent, LwwSyncState> {
  final LwwSyncService _syncService;
  final ChangeWatcherService _changeWatcher;
  final TcpService _tcpService;
  final MessageRouter _router;

  static const syncMessages = [
    'sync.batch',
    'sync.ack',
    'sync.digest',
    'sync.manifest',
    'sync.file_request',
    'sync.file_chunk',
    'sync.file_missing',
  ];

  @visibleForTesting
  static Duration ackTimeout = const Duration(seconds: 60);

  @visibleForTesting
  static Duration settleDelay = const Duration(seconds: 1);

  final _subscriptions = <StreamSubscription>[];
  SyncPeerState? _peer;
  int? _inFlight;
  Timer? _ackTimer;
  Timer? _settleTimer;
  bool _sentSinceVerify = false;
  final _manifestsSent = <String>{};
  final _awaitingFiles = <String>{};
  Future<void> _fileQueue = Future.value();
  final _drainWaiters = <Completer<void>>[];
  Completer<void>? _applying;

  LwwSyncBloc(
    this._syncService,
    this._changeWatcher,
    this._tcpService,
    this._router,
  ) : super(LwwSyncState.initial()) {
    on<LwwSyncEvent>(_onEvent, transformer: sequential());
  }

  Future<void> _onEvent(LwwSyncEvent event, Emitter<LwwSyncState> emit) async {
    try {
      switch (event) {
        case LwwSyncInitialised():
          await _onInitialised(emit);
        case SyncTriggered():
          await _onTriggered(emit);
        case LwwLocalChanged():
          await _refreshPending(emit);
          await _push(emit);
        case ConnectionChanged(:final isConnected):
          await _onConnectionChanged(isConnected, emit);
        case LwwMessageReceived(:final type, :final payload):
          await _onMessage(type, payload, emit);
        case LwwRecordsSettled():
          emit(state.copyWith(recordsVersion: state.recordsVersion + 1));
        case LwwAckTimedOut(:final batchId):
          if (_inFlight == batchId) {
            _inFlight = null;
            emit(
              state.copyWith(
                sending: false,
                syncStatus: LwwSyncStatus.error,
                error: 'no answer from the other device',
              ),
            );
          }
      }
    } catch (e, stack) {
      logger.e('[LwwSync] ${event.runtimeType} failed', e, stack);
      _inFlight = null;
      _ackTimer?.cancel();
      _completeApplying();
      emit(
        state.copyWith(
          syncStatus: LwwSyncStatus.error,
          error: e.toString(),
          sending: false,
          receiving: false,
        ),
      );
    }
    _notifyDrained();
  }

  Future<void> _onInitialised(Emitter<LwwSyncState> emit) async {
    if (_subscriptions.isNotEmpty) return;
    await _syncService.discardAllPartials();
    await _syncService.backfillExistingRows();
    await _syncService.fixBrokenAttachmentUrls();
    await _syncService.cleanupTombstones();

    _peer = _syncService.loadPeerState();
    emit(
      state.copyWith(
        lastSyncTime: _peer?.lastSyncAt,
        lastSyncPeerName: _peer?.peerName,
      ),
    );
    await _refreshPending(emit);

    _subscriptions.add(
      _tcpService.connectionState.listen(
        (s) => add(
          ConnectionChanged(isConnected: s == ConnectionState.connected),
        ),
      ),
    );
    for (final type in syncMessages) {
      _subscriptions.add(
        _router
            .on(type)
            .listen(
              (payload) =>
                  add(LwwMessageReceived(type: type, payload: payload)),
            ),
      );
    }
    _changeWatcher.startWatching(() {
      if (!isClosed) add(const LwwLocalChanged());
    });
    if (_tcpService.isConnected) {
      await _onConnectionChanged(true, emit);
    }
  }

  Future<void> _onTriggered(Emitter<LwwSyncState> emit) async {
    await _refreshPending(emit);
    if (!state.connected) return;
    _sentSinceVerify = true;
    await _push(emit);
  }

  Future<void> _onConnectionChanged(
    bool connected,
    Emitter<LwwSyncState> emit,
  ) async {
    _manifestsSent.clear();
    _inFlight = null;
    _ackTimer?.cancel();
    for (final path in _awaitingFiles) {
      await _syncService.discardPartial(path);
    }
    _awaitingFiles.clear();

    final peer = _tcpService.peer;
    if (!connected || peer == null) {
      emit(
        state.copyWith(
          connected: false,
          sending: false,
          receiving: false,
          tablesMatch: false,
          syncStatus: state.syncStatus == LwwSyncStatus.error
              ? LwwSyncStatus.error
              : LwwSyncStatus.idle,
        ),
      );
      return;
    }

    _peer = await _syncService.peerStateFor(
      peer.deviceId,
      peerName: peer.name.isEmpty ? null : peer.name,
    );
    emit(
      state.copyWith(
        connected: true,
        tablesMatch: false,
        sentRows: 0,
        receivedRows: 0,
        error: null,
        syncStatus: LwwSyncStatus.idle,
        lastSyncTime: _peer?.lastSyncAt,
        lastSyncPeerName: _peer?.peerName,
      ),
    );
    await _refreshPending(emit);
    await _sendDigest(reply: false);
    await _requestFiles(await _syncService.missingAttachmentPaths());
    await _push(emit);
  }

  // ---------------------------------------------------------------------------
  // Sending

  Future<void> _push(Emitter<LwwSyncState> emit) async {
    final peer = _peer;
    while (state.connected && _inFlight == null && peer != null) {
      final batch = await _syncService.nextBatch(_peer!.ackedSeq);
      if (batch == null) {
        if (state.sending) emit(state.copyWith(sending: false));
        if (_sentSinceVerify) {
          _sentSinceVerify = false;
          await _sendDigest(reply: false);
        }
        _syncStatusFromWork(emit);
        return;
      }
      if (batch.tables.isEmpty) {
        // Only rows deleted since: nothing to send.
        await _acknowledged(batch.id, emit);
        continue;
      }
      final rows = batch.tables.values.fold(0, (n, r) => n + r.length);
      try {
        await _tcpService.sendData('sync.batch', batch.toJson());
      } on LinkNotConnectedException {
        emit(state.copyWith(connected: false, sending: false));
        return;
      }
      _inFlight = batch.id;
      _sentSinceVerify = true;
      _ackTimer?.cancel();
      _ackTimer = Timer(ackTimeout, () {
        if (!isClosed) add(LwwAckTimedOut(batchId: batch.id));
      });
      emit(
        state.copyWith(
          sending: true,
          syncStatus: LwwSyncStatus.syncing,
          sentRows: state.sentRows + rows,
        ),
      );
    }
  }

  Future<void> _acknowledged(int batchId, Emitter<LwwSyncState> emit) async {
    final peer = _peer;
    if (peer == null) return;
    final updated = peer.copyWith(
      ackedSeq: batchId,
      lastSyncAt: DateTime.now(),
    );
    _peer = updated;
    await _syncService.savePeerState(updated);
    await _syncService.pruneOutbox(batchId);
    emit(state.copyWith(lastSyncTime: updated.lastSyncAt));
    await _refreshPending(emit);
  }

  Future<void> _sendDigest({required bool reply}) async {
    final digest = await _syncService.computeDigest();
    await _send('sync.digest', {
      'reply': reply,
      'tables': {
        for (final MapEntry(:key, :value) in digest.entries)
          key: value.toJson(),
      },
    });
  }

  /// Sends a message that may be lost without harm (it is repeated on the
  /// next connection), logging instead of failing the event.
  Future<void> _send(String type, Map<String, dynamic> payload) async {
    try {
      await _tcpService.sendData(type, payload);
    } on LinkNotConnectedException {
      logger.w('[LwwSync] $type not sent: not connected');
    }
  }

  // ---------------------------------------------------------------------------
  // Receiving

  Future<void> _onMessage(
    String type,
    Map<String, dynamic> payload,
    Emitter<LwwSyncState> emit,
  ) async {
    switch (type) {
      case 'sync.batch':
        await _onBatch(payload, emit);
      case 'sync.ack':
        final id = payload['id'];
        if (id is! int || id != _inFlight) return;
        _ackTimer?.cancel();
        _inFlight = null;
        if (payload['ok'] == false) {
          logger.w('[LwwSync] the peer could not apply batch $id');
          emit(
            state.copyWith(
              syncStatus: LwwSyncStatus.error,
              error: 'the other device could not save some changes',
            ),
          );
        }
        await _acknowledged(id, emit);
        await _push(emit);
      case 'sync.digest':
        await _onDigest(payload, emit);
      case 'sync.manifest':
        final table = payload['table'];
        final rows = payload['rows'];
        if (table is! String || rows is! Map) return;
        await _syncService.queueRowsNewerThan(table, {
          for (final MapEntry(:key, :value) in rows.entries)
            if (key is String && value is num) key: value.toInt(),
        });
        await _refreshPending(emit);
        await _push(emit);
      case 'sync.file_request':
        final paths = payload['paths'];
        if (paths is! List) return;
        final list = paths.whereType<String>().toList();
        _fileQueue = _fileQueue.then((_) => _serveFiles(list));
      case 'sync.file_chunk':
        await _onFileChunk(payload, emit);
      case 'sync.file_missing':
        final path = payload['path'];
        if (path is String && _awaitingFiles.remove(path)) {
          logger.w('[LwwSync] the other device has no file for an attachment');
          await _syncService.discardPartial(path);
          _syncStatusFromWork(emit);
        }
    }
  }

  Future<void> _onBatch(
    Map<String, dynamic> payload,
    Emitter<LwwSyncState> emit,
  ) async {
    final SyncBatch batch;
    try {
      batch = SyncBatch.fromJson(payload);
    } catch (e) {
      logger.e('[LwwSync] unreadable batch', e);
      final id = payload['id'];
      if (id is int) await _send('sync.ack', {'id': id, 'ok': false});
      return;
    }
    _applying = Completer<void>();
    emit(state.copyWith(receiving: true, syncStatus: LwwSyncStatus.syncing));
    final AppliedBatch applied;
    try {
      applied = await _syncService.applyBatch(batch);
    } finally {
      _completeApplying();
    }
    await _send('sync.ack', {'id': batch.id, 'ok': true});

    final peer = _peer;
    if (peer != null && applied.count > 0) {
      final updated = peer.copyWith(lastSyncAt: DateTime.now());
      _peer = updated;
      await _syncService.savePeerState(updated);
    }
    emit(
      state.copyWith(
        receiving: false,
        tablesMatch: false,
        receivedRows: state.receivedRows + applied.count,
        lastSyncTime: _peer?.lastSyncAt ?? state.lastSyncTime,
      ),
    );
    if (applied.count > 0) {
      _settleTimer?.cancel();
      _settleTimer = Timer(settleDelay, () {
        if (!isClosed) add(const LwwRecordsSettled());
      });
    }
    final documents = applied.rows['fhir_resource'];
    if (documents != null && documents.isNotEmpty) {
      await _requestFiles(await _syncService.missingAttachmentPaths(documents));
    }
    _syncStatusFromWork(emit);
  }

  Future<void> _onDigest(
    Map<String, dynamic> payload,
    Emitter<LwwSyncState> emit,
  ) async {
    final tables = payload['tables'];
    if (tables is! Map) return;
    final local = await _syncService.computeDigest();
    final differing = <String>[];
    for (final table in LwwSyncService.syncedTables) {
      final theirs = tables[table];
      final mine = local[table]!;
      final match =
          theirs is Map &&
          theirs['count'] == mine.count &&
          theirs['hash'] == mine.hash;
      if (!match) differing.add(table);
    }
    emit(state.copyWith(tablesMatch: differing.isEmpty));

    for (final table in differing) {
      // Once per connection: a row that keeps failing on one side would
      // otherwise go back and forth for ever.
      if (!_manifestsSent.add(table)) continue;
      await _send('sync.manifest', {
        'table': table,
        'rows': await _syncService.manifest(table),
      });
    }
    if (payload['reply'] != true) await _sendDigest(reply: true);
    _syncStatusFromWork(emit);
  }

  // ---------------------------------------------------------------------------
  // Files

  Future<void> _requestFiles(List<String> paths) async {
    final wanted = paths.where(_awaitingFiles.add).toList();
    if (wanted.isEmpty) return;
    await _send('sync.file_request', {'paths': wanted});
  }

  /// Streams the requested files, one chunk at a time, outside the event
  /// queue so a large file doesn't hold back the sync.
  Future<void> _serveFiles(List<String> paths) async {
    for (final path in paths) {
      try {
        final file = await _syncService.fileForRequest(path);
        if (file == null) {
          await _tcpService.sendData('sync.file_missing', {'path': path});
          continue;
        }
        await for (final chunk in _syncService.readChunks(path, file)) {
          await _tcpService.sendData('sync.file_chunk', {
            'path': chunk.path,
            'offset': chunk.offset,
            'total': chunk.total,
            'data': base64Encode(chunk.bytes),
          });
        }
      } on LinkNotConnectedException {
        // The peer asks again when it reconnects.
        return;
      } catch (e) {
        logger.w('[LwwSync] sending an attachment failed', e);
      }
    }
  }

  Future<void> _onFileChunk(
    Map<String, dynamic> payload,
    Emitter<LwwSyncState> emit,
  ) async {
    final path = payload['path'];
    final offset = payload['offset'];
    final total = payload['total'];
    final data = payload['data'];
    if (path is! String ||
        offset is! int ||
        total is! int ||
        data is! String ||
        !_awaitingFiles.contains(path)) {
      return;
    }
    try {
      final saved = await _syncService.saveChunk(
        FileChunk(
          path: path,
          offset: offset,
          total: total,
          bytes: base64Decode(data),
        ),
      );
      if (saved != null) _awaitingFiles.remove(path);
    } catch (e) {
      logger.w('[LwwSync] a received attachment was dropped', e);
      _awaitingFiles.remove(path);
      await _syncService.discardPartial(path);
    }
    _syncStatusFromWork(emit);
  }

  // ---------------------------------------------------------------------------
  // Status

  Future<void> _refreshPending(Emitter<LwwSyncState> emit) async {
    final peer = _peer;
    final pending = peer == null
        ? 0
        : await _syncService.pendingCount(peer.ackedSeq);
    if (pending != state.pendingChangeCount) {
      emit(state.copyWith(pendingChangeCount: pending));
    }
  }

  void _syncStatusFromWork(Emitter<LwwSyncState> emit) {
    final busy =
        _inFlight != null || state.receiving || _awaitingFiles.isNotEmpty;
    if (busy) {
      if (state.syncStatus != LwwSyncStatus.syncing) {
        emit(state.copyWith(syncStatus: LwwSyncStatus.syncing));
      }
    } else if (state.syncStatus == LwwSyncStatus.syncing) {
      emit(state.copyWith(syncStatus: LwwSyncStatus.idle, error: null));
    }
  }

  void _completeApplying() {
    final applying = _applying;
    _applying = null;
    if (applying != null && !applying.isCompleted) applying.complete();
  }

  void _notifyDrained() {
    if (_drainWaiters.isEmpty) return;
    if (state.connected && _inFlight == null && state.pendingChangeCount == 0) {
      for (final waiter in _drainWaiters) {
        if (!waiter.isCompleted) waiter.complete();
      }
      _drainWaiters.clear();
    }
  }

  /// Completes once every local change reached the peer, or after
  /// [timeout]. Returns whether it did.
  Future<bool> waitUntilDrained({
    Duration timeout = const Duration(seconds: 30),
  }) async {
    add(const SyncTriggered());
    final waiter = Completer<void>();
    _drainWaiters.add(waiter);
    try {
      await waiter.future.timeout(timeout);
      return true;
    } on TimeoutException {
      _drainWaiters.remove(waiter);
      return false;
    }
  }

  /// Lets a batch being applied finish, e.g. before the app quits.
  Future<void> shutdown() async {
    await _applying?.future.timeout(
      const Duration(seconds: 4),
      onTimeout: () {},
    );
  }

  @override
  Future<void> close() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _ackTimer?.cancel();
    _settleTimer?.cancel();
    _changeWatcher.stopWatching();
    return super.close();
  }
}
