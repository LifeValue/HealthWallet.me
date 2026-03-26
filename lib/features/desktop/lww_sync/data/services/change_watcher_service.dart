import 'dart:async';

import 'package:health_wallet/core/data/local/app_database.dart';
import 'package:health_wallet/features/desktop/communication/data/services/tcp_service.dart';
import 'package:health_wallet/features/desktop/lww_sync/data/services/lww_sync_service.dart';
import 'package:health_wallet/features/desktop/lww_sync/data/services/offline_queue_service.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class ChangeWatcherService {
  static const _debounceMs = 500;

  final AppDatabase _db;
  final LwwSyncService _syncService;
  final TcpService _tcpService;
  final OfflineQueueService _offlineQueue;

  final List<StreamSubscription> _subscriptions = [];
  Timer? _debounceTimer;
  bool _isWatching = false;

  ChangeWatcherService(
    this._db,
    this._syncService,
    this._tcpService,
    this._offlineQueue,
  );

  void startWatching() {
    if (_isWatching) return;
    _isWatching = true;

    _subscriptions.add(
      _db.select(_db.fhirResource).watch().listen((_) {
        _onTableChanged('fhir_resource');
      }),
    );

    _subscriptions.add(
      _db.select(_db.sources).watch().listen((_) {
        _onTableChanged('sources');
      }),
    );

    _subscriptions.add(
      _db.select(_db.recordNotes).watch().listen((_) {
        _onTableChanged('record_notes');
      }),
    );

    _subscriptions.add(
      _db.select(_db.processingSessions).watch().listen((_) {
        _onTableChanged('processing_sessions');
      }),
    );
  }

  void stopWatching() {
    _debounceTimer?.cancel();
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
    _isWatching = false;
  }

  void _onTableChanged(String tableName) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(
      const Duration(milliseconds: _debounceMs),
      _sendPendingDeltas,
    );
  }

  Future<void> _sendPendingDeltas() async {
    final lastSync = await _syncService.getLastSyncTimestamp();
    final since = lastSync ?? DateTime.fromMillisecondsSinceEpoch(0);

    final deltas = await _syncService.computeAllDeltas(since);
    if (deltas.isEmpty) return;

    var sentCount = 0;
    for (final delta in deltas) {
      final payload = delta.toJson();

      if (_tcpService.isConnected) {
        try {
          await _tcpService.sendData('sync.delta', payload);
          sentCount++;
        } catch (_) {
          await _offlineQueue.enqueue(delta);
        }
      } else {
        await _offlineQueue.enqueue(delta);
      }
    }

    if (sentCount > 0) {
      await _syncService.setLastSyncTimestamp(DateTime.now());
    }
  }

  void dispose() {
    stopWatching();
  }
}
