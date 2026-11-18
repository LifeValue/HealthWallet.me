import 'dart:async';
import 'dart:typed_data';

enum TransportType { tcp, multipeerConnectivity }

enum CommunicationState { disconnected, connecting, connected }

abstract class CommunicationService {
  TransportType get transportType;
  CommunicationState get currentState;
  Stream<CommunicationState> get stateStream;
  Stream<Uint8List> get dataStream;

  /// [token] limits who connects: only peers that know it (derived from the
  /// pairing key) are accepted or invited.
  Future<void> startServer({required int port, String? token});
  Future<void> connect({
    required String address,
    required int port,
    String? token,
  });
  Future<void> send(Uint8List data);
  Future<void> disconnect();
  Future<void> dispose();
}
