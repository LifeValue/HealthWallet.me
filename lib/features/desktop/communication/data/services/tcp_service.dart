import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:injectable/injectable.dart';
import 'package:pointycastle/export.dart';

enum MessageType {
  hello(0x01),
  ack(0x02),
  ping(0x03),
  pong(0x04),
  data(0x05),
  kill(0xFF);

  final int code;
  const MessageType(this.code);

  static MessageType fromCode(int code) {
    return MessageType.values.firstWhere(
      (t) => t.code == code,
      orElse: () => throw ArgumentError('Unknown message type: $code'),
    );
  }
}

class TcpMessage {
  final MessageType type;
  final Uint8List payload;

  const TcpMessage({required this.type, required this.payload});

  TcpMessage.fromString({required this.type, required String data})
    : payload = Uint8List.fromList(utf8.encode(data));

  String get payloadString => utf8.decode(payload);
}

enum ConnectionState { disconnected, connecting, connected }

class _IsolateServerConfig {
  final SendPort mainPort;
  final int port;

  _IsolateServerConfig(this.mainPort, this.port);
}

@lazySingleton
class TcpService {
  static const defaultPort = 49152;
  static const _pingInterval = Duration(seconds: 10);
  static const _pingTimeout = Duration(seconds: 5);

  Isolate? _serverIsolate;
  SendPort? _isolateSendPort;
  Socket? _clientSocket;
  Timer? _pingTimer;
  Timer? _pingTimeoutTimer;

  String? _pairingKey;
  final _messageController = StreamController<TcpMessage>.broadcast();
  final _connectionStateController =
      StreamController<ConnectionState>.broadcast();

  ConnectionState _state = ConnectionState.disconnected;
  Uint8List _buffer = Uint8List(0);
  Completer<void>? _writeLock;

  Stream<TcpMessage> get messages => _messageController.stream;
  Stream<ConnectionState> get connectionState =>
      _connectionStateController.stream;
  ConnectionState get currentState => _state;
  bool get isConnected => _state == ConnectionState.connected;

  Future<({String ip, int port})> startServer({
    required String pairingKey,
    int port = defaultPort,
  }) async {
    await stopServer();
    _pairingKey = pairingKey;

    final receivePort = ReceivePort();
    final config = _IsolateServerConfig(receivePort.sendPort, port);

    _serverIsolate = await Isolate.spawn(_isolateServer, config);

    final completer = Completer<({String ip, int port})>();

    receivePort.listen((message) {
      if (message is Map) {
        final type = message['type'] as String;

        if (type == 'listening') {
          final actualPort = message['port'] as int;
          final ip = message['ip'] as String;
          completer.complete((ip: ip, port: actualPort));
        } else if (type == 'sendPort') {
          _isolateSendPort = message['sendPort'] as SendPort;
        } else if (type == 'clientConnected') {
        } else if (type == 'data') {
          final data = Uint8List.fromList(
            (message['bytes'] as List).cast<int>(),
          );
          _onData(data);
        } else if (type == 'clientDisconnected') {
          _handleDisconnect();
        } else if (type == 'error') {}
      }
    });

    return completer.future;
  }

  static Future<void> _isolateServer(_IsolateServerConfig config) async {
    runZonedGuarded(() => _isolateServerImpl(config), (_, __) {});
  }

  static Future<void> _isolateServerImpl(_IsolateServerConfig config) async {
    final commandPort = ReceivePort();
    config.mainPort.send({
      'type': 'sendPort',
      'sendPort': commandPort.sendPort,
    });

    final ip = await _getLocalIpStatic();
    final bindAddress = InternetAddress(ip);

    ServerSocket server;
    try {
      server = await ServerSocket.bind(bindAddress, config.port);
    } on SocketException {
      try {
        server = await ServerSocket.bind(bindAddress, 0);
      } on SocketException {
        server = await ServerSocket.bind(InternetAddress.anyIPv4, 0);
      }
    }
    config.mainPort.send({'type': 'listening', 'port': server.port, 'ip': ip});

    Socket? clientSocket;

    server.listen((client) {
      String address;
      try {
        address = client.remoteAddress.address;
      } catch (_) {
        address = 'unknown';
      }
      config.mainPort.send({'type': 'clientConnected', 'address': address});

      clientSocket?.destroy();
      clientSocket = client;

      client.listen(
        (data) {
          config.mainPort.send({'type': 'data', 'bytes': data});
        },
        onError: (e) {
          config.mainPort.send({
            'type': 'clientDisconnected',
            'reason': e.toString(),
          });
          clientSocket = null;
        },
        onDone: () {
          config.mainPort.send({
            'type': 'clientDisconnected',
            'reason': 'done',
          });
          clientSocket = null;
        },
      );
    });

    commandPort.listen((message) {
      if (message is Map && message['type'] == 'send') {
        final bytes = Uint8List.fromList(
          (message['bytes'] as List).cast<int>(),
        );
        try {
          clientSocket?.add(bytes);
        } catch (_) {
          clientSocket?.destroy();
          clientSocket = null;
          config.mainPort.send({
            'type': 'clientDisconnected',
            'reason': 'write_failed',
          });
        }
      } else if (message == 'stop') {
        clientSocket?.destroy();
        server.close();
        Isolate.exit();
      }
    });
  }

  static Future<String> _getLocalIpStatic() async {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
    );
    if (interfaces.isEmpty) return '127.0.0.1';

    final vpnPrefixes = ['utun', 'tun', 'tap', 'ppp', 'ipsec', 'wg'];
    final lanPrefixes = ['en', 'eth', 'wlan'];

    bool isVpn(String name) =>
        vpnPrefixes.any((p) => name.toLowerCase().startsWith(p));
    bool isLan(String name) =>
        lanPrefixes.any((p) => name.toLowerCase().startsWith(p));

    for (final iface in interfaces) {
      if (isLan(iface.name) && iface.addresses.isNotEmpty) {
        final addr = iface.addresses.first.address;
        if (!addr.startsWith('169.254.')) return addr;
      }
    }

    for (final iface in interfaces) {
      if (!isVpn(iface.name) && iface.addresses.isNotEmpty) {
        return iface.addresses.first.address;
      }
    }

    return interfaces.first.addresses.first.address;
  }

  Future<void> connectToServer({
    required String ip,
    required int port,
    required String pairingKey,
  }) async {
    _pairingKey = pairingKey;
    _updateState(ConnectionState.connecting);

    try {
      _clientSocket = await Socket.connect(
        ip,
        port,
        timeout: const Duration(seconds: 5),
      );
      _setupClientSocket(_clientSocket!);
      _updateState(ConnectionState.connected);
      debugPrint('[TCP] Connected to $ip:$port, sending hello');

      await sendMessage(
        TcpMessage.fromString(
          type: MessageType.hello,
          data: jsonEncode({
            'pairing_key_hash': _hashKey(pairingKey),
            'device_name': Platform.localHostname
                .replaceAll('.local', '')
                .replaceAll('-', ' '),
          }),
        ),
      );

      _startPingTimer();
    } catch (e) {
      _updateState(ConnectionState.disconnected);
      rethrow;
    }
  }

  void _setupClientSocket(Socket socket) {
    _buffer = Uint8List(0);
    socket.listen(
      (data) {
        _onData(Uint8List.fromList(data));
      },
      onError: (_) {
        _handleDisconnect();
      },
      onDone: () {
        _handleDisconnect();
      },
    );
  }

  void _onData(Uint8List data) {
    final combined = Uint8List(_buffer.length + data.length);
    combined.setAll(0, _buffer);
    combined.setAll(_buffer.length, data);
    _buffer = combined;

    while (_buffer.length >= 4) {
      final length = ByteData.sublistView(_buffer, 0, 4).getUint32(0);
      if (_buffer.length < 4 + length) break;

      final encrypted = _buffer.sublist(4, 4 + length);
      _buffer = _buffer.sublist(4 + length);

      try {
        final decrypted = _decrypt(encrypted);
        final type = MessageType.fromCode(decrypted[0]);
        final payload = decrypted.sublist(1);

        final message = TcpMessage(type: type, payload: payload);
        debugPrint('[TCP] Received message: ${type.name}');
        _handleMessage(message);
      } catch (e) {
        debugPrint('[TCP] Decrypt/parse failed: $e');
      }
    }
  }

  void _handleMessage(TcpMessage message) {
    debugPrint('[TCP] Handling: ${message.type.name}');
    switch (message.type) {
      case MessageType.ping:
        sendMessage(TcpMessage(type: MessageType.pong, payload: Uint8List(0)));
        return;
      case MessageType.pong:
        _pingTimeoutTimer?.cancel();
        return;
      case MessageType.kill:
        sendMessage(TcpMessage(type: MessageType.ack, payload: Uint8List(0)));
        _handleDisconnect();
        return;
      case MessageType.hello:
        _updateState(ConnectionState.connected);
        sendMessage(TcpMessage(type: MessageType.ack, payload: Uint8List(0)));
        _messageController.add(message);
        return;
      default:
        _messageController.add(message);
    }
  }

  Future<void> sendMessage(TcpMessage message) async {
    while (_writeLock != null) {
      await _writeLock!.future;
    }
    _writeLock = Completer<void>();

    try {
      final typeAndPayload = Uint8List(1 + message.payload.length);
      typeAndPayload[0] = message.type.code;
      typeAndPayload.setAll(1, message.payload);

      final encrypted = _encrypt(typeAndPayload);
      final frame = Uint8List(4 + encrypted.length);
      ByteData.sublistView(frame, 0, 4).setUint32(0, encrypted.length);
      frame.setAll(4, encrypted);

      if (_isolateSendPort != null) {
        _isolateSendPort!.send({'type': 'send', 'bytes': frame.toList()});
      } else if (_clientSocket != null) {
        _clientSocket!.add(frame);
        await _clientSocket!.flush();
      }
    } finally {
      final lock = _writeLock;
      _writeLock = null;
      lock?.complete();
    }
  }

  Future<void> sendData(String type, Map<String, dynamic> payload) async {
    final data = jsonEncode({'type': type, 'payload': payload});
    await sendMessage(
      TcpMessage.fromString(type: MessageType.data, data: data),
    );
  }

  Uint8List _encrypt(Uint8List plaintext) {
    if (_pairingKey == null) return plaintext;

    final key = _deriveKey(_pairingKey!);
    final nonce = _generateNonce();

    final cipher = GCMBlockCipher(AESEngine())
      ..init(true, AEADParameters(KeyParameter(key), 128, nonce, Uint8List(0)));

    final output = Uint8List(cipher.getOutputSize(plaintext.length));
    final len = cipher.processBytes(plaintext, 0, plaintext.length, output, 0);
    final finalLen = cipher.doFinal(output, len);
    final ciphertext = output.sublist(0, len + finalLen);

    final result = Uint8List(nonce.length + ciphertext.length);
    result.setAll(0, nonce);
    result.setAll(nonce.length, ciphertext);
    return result;
  }

  Uint8List _decrypt(Uint8List data) {
    if (_pairingKey == null) return data;

    final key = _deriveKey(_pairingKey!);
    final nonce = data.sublist(0, 12);
    final ciphertext = data.sublist(12);

    final cipher = GCMBlockCipher(
      AESEngine(),
    )..init(false, AEADParameters(KeyParameter(key), 128, nonce, Uint8List(0)));

    final plaintext = Uint8List(cipher.getOutputSize(ciphertext.length));
    final len = cipher.processBytes(
      ciphertext,
      0,
      ciphertext.length,
      plaintext,
      0,
    );
    final finalLen = cipher.doFinal(plaintext, len);

    return plaintext.sublist(0, len + finalLen);
  }

  Uint8List _deriveKey(String pairingKey) {
    final keyBytes = base64Url.decode(pairingKey);
    if (keyBytes.length >= 32)
      return Uint8List.fromList(keyBytes.sublist(0, 32));
    final padded = Uint8List(32);
    padded.setAll(0, keyBytes);
    return padded;
  }

  Uint8List _generateNonce() {
    final random = Random.secure();
    return Uint8List.fromList(List.generate(12, (_) => random.nextInt(256)));
  }

  String _hashKey(String key) {
    final digest = SHA256Digest();
    final keyBytes = Uint8List.fromList(utf8.encode(key));
    return base64Url.encode(digest.process(keyBytes));
  }

  void _startPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(_pingInterval, (_) {
      sendMessage(TcpMessage(type: MessageType.ping, payload: Uint8List(0)));
      _pingTimeoutTimer = Timer(_pingTimeout, _handleDisconnect);
    });
  }

  void _handleDisconnect() {
    _pingTimer?.cancel();
    _pingTimeoutTimer?.cancel();
    _clientSocket?.destroy();
    _clientSocket = null;
    _updateState(ConnectionState.disconnected);
  }

  void _updateState(ConnectionState state) {
    if (_state == state) return;
    _state = state;
    _connectionStateController.add(state);
  }

  Future<void> stopServer() async {
    _pingTimer?.cancel();
    _pingTimeoutTimer?.cancel();
    _clientSocket?.destroy();
    _clientSocket = null;
    _isolateSendPort?.send('stop');
    _isolateSendPort = null;
    _serverIsolate?.kill();
    _serverIsolate = null;
    _updateState(ConnectionState.disconnected);
  }

  Future<void> disconnect() async {
    try {
      await sendMessage(
        TcpMessage(type: MessageType.kill, payload: Uint8List(0)),
      );
    } catch (_) {}
    _handleDisconnect();
  }

  void dispose() {
    stopServer();
    _messageController.close();
    _connectionStateController.close();
  }
}
