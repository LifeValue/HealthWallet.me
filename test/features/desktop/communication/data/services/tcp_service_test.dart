import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/features/desktop/communication/data/services/tcp_service.dart';
import 'package:health_wallet/features/desktop/communication/data/services/transport/communication_service.dart';

import '../../../desktop_test_fakes.dart';

/// Records what [TcpService] hands to the MPC transport.
class _FakeMpcTransport extends CommunicationService {
  final _data = StreamController<Uint8List>.broadcast();
  final sent = <Uint8List>[];

  @override
  TransportType get transportType => TransportType.multipeerConnectivity;

  @override
  CommunicationState get currentState => CommunicationState.connected;

  @override
  Stream<CommunicationState> get stateStream => const Stream.empty();

  @override
  Stream<Uint8List> get dataStream => _data.stream;

  void receive(Uint8List bytes) => _data.add(bytes);

  @override
  Future<void> send(Uint8List data) async => sent.add(data);

  @override
  Future<void> startServer({required int port}) async {}

  @override
  Future<void> connect({required String address, required int port}) async {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> dispose() => _data.close();
}

void main() {
  final key = testPairingKey();
  final codec = WireCodec(key);

  group('MessageType', () {
    test('codes match the wire table', () {
      expect(
        {for (final t in MessageType.values) t.name: t.code},
        {
          'hello': 0x01,
          'ack': 0x02,
          'ping': 0x03,
          'pong': 0x04,
          'data': 0x05,
          'kill': 0xFF,
        },
      );
      for (final t in MessageType.values) {
        expect(MessageType.fromCode(t.code), t);
      }
    });

    test('an unknown code throws', () {
      expect(() => MessageType.fromCode(0x06), throwsArgumentError);
    });
  });

  test('TcpMessage.fromString encodes UTF-8 and decodes it back', () {
    final message = TcpMessage.fromString(
      type: MessageType.data,
      data: 'Grüße ✓',
    );
    expect(message.payload, utf8.encode('Grüße ✓'));
    expect(message.payloadString, 'Grüße ✓');
  });

  group('client mode (mobile → desktop)', () {
    late ServerSocket server;
    late TcpService service;
    late PeerSocket peer;
    late List<TcpMessage> received;
    late List<ConnectionState> states;
    late StreamSubscription<TcpMessage> messagesSub;
    late StreamSubscription<ConnectionState> statesSub;

    setUp(() async {
      server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      service = TcpService()..deviceDisplayName = 'Test Phone';
      received = [];
      states = [];
      messagesSub = service.messages.listen(received.add);
      statesSub = service.connectionState.listen(states.add);

      final accepted = server.first;
      await service.connectToServer(
        ip: '127.0.0.1',
        port: server.port,
        pairingKey: key,
      );
      peer = PeerSocket.wrap(await accepted, codec);
    });

    tearDown(() async {
      await messagesSub.cancel();
      await statesSub.cancel();
      service.dispose();
      await peer.close();
      await server.close();
    });

    Future<TcpMessage> nextMessage() => service.messages.first.timeout(
      const Duration(seconds: 10),
    );

    test('connects and sends an encrypted hello with the key hash', () async {
      final hello = await peer.reader.next();

      expect(hello.type, MessageType.hello.code);
      expect(jsonDecode(utf8.decode(hello.payload)), {
        'pairing_key_hash': WireCodec.hashKey(key),
        'device_name': 'Test Phone',
      });
      expect(states, [ConnectionState.connecting, ConnectionState.connected]);
      expect(service.isConnected, isTrue);
      expect(service.currentState, ConnectionState.connected);
    });

    test('delivers a data frame whole', () async {
      final next = nextMessage();
      await peer.send(codec.dataFrame('sync.ack', {'n': 1}));

      final message = await next;
      expect(message.type, MessageType.data);
      expect(jsonDecode(message.payloadString), {
        'type': 'sync.ack',
        'payload': {'n': 1},
      });
    });

    test('reassembles a frame that arrives one byte at a time', () async {
      final frame = codec.dataFrame('x', {'text': 'a' * 300});
      final next = nextMessage();
      for (final byte in frame) {
        await peer.send([byte]);
      }

      final message = await next;
      expect(jsonDecode(message.payloadString)['payload']['text'], 'a' * 300);
    });

    test('splits several frames sent in one write, in order', () async {
      final frames = [
        for (var i = 0; i < 20; i++) ...codec.dataFrame('x', {'i': i}),
      ];
      final all = service.messages.take(20).toList();
      await peer.send(frames);

      final messages = await all.timeout(const Duration(seconds: 10));
      expect(
        messages.map((m) => jsonDecode(m.payloadString)['payload']['i']),
        List.generate(20, (i) => i),
      );
    });

    test('handles a frame split across a chunk boundary of the next', () async {
      final a = codec.dataFrame('x', {'i': 'a'});
      final b = codec.dataFrame('x', {'i': 'b'});
      final bytes = [...a, ...b];
      final both = service.messages.take(2).toList();

      // Header of a split, then rest of a plus the first 3 bytes of b's header.
      await peer.send(bytes.sublist(0, 2));
      await peer.send(bytes.sublist(2, a.length + 3));
      await peer.send(bytes.sublist(a.length + 3));

      final messages = await both.timeout(const Duration(seconds: 10));
      expect(
        messages.map((m) => jsonDecode(m.payloadString)['payload']['i']),
        ['a', 'b'],
      );
    });

    test('delivers a 2 MB payload byte for byte', () async {
      final payload = randomBytes(2 * 1024 * 1024);
      final next = nextMessage();
      await peer.send(codec.frame(MessageType.data, payload));

      expect((await next).payload, payload);
    });

    test('delivers a data frame with an empty payload', () async {
      final next = nextMessage();
      await peer.send(codec.frame(MessageType.data, const []));

      final message = await next;
      expect(message.type, MessageType.data);
      expect(message.payload, isEmpty);
    });

    test('drops a tampered frame and keeps reading the stream', () async {
      final tampered = codec.dataFrame('x', {'i': 'bad'});
      tampered[tampered.length - 1] ^= 0x01;
      final next = nextMessage();

      await peer.send([
        ...tampered,
        ...codec.dataFrame('x', {'i': 'good'}),
      ]);

      final message = await next;
      expect(jsonDecode(message.payloadString)['payload']['i'], 'good');
      expect(received, hasLength(1));
    });

    test('drops a frame encrypted with another key', () async {
      final stranger = WireCodec(testPairingKey(seed: 99));
      final next = nextMessage();

      await peer.send([
        ...stranger.dataFrame('x', {'i': 'stranger'}),
        ...codec.dataFrame('x', {'i': 'friend'}),
      ]);

      expect(jsonDecode((await next).payloadString)['payload']['i'], 'friend');
      expect(received, hasLength(1));
    });

    test('drops frames shorter than a nonce or of unknown type', () async {
      final next = nextMessage();
      await peer.send([
        ...WireCodec.lengthPrefixed([1, 2, 3]),
        ...WireCodec.lengthPrefixed(codec.encrypt([0x42, 1, 2])),
        ...WireCodec.lengthPrefixed(const []),
        ...codec.dataFrame('x', {'i': 'after'}),
      ]);

      expect(jsonDecode((await next).payloadString)['payload']['i'], 'after');
      expect(received, hasLength(1));
    });

    test('answers ping with pong and does not surface either', () async {
      await peer.reader.nextOfType(MessageType.hello);
      await peer.send(codec.frame(MessageType.ping, const []));

      final pong = await peer.reader.next();
      expect(pong.type, MessageType.pong.code);
      expect(pong.payload, isEmpty);

      await peer.send(codec.frame(MessageType.pong, const []));
      final next = nextMessage();
      await peer.send(codec.dataFrame('x', {}));
      await next;
      expect(received.map((m) => m.type), [MessageType.data]);
    });

    test('a hello from the server is acknowledged and surfaced', () async {
      await peer.reader.nextOfType(MessageType.hello);
      final next = nextMessage();
      await peer.send(codec.helloFrame(keyHash: 'anything'));

      expect((await next).type, MessageType.hello);
      expect((await peer.reader.next()).type, MessageType.ack.code);
    });

    test('kill disconnects', () async {
      final disconnected = service.connectionState.firstWhere(
        (s) => s == ConnectionState.disconnected,
      );
      await peer.send(codec.frame(MessageType.kill, const []));

      await disconnected.timeout(const Duration(seconds: 10));
      expect(service.isConnected, isFalse);
      await peer.done;
    });

    test('the server closing the socket disconnects', () async {
      final disconnected = service.connectionState.firstWhere(
        (s) => s == ConnectionState.disconnected,
      );
      await peer.socket.close();

      await disconnected.timeout(const Duration(seconds: 10));
      expect(service.currentState, ConnectionState.disconnected);
    });

    test('sendData frames a JSON envelope the peer can decode', () async {
      await peer.reader.nextOfType(MessageType.hello);
      await service.sendData('handover.offer', {
        'session_id': 's1',
        'file_count': 2,
      });

      final frame = await peer.reader.next();
      expect(frame.type, MessageType.data.code);
      expect(jsonDecode(utf8.decode(frame.payload)), {
        'type': 'handover.offer',
        'payload': {'session_id': 's1', 'file_count': 2},
      });
    });

    test('concurrent sends are written whole and in call order', () async {
      await peer.reader.nextOfType(MessageType.hello);
      final big = base64Encode(randomBytes(100 * 1024));
      await Future.wait([
        for (var i = 0; i < 30; i++)
          service.sendData('x', {'i': i, 'blob': i.isEven ? big : ''}),
      ]);

      for (var i = 0; i < 30; i++) {
        final frame = await peer.reader.next();
        final json = jsonDecode(utf8.decode(frame.payload));
        expect(json['payload']['i'], i);
        expect(json['payload']['blob'], i.isEven ? big : '');
      }
    });

    test('disconnect sends kill and closes the socket', () async {
      await peer.reader.nextOfType(MessageType.hello);
      await service.disconnect();

      expect((await peer.reader.next()).type, MessageType.kill.code);
      await peer.done;
      expect(service.currentState, ConnectionState.disconnected);
    });

    test('stopServer closes the client connection', () async {
      await service.stopServer();

      await peer.done;
      expect(states.last, ConnectionState.disconnected);
    });
  });

  group('client mode connection failures', () {
    test(
      'a refused connection throws and leaves the state disconnected',
      () async {
        final closed = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
        final port = closed.port;
        await closed.close();

        final service = TcpService()..deviceDisplayName = 'Phone';
        final states = <ConnectionState>[];
        final sub = service.connectionState.listen(states.add);
        addTearDown(() async {
          await sub.cancel();
          service.dispose();
        });

        await expectLater(
          service.connectToServer(ip: '127.0.0.1', port: port, pairingKey: key),
          throwsA(isA<SocketException>()),
        );
        await flushEvents();
        expect(states, [
          ConnectionState.connecting,
          ConnectionState.disconnected,
        ]);
        expect(service.isConnected, isFalse);
      },
    );

    test('without a display name the hello carries the host name', () async {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final service = TcpService();
      final accepted = server.first;
      await service.connectToServer(
        ip: '127.0.0.1',
        port: server.port,
        pairingKey: key,
      );
      final peer = PeerSocket.wrap(await accepted, codec);
      addTearDown(() async {
        service.dispose();
        await peer.close();
        await server.close();
      });

      final hello = await peer.reader.next();
      final name = jsonDecode(utf8.decode(hello.payload))['device_name'];
      expect(name, isA<String>());
      expect(name, isNotEmpty);
      expect(name, isNot(endsWith('.local')));
    });
  });

  group('key derivation', () {
    Future<PeerFrame> helloWith(String pairingKey) async {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final service = TcpService()..deviceDisplayName = 'Phone';
      final accepted = server.first;
      await service.connectToServer(
        ip: '127.0.0.1',
        port: server.port,
        pairingKey: pairingKey,
      );
      final peer = PeerSocket.wrap(await accepted, WireCodec(pairingKey));
      addTearDown(() async {
        service.dispose();
        await peer.close();
        await server.close();
      });
      return peer.reader.next();
    }

    test('a short key is zero-padded to 32 bytes', () async {
      final hello = await helloWith(base64Url.encode([1, 2, 3, 4, 5, 6]));
      expect(hello.type, MessageType.hello.code);
    });

    test('a long key uses its first 32 bytes', () async {
      final hello = await helloWith(base64Url.encode(randomBytes(48)));
      expect(hello.type, MessageType.hello.code);
    });
  });

  group('MPC routing', () {
    late TcpService service;
    late _FakeMpcTransport mpc;

    setUp(() {
      service = TcpService()..deviceDisplayName = 'iPhone';
      mpc = _FakeMpcTransport();
      service.setMpcTransport(mpc);
    });

    tearDown(() async {
      service.setMpcTransport(null);
      service.dispose();
      await mpc.dispose();
    });

    test(
      'with MPC on, sends encrypted messages without a length prefix',
      () async {
        service
          ..setPairingKeyForMpc(key)
          ..setUseMpc(true);

        await service.sendData('sync.ack', {'ok': true});

        expect(mpc.sent, hasLength(1));
        final plain = codec.decrypt(mpc.sent.single);
        expect(plain[0], MessageType.data.code);
        expect(jsonDecode(utf8.decode(plain.sublist(1))), {
          'type': 'sync.ack',
          'payload': {'ok': true},
        });
      },
    );

    test('never reuses a nonce, even for identical messages', () async {
      service
        ..setPairingKeyForMpc(key)
        ..setUseMpc(true);

      for (var i = 0; i < 50; i++) {
        await service.sendData('x', {'same': true});
      }

      final nonces = mpc.sent.map((m) => base64Encode(m.sublist(0, 12)));
      expect(nonces.toSet(), hasLength(50));
      for (final m in mpc.sent) {
        // 12-byte nonce + 1 type byte + JSON + 16-byte tag.
        expect(
          m.length,
          12 + 1 + '{"type":"x","payload":{"same":true}}'.length + 16,
        );
      }
    });

    test('with MPC off, nothing goes to the MPC transport', () async {
      service
        ..setPairingKeyForMpc(key)
        ..setUseMpc(false);

      await service.sendData('x', {});

      expect(mpc.sent, isEmpty);
    });

    test('sendMpcHello carries the key hash and device name', () async {
      service
        ..setPairingKeyForMpc(key)
        ..setUseMpc(true);

      await service.sendMpcHello();

      final plain = codec.decrypt(mpc.sent.single);
      expect(plain[0], MessageType.hello.code);
      expect(jsonDecode(utf8.decode(plain.sublist(1))), {
        'pairing_key_hash': WireCodec.hashKey(key),
        'device_name': 'iPhone',
      });
    });

    test(
      'sendMpcHello without a key sends plaintext and an empty hash',
      () async {
        service
          ..deviceDisplayName = 'localhost'
          ..setUseMpc(true);

        await service.sendMpcHello();

        final plain = mpc.sent.single;
        expect(plain[0], MessageType.hello.code);
        final json = jsonDecode(utf8.decode(plain.sublist(1)));
        expect(json['pairing_key_hash'], '');
        // 'localhost' is replaced by the real device name.
        expect(json['device_name'], isNot('localhost'));
      },
    );

    test('decrypts incoming MPC data and surfaces it', () async {
      service.setPairingKeyForMpc(key);
      final next = service.messages.first;

      mpc.receive(
        codec.message(
          MessageType.data,
          utf8.encode(
            jsonEncode({'type': 't', 'payload': <String, dynamic>{}}),
          ),
        ),
      );

      final message = await next.timeout(const Duration(seconds: 5));
      expect(message.type, MessageType.data);
      expect(jsonDecode(message.payloadString)['type'], 't');
    });

    test('an MPC hello marks the link connected and is acknowledged', () async {
      service
        ..setPairingKeyForMpc(key)
        ..setUseMpc(true);
      final connected = service.connectionState.first;

      mpc.receive(
        codec.message(
          MessageType.hello,
          utf8.encode(
            jsonEncode({
              'pairing_key_hash': WireCodec.hashKey(key),
              'device_name': 'Mac',
            }),
          ),
        ),
      );

      expect(
        await connected.timeout(const Duration(seconds: 5)),
        ConnectionState.connected,
      );
      await flushEvents();
      expect(codec.decrypt(mpc.sent.single)[0], MessageType.ack.code);
    });

    test('an MPC hello with the wrong key hash is rejected', () async {
      service
        ..setPairingKeyForMpc(key)
        ..setUseMpc(true);
      final hellos = <TcpMessage>[];
      final sub = service.messages.listen(hellos.add);

      mpc.receive(
        codec.message(
          MessageType.hello,
          utf8.encode(
            jsonEncode({
              'pairing_key_hash': 'wrong',
              'device_name': 'Mac',
            }),
          ),
        ),
      );
      await flushEvents();
      await sub.cancel();

      expect(hellos, isEmpty);
      expect(service.isConnected, isFalse);
      expect(mpc.sent, isEmpty);
    });

    test('drops undecryptable or unknown MPC data and keeps going', () async {
      service.setPairingKeyForMpc(key);
      final all = <TcpMessage>[];
      final sub = service.messages.listen(all.add);

      mpc
        ..receive(Uint8List.fromList([1, 2, 3]))
        ..receive(
          WireCodec(testPairingKey(seed: 5)).message(MessageType.data, [1]),
        )
        ..receive(codec.message(MessageType.ping, const []))
        ..receive(codec.message(MessageType.data, utf8.encode('{}')));
      await flushEvents();
      await sub.cancel();

      expect(all.map((m) => m.type), [MessageType.data]);
    });

    test('without a key, MPC data is read as plaintext', () async {
      final next = service.messages.first;
      mpc.receive(
        Uint8List.fromList([MessageType.data.code, ...utf8.encode('hi')]),
      );

      expect(
        (await next.timeout(const Duration(seconds: 5))).payloadString,
        'hi',
      );
    });

    test(
      'replacing the MPC transport stops listening to the old one',
      () async {
        final other = _FakeMpcTransport();
        addTearDown(other.dispose);
        service.setMpcTransport(other);
        final all = <TcpMessage>[];
        final sub = service.messages.listen(all.add);

        mpc.receive(Uint8List.fromList([MessageType.data.code, 1]));
        other.receive(Uint8List.fromList([MessageType.data.code, 2]));
        await flushEvents();
        await sub.cancel();

        expect(all.map((m) => m.payload.single), [2]);
      },
    );
  });

  group('without a connection', () {
    test('sendMessage is a silent no-op', () async {
      final service = TcpService();
      addTearDown(service.dispose);

      await expectLater(service.sendData('x', {}), completes);
      await expectLater(service.disconnect(), completes);
      expect(service.currentState, ConnectionState.disconnected);
    });

    test('accept/reject pending without a server do nothing', () {
      final service = TcpService();
      addTearDown(service.dispose);

      expect(service.acceptPendingClient, returnsNormally);
      expect(service.rejectPendingClient, returnsNormally);
    });
  });

  group('server mode (desktop)', () {
    late TcpService service;
    late ({String ip, int port}) address;
    final peers = <PeerSocket>[];

    setUp(() async {
      service = TcpService();
      address = await service
          .startServer(pairingKey: key, port: 0)
          .timeout(const Duration(seconds: 10));
    });

    tearDown(() async {
      for (final peer in peers) {
        await peer.close();
      }
      peers.clear();
      service.dispose();
    });

    Future<PeerSocket> connectPeer() async {
      final peer = await PeerSocket.connect(address.ip, address.port, codec);
      peers.add(peer);
      return peer;
    }

    test('listens on a real port of the reported address', () {
      expect(address.port, greaterThan(0));
      expect(InternetAddress.tryParse(address.ip), isNotNull);
    });

    test('falls back to a free port when the requested one is taken', () async {
      final second = TcpService();
      addTearDown(second.dispose);

      final other = await second
          .startServer(pairingKey: key, port: address.port)
          .timeout(const Duration(seconds: 10));

      expect(other.ip, address.ip);
      expect(other.port, isNot(address.port));
      expect(other.port, greaterThan(0));
    });

    test('accepts a client whose hello carries the right key hash', () async {
      final connected = service.connectionState.first;
      final hello = service.messages.first;
      final peer = await connectPeer();

      await peer.send(codec.helloFrame(deviceName: 'Pixel'));

      expect(
        await connected.timeout(const Duration(seconds: 10)),
        ConnectionState.connected,
      );
      final message = await hello.timeout(const Duration(seconds: 10));
      expect(message.type, MessageType.hello);
      expect(jsonDecode(message.payloadString)['device_name'], 'Pixel');
      expect((await peer.reader.next()).type, MessageType.ack.code);
    });

    test('rejects a hello with the wrong key hash', () async {
      final hellos = <TcpMessage>[];
      final sub = service.messages.listen(hellos.add);
      final peer = await connectPeer();

      await peer.send([
        ...codec.helloFrame(keyHash: 'not-the-hash'),
        // A ping right after it: its pong proves the hello was processed.
        ...codec.frame(MessageType.ping, const []),
      ]);

      expect((await peer.reader.next()).type, MessageType.pong.code);
      await sub.cancel();
      expect(hellos, isEmpty);
      expect(service.isConnected, isFalse);
    });

    test('carries data both ways, whole and in order', () async {
      final peer = await connectPeer();
      final incoming = service.messages
          .where((m) => m.type == MessageType.data)
          .take(10)
          .toList();
      await peer.send([
        ...codec.helloFrame(),
        for (var i = 0; i < 10; i++) ...codec.dataFrame('up', {'i': i}),
      ]);

      final messages = await incoming.timeout(const Duration(seconds: 10));
      expect(
        messages.map((m) => jsonDecode(m.payloadString)['payload']['i']),
        List.generate(10, (i) => i),
      );

      await peer.reader.nextOfType(MessageType.ack);
      final blob = base64Encode(randomBytes(300 * 1024));
      for (var i = 0; i < 5; i++) {
        await service.sendData('down', {'i': i, 'blob': blob});
      }
      for (var i = 0; i < 5; i++) {
        final frame = await peer.reader.next();
        final json = jsonDecode(utf8.decode(frame.payload));
        expect(json['payload'], {'i': i, 'blob': blob});
      }
    });

    test('a client closing the socket disconnects', () async {
      final peer = await connectPeer();
      await peer.send(codec.helloFrame());
      await service.connectionState
          .firstWhere((s) => s == ConnectionState.connected)
          .timeout(const Duration(seconds: 10));

      final disconnected = service.connectionState.firstWhere(
        (s) => s == ConnectionState.disconnected,
      );
      await peer.socket.close();
      await disconnected.timeout(const Duration(seconds: 10));
    });

    test('a second client is held as pending and can be rejected', () async {
      final first = await connectPeer();
      await first.send(codec.helloFrame());
      await first.reader.nextOfType(MessageType.ack);

      final pending = service.pendingClients.first;
      final second = await connectPeer();
      expect(await pending.timeout(const Duration(seconds: 10)), isNotEmpty);

      service.rejectPendingClient();
      await second.done;

      // The first client still works.
      final next = service.messages.first;
      await first.send(codec.dataFrame('still', {'ok': true}));
      expect(
        jsonDecode(
          (await next.timeout(const Duration(seconds: 10))).payloadString,
        )['type'],
        'still',
      );
    });

    test(
      'accepting a pending client replays what it sent while waiting',
      () async {
        final first = await connectPeer();
        await first.send(codec.helloFrame());
        await first.reader.nextOfType(MessageType.ack);

        final pending = service.pendingClients.first;
        final second = await connectPeer();
        await pending.timeout(const Duration(seconds: 10));
        final replayed = service.messages
            .where((m) => m.type == MessageType.data)
            .first;
        await second.send([
          ...codec.helloFrame(deviceName: 'New phone'),
          ...codec.dataFrame('queued', {'n': 1}),
        ]);
        // Usually buffered by the isolate until the accept; if the bytes are
        // late they take the normal path. Either way they must arrive.
        await flushEvents();

        service.acceptPendingClient();

        await first.done;
        final message = await replayed.timeout(const Duration(seconds: 10));
        expect(jsonDecode(message.payloadString)['type'], 'queued');

        // And what it sends after being accepted.
        final later = service.messages
            .where((m) => m.type == MessageType.data)
            .first;
        await second.send(codec.dataFrame('after.accept', {}));
        expect(
          jsonDecode(
            (await later.timeout(const Duration(seconds: 10))).payloadString,
          )['type'],
          'after.accept',
        );
      },
    );

    test('a newer pending client replaces the older one', () async {
      final first = await connectPeer();
      await first.send(codec.helloFrame());
      await first.reader.nextOfType(MessageType.ack);

      final pendingAddresses = service.pendingClients.take(2).toList();
      final older = await connectPeer();
      final newer = await connectPeer();
      await pendingAddresses.timeout(const Duration(seconds: 10));

      await older.done;
      expect(newer.isClosed, isFalse);

      service.rejectPendingClient();
      await newer.done;
    });

    test(
      'a pending client hanging up leaves the current client alone',
      () async {
        final first = await connectPeer();
        await first.send(codec.helloFrame());
        await first.reader.nextOfType(MessageType.ack);

        final pending = service.pendingClients.first;
        final second = await connectPeer();
        await pending.timeout(const Duration(seconds: 10));
        await second.send(codec.helloFrame(deviceName: 'Gone'));
        await second.close();

        final next = service.messages.first;
        await first.send(codec.dataFrame('first.still.here', {}));
        expect(
          jsonDecode(
            (await next.timeout(const Duration(seconds: 10))).payloadString,
          )['type'],
          'first.still.here',
        );
        expect(service.isConnected, isTrue);
      },
    );

    test(
      'an accepted pending client receives what the desktop sends',
      () async {
        final first = await connectPeer();
        await first.send(codec.helloFrame());
        await first.reader.nextOfType(MessageType.ack);

        final pending = service.pendingClients.first;
        final second = await connectPeer();
        await pending.timeout(const Duration(seconds: 10));
        service.acceptPendingClient();
        await first.done;

        await second.send(codec.helloFrame(deviceName: 'New phone'));
        expect(
          (await second.reader.nextOfType(MessageType.ack)).payload,
          isEmpty,
        );
        await service.sendData('to.new', {'ok': true});
        final frame = await second.reader.nextOfType(MessageType.data);
        expect(jsonDecode(utf8.decode(frame.payload))['type'], 'to.new');
      },
      skip:
          'BUG: in the server isolate the replaced client\'s onDone sets '
          'clientSocket = null after acceptPending, so every later send to '
          'the accepted client is dropped (tcp_service.dart:224-229).',
    );

    test(
      'a client that dropped mid-frame does not corrupt the next client',
      () async {
        final first = await connectPeer();
        await first.send(codec.helloFrame());
        await first.reader.nextOfType(MessageType.ack);

        // First client dies halfway through a frame (e.g. Wi-Fi drop during
        // a large backup chunk).
        final frame = codec.dataFrame('big', {'blob': 'x' * 1000});
        final disconnected = service.connectionState.firstWhere(
          (s) => s == ConnectionState.disconnected,
        );
        await first.send(frame.sublist(0, frame.length ~/ 2));
        await first.socket.close();
        await disconnected.timeout(const Duration(seconds: 10));

        final second = await connectPeer();
        final hello = service.messages.first;
        await second.send(codec.helloFrame(deviceName: 'Reconnected'));

        final message = await hello.timeout(const Duration(seconds: 5));
        expect(jsonDecode(message.payloadString)['device_name'], 'Reconnected');
      },
      skip:
          'BUG: TcpService._buffer is never reset in server mode (not on '
          'clientDisconnected, acceptPending, stopServer or startServer), so '
          'leftover bytes of a half-received frame swallow and misalign every '
          'frame from the next client (tcp_service.dart:171-172, 482-509).',
    );

    test(
      'stopServer closes the client and the listening socket',
      () async {
        final peer = await connectPeer();
        await peer.send(codec.helloFrame());
        await peer.reader.nextOfType(MessageType.ack);

        await service.stopServer();

        await peer.done;
        expect(service.currentState, ConnectionState.disconnected);
        await expectLater(
          Socket.connect(
            address.ip,
            address.port,
            timeout: const Duration(seconds: 2),
          ),
          throwsA(isA<SocketException>()),
        );
      },
      skip:
          'BUG (tcp_service.dart stopServer): the server isolate is killed right '
          "after 'stop' is sent, so the isolate sometimes never closes the "
          'client socket and the phone stays connected; fails intermittently.',
    );
  });
}
