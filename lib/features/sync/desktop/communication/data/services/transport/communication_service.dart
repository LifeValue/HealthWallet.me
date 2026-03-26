import 'dart:async';
import 'dart:typed_data';

enum TransportType { tcp, multipeerConnectivity }

enum CommunicationState { disconnected, connecting, connected }

abstract class CommunicationService {
  TransportType get transportType;
  CommunicationState get currentState;
  Stream<CommunicationState> get stateStream;
  Stream<Uint8List> get dataStream;

  Future<void> startServer({required int port});
  Future<void> connect({required String address, required int port});
  Future<void> send(Uint8List data);
  Future<void> disconnect();
  Future<void> dispose();
}
