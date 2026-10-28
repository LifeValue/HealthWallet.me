import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:health_wallet/features/desktop/communication/data/services/transport/communication_service.dart';
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

  /// Largest frame accepted from a server client before its hello is
  /// verified. A hello is a few hundred bytes.
  static const maxUnauthenticatedFrameBytes = 64 * 1024;

  /// Largest frame accepted once the peer is known (large LWW deltas and
  /// `file_data` messages).
  static const maxFrameBytes = 1024 * 1024 * 1024;

  static const _maxPendingBytes = maxUnauthenticatedFrameBytes + 4;

  /// How long a server client has to send a valid hello before it is closed.
  /// Generous for slow networks and phones just waking up; a paired phone
  /// sends its hello right after connecting.
  @visibleForTesting
  Duration helloTimeout = const Duration(seconds: 15);

  /// How often a client pings the server, and how long it waits for the
  /// pong before treating the link as dead.
  @visibleForTesting
  Duration pingInterval = const Duration(seconds: 10);
  @visibleForTesting
  Duration pingTimeout = const Duration(seconds: 5);

  Isolate? _serverIsolate;
  SendPort? _isolateSendPort;
  Socket? _clientSocket;
  Timer? _pingTimer;
  Timer? _pingTimeoutTimer;

  String? _pairingKey;
  final _messageController = StreamController<TcpMessage>.broadcast();
  final _connectionStateController =
      StreamController<ConnectionState>.broadcast();
  final _pendingClientController = StreamController<String>.broadcast();

  ConnectionState _state = ConnectionState.disconnected;
  Uint8List _buffer = Uint8List(0);
  Completer<void>? _writeLock;

  /// The server isolate's id for the current client, null without one.
  int? _serverClientId;

  /// Whether the current server client has sent a hello with the pairing
  /// key's hash. Until then only a hello is read from it.
  bool _serverClientVerified = false;
  Timer? _helloTimer;

  CommunicationService? _mpcTransport;
  StreamSubscription? _mpcDataSub;
  bool _useMpc = false;

  void setMpcTransport(CommunicationService? transport) {
    _mpcDataSub?.cancel();
    _mpcTransport = transport;
    if (transport != null) {
      _mpcDataSub = transport.dataStream.listen(_onMpcData);
    }
  }

  void setUseMpc(bool value) {
    _useMpc = value;
    if (value) {
      debugPrint('[TCP] Routing data through MPC transport');
    }
  }

  void setPairingKeyForMpc(String key) {
    _pairingKey = key;
  }

  Future<void> sendMpcHello() async {
    var name = deviceDisplayName;
    if (name == null || name.isEmpty || name == 'localhost') {
      name = await _getDeviceName();
    }
    debugPrint('[MPC] Sending hello as: "$name"');
    await sendMessage(
      TcpMessage.fromString(
        type: MessageType.hello,
        data: jsonEncode({
          'pairing_key_hash': _pairingKey != null ? _hashKey(_pairingKey!) : '',
          'device_name': name,
        }),
      ),
    );
  }

  void _onMpcData(Uint8List data) {
    try {
      final decrypted = _decrypt(data);
      final type = MessageType.fromCode(decrypted[0]);
      final payload = decrypted.sublist(1);

      final message = TcpMessage(type: type, payload: payload);
      if (type != MessageType.ping && type != MessageType.pong) {
        debugPrint('[MPC] Received: ${type.name}');
      }
      _handleMessage(message);
    } catch (e) {
      debugPrint('[MPC] Decrypt/parse failed: $e');
    }
  }

  Stream<TcpMessage> get messages => _messageController.stream;
  Stream<ConnectionState> get connectionState =>
      _connectionStateController.stream;
  Stream<String> get pendingClients => _pendingClientController.stream;
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
          _onServerClientConnected(message['id'] as int?);
        } else if (type == 'newClientPending') {
          final address = message['address'] as String? ?? 'unknown';
          _pendingClientController.add(address);
        } else if (type == 'data') {
          final data = Uint8List.fromList(
            (message['bytes'] as List).cast<int>(),
          );
          _onData(data);
        } else if (type == 'clientDisconnected') {
          _onServerClientDisconnected();
        }
      }
    });

    return completer.future;
  }

  static Future<void> _isolateServer(_IsolateServerConfig config) async {
    unawaited(runZonedGuarded(() => _isolateServerImpl(config), (_, _) {}));
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
    var clientId = 0;
    Socket? pendingSocket;
    final pendingBuffer = <List<int>>[];
    var pendingBytes = 0;

    void clearPending() {
      pendingSocket = null;
      pendingBuffer.clear();
      pendingBytes = 0;
    }

    void activate(Socket client, String address) {
      clientSocket = client;
      clientId++;
      config.mainPort.send({
        'type': 'clientConnected',
        'address': address,
        'id': clientId,
      });
    }

    // One listener per socket, routed by the role the socket has when the
    // event arrives: a replaced or rejected socket reports nothing.
    void closed(Socket client, String reason) {
      if (client == clientSocket) {
        clientSocket = null;
        config.mainPort.send({'type': 'clientDisconnected', 'reason': reason});
      } else if (client == pendingSocket) {
        clearPending();
      }
    }

    void listenTo(Socket client) {
      client.listen(
        (data) {
          if (client == clientSocket) {
            config.mainPort.send({'type': 'data', 'bytes': data});
          } else if (client == pendingSocket) {
            pendingBytes += data.length;
            if (pendingBytes > _maxPendingBytes) {
              // A waiting phone sends only its hello; anything bigger is
              // not one.
              clearPending();
              client.destroy();
            } else {
              pendingBuffer.add(data);
            }
          }
        },
        onError: (Object e) => closed(client, e.toString()),
        onDone: () => closed(client, 'done'),
        cancelOnError: true,
      );
    }

    server.listen((client) {
      String address;
      try {
        address = client.remoteAddress.address;
      } catch (_) {
        // The socket closed before its address could be read.
        address = 'unknown';
      }

      if (clientSocket == null) {
        activate(client, address);
        listenTo(client);
        return;
      }

      pendingSocket?.destroy();
      clearPending();
      pendingSocket = client;
      listenTo(client);

      config.mainPort.send({
        'type': 'newClientPending',
        'address': address,
      });
    });

    commandPort.listen((message) {
      if (message is Map) {
        final type = message['type'] as String;
        if (type == 'send') {
          final bytes = Uint8List.fromList(
            (message['bytes'] as List).cast<int>(),
          );
          final client = clientSocket;
          try {
            client?.add(bytes);
          } catch (_) {
            // The write failed: treat the client as gone.
            client?.destroy();
            if (client != null) closed(client, 'write_failed');
          }
        } else if (type == 'dropClient') {
          final client = clientSocket;
          if (client != null && message['id'] == clientId) {
            client.destroy();
            closed(client, 'dropped');
          }
        } else if (type == 'acceptPending') {
          final next = pendingSocket;
          // The pending client already hung up: keep the current one.
          if (next == null) return;
          final old = clientSocket;
          final buffered = List<List<int>>.of(pendingBuffer);
          clearPending();
          clientSocket = null;
          old?.destroy();

          config.mainPort.send({
            'type': 'clientDisconnected',
            'reason': 'replaced',
          });

          activate(next, 'pending-accepted');
          for (final data in buffered) {
            config.mainPort.send({'type': 'data', 'bytes': data});
          }
        } else if (type == 'rejectPending') {
          pendingSocket?.destroy();
          clearPending();
        }
      } else if (message == 'stop') {
        pendingSocket?.destroy();
        clientSocket?.destroy();
        server.close();
        Isolate.exit();
      }
    });
  }

  static Future<String> _getDeviceName() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isIOS) {
        final ios = await deviceInfo.iosInfo;
        return ios.name;
      } else if (Platform.isAndroid) {
        final android = await deviceInfo.androidInfo;
        final brand = android.brand;
        final model = android.model;
        if (brand.isEmpty) return model;
        final words = brand
            .split(' ')
            .map(
              (w) =>
                  w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : w,
            );
        return '${words.join(' ')} $model';
      }
      var hostname = Platform.localHostname;
      if (hostname.endsWith('.local')) {
        hostname = hostname.substring(0, hostname.length - 6);
      }
      return hostname.replaceAll('-', ' ');
    } catch (_) {
      return Platform.localHostname
          .replaceAll('.local', '')
          .replaceAll('-', ' ');
    }
  }

  static Future<String> _getLocalIpStatic() async {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
    );
    if (interfaces.isEmpty) return '127.0.0.1';

    final vpnPrefixes = ['utun', 'tun', 'tap', 'ppp', 'ipsec', 'wg'];
    final virtualKeywords = [
      'vethernet',
      'vmware',
      'virtualbox',
      'docker',
      'hyper-v',
    ];

    bool isVpn(String name) =>
        vpnPrefixes.any((p) => name.toLowerCase().startsWith(p));
    bool isVirtual(String name) =>
        virtualKeywords.any((k) => name.toLowerCase().contains(k));
    bool isUsable(NetworkInterface iface) =>
        !isVpn(iface.name) &&
        !isVirtual(iface.name) &&
        iface.addresses.isNotEmpty;
    bool isWifi(String name) {
      final lower = name.toLowerCase();
      return lower.startsWith('en') ||
          lower.startsWith('wlan') ||
          lower.startsWith('wi-fi');
    }

    bool isEthernet(String name) {
      final lower = name.toLowerCase();
      return lower.startsWith('eth');
    }

    for (final iface in interfaces) {
      if (isWifi(iface.name) && isUsable(iface)) {
        final addr = iface.addresses.first.address;
        if (!addr.startsWith('169.254.')) return addr;
      }
    }

    for (final iface in interfaces) {
      if (isEthernet(iface.name) && isUsable(iface)) {
        final addr = iface.addresses.first.address;
        if (!addr.startsWith('169.254.')) return addr;
      }
    }

    for (final iface in interfaces) {
      if (isUsable(iface)) {
        return iface.addresses.first.address;
      }
    }

    return interfaces.first.addresses.first.address;
  }

  String? deviceDisplayName;

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

      var name = deviceDisplayName;
      if (name == null || name.isEmpty || name == 'localhost') {
        name = await _getDeviceName();
      }
      debugPrint('[TCP] Sending hello as: "$name"');

      await sendMessage(
        TcpMessage.fromString(
          type: MessageType.hello,
          data: jsonEncode({
            'pairing_key_hash': _hashKey(pairingKey),
            'device_name': name,
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
      onDone: _handleDisconnect,
    );
  }

  bool get _isServerMode => _isolateSendPort != null;

  void _onServerClientConnected(int? id) {
    _buffer = Uint8List(0);
    _serverClientId = id;
    _serverClientVerified = false;
    _helloTimer?.cancel();
    _helloTimer = Timer(helloTimeout, () {
      if (_serverClientId == id && !_serverClientVerified) {
        debugPrint('[TCP] Rejected: no valid hello in time');
        _dropServerClient();
      }
    });
  }

  void _onServerClientDisconnected() {
    _buffer = Uint8List(0);
    _serverClientId = null;
    _serverClientVerified = false;
    _helloTimer?.cancel();
    _handleDisconnect();
  }

  /// Closes the current server client; the isolate then reports it gone.
  void _dropServerClient() {
    _buffer = Uint8List(0);
    _serverClientVerified = false;
    _helloTimer?.cancel();
    final id = _serverClientId;
    if (id != null) {
      _isolateSendPort?.send({'type': 'dropClient', 'id': id});
    }
  }

  void _rejectPeer() {
    if (_isServerMode) {
      _dropServerClient();
    } else {
      _buffer = Uint8List(0);
      _handleDisconnect();
    }
  }

  void _onData(Uint8List data) {
    final combined = Uint8List(_buffer.length + data.length);
    combined.setAll(0, _buffer);
    combined.setAll(_buffer.length, data);
    _buffer = combined;

    while (_buffer.length >= 4) {
      final length = ByteData.sublistView(_buffer, 0, 4).getUint32(0);
      final unverified = _isServerMode && !_serverClientVerified;
      final cap = unverified ? maxUnauthenticatedFrameBytes : maxFrameBytes;
      if (length > cap) {
        debugPrint('[TCP] Rejected: frame of $length bytes over $cap');
        _rejectPeer();
        return;
      }
      if (_buffer.length < 4 + length) break;

      final encrypted = _buffer.sublist(4, 4 + length);
      _buffer = _buffer.sublist(4 + length);

      final TcpMessage message;
      try {
        final decrypted = _decrypt(encrypted);
        final type = MessageType.fromCode(decrypted[0]);
        message = TcpMessage(type: type, payload: decrypted.sublist(1));
      } catch (e) {
        debugPrint('[TCP] Decrypt/parse failed: $e');
        if (unverified) {
          _rejectPeer();
          return;
        }
        continue;
      }

      if (unverified) {
        // Nothing from an unknown client is read until its hello.
        if (message.type != MessageType.hello) continue;
        if (!_isValidHello(message)) {
          debugPrint('[TCP] Rejected: invalid hello');
          _rejectPeer();
          return;
        }
        _serverClientVerified = true;
        _helloTimer?.cancel();
      }

      if (message.type != MessageType.ping &&
          message.type != MessageType.pong) {
        debugPrint('[TCP] ${message.type.name}');
      }
      _handleMessage(message, viaServerSocket: _isServerMode);
      // A rejected hello drops the client; stop reading its bytes.
      if (_isServerMode && !_serverClientVerified) return;
    }
  }

  /// A hello that carries the hash of this side's pairing key.
  bool _isValidHello(TcpMessage message) {
    final key = _pairingKey;
    if (key == null) return false;
    try {
      final json = jsonDecode(message.payloadString);
      if (json is! Map<String, dynamic>) return false;
      final remoteHash = json['pairing_key_hash'];
      return remoteHash is String && remoteHash == _hashKey(key);
    } catch (e) {
      debugPrint('[TCP] Unreadable hello: $e');
      return false;
    }
  }

  void _handleMessage(TcpMessage message, {bool viaServerSocket = false}) {
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
        if (_pairingKey != null && _clientSocket == null) {
          if (!_isValidHello(message)) {
            debugPrint('[TCP] Rejected: pairing key mismatch');
            if (viaServerSocket) {
              _dropServerClient();
            } else {
              _handleDisconnect();
            }
            return;
          }
        }
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

      if (_useMpc && _mpcTransport != null) {
        await _mpcTransport!.send(encrypted);
        return;
      }

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
    if (keyBytes.length >= 32) {
      return Uint8List.fromList(keyBytes.sublist(0, 32));
    }
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
    _pingTimer = Timer.periodic(pingInterval, (_) {
      sendMessage(TcpMessage(type: MessageType.ping, payload: Uint8List(0)));
      _pingTimeoutTimer = Timer(pingTimeout, _handleDisconnect);
    });
  }

  void _handleDisconnect() {
    _pingTimer?.cancel();
    _pingTimeoutTimer?.cancel();
    if (_clientSocket != null) _buffer = Uint8List(0);
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
    _helloTimer?.cancel();
    _buffer = Uint8List(0);
    _serverClientId = null;
    _serverClientVerified = false;
    _clientSocket?.destroy();
    _clientSocket = null;
    _isolateSendPort?.send('stop');
    _isolateSendPort = null;
    _serverIsolate?.kill();
    _serverIsolate = null;
    _updateState(ConnectionState.disconnected);
  }

  void acceptPendingClient() {
    _isolateSendPort?.send({'type': 'acceptPending'});
  }

  void rejectPendingClient() {
    _isolateSendPort?.send({'type': 'rejectPending'});
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
    _pendingClientController.close();
  }
}
