import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/features/desktop/communication/data/services/ssdp_service.dart';

/// A UDP socket the test drives: datagrams it [deliver]s arrive as read
/// events, what the service sends is recorded, and sending can fail as it
/// does without a network.
class _FakeSocket extends Stream<RawSocketEvent> implements RawDatagramSocket {
  final _events = StreamController<RawSocketEvent>();
  final _inbox = <Datagram>[];
  final sent = <({String message, InternetAddress address, int port})>[];
  SocketException? sendError;
  bool closed = false;

  @override
  bool broadcastEnabled = false;

  @override
  int get port => 1900;

  @override
  void joinMulticast(InternetAddress group, [NetworkInterface? interface]) {}

  void deliver(String message, {int port = 50000}) {
    _inbox.add(
      Datagram(utf8.encode(message), InternetAddress.loopbackIPv4, port),
    );
    _events.add(RawSocketEvent.read);
  }

  void fail(Object error) => _events.addError(error);

  @override
  StreamSubscription<RawSocketEvent> listen(
    void Function(RawSocketEvent event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => _events.stream.listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );

  @override
  Datagram? receive() => _inbox.isEmpty ? null : _inbox.removeAt(0);

  @override
  int send(List<int> buffer, InternetAddress address, int port) {
    if (sendError != null) throw sendError!;
    sent.add((message: utf8.decode(buffer), address: address, port: port));
    return buffer.length;
  }

  @override
  void close() {
    closed = true;
    unawaited(_events.close());
  }

  List<String> sentStartingWith(String prefix) => [
    for (final m in sent)
      if (m.message.startsWith(prefix)) m.message,
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _search =
    'M-SEARCH * HTTP/1.1\r\n'
    'ST: urn:healthwallet:device:desktop:1\r\n'
    '\r\n';

void main() {
  late SsdpService ssdp;
  late _FakeSocket socket;

  setUp(() {
    ssdp = SsdpService();
    socket = _FakeSocket();
  });

  group('advertising', () {
    test('announces itself again every 30 seconds until stopped', () {
      fakeAsync((async) {
        ssdp.startAdvertising(
          ip: '10.0.0.5',
          port: 49152,
          deviceId: 'desk',
          bind: () async => socket,
        );
        async.flushMicrotasks();
        final notifies = socket.sentStartingWith('NOTIFY');
        expect(notifies, hasLength(1));
        expect(notifies.single, contains('LOCATION: tcp://10.0.0.5:49152\r\n'));
        expect(socket.sent.single.address.address, '239.255.255.250');
        expect(socket.sent.single.port, 1900);
        expect(socket.broadcastEnabled, isTrue);

        async.elapse(const Duration(seconds: 29));
        expect(socket.sentStartingWith('NOTIFY'), hasLength(1));
        async.elapse(const Duration(seconds: 31));
        expect(socket.sentStartingWith('NOTIFY'), hasLength(3));

        ssdp.stopAdvertising();
        async.elapse(const Duration(minutes: 2));
        expect(socket.sentStartingWith('NOTIFY'), hasLength(3));
        expect(socket.closed, isTrue);
      });
    });

    test('a read event without a datagram is ignored', () {
      fakeAsync((async) {
        ssdp.startAdvertising(
          ip: '10.0.0.5',
          port: 49152,
          deviceId: 'desk',
          bind: () async => socket,
        );
        async.flushMicrotasks();

        socket._events.add(RawSocketEvent.read);
        async.flushMicrotasks();

        expect(socket.sentStartingWith('HTTP/1.1'), isEmpty);
        ssdp.stopAdvertising();
      });
    });

    test('keeps advertising when it cannot send, as without a network', () {
      fakeAsync((async) {
        socket.sendError = const SocketException('Network is unreachable');
        Object? error;
        ssdp
            .startAdvertising(
              ip: '10.0.0.5',
              port: 49152,
              deviceId: 'desk',
              bind: () async => socket,
            )
            .catchError((Object e) => error = e);
        async.flushMicrotasks();
        expect(error, isNull);
        expect(ssdp.listeningPort, 1900);

        // Neither the next announcement nor an answer to a search throws.
        async.elapse(const Duration(seconds: 30));
        socket.deliver(_search);
        async.flushMicrotasks();
        expect(socket.sent, isEmpty);

        // The network is back: the next search is answered.
        socket.sendError = null;
        socket.deliver(_search, port: 50001);
        async.flushMicrotasks();
        expect(socket.sent.single.message, startsWith('HTTP/1.1 200 OK'));
        expect(socket.sent.single.port, 50001);
        ssdp.stopAdvertising();
      });
    });

    test('a socket that cannot be bound fails advertising', () async {
      await expectLater(
        ssdp.startAdvertising(
          ip: '10.0.0.5',
          port: 49152,
          deviceId: 'desk',
          bind: () async =>
              throw const SocketException('Address already in use'),
        ),
        throwsA(isA<SocketException>()),
      );
      expect(ssdp.listeningPort, isNull);
    });
  });

  group('search', () {
    test('gives up at once when no socket can be bound', () async {
      final result = await ssdp.search(
        bind: () async => throw const SocketException('No buffer space'),
      );

      expect(result, isNull);
    });

    test('gives up and closes the socket when the search cannot be '
        'sent', () async {
      socket.sendError = const SocketException('Network is unreachable');

      final result = await ssdp.search(bind: () async => socket);

      expect(result, isNull);
      expect(socket.closed, isTrue);
    });

    test('gives up and closes the socket on a socket error', () async {
      final result = ssdp.search(bind: () async => socket);
      await pumpEventQueue();
      expect(socket.sentStartingWith('M-SEARCH'), hasLength(1));

      socket.fail(const SocketException('Connection reset'));

      expect(await result, isNull);
      expect(socket.closed, isTrue);
    });

    test(
      'skips answers it cannot use and takes the expected desktop',
      () async {
        final result = ssdp.search(
          expectedDeviceId: 'desk',
          bind: () async => socket,
        );
        await pumpEventQueue();

        // A read event without a datagram, then answers it must skip.
        socket._events.add(RawSocketEvent.read);
        socket.deliver('HTTP/1.1 200 OK\r\nST: something else\r\n\r\n');
        socket.deliver(
          'HTTP/1.1 200 OK\r\n'
          'ST: urn:healthwallet:device:desktop:1\r\n'
          'LOCATION: tcp://10.0.0.7:99999\r\n'
          '\r\n',
        );
        socket.deliver(
          'HTTP/1.1 200 OK\r\n'
          'ST: urn:healthwallet:device:desktop:1\r\n'
          'USN: uuid:desk::urn:healthwallet:device:desktop:1\r\n'
          '\r\n',
        );
        socket.deliver(
          'HTTP/1.1 200 OK\r\n'
          'ST: urn:healthwallet:device:desktop:1\r\n'
          'LOCATION: tcp://10.0.0.7:49152\r\n'
          'USN: uuid:other::urn:healthwallet:device:desktop:1\r\n'
          '\r\n',
        );
        socket.deliver(
          'HTTP/1.1 200 OK\r\n'
          'ST: urn:healthwallet:device:desktop:1\r\n'
          'LOCATION: tcp://10.0.0.7:49152\r\n'
          'USN: uuid:desk::urn:healthwallet:device:desktop:1\r\n'
          '\r\n',
          port: 1900,
        );

        expect(await result, (ip: '127.0.0.1', port: 49152, deviceId: 'desk'));
        expect(socket.closed, isTrue);
      },
    );

    test('an answer without a device id is taken when no id is '
        'expected', () async {
      final result = ssdp.search(bind: () async => socket);
      await pumpEventQueue();

      socket.deliver(
        'HTTP/1.1 200 OK\r\n'
        'ST: urn:healthwallet:device:desktop:1\r\n'
        'LOCATION: tcp://10.0.0.7:49152\r\n'
        '\r\n',
      );

      expect(await result, (ip: '127.0.0.1', port: 49152, deviceId: ''));
    });
  });
}
