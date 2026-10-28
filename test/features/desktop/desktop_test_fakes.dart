// Shared fakes and wire helpers for the desktop communication, backup and
// handover tests. Not a test file itself.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/features/desktop/communication/data/services/tcp_service.dart';
import 'package:pointycastle/export.dart';

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

  ConnectionState state = ConnectionState.disconnected;

  @override
  Stream<TcpMessage> get messages => _messages.stream;

  @override
  Stream<ConnectionState> get connectionState => _connectionState.stream;

  @override
  ConnectionState get currentState => state;

  @override
  Future<void> sendData(String type, Map<String, dynamic> payload) async {
    // Round-trip through JSON so the receiver sees what the wire would carry.
    final copy = jsonDecode(jsonEncode(payload)) as Map<String, dynamic>;
    sent.add((type: type, payload: copy));
    await onSend?.call(type, copy);
  }

  @override
  Future<void> disconnect() async => disconnectCalls++;

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

/// The peer's side of the wire format in
/// _bmad-output/planning-artifacts/architecture.md, written
/// independently of [TcpService]: AES-256-GCM with the first 32 bytes of the
/// base64url-decoded key (zero-padded), `[12-byte nonce][ciphertext+tag]`,
/// and a 4-byte big-endian length prefix on TCP.
class WireCodec {
  WireCodec(this.pairingKey);

  final String? pairingKey;
  final _random = Random(1);

  Uint8List get _key {
    final raw = base64Url.decode(pairingKey!);
    final key = Uint8List(32);
    key.setAll(0, raw.length >= 32 ? raw.sublist(0, 32) : raw);
    return key;
  }

  static String hashKey(String key) =>
      base64Url.encode(crypto.sha256.convert(utf8.encode(key)).bytes);

  Uint8List encrypt(List<int> plaintext) {
    if (pairingKey == null) return Uint8List.fromList(plaintext);
    final nonce = Uint8List.fromList(
      List.generate(12, (_) => _random.nextInt(256)),
    );
    final cipher = GCMBlockCipher(
      AESEngine(),
    )..init(true, AEADParameters(KeyParameter(_key), 128, nonce, Uint8List(0)));
    final sealed = cipher.process(Uint8List.fromList(plaintext));
    return Uint8List.fromList([...nonce, ...sealed]);
  }

  Uint8List decrypt(List<int> data) {
    if (pairingKey == null) return Uint8List.fromList(data);
    final bytes = Uint8List.fromList(data);
    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        false,
        AEADParameters(
          KeyParameter(_key),
          128,
          bytes.sublist(0, 12),
          Uint8List(0),
        ),
      );
    return cipher.process(bytes.sublist(12));
  }

  /// `[type][payload]`, encrypted, without a length prefix (MPC framing).
  Uint8List message(MessageType type, List<int> payload) =>
      encrypt([type.code, ...payload]);

  /// A full TCP frame: length prefix + encrypted message.
  Uint8List frame(MessageType type, List<int> payload) =>
      lengthPrefixed(message(type, payload));

  Uint8List dataFrame(String type, Map<String, dynamic> payload) => frame(
    MessageType.data,
    utf8.encode(jsonEncode({'type': type, 'payload': payload})),
  );

  Uint8List helloFrame({String? keyHash, String deviceName = 'Peer'}) => frame(
    MessageType.hello,
    utf8.encode(
      jsonEncode({
        'pairing_key_hash': keyHash ?? hashKey(pairingKey!),
        'device_name': deviceName,
      }),
    ),
  );

  static Uint8List lengthPrefixed(List<int> body) {
    final out = Uint8List(4 + body.length);
    ByteData.sublistView(out, 0, 4).setUint32(0, body.length);
    out.setAll(4, body);
    return out;
  }
}

/// A decoded frame read from the socket by the test peer.
typedef PeerFrame = ({int type, Uint8List payload});

/// Reassembles length-prefixed frames written by [TcpService] and hands them
/// out one at a time.
class FrameReader {
  FrameReader(this.codec);

  final WireCodec codec;
  final _frames = <PeerFrame>[];
  final _waiters = <Completer<PeerFrame>>[];
  var _buffer = <int>[];

  void add(List<int> data) {
    _buffer = [..._buffer, ...data];
    while (_buffer.length >= 4) {
      final length = ByteData.sublistView(
        Uint8List.fromList(_buffer.sublist(0, 4)),
      ).getUint32(0);
      if (_buffer.length < 4 + length) break;
      final body = _buffer.sublist(4, 4 + length);
      _buffer = _buffer.sublist(4 + length);
      final plain = codec.decrypt(body);
      final frame = (type: plain[0], payload: plain.sublist(1));
      if (_waiters.isNotEmpty) {
        _waiters.removeAt(0).complete(frame);
      } else {
        _frames.add(frame);
      }
    }
  }

  Future<PeerFrame> next() {
    if (_frames.isNotEmpty) return Future.value(_frames.removeAt(0));
    final waiter = Completer<PeerFrame>();
    _waiters.add(waiter);
    return waiter.future.timeout(const Duration(seconds: 10));
  }

  /// Skips frames until one of [type] arrives (e.g. past pings).
  Future<PeerFrame> nextOfType(MessageType type) async {
    while (true) {
      final frame = await next();
      if (frame.type == type.code) return frame;
    }
  }
}

/// A raw socket playing the other end of the link.
class PeerSocket {
  PeerSocket._(this.socket, this.reader) {
    _sub = socket.listen(
      reader.add,
      onDone: _done.complete,
      onError: (Object _) {
        if (!_done.isCompleted) _done.complete();
      },
    );
  }

  static Future<PeerSocket> connect(
    String ip,
    int port,
    WireCodec codec,
  ) async {
    return PeerSocket._(await Socket.connect(ip, port), FrameReader(codec));
  }

  static PeerSocket wrap(Socket socket, WireCodec codec) =>
      PeerSocket._(socket, FrameReader(codec));

  final Socket socket;
  final FrameReader reader;
  final _done = Completer<void>();
  late final StreamSubscription<List<int>> _sub;

  /// Completes when the other side closes the connection.
  Future<void> get done => _done.future.timeout(const Duration(seconds: 10));

  bool get isClosed => _done.isCompleted;

  Future<void> send(List<int> bytes) async {
    socket.add(bytes);
    await socket.flush();
  }

  Future<void> close() async {
    await _sub.cancel();
    socket.destroy();
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
