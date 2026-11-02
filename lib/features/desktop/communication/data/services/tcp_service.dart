import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:health_wallet/core/utils/logger.dart';
import 'package:health_wallet/features/desktop/communication/data/services/link_protocol.dart';
import 'package:health_wallet/features/desktop/communication/data/services/transport/communication_service.dart';
import 'package:injectable/injectable.dart';

export 'link_protocol.dart'
    show
        LinkException,
        LinkFailure,
        LinkNotConnectedException,
        LinkTimings,
        MessageType,
        PeerInfo,
        TcpMessage,
        discoveryToken,
        isValidPairingKey;

enum ConnectionState { disconnected, connecting, awaitingApproval, connected }

enum LinkTransport { tcp, mpc }

/// A phone that proved it holds the pairing key but isn't the paired one;
/// the desktop's user decides.
class PendingApproval {
  const PendingApproval(this.peer);

  final PeerInfo peer;
}

/// The link between the phone and the desktop, over TCP or MPC: the phone
/// connects as a client, the desktop listens. One verified session is active
/// at a time; on the desktop the newest verified one replaces the previous,
/// so a phone that reconnects after a drop is never locked out by its own
/// half-open socket.
@lazySingleton
class TcpService {
  static const defaultPort = 49152;

  /// Sockets the desktop holds at once, verified or not.
  static const maxServerSockets = 8;

  @visibleForTesting
  LinkTimings timings = const LinkTimings();

  /// The name sent in the hello; the device's own name when unset.
  String? deviceDisplayName;

  final _messageController = StreamController<TcpMessage>.broadcast();
  final _connectionStateController =
      StreamController<ConnectionState>.broadcast();
  final _approvalController = StreamController<PendingApproval?>.broadcast();
  final _approvedController = StreamController<PeerInfo>.broadcast();
  final _serverFailureController = StreamController<LinkFailure>.broadcast();

  ConnectionState _state = ConnectionState.disconnected;
  bool _disposed = false;
  SecureChannel? _active;
  LinkTransport? _activeTransport;

  // Client (phone).
  SecureChannel? _clientChannel;

  // Server (desktop).
  Isolate? _serverIsolate;
  SendPort? _isolatePort;
  ReceivePort? _receivePort;
  final _serverSockets = <int, _ServerSocket>{};
  List<String> _serverKeys = const [];
  String? _serverId;
  String _serverName = '';
  String? _pairedPeerId;
  SecureChannel? _pendingApproval;

  // MPC.
  CommunicationService? _mpc;
  bool _mpcAsServer = false;
  StreamSubscription? _mpcStateSub;
  StreamSubscription? _mpcDataSub;
  SecureChannel? _mpcChannel;
  MpcFramer? _mpcFramer;
  _ClientConfig? _mpcClientConfig;

  /// Application (`data`) messages of the verified session.
  Stream<TcpMessage> get messages => _messageController.stream;
  Stream<ConnectionState> get connectionState =>
      _connectionStateController.stream;
  ConnectionState get currentState => _state;
  bool get isConnected => _state == ConnectionState.connected;

  /// The verified device at the other end, while connected.
  PeerInfo? get peer => _active?.peer;
  LinkTransport? get transport => _active == null ? null : _activeTransport;

  /// Why the other side ended the last verified session, when it said:
  /// `user` (its user disconnected) or `shutdown` (the app quit).
  String? lastPeerCloseReason;

  /// Phone: why its last session ended, e.g. [LinkFailure.declined] after
  /// waiting for the desktop's user.
  LinkFailure? lastClientFailure;

  /// Which pairing key the connected phone used: 0 the current one, 1 the
  /// one the desktop is moving to.
  int? get activeKeyIndex => _active?.keyIndex;

  /// Desktop: a phone waiting for the user's decision, or null once decided.
  Stream<PendingApproval?> get approvalRequests => _approvalController.stream;
  PendingApproval? get pendingApproval {
    final peer = _pendingApproval?.peer;
    return peer == null ? null : PendingApproval(peer);
  }

  /// Desktop: a phone that became the paired one, by approval or as the first
  /// phone to pair.
  Stream<PeerInfo> get peerApproved => _approvedController.stream;

  /// Desktop: why connections that never became ready ended.
  Stream<LinkFailure> get serverFailures => _serverFailureController.stream;

  // ---------------------------------------------------------------------------
  // Sending

  /// Sends an application message on the verified session. Throws
  /// [LinkNotConnectedException] without one.
  Future<void> sendData(String type, Map<String, dynamic> payload) async {
    final channel = _active;
    if (channel == null || !channel.isReady) {
      throw const LinkNotConnectedException();
    }
    final data = utf8.encode(jsonEncode({'type': type, 'payload': payload}));
    await channel.send(MessageType.data, Uint8List.fromList(data));
  }

  // ---------------------------------------------------------------------------
  // Client (phone)

  /// Connects to the desktop at [ip]:[port] and completes once it accepted
  /// the session, or once it asks its user to accept this phone (the state is
  /// then [ConnectionState.awaitingApproval]). Throws [LinkException] when the
  /// desktop rejects the phone or doesn't answer, and [SocketException] when
  /// nothing listens there.
  Future<void> connectToServer({
    required String ip,
    required int port,
    required String pairingKey,
    required String expectedDeviceId,
    required String localDeviceId,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    await _closeClient();
    _updateState(ConnectionState.connecting);

    final Socket socket;
    try {
      socket = await Socket.connect(
        ip,
        port,
        timeout: const Duration(seconds: 5),
      );
    } catch (e) {
      _refreshState();
      rethrow;
    }

    final endpoint = _SocketEndpoint(socket);
    final SecureChannel channel;
    try {
      channel = SecureChannel.client(
        endpoint: endpoint,
        pairingKey: pairingKey,
        localId: localDeviceId,
        localName: await _localName(),
        expectedPeerId: expectedDeviceId,
        timings: timings,
      );
    } on FormatException {
      socket.destroy();
      _refreshState();
      rethrow;
    }
    _clientChannel = channel;
    final reader = FrameReader(
      maxFrame: () => channel.maxFrame,
      onFrame: channel.receive,
      onTooLarge: (length) => channel.lowerClosed(),
    );
    socket.listen(
      reader.add,
      onError: (Object e) => channel.lowerClosed(),
      onDone: channel.lowerClosed,
      cancelOnError: true,
    );
    _track(channel, LinkTransport.tcp, server: false);
    channel.start();

    await _await(channel, timeout);
  }

  Future<void> _await(SecureChannel channel, Duration timeout) async {
    try {
      await channel.established.timeout(timeout);
    } on TimeoutException {
      await channel.close(sendKill: false);
      throw const LinkException(LinkFailure.noAnswer, 'timed out');
    }
  }

  Future<void> _closeClient() async {
    final channel = _clientChannel;
    _clientChannel = null;
    await channel?.close();
  }

  Future<String> _localName() async {
    final name = deviceDisplayName;
    if (name != null && name.isNotEmpty && name != 'localhost') return name;
    return _getDeviceName();
  }

  // ---------------------------------------------------------------------------
  // Server (desktop)

  /// Listens for phones on [port] (a free port when it is taken) on every
  /// interface, so a new address after a network change still reaches it.
  /// [pairingKeys] are the current key and, while the desktop moves to a new
  /// one, that key. Returns the port.
  Future<int> startServer({
    required List<String> pairingKeys,
    required String deviceId,
    required String deviceName,
    required String? pairedPeerId,
    int port = defaultPort,
  }) async {
    await stopServer();
    _serverKeys = pairingKeys;
    _serverId = deviceId;
    _serverName = deviceName;
    _pairedPeerId = pairedPeerId;

    final receivePort = ReceivePort();
    _receivePort = receivePort;
    final listening = Completer<int>();

    receivePort.listen((message) {
      if (message is! Map) return;
      switch (message['type']) {
        case 'commands':
          _isolatePort = message['port'] as SendPort;
        case 'listening':
          if (!listening.isCompleted) {
            listening.complete(message['port'] as int);
          }
        case 'error':
          final error = message['message'] as String? ?? 'unknown';
          logger.e('[TCP] server failed: $error');
          if (!listening.isCompleted) {
            listening.completeError(SocketException(error));
          }
        case 'opened':
          _onSocketOpened(message['id'] as int);
        case 'data':
          final bytes = (message['bytes'] as TransferableTypedData)
              .materialize()
              .asUint8List();
          _serverSockets[message['id']]?.reader.add(bytes);
        case 'flushed':
          _serverSockets[message['id']]?.endpoint.flushed();
        case 'closed':
          final socket = _serverSockets.remove(message['id']);
          socket?.reader.stop();
          socket?.endpoint.closedBelow();
          socket?.channel.lowerClosed();
        case 'stopped':
          break;
      }
    });

    _serverIsolate = await Isolate.spawn(
      _isolateServer,
      _IsolateServerConfig(receivePort.sendPort, port, maxServerSockets),
    );

    try {
      return await listening.future.timeout(const Duration(seconds: 10));
    } catch (e) {
      await stopServer();
      rethrow;
    }
  }

  /// Desktop: the keys a phone may use, after a pairing or a key change.
  void updateServerKeys(List<String> pairingKeys) {
    _serverKeys = pairingKeys;
  }

  /// Desktop: the phone that connects without asking, null for "none yet"
  /// (the first phone to pair is accepted).
  void setPairedPeer(String? deviceId) {
    _pairedPeerId = deviceId;
  }

  bool _isPairedPeer(String deviceId) =>
      _pairedPeerId == null || _pairedPeerId == deviceId;

  void _onSocketOpened(int id) {
    final endpoint = _IsolateEndpoint(id, this);
    final SecureChannel channel;
    try {
      channel = SecureChannel.server(
        endpoint: endpoint,
        pairingKeys: _serverKeys,
        localId: _serverId!,
        localName: _serverName,
        isPairedPeer: _isPairedPeer,
        timings: timings,
      );
    } catch (e) {
      logger.e('[TCP] server keys unusable', e);
      _isolatePort?.send({'type': 'close', 'id': id});
      return;
    }
    final reader = FrameReader(
      maxFrame: () => channel.maxFrame,
      onFrame: channel.receive,
      onTooLarge: (length) => channel.close(sendKill: false),
    );
    _serverSockets[id] = _ServerSocket(endpoint, channel, reader);
    _track(channel, LinkTransport.tcp, server: true);
    channel.start();
  }

  /// Desktop: the user accepted the waiting phone.
  void approvePending() {
    final channel = _pendingApproval;
    _pendingApproval = null;
    _emit(_approvalController, null);
    channel?.approve();
  }

  /// Desktop: the user declined the waiting phone.
  void declinePending() {
    final channel = _pendingApproval;
    _pendingApproval = null;
    _emit(_approvalController, null);
    channel?.decline();
  }

  Future<void> stopServer() async {
    final isolate = _serverIsolate;
    final port = _isolatePort;
    _serverIsolate = null;
    _isolatePort = null;
    for (final socket in _serverSockets.values.toList()) {
      await socket.channel.close(sendKill: socket.channel == _active);
    }
    _serverSockets.clear();
    if (isolate != null) {
      final exited = ReceivePort();
      isolate.addOnExitListener(exited.sendPort);
      port?.send({'type': 'stop'});
      // The isolate closes its sockets and exits by itself; it is killed
      // only if it hangs.
      await exited.first.timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          isolate.kill(priority: Isolate.immediate);
          return null;
        },
      );
      exited.close();
    }
    _receivePort?.close();
    _receivePort = null;
    if (_pendingApproval != null) {
      _pendingApproval = null;
      _emit(_approvalController, null);
    }
  }

  // ---------------------------------------------------------------------------
  // MPC

  /// Routes the MPC transport through the same handshake: the desktop
  /// ([asServer]) answers phones, the phone connects with
  /// [connectOverMpc].
  void attachMpc(CommunicationService? transport, {required bool asServer}) {
    _mpcStateSub?.cancel();
    _mpcDataSub?.cancel();
    _mpc = transport;
    _mpcAsServer = asServer;
    if (transport == null) return;
    _mpcStateSub = transport.stateStream.listen((state) {
      if (state == CommunicationState.connected) {
        unawaited(_onMpcConnected());
      } else if (state == CommunicationState.disconnected) {
        _mpcFramer?.stop();
        _mpcChannel?.lowerClosed();
      }
    });
    _mpcDataSub = transport.dataStream.listen(
      (piece) => _mpcFramer?.add(piece),
    );
  }

  /// Phone: runs the handshake over MPC once the transport connects, within
  /// [timeout].
  Future<void> connectOverMpc({
    required String pairingKey,
    required String expectedDeviceId,
    required String localDeviceId,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final mpc = _mpc;
    if (mpc == null) throw const LinkException(LinkFailure.noAnswer, 'no MPC');
    final config = _ClientConfig(
      pairingKey: pairingKey,
      expectedDeviceId: expectedDeviceId,
      localDeviceId: localDeviceId,
    );
    _mpcClientConfig = config;
    _updateState(ConnectionState.connecting);
    if (mpc.currentState == CommunicationState.connected &&
        _mpcChannel == null) {
      unawaited(_onMpcConnected());
    }
    final deadline = DateTime.now().add(timeout);
    while (_mpcChannel == null || _mpcChannel!.state == ChannelState.closed) {
      if (DateTime.now().isAfter(deadline) || _mpcClientConfig != config) {
        _mpcClientConfig = null;
        _refreshState();
        throw const LinkException(LinkFailure.noAnswer, 'MPC not connected');
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    final remaining = deadline.difference(DateTime.now());
    await _await(
      _mpcChannel!,
      remaining.isNegative ? Duration.zero : remaining,
    );
  }

  /// Phone: stops waiting for or using MPC.
  void cancelMpcClient() {
    _mpcClientConfig = null;
    _mpcChannel?.close(sendKill: false);
  }

  Future<void> _onMpcConnected() async {
    final mpc = _mpc;
    if (mpc == null) return;
    // Cleared first, so closing the old session doesn't disconnect the new
    // MPC link.
    final old = _mpcChannel;
    _mpcChannel = null;
    unawaited(old?.close(sendKill: false));

    if (!_mpcAsServer) {
      final config = _mpcClientConfig;
      // Not asked for, or the phone already has a working TCP link.
      if (config == null || (_active?.isReady ?? false)) {
        unawaited(mpc.disconnect());
        return;
      }
    }

    final endpoint = _MpcEndpoint(mpc);
    final SecureChannel channel;
    try {
      if (_mpcAsServer) {
        channel = SecureChannel.server(
          endpoint: endpoint,
          pairingKeys: _serverKeys,
          localId: _serverId!,
          localName: _serverName,
          isPairedPeer: _isPairedPeer,
          timings: timings,
        );
      } else {
        final config = _mpcClientConfig!;
        channel = SecureChannel.client(
          endpoint: endpoint,
          pairingKey: config.pairingKey,
          localId: config.localDeviceId,
          localName: await _localName(),
          expectedPeerId: config.expectedDeviceId,
          timings: timings,
        );
      }
    } catch (e) {
      logger.e('[MPC] no usable pairing key', e);
      unawaited(mpc.disconnect());
      return;
    }
    _mpcChannel = channel;
    _mpcFramer = MpcFramer(
      maxFrame: () => channel.maxFrame,
      onFrame: channel.receive,
      onTooLarge: (length) => channel.close(sendKill: false),
    );
    _track(channel, LinkTransport.mpc, server: _mpcAsServer);
    channel.start();
  }

  // ---------------------------------------------------------------------------
  // Sessions

  void _track(
    SecureChannel channel,
    LinkTransport transport, {
    required bool server,
  }) {
    channel.messages.listen((message) {
      if (channel == _active) _emit(_messageController, message);
    });
    channel.states.listen(
      (state) => _onChannelState(channel, transport, state, server: server),
    );
  }

  void _onChannelState(
    SecureChannel channel,
    LinkTransport transport,
    ChannelState state, {
    required bool server,
  }) {
    switch (state) {
      case ChannelState.handshaking:
        break;
      case ChannelState.awaitingApproval:
        if (server) {
          final previous = _pendingApproval;
          _pendingApproval = channel;
          // A newer request replaces an unanswered older one.
          previous?.decline();
          _emit(_approvalController, PendingApproval(channel.peer!));
        } else {
          _refreshState();
        }
      case ChannelState.ready:
        final previous = _active;
        _active = channel;
        _activeTransport = transport;
        if (previous != null && previous != channel) {
          unawaited(previous.close());
        }
        if (server) {
          final peer = channel.peer!;
          if (_pairedPeerId != peer.deviceId) {
            _pairedPeerId = peer.deviceId;
            _emit(_approvedController, peer);
          }
        } else if (transport == LinkTransport.tcp) {
          // A working TCP link; MPC isn't needed.
          cancelMpcClient();
        }
        _refreshState();
      case ChannelState.closed:
        if (channel == _pendingApproval) {
          _pendingApproval = null;
          _emit(_approvalController, null);
        }
        final failure = channel.failure;
        if (server &&
            (failure == LinkFailure.version ||
                failure == LinkFailure.unknownKey)) {
          _emit(_serverFailureController, failure!);
        }
        if (!server) lastClientFailure = channel.failure;
        if (channel == _clientChannel) _clientChannel = null;
        if (channel == _mpcChannel) {
          _mpcChannel = null;
          _mpcFramer = null;
          // The desktop advertises again; the phone stops browsing.
          final mpc = _mpc;
          if (mpc != null) unawaited(mpc.disconnect());
        }
        if (channel == _active) {
          _active = null;
          _activeTransport = null;
          lastPeerCloseReason = channel.peerCloseReason;
        }
        _refreshState();
    }
  }

  /// Derives the state from the sessions: connected while one is verified,
  /// otherwise what the phone's attempt is doing.
  void _refreshState() {
    final ConnectionState next;
    if (_active?.isReady ?? false) {
      next = ConnectionState.connected;
    } else if (_clientChannel?.state == ChannelState.awaitingApproval ||
        (!_mpcAsServer &&
            _mpcChannel?.state == ChannelState.awaitingApproval)) {
      next = ConnectionState.awaitingApproval;
    } else if (_clientChannel != null ||
        (!_mpcAsServer && (_mpcClientConfig != null || _mpcChannel != null))) {
      next = ConnectionState.connecting;
    } else {
      next = ConnectionState.disconnected;
    }
    _updateState(next);
  }

  void _updateState(ConnectionState state) {
    if (_state == state) return;
    _state = state;
    if (!_disposed) _connectionStateController.add(state);
  }

  /// Ends the verified session, telling the peer why ([reason]: `user` by
  /// default, `shutdown` when the app quits). The desktop keeps listening.
  Future<void> disconnect({String reason = 'user'}) async {
    final active = _active;
    _mpcClientConfig = null;
    await active?.close(reason: reason);
    final client = _clientChannel;
    _clientChannel = null;
    await client?.close(reason: reason);
    await _mpcChannel?.close(reason: reason);
    _refreshState();
  }

  void dispose() {
    _disposed = true;
    unawaited(stopServer());
    unawaited(disconnect());
    _mpcStateSub?.cancel();
    _mpcDataSub?.cancel();
    _messageController.close();
    _connectionStateController.close();
    _approvalController.close();
    _approvedController.close();
    _serverFailureController.close();
  }

  void _emit<T>(StreamController<T> controller, T value) {
    if (!_disposed && !controller.isClosed) controller.add(value);
  }

  // ---------------------------------------------------------------------------
  // Isolate

  static Future<void> _isolateServer(_IsolateServerConfig config) async {
    await runZonedGuarded(() => _isolateServerImpl(config), (e, stack) {
      config.mainPort.send({'type': 'error', 'message': '$e'});
    });
  }

  static Future<void> _isolateServerImpl(_IsolateServerConfig config) async {
    final commands = ReceivePort();
    config.mainPort.send({'type': 'commands', 'port': commands.sendPort});

    ServerSocket server;
    try {
      server = await ServerSocket.bind(InternetAddress.anyIPv4, config.port);
    } on SocketException {
      server = await ServerSocket.bind(InternetAddress.anyIPv4, 0);
    }
    config.mainPort.send({'type': 'listening', 'port': server.port});

    final sockets = <int, Socket>{};
    final queues = <int, Future<void>>{};
    var nextId = 0;

    void closed(int id) {
      if (sockets.remove(id) == null) return;
      queues.remove(id);
      config.mainPort.send({'type': 'closed', 'id': id});
    }

    server.listen((client) {
      if (sockets.length >= config.maxSockets) {
        client.destroy();
        return;
      }
      final id = nextId++;
      sockets[id] = client;
      String address;
      try {
        address = client.remoteAddress.address;
      } catch (_) {
        // The socket closed before its address could be read.
        address = 'unknown';
      }
      config.mainPort.send({'type': 'opened', 'id': id, 'address': address});
      client.listen(
        (data) => config.mainPort.send({
          'type': 'data',
          'id': id,
          'bytes': TransferableTypedData.fromList([data]),
        }),
        onError: (Object _) => closed(id),
        onDone: () => closed(id),
        cancelOnError: true,
      );
    });

    commands.listen((message) async {
      if (message is! Map) return;
      final id = message['id'];
      switch (message['type']) {
        case 'send':
          final socket = sockets[id];
          final bytes = (message['bytes'] as TransferableTypedData)
              .materialize()
              .asUint8List();
          queues[id] = (queues[id] ?? Future.value()).then((_) async {
            try {
              socket?.add(bytes);
              await socket?.flush();
            } catch (_) {
              // The write failed: the socket is gone.
              socket?.destroy();
              closed(id as int);
            }
            config.mainPort.send({'type': 'flushed', 'id': id});
          });
        case 'close':
          final socket = sockets[id];
          await (queues[id] ?? Future.value());
          try {
            await socket?.close().timeout(const Duration(seconds: 2));
          } catch (_) {
            // Closing politely failed; drop it.
          }
          socket?.destroy();
          if (id is int) closed(id);
        case 'stop':
          for (final socket in sockets.values.toList()) {
            socket.destroy();
          }
          sockets.clear();
          await server.close();
          config.mainPort.send({'type': 'stopped'});
          commands.close();
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
    } catch (e) {
      logger.w('[TCP] device name unavailable', e);
      return Platform.localHostname
          .replaceAll('.local', '')
          .replaceAll('-', ' ');
    }
  }

  static Future<List<NetworkInterface>> ipv4Interfaces() =>
      NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );

  /// The address phones should use for this computer: a Wi-Fi, then
  /// Ethernet, then any other IPv4 address that isn't a VPN, virtual
  /// adapter, loopback or link-local; null without one. Also whether a VPN
  /// is up. Reads [interfaces], this computer's IPv4 ones by default.
  static Future<({String? ip, bool vpnDetected})> localAddress([
    List<NetworkInterface>? interfaces,
  ]) async {
    interfaces ??= await ipv4Interfaces();

    const vpnPrefixes = ['utun', 'tun', 'tap', 'ppp', 'ipsec', 'wg'];
    const virtualKeywords = [
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
    String? usableAddress(NetworkInterface iface) {
      if (isVpn(iface.name) || isVirtual(iface.name)) return null;
      for (final address in iface.addresses) {
        if (address.isLoopback || address.isLinkLocal) continue;
        return address.address;
      }
      return null;
    }

    bool isWifi(String name) {
      final lower = name.toLowerCase();
      return lower.startsWith('en') ||
          lower.startsWith('wlan') ||
          lower.startsWith('wi-fi');
    }

    final hasVpn = interfaces.any((i) => isVpn(i.name));
    for (final match in [
      isWifi,
      (String name) => name.toLowerCase().startsWith('eth'),
      (String _) => true,
    ]) {
      for (final iface in interfaces) {
        if (!match(iface.name)) continue;
        final address = usableAddress(iface);
        if (address != null) return (ip: address, vpnDetected: hasVpn);
      }
    }
    return (ip: null, vpnDetected: hasVpn);
  }
}

class _ClientConfig {
  const _ClientConfig({
    required this.pairingKey,
    required this.expectedDeviceId,
    required this.localDeviceId,
  });

  final String pairingKey;
  final String expectedDeviceId;
  final String localDeviceId;
}

class _IsolateServerConfig {
  const _IsolateServerConfig(this.mainPort, this.port, this.maxSockets);

  final SendPort mainPort;
  final int port;
  final int maxSockets;
}

class _ServerSocket {
  _ServerSocket(this.endpoint, this.channel, this.reader);

  final _IsolateEndpoint endpoint;
  final SecureChannel channel;
  final FrameReader reader;
}

class _SocketEndpoint implements LinkEndpoint {
  _SocketEndpoint(this._socket);

  final Socket _socket;
  bool _closed = false;

  @override
  Future<void> sendBody(Uint8List body) async {
    if (_closed) throw const LinkNotConnectedException();
    _socket.add(FrameReader.frame(body));
    await _socket.flush();
  }

  @override
  void close() {
    if (_closed) return;
    _closed = true;
    unawaited(
      _socket
          .close()
          .timeout(const Duration(seconds: 2))
          .catchError((Object _) => _socket)
          .whenComplete(_socket.destroy),
    );
  }
}

/// A desktop socket held by the server isolate. A send completes once the
/// isolate flushed it, so a long transfer can't pile up in memory.
class _IsolateEndpoint implements LinkEndpoint {
  _IsolateEndpoint(this._id, this._service);

  final int _id;
  final TcpService _service;
  final _flushes = <Completer<void>>[];
  bool _closed = false;

  @override
  Future<void> sendBody(Uint8List body) {
    final port = _service._isolatePort;
    if (_closed || port == null) {
      return Future.error(const LinkNotConnectedException());
    }
    final done = Completer<void>();
    _flushes.add(done);
    port.send({
      'type': 'send',
      'id': _id,
      'bytes': TransferableTypedData.fromList([FrameReader.frame(body)]),
    });
    return done.future;
  }

  void flushed() {
    if (_flushes.isNotEmpty) _flushes.removeAt(0).complete();
  }

  void closedBelow() {
    _closed = true;
    for (final pending in _flushes) {
      pending.completeError(const LinkNotConnectedException());
    }
    _flushes.clear();
  }

  @override
  void close() {
    if (_closed) return;
    _closed = true;
    _service._isolatePort?.send({'type': 'close', 'id': _id});
  }
}

class _MpcEndpoint implements LinkEndpoint {
  _MpcEndpoint(this._mpc);

  final CommunicationService _mpc;
  bool _closed = false;

  @override
  Future<void> sendBody(Uint8List body) async {
    for (final piece in MpcFramer.split(body)) {
      if (_closed) throw const LinkNotConnectedException();
      await _mpc.send(piece);
    }
  }

  @override
  void close() {
    _closed = true;
  }
}
