import 'dart:async';

import 'package:drift/drift.dart';
import 'package:health_wallet/core/data/local/app_database.dart';
import 'package:health_wallet/core/utils/logger.dart';
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

    // Table update notifications, not queries: a write costs nothing until
    // the debounce runs.
    _subscriptions.add(
      _db
          .tableUpdates(
            TableUpdateQuery.onAllTables([
              _db.fhirResource,
              _db.sources,
              _db.recordNotes,
            ]),
          )
          .listen((_) => _onTableChanged()),
    );

    // Whatever changed while nothing was watching.
    _onTableChanged();
  }

  void stopWatching() {
    _debounceTimer?.cancel();
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
    _isWatching = false;
  }

  void _onTableChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(
      const Duration(milliseconds: _debounceMs),
      _sendPendingDeltas,
    );
  }

  Future<void> _sendPendingDeltas() async {
    final lastSync = await _syncService.getLastSyncTimestamp();
    final connected = _tcpService.isConnected;
    // A device that never synced has nothing to keep for later: its first
    // connection sends every row.
    if (!connected && lastSync == null) return;
    final since = lastSync ?? DateTime.fromMillisecondsSinceEpoch(0);

    final deltas = await _syncService.computeAllDeltas(
      since,
      embedAttachments: connected,
    );
    if (deltas.isEmpty) return;

    var sentCount = 0;
    for (final delta in deltas) {
      if (connected) {
        try {
          await _tcpService.sendData('sync.delta', delta.toJson());
          sentCount++;
          continue;
        } catch (e) {
          logger.w('[LwwSync] sending ${delta.tableName} failed; queued', e);
        }
      }
      // Queued without file bytes, which would otherwise sit in preferences.
      await _offlineQueue.replace(
        connected
            ? await _syncService.computeDelta(
                delta.tableName,
                since,
                embedAttachments: false,
              )
            : delta,
      );
    }

    if (sentCount > 0) {
      await _syncService.setLastSyncTimestamp(DateTime.now());
    }
  }

  void dispose() {
    stopWatching();
  }
}
