import 'dart:convert';

import 'package:health_wallet/features/desktop/communication/data/services/tcp_service.dart';
import 'package:health_wallet/features/desktop/lww_sync/domain/entity/sync_delta.dart';
import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

@lazySingleton
class OfflineQueueService {
  static const _queueKey = 'lww_offline_queue';

  final SharedPreferences _prefs;
  final TcpService _tcpService;

  OfflineQueueService(this._prefs, this._tcpService);

  Future<void> enqueue(SyncDelta delta) async {
    final queue = _loadQueue();
    queue.add(delta);
    await _saveQueue(queue);
  }

  Future<int> flush() async {
    final queue = _loadQueue();
    if (queue.isEmpty) return 0;

    final sent = <int>[];
    for (var i = 0; i < queue.length; i++) {
      final delta = queue[i];
      try {
        await _tcpService.sendData('sync.delta', delta.toJson());
        sent.add(i);
      } catch (_) {
        break;
      }
    }

    if (sent.isNotEmpty) {
      final remaining = <SyncDelta>[];
      for (var i = 0; i < queue.length; i++) {
        if (!sent.contains(i)) {
          remaining.add(queue[i]);
        }
      }
      await _saveQueue(remaining);
    }

    return sent.length;
  }

  Future<void> acknowledge(String tableName, DateTime timestamp) async {
    final queue = _loadQueue();

    final remaining = queue.where((delta) {
      if (delta.tableName != tableName) return true;
      return delta.timestamp.isAfter(timestamp);
    }).toList();

    await _saveQueue(remaining);
  }

  int get pendingCount => _loadQueue().length;

  Future<void> clear() async {
    await _prefs.remove(_queueKey);
  }

  List<SyncDelta> _loadQueue() {
    final raw = _prefs.getString(_queueKey);
    if (raw == null) return [];

    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => SyncDelta.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      _prefs.remove(_queueKey);
      return [];
    }
  }

  Future<void> _saveQueue(List<SyncDelta> queue) async {
    final raw = jsonEncode(queue.map((d) => d.toJson()).toList());
    await _prefs.setString(_queueKey, raw);
  }
}
