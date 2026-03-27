import 'dart:async';
import 'dart:convert';

import 'package:injectable/injectable.dart';

import 'tcp_service.dart';

@lazySingleton
class MessageRouter {
  final TcpService _tcpService;
  final Map<String, StreamController<Map<String, dynamic>>> _controllers = {};
  StreamSubscription<TcpMessage>? _subscription;

  MessageRouter(this._tcpService) {
    _subscription = _tcpService.messages
        .where((msg) => msg.type == MessageType.data)
        .listen(_routeMessage);
  }

  void _routeMessage(TcpMessage message) {
    try {
      final json = jsonDecode(message.payloadString) as Map<String, dynamic>;
      final type = json['type'] as String?;
      final payload = json['payload'] as Map<String, dynamic>? ?? {};

      if (type == null) return;

      final controller = _controllers[type];
      if (controller != null && !controller.isClosed) {
        controller.add(payload);
      }
    } catch (_) {}
  }

  Stream<Map<String, dynamic>> on(String type) {
    _controllers[type] ??= StreamController<Map<String, dynamic>>.broadcast();
    return _controllers[type]!.stream;
  }

  void dispose() {
    _subscription?.cancel();
    for (final controller in _controllers.values) {
      controller.close();
    }
    _controllers.clear();
  }
}
