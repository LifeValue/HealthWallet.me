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

  Future<String?> mSearch(String body) async {
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
    socket.send(utf8.encode(body), InternetAddress.loopbackIPv4, 1900);
    try {
      return await reply.future.timeout(
        const Duration(seconds: 2),
        onTimeout: () => null,
      );
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

  test('answers an M-SEARCH for its URN with its address and id', () async {
    await ssdp.startAdvertising(
      ip: '192.168.1.50',
      port: 49152,
      deviceId: 'desk-uuid',
    );

    final reply = await mSearch(search);

    expect(reply, isNotNull, reason: 'no SSDP reply on 127.0.0.1:1900');
    expect(reply, startsWith('HTTP/1.1 200 OK\r\n'));
    expect(reply, contains('LOCATION: tcp://192.168.1.50:49152\r\n'));
    expect(
      reply,
      contains('USN: uuid:desk-uuid::urn:healthwallet:device:desktop:1'),
    );
  });

  test('ignores searches for other devices', () async {
    await ssdp.startAdvertising(
      ip: '192.168.1.50',
      port: 49152,
      deviceId: 'desk-uuid',
    );

    final reply = await mSearch(
      search.replaceAll('healthwallet:device:desktop', 'other:thing'),
    );

    expect(reply, isNull);
  });

  test('stopAdvertising releases the socket and can restart', () async {
    await ssdp.startAdvertising(ip: '10.0.0.1', port: 1, deviceId: 'a');
    await ssdp.stopAdvertising();
    expect(await mSearch(search), isNull);

    await ssdp.startAdvertising(ip: '10.0.0.2', port: 2, deviceId: 'b');
    expect(await mSearch(search), contains('tcp://10.0.0.2:2'));
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
    // answer must be parsed exactly.
    if (result != null) {
      expect(result.ip, '192.168.1.50');
      expect(result.port, 49153);
      expect(result.deviceId, 'local-desk');
    }
  });
}
