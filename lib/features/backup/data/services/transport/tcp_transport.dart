import 'dart:async';
import 'dart:typed_data';

import 'package:health_wallet/features/backup/data/services/tcp_service.dart'
    as tcp;
import 'package:health_wallet/features/backup/data/services/transport/communication_service.dart';

class TcpTransport implements CommunicationService {
  final tcp.TcpService _tcpService;

  TcpTransport(this._tcpService);

  @override
  TransportType get transportType => TransportType.tcp;

  @override
  CommunicationState get currentState {
    return switch (_tcpService.currentState) {
      tcp.ConnectionState.connected => CommunicationState.connected,
      tcp.ConnectionState.connecting => CommunicationState.connecting,
      tcp.ConnectionState.disconnected => CommunicationState.disconnected,
    };
  }

  @override
  Stream<CommunicationState> get stateStream {
    return _tcpService.connectionState.map((state) {
      return switch (state) {
        tcp.ConnectionState.connected => CommunicationState.connected,
        tcp.ConnectionState.connecting => CommunicationState.connecting,
        tcp.ConnectionState.disconnected => CommunicationState.disconnected,
      };
    });
  }

  @override
  Stream<Uint8List> get dataStream {
    return _tcpService.messages.map((msg) {
      final result = Uint8List(1 + msg.payload.length);
      result[0] = msg.type.code;
      result.setAll(1, msg.payload);
      return result;
    });
  }

  @override
  Future<void> startServer({required int port}) async {
    throw UnimplementedError('Use TcpService.startServer directly');
  }

  @override
  Future<void> connect({required String address, required int port}) async {
    throw UnimplementedError('Use TcpService.connectToServer directly');
  }

  @override
  Future<void> send(Uint8List data) async {
    throw UnimplementedError('Use TcpService.sendMessage directly');
  }

  @override
  Future<void> disconnect() async {
    await _tcpService.disconnect();
  }

  @override
  Future<void> dispose() async {
    await _tcpService.stopServer();
  }
}
