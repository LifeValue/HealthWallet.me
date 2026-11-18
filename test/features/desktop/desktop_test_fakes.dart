// Shared fakes and wire helpers for the desktop communication, backup and
// handover tests. Not a test file itself.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/features/desktop/communication/data/services/tcp_service.dart';

/// Lets queued microtasks and already-due timers run.
Future<void> flushEvents([int rounds = 10]) async {
  for (var i = 0; i < rounds; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

/// Deterministic pseudo-random bytes, so failures are reproducible.
Uint8List randomBytes(int length, {int seed = 42}) {
  final random = Random(seed);
  return Uint8List.fromList(List.generate(length, (_) => random.nextInt(256)));
}

/// A 32-byte pairing key encoded the way [DevicePairing.generate] does it.
String testPairingKey({int seed = 7}) =>
    base64Url.encode(randomBytes(32, seed: seed));

/// One `sendData` call captured by [FakeTcpService].
typedef SentData = ({String type, Map<String, dynamic> payload});

/// In-memory [TcpService] for the layers above the wire: records what is sent
/// and lets the test deliver `data` messages as if they came off the socket.
class FakeTcpService extends Fake implements TcpService {
  final _messages = StreamController<TcpMessage>.broadcast();
  final _connectionState = StreamController<ConnectionState>.broadcast();

  final List<SentData> sent = [];
  int disconnectCalls = 0;
  int stopServerCalls = 0;

  /// Runs after a `sendData` call is recorded; may throw to simulate a
  /// failing link or deliver a reply.
  Future<void> Function(String type, Map<String, dynamic> payload)? onSend;

  /// Connected unless a test says otherwise, like a working link.
  ConnectionState state = ConnectionState.connected;
  PeerInfo? connectedPeer;

  @override
  Stream<TcpMessage> get messages => _messages.stream;

  @override
  bool get isConnected => state == ConnectionState.connected;

  @override
  PeerInfo? get peer => isConnected ? connectedPeer : null;

  @override
  Stream<ConnectionState> get connectionState => _connectionState.stream;

  @override
  ConnectionState get currentState => state;

  @override
  Future<void> sendData(String type, Map<String, dynamic> payload) async {
    if (!isConnected) throw const LinkNotConnectedException();
    // Round-trip through JSON so the receiver sees what the wire would carry.
    final copy = jsonDecode(jsonEncode(payload)) as Map<String, dynamic>;
    sent.add((type: type, payload: copy));
    await onSend?.call(type, copy);
  }

  @override
  Future<void> disconnect({String reason = 'user'}) async => disconnectCalls++;

  @override
  Future<void> stopServer() async => stopServerCalls++;

  List<Map<String, dynamic>> sentOf(String type) =>
      sent.where((s) => s.type == type).map((s) => s.payload).toList();

  /// Delivers an application message as a `data` frame.
  void deliver(String type, Map<String, dynamic> payload) {
    deliverRaw(
      TcpMessage.fromString(
        type: MessageType.data,
        data: jsonEncode({'type': type, 'payload': payload}),
      ),
    );
  }

  void deliverRaw(TcpMessage message) => _messages.add(message);

  void emitState(ConnectionState newState) {
    state = newState;
    _connectionState.add(newState);
  }

  Future<void> close() async {
    await _messages.close();
    await _connectionState.close();
  }
}

/// Points path_provider at [dir] for the app documents and temp directories.
void mockPathProvider(Directory dir) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async => dir.path,
      );
}

void clearPathProviderMock() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        null,
      );
}
