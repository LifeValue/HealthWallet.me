import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/features/desktop/communication/data/services/link_protocol.dart';
import 'package:health_wallet/features/desktop/communication/data/services/tcp_service.dart';
import 'package:health_wallet/features/desktop/communication/data/services/transport/communication_service.dart';

import '../../../desktop_test_fakes.dart';

const _fast = LinkTimings(
  handshake: Duration(milliseconds: 800),
  approval: Duration(seconds: 5),
  pingInterval: Duration(milliseconds: 100),
  clientIdle: Duration(seconds: 2),
  serverIdle: Duration(seconds: 2),
);

/// [_fast] without the idle limits, for tests about what arrives rather than
/// liveness: both ends share one isolate here, so sealing and opening a few
/// megabytes stops both from hearing anything for longer than [_fast] allows
/// on a slow runner.
const _noIdle = LinkTimings(
  handshake: Duration(milliseconds: 800),
  approval: Duration(seconds: 5),
  pingInterval: Duration(milliseconds: 100),
  clientIdle: Duration(minutes: 1),
  serverIdle: Duration(minutes: 1),
);

const desktopId = 'desktop-1';
const phoneId = 'phone-1';

/// One end of an in-memory MPC session; [link] connects two of them.
class _FakeMpc implements CommunicationService {
  final _states = StreamController<CommunicationState>.broadcast();
  final _data = StreamController<Uint8List>.broadcast();
  _FakeMpc? peer;
  CommunicationState _state = CommunicationState.disconnected;
  int disconnects = 0;
  final sent = <Uint8List>[];

  static void link(_FakeMpc a, _FakeMpc b) {
    a.peer = b;
    b.peer = a;
    a._set(CommunicationState.connected);
    b._set(CommunicationState.connected);
  }

  void _set(CommunicationState state) {
    _state = state;
    _states.add(state);
  }

  void drop() {
    _set(CommunicationState.disconnected);
    peer?._set(CommunicationState.disconnected);
  }

  @override
  TransportType get transportType => TransportType.multipeerConnectivity;
  @override
  CommunicationState get currentState => _state;
  @override
  Stream<CommunicationState> get stateStream => _states.stream;
  @override
  Stream<Uint8List> get dataStream => _data.stream;

  @override
  Future<void> send(Uint8List data) async {
    if (_state != CommunicationState.connected) {
      throw StateError('not connected');
    }
    sent.add(data);
    final target = peer;
    // Delivered asynchronously, in order, like MPC's reliable mode.
    scheduleMicrotask(() => target?._data.add(Uint8List.fromList(data)));
  }

  @override
  Future<void> disconnect() async {
    disconnects++;
    if (_state == CommunicationState.connected) drop();
  }

  @override
  Future<void> startServer({required int port, String? token}) async {}
  @override
  Future<void> connect({
    required String address,
    required int port,
    String? token,
  }) async {}
  @override
  Future<void> dispose() async {
    await _states.close();
    await _data.close();
  }
}

Future<void> until(bool Function() condition, {String? reason}) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('timed out waiting${reason == null ? '' : ' for $reason'}');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  final key = testPairingKey();
  final otherKey = testPairingKey(seed: 99);

  TcpService service() => TcpService()
    ..timings = _fast
    ..deviceDisplayName = 'Test device';

  group('pairing keys', () {
    test('a key must decode to exactly 32 bytes', () {
      expect(isValidPairingKey(key), isTrue);
      expect(
        isValidPairingKey(key.replaceAll('=', '')),
        isTrue,
        reason: 'padding is optional',
      );
      expect(isValidPairingKey(''), isFalse);
      expect(isValidPairingKey(base64Url.encode([1, 2, 3])), isFalse);
      expect(isValidPairingKey('not base64 !!'), isFalse);
    });

    test('the discovery token depends on the key and the desktop', () {
      final token = discoveryToken(key, desktopId);
      expect(token, discoveryToken(key, desktopId));
      expect(token, isNot(discoveryToken(otherKey, desktopId)));
      expect(token, isNot(discoveryToken(key, 'desktop-2')));
      expect(token, isNot(contains(key.substring(0, 8))));
    });
  });

  group('session frames', () {
    SessionCipher pair(bool phone) {
      final a = Uint8List.fromList(List.filled(32, 1));
      final b = Uint8List.fromList(List.filled(32, 2));
      return phone ? SessionCipher(a, b) : SessionCipher(b, a);
    }

    test('a replayed, reordered or reflected frame is rejected', () {
      final phone = pair(true);
      final desktop = pair(false);
      final first = phone.seal(MessageType.data, Uint8List.fromList([1]));
      final second = phone.seal(MessageType.data, Uint8List.fromList([2]));

      expect(() => desktop.open(second), throwsFormatException);
      expect(desktop.open(first).payload, [1]);
      expect(
        () => desktop.open(first),
        throwsFormatException,
        reason: 'replay',
      );
      expect(desktop.open(second).payload, [2]);

      final own = desktop.seal(MessageType.data, Uint8List.fromList([3]));
      expect(() => desktop.open(own), throwsA(anything), reason: 'reflection');
    });
  });

  group('phone and desktop over TCP', () {
    late TcpService desktop;
    late TcpService phone;
    late int port;

    setUp(() async {
      desktop = service()..deviceDisplayName = 'Desktop';
      phone = service()..deviceDisplayName = 'Phone';
      port = await desktop.startServer(
        pairingKeys: [key],
        deviceId: desktopId,
        deviceName: 'Desktop',
        pairedPeerId: phoneId,
        port: 0,
      );
    });

    tearDown(() async {
      phone.dispose();
      await desktop.stopServer();
      desktop.dispose();
    });

    Future<void> connect(TcpService client, {String id = phoneId, String? k}) =>
        client.connectToServer(
          ip: '127.0.0.1',
          port: port,
          pairingKey: k ?? key,
          expectedDeviceId: desktopId,
          localDeviceId: id,
        );

    test('both report connected only after the handshake, with each '
        "other's identity", () async {
      await connect(phone);
      await until(() => desktop.isConnected, reason: 'desktop');
      expect(phone.isConnected, isTrue);
      expect(phone.peer?.deviceId, desktopId);
      expect(phone.peer?.name, 'Desktop');
      expect(desktop.peer?.deviceId, phoneId);
      expect(desktop.peer?.name, 'Phone');
    });

    test('carries data both ways, whole and in order', () async {
      final atDesktop = <String>[];
      final atPhone = <String>[];
      desktop.messages.listen((m) => atDesktop.add(m.payloadString));
      phone.messages.listen((m) => atPhone.add(m.payloadString));
      desktop.timings = _noIdle;
      phone.timings = _noIdle;
      await connect(phone);
      await until(() => desktop.isConnected);

      final big = 'x' * (3 * 1024 * 1024);
      await phone.sendData('a', {'n': 1});
      await phone.sendData('b', {'big': big});
      await desktop.sendData('c', {'n': 3});

      await until(() => atDesktop.length == 2 && atPhone.length == 1);
      expect(jsonDecode(atDesktop[0])['type'], 'a');
      expect(jsonDecode(atDesktop[1])['payload']['big'], big);
      expect(jsonDecode(atPhone[0])['type'], 'c');
    });

    test('sending without a verified link throws instead of dropping the '
        'data', () async {
      await expectLater(
        phone.sendData('sync.batch', {}),
        throwsA(isA<LinkNotConnectedException>()),
      );
      await connect(phone);
      await until(() => desktop.isConnected);
      await desktop.stopServer();
      await until(() => !phone.isConnected);
      await expectLater(
        phone.sendData('sync.batch', {}),
        throwsA(isA<LinkNotConnectedException>()),
      );
    });

    test(
      'a listener that never answers is not reported as connected',
      () async {
        final silent = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
        silent.listen((_) {});
        final states = <ConnectionState>[];
        phone.connectionState.listen(states.add);

        await expectLater(
          phone.connectToServer(
            ip: '127.0.0.1',
            port: silent.port,
            pairingKey: key,
            expectedDeviceId: desktopId,
            localDeviceId: phoneId,
          ),
          throwsA(isA<LinkException>()),
        );
        expect(states, isNot(contains(ConnectionState.connected)));
        expect(phone.isConnected, isFalse);
        await silent.close();
      },
    );

    test('another desktop holding the key is refused by the phone', () async {
      final other = service();
      final otherPort = await other.startServer(
        pairingKeys: [key],
        deviceId: 'desktop-2',
        deviceName: 'Other',
        pairedPeerId: phoneId,
        port: 0,
      );
      await expectLater(
        phone.connectToServer(
          ip: '127.0.0.1',
          port: otherPort,
          pairingKey: key,
          expectedDeviceId: desktopId,
          localDeviceId: phoneId,
        ),
        throwsA(
          isA<LinkException>().having(
            (e) => e.failure,
            'failure',
            LinkFailure.wrongDesktop,
          ),
        ),
      );
      await other.stopServer();
      other.dispose();
    });

    test('a phone with a key the desktop no longer has is told so', () async {
      await expectLater(
        connect(phone, k: otherKey),
        throwsA(
          isA<LinkException>().having(
            (e) => e.failure,
            'failure',
            LinkFailure.unknownKey,
          ),
        ),
      );
      expect(desktop.isConnected, isFalse);
    });

    test('a phone reconnecting while its old socket is half open takes '
        'over', () async {
      // The old connection: a socket that accepted but went silent, as one
      // left behind by a Wi-Fi drop.
      final stale = await Socket.connect('127.0.0.1', port);
      await connect(phone);
      await until(() => desktop.isConnected);
      expect(desktop.peer?.deviceId, phoneId);

      // And a second phone session after a drop replaces the first.
      final again = service();
      await connect(again);
      await until(() => !phone.isConnected, reason: 'old session closed');
      expect(again.isConnected, isTrue);
      expect(desktop.isConnected, isTrue);
      stale.destroy();
      again.dispose();
    });

    test('a socket that never finishes the handshake is dropped', () async {
      final raw = await Socket.connect('127.0.0.1', port);
      final closed = Completer<void>();
      raw.listen((_) {}, onDone: closed.complete, onError: (_) {});
      // A recorded hello replayed: the desktop answers, but without the key
      // nothing can confirm it.
      raw.add(
        FrameReader.frame(
          sealHandshake(decodePairingKey(key), MessageType.hello, {
            'v': protocolVersion,
            'id': phoneId,
            'name': 'Replayed',
            'cn': base64Url.encode(List.filled(16, 7)),
          }),
        ),
      );
      await closed.future.timeout(const Duration(seconds: 3));
      expect(desktop.isConnected, isFalse);
      raw.destroy();
    });

    test('a frame announced over 64 KiB before the handshake drops the '
        'socket', () async {
      final raw = await Socket.connect('127.0.0.1', port);
      final closed = Completer<void>();
      raw.listen((_) {}, onDone: closed.complete, onError: (_) {});
      final header = Uint8List(4);
      ByteData.sublistView(header).setUint32(0, 70 * 1024);
      raw.add(header);
      await closed.future.timeout(const Duration(seconds: 3));
      raw.destroy();
    });

    test('an older phone app is reported to the desktop', () async {
      final failures = <LinkFailure>[];
      desktop.serverFailures.listen(failures.add);
      final raw = await Socket.connect('127.0.0.1', port);
      raw.listen((_) {}, onError: (_) {});
      // The v1 hello: [nonce][ciphertext], no kind byte.
      raw.add(FrameReader.frame(Uint8List.fromList(List.filled(60, 0x5a))));
      await until(() => failures.isNotEmpty);
      expect(failures.single, LinkFailure.version);
      raw.destroy();
    });

    test('a phone that stops talking is dropped, a busy link is not', () async {
      await connect(phone);
      await until(() => desktop.isConnected);
      // Pings every 100 ms keep it up well past the 2 s idle limit.
      await Future<void>.delayed(const Duration(milliseconds: 3000));
      expect(desktop.isConnected, isTrue);
      expect(phone.isConnected, isTrue);
    });

    test('disconnect tells the desktop at once', () async {
      await connect(phone);
      await until(() => desktop.isConnected);
      await phone.disconnect();
      await until(() => !desktop.isConnected);
    });

    test('the port is free again after stopServer', () async {
      final fixed = service();
      final first = await fixed.startServer(
        pairingKeys: [key],
        deviceId: desktopId,
        deviceName: 'Desktop',
        pairedPeerId: null,
        port: 0,
      );
      await fixed.stopServer();
      final second = await fixed.startServer(
        pairingKeys: [key],
        deviceId: desktopId,
        deviceName: 'Desktop',
        pairedPeerId: null,
        port: first,
      );
      expect(second, first);
      await fixed.stopServer();
      fixed.dispose();
    });
  });

  group('pairing a phone', () {
    late TcpService desktop;
    late int port;

    Future<int> start(String? paired) => desktop.startServer(
      pairingKeys: [key],
      deviceId: desktopId,
      deviceName: 'Desktop',
      pairedPeerId: paired,
      port: 0,
    );

    setUp(() => desktop = service());
    tearDown(() async {
      await desktop.stopServer();
      desktop.dispose();
    });

    Future<void> connect(TcpService phone, String id) => phone.connectToServer(
      ip: '127.0.0.1',
      port: port,
      pairingKey: key,
      expectedDeviceId: desktopId,
      localDeviceId: id,
    );

    test('the first phone is accepted and becomes the paired one', () async {
      port = await start(null);
      final approved = <PeerInfo>[];
      desktop.peerApproved.listen(approved.add);
      final phone = service();
      await connect(phone, 'phone-A');
      await until(() => desktop.isConnected);
      expect(approved.single.deviceId, 'phone-A');
      phone.dispose();
    });

    test(
      'another phone waits for the desktop user, who can accept it',
      () async {
        port = await start('phone-A');
        final requests = <PendingApproval?>[];
        final approved = <PeerInfo>[];
        desktop.approvalRequests.listen(requests.add);
        desktop.peerApproved.listen(approved.add);

        final phone = service();
        await connect(phone, 'phone-B');
        expect(phone.currentState, ConnectionState.awaitingApproval);
        expect(phone.isConnected, isFalse);
        await until(() => requests.isNotEmpty);
        expect(requests.single?.peer.deviceId, 'phone-B');
        expect(desktop.isConnected, isFalse);
        await expectLater(
          phone.sendData('sync.batch', {}),
          throwsA(isA<LinkNotConnectedException>()),
          reason: 'nothing syncs before the user accepts',
        );

        desktop.approvePending();
        await until(() => phone.isConnected && desktop.isConnected);
        expect(approved.single.deviceId, 'phone-B');
        phone.dispose();
      },
    );

    test('a declined phone is told so', () async {
      port = await start('phone-A');
      final phone = service();
      final failures = <LinkFailure?>[];
      phone.connectionState.listen((_) {});
      await connect(phone, 'phone-B');
      await until(() => desktop.pendingApproval != null);
      desktop.declinePending();
      await until(() => phone.currentState == ConnectionState.disconnected);
      expect(desktop.isConnected, isFalse);
      expect(failures, isEmpty);
      phone.dispose();
    });

    test('while the desktop moves to a new key, both keys are accepted '
        'and the one used is reported', () async {
      port = await desktop.startServer(
        pairingKeys: [key, otherKey],
        deviceId: desktopId,
        deviceName: 'Desktop',
        pairedPeerId: phoneId,
        port: 0,
      );
      final phone = service();
      await phone.connectToServer(
        ip: '127.0.0.1',
        port: port,
        pairingKey: otherKey,
        expectedDeviceId: desktopId,
        localDeviceId: phoneId,
      );
      await until(() => desktop.isConnected);
      expect(desktop.activeKeyIndex, 1);
      phone.dispose();
    });
  });

  group('MPC', () {
    late TcpService desktop;
    late TcpService phone;
    late _FakeMpc desktopMpc;
    late _FakeMpc phoneMpc;

    setUp(() async {
      desktop = service();
      phone = service();
      desktopMpc = _FakeMpc();
      phoneMpc = _FakeMpc();
      await desktop.startServer(
        pairingKeys: [key],
        deviceId: desktopId,
        deviceName: 'Desktop',
        pairedPeerId: phoneId,
        port: 0,
      );
      desktop.attachMpc(desktopMpc, asServer: true);
      phone.attachMpc(phoneMpc, asServer: false);
    });

    tearDown(() async {
      phone.dispose();
      await desktop.stopServer();
      desktop.dispose();
    });

    Future<void> connectPhone() {
      final done = phone.connectOverMpc(
        pairingKey: key,
        expectedDeviceId: desktopId,
        localDeviceId: phoneId,
      );
      _FakeMpc.link(phoneMpc, desktopMpc);
      return done;
    }

    test(
      'runs the same handshake and carries large messages in pieces',
      () async {
        final atDesktop = <String>[];
        desktop.messages.listen((m) => atDesktop.add(m.payloadString));
        desktop.timings = _noIdle;
        phone.timings = _noIdle;
        await connectPhone();
        await until(() => desktop.isConnected);
        expect(desktop.transport, LinkTransport.mpc);

        final big = 'y' * 300000;
        await phone.sendData('big', {'v': big});
        await until(() => atDesktop.isNotEmpty);
        expect(jsonDecode(atDesktop.single)['payload']['v'], big);
        expect(
          phoneMpc.sent.every(
            (piece) => piece.length <= MpcFramer.pieceSize + 1,
          ),
          isTrue,
        );
      },
    );

    test('a nearby device without the key can neither connect nor take the '
        "desktop's traffic", () async {
      final tcpPhone = service();
      final port = await desktop.startServer(
        pairingKeys: [key],
        deviceId: desktopId,
        deviceName: 'Desktop',
        pairedPeerId: phoneId,
        port: 0,
      );
      desktop.attachMpc(desktopMpc, asServer: true);
      await tcpPhone.connectToServer(
        ip: '127.0.0.1',
        port: port,
        pairingKey: key,
        expectedDeviceId: desktopId,
        localDeviceId: phoneId,
      );
      await until(() => desktop.isConnected);

      final stranger = service();
      final strangerMpc = _FakeMpc();
      stranger.attachMpc(strangerMpc, asServer: false);
      final attempt = stranger.connectOverMpc(
        pairingKey: otherKey,
        expectedDeviceId: desktopId,
        localDeviceId: 'stranger',
      );
      _FakeMpc.link(strangerMpc, desktopMpc);
      await expectLater(attempt, throwsA(isA<LinkException>()));

      expect(desktop.isConnected, isTrue);
      expect(desktop.transport, LinkTransport.tcp);
      expect(desktop.peer?.deviceId, phoneId);
      tcpPhone.dispose();
      stranger.dispose();
    });

    test('when MPC drops, both sides report the link down', () async {
      await connectPhone();
      await until(() => desktop.isConnected);
      phoneMpc.drop();
      await until(() => !desktop.isConnected && !phone.isConnected);
      await expectLater(
        desktop.sendData('sync.batch', {}),
        throwsA(isA<LinkNotConnectedException>()),
      );
    });

    test(
      'a phone with a working TCP link drops a late MPC connection',
      () async {
        final port = await desktop.startServer(
          pairingKeys: [key],
          deviceId: desktopId,
          deviceName: 'Desktop',
          pairedPeerId: phoneId,
          port: 0,
        );
        desktop.attachMpc(desktopMpc, asServer: true);
        await phone.connectToServer(
          ip: '127.0.0.1',
          port: port,
          pairingKey: key,
          expectedDeviceId: desktopId,
          localDeviceId: phoneId,
        );
        await until(() => desktop.isConnected);

        _FakeMpc.link(phoneMpc, desktopMpc);
        await until(() => phoneMpc.disconnects > 0);
        expect(phone.transport, LinkTransport.tcp);
        expect(desktop.transport, LinkTransport.tcp);
      },
    );
  });
}
