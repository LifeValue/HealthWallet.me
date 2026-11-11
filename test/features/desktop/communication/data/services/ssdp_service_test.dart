import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/features/desktop/communication/data/services/ssdp_service.dart';

/// Exercises the advertiser over unicast loopback. Multicast search depends on
/// the host network, so `search` is only checked for its timeout path.
void main() {
  late SsdpService ssdp;

  setUp(() => ssdp = SsdpService());
  tearDown(() => ssdp.stopAdvertising());

  /// Sends [body] to the advertiser on [port] and returns its reply, or null
  /// when none comes within [wait]. A reply can take a while on a busy
  /// machine; checks that expect none pass a shorter [wait].
  Future<String?> mSearch(
    String body, {
    required int port,
    Duration wait = const Duration(seconds: 10),
  }) async {
    final socket = await RawDatagramSocket.bind(
      InternetAddress.loopbackIPv4,
      0,
    );
    final reply = Completer<String?>();
    final sub = socket.listen((event) {
      if (event != RawSocketEvent.read) return;
      final datagram = socket.receive();
      if (datagram != null && !reply.isCompleted) {
        reply.complete(utf8.decode(datagram.data));
      }
    });
    socket.send(utf8.encode(body), InternetAddress.loopbackIPv4, port);
    try {
      return await reply.future.timeout(wait, onTimeout: () => null);
    } finally {
      await sub.cancel();
      socket.close();
    }
  }

  const search =
      'M-SEARCH * HTTP/1.1\r\n'
      'HOST: 239.255.255.250:1900\r\n'
      'MAN: "ssdp:discover"\r\n'
      'ST: urn:healthwallet:device:desktop:1\r\n'
      '\r\n';

  /// Advertises on a free port of its own: a HealthWallet desktop running on
  /// this machine shares 1900, and the system hands a datagram sent there to
  /// only one of them.
  Future<int> advertise({
    required String ip,
    required int port,
    required String deviceId,
  }) async {
    await ssdp.startAdvertising(
      ip: ip,
      port: port,
      deviceId: deviceId,
      listenPort: 0,
    );
    return ssdp.listeningPort!;
  }

  test('answers an M-SEARCH for its URN with its address and id', () async {
    final at = await advertise(
      ip: '192.168.1.50',
      port: 49152,
      deviceId: 'desk-uuid',
    );

    final reply = await mSearch(search, port: at);

    expect(reply, isNotNull, reason: 'no SSDP reply on 127.0.0.1:$at');
    expect(reply, startsWith('HTTP/1.1 200 OK\r\n'));
    expect(reply, contains('LOCATION: tcp://192.168.1.50:49152\r\n'));
    expect(
      reply,
      contains('USN: uuid:desk-uuid::urn:healthwallet:device:desktop:1'),
    );
  });

  test('ignores searches for other devices', () async {
    final at = await advertise(
      ip: '192.168.1.50',
      port: 49152,
      deviceId: 'desk-uuid',
    );

    final reply = await mSearch(
      search.replaceAll('healthwallet:device:desktop', 'other:thing'),
      port: at,
      wait: const Duration(seconds: 2),
    );

    expect(reply, isNull);
  });

  test('stopAdvertising releases the socket and can restart', () async {
    final first = await advertise(ip: '10.0.0.1', port: 1, deviceId: 'a');
    await ssdp.stopAdvertising();
    expect(ssdp.listeningPort, isNull);
    expect(
      await mSearch(search, port: first, wait: const Duration(seconds: 2)),
      isNull,
    );

    final second = await advertise(ip: '10.0.0.2', port: 2, deviceId: 'b');
    expect(await mSearch(search, port: second), contains('tcp://10.0.0.2:2'));
  });

  test('advertises on the SSDP port by default', () async {
    await ssdp.startAdvertising(ip: '10.0.0.3', port: 3, deviceId: 'c');

    expect(ssdp.listeningPort, 1900);
  });

  test('search gives up after its timeout when nobody answers', () async {
    final result = await ssdp.search(
      timeout: const Duration(milliseconds: 200),
      expectedDeviceId:
          'no-such-device-${DateTime.now().microsecondsSinceEpoch}',
    );

    expect(result, isNull);
  });

  test('search finds a local advertiser through multicast', () async {
    await ssdp.startAdvertising(
      ip: '192.168.1.50',
      port: 49153,
      deviceId: 'local-desk',
    );

    final result = await ssdp.search(
      timeout: const Duration(seconds: 2),
      expectedDeviceId: 'local-desk',
    );

    // Multicast loopback depends on the host network; when it works the
    // answer must be parsed exactly. The address is the one the answer came
    // from, an address of this host, not the one the advertiser names.
    if (result != null) {
      final hostAddresses = {
        InternetAddress.loopbackIPv4.address,
        for (final interface in await NetworkInterface.list(
          type: InternetAddressType.IPv4,
          includeLoopback: true,
        ))
          for (final address in interface.addresses) address.address,
      };
      expect(hostAddresses, contains(result.ip));
      expect(result.ip, isNot('192.168.1.50'));
      expect(result.port, 49153);
      expect(result.deviceId, 'local-desk');
    }
  });

  test('search takes the address the answer came from, not the one it '
      'names', () async {
    final responder = await RawDatagramSocket.bind(
      InternetAddress.loopbackIPv4,
      0,
    );
    addTearDown(responder.close);
    final searchSocket = Completer<(InternetAddress, int)>();
    // A stand-in for the multicast group: answers the first M-SEARCH sent to
    // it with a LOCATION pointing elsewhere.
    responder.listen((event) {
      if (event != RawSocketEvent.read) return;
      final datagram = responder.receive();
      if (datagram != null && !searchSocket.isCompleted) {
        searchSocket.complete((datagram.address, datagram.port));
      }
    });

    final result = ssdp.search(
      timeout: const Duration(seconds: 5),
      expectedDeviceId: 'desk',
      target: (InternetAddress.loopbackIPv4, responder.port),
    );
    final (address, port) = await searchSocket.future;
    responder.send(
      utf8.encode(
        'HTTP/1.1 200 OK\r\n'
        'ST: urn:healthwallet:device:desktop:1\r\n'
        'LOCATION: tcp://203.0.113.9:49153\r\n'
        'USN: uuid:desk::urn:healthwallet:device:desktop:1\r\n'
        '\r\n',
      ),
      address,
      port,
    );

    expect(await result, (ip: '127.0.0.1', port: 49153, deviceId: 'desk'));
  });
}
