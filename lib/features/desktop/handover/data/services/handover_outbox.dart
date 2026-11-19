import 'dart:async';
import 'dart:convert';

import 'package:health_wallet/core/utils/logger.dart';
import 'package:health_wallet/features/desktop/communication/data/services/tcp_service.dart';
import 'package:health_wallet/features/desktop/handover/domain/entity/handover_protocol.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Handover messages the other device must receive: kept in preferences
/// until it acknowledges them ([HandoverMessage.ack]), and sent again on
/// every connection, so a drop, a restart or a link that was down when the
/// message was made loses nothing.
class HandoverOutbox {
  HandoverOutbox(this._prefs, this._tcp, {required this.key});

  final SharedPreferences _prefs;
  final TcpService _tcp;

  /// The preferences key; the phone and the desktop use their own.
  final String key;

  List<Map<String, dynamic>> get _entries {
    final raw = _prefs.getString(key);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    } on FormatException catch (e) {
      logger.w('[HandoverOutbox] unreadable outbox dropped', e);
      return [];
    }
  }

  Future<void> _save(List<Map<String, dynamic>> entries) => entries.isEmpty
      ? _prefs.remove(key)
      : _prefs.setString(key, jsonEncode(entries));

  /// The messages waiting, oldest first.
  List<({String type, Map<String, dynamic> payload})> get pending => [
    for (final e in _entries)
      (
        type: e['type'] as String,
        payload: (e['payload'] as Map).cast<String, dynamic>(),
      ),
  ];

  /// Keeps [type] for the session in [payload] (replacing an earlier one of
  /// the same type) and sends it now if the link is up.
  Future<void> add(String type, Map<String, dynamic> payload) async {
    final sessionId = payload['session_id'];
    final entries = _entries
      ..removeWhere((e) => e['type'] == type && _sessionOf(e) == sessionId)
      ..add({'type': type, 'payload': payload});
    await _save(entries);
    await _send(type, payload);
  }

  /// Drops [type] for [sessionId] once the other device received it.
  Future<void> acknowledge(String sessionId, String type) => _save(
    _entries
      ..removeWhere((e) => e['type'] == type && _sessionOf(e) == sessionId),
  );

  /// Drops everything waiting for [sessionId].
  Future<void> forget(String sessionId) =>
      _save(_entries..removeWhere((e) => _sessionOf(e) == sessionId));

  Timer? _retry;

  /// Sends what is waiting every [interval] too: a phone that reconnects
  /// while the desktop still holds its old session never brings the link
  /// down, so no "connected" event announces it.
  void retryEvery(Duration interval) {
    _retry?.cancel();
    _retry = Timer.periodic(interval, (_) {
      if (_entries.isNotEmpty) unawaited(flush());
    });
  }

  void stopRetrying() {
    _retry?.cancel();
    _retry = null;
  }

  /// Sends every waiting message; called when the link comes up.
  Future<void> flush() async {
    for (final m in pending) {
      if (!await _send(m.type, m.payload)) return;
    }
  }

  Future<bool> _send(String type, Map<String, dynamic> payload) async {
    if (!_tcp.isConnected) return false;
    try {
      await _tcp.sendData(type, payload);
      return true;
    } on Exception catch (e) {
      // Kept: sent again on the next connection.
      logger.w('[HandoverOutbox] $type not sent yet', e);
      return false;
    }
  }

  static Object? _sessionOf(Map<String, dynamic> entry) =>
      (entry['payload'] as Map?)?['session_id'];
}
