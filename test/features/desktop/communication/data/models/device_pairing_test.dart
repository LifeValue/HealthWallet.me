import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/features/desktop/communication/data/models/device_pairing.dart';

void main() {
  group('DevicePairing.generate', () {
    test(
      'creates a 32-byte base64url key, a UUID v4 id and the default port',
      () {
        final before = DateTime.now();
        final pairing = DevicePairing.generate(
          deviceName: 'Studio Mac',
          localIp: '192.168.1.20',
          os: 'macos',
        );

        expect(base64Url.decode(pairing.pairingKey), hasLength(32));
        expect(
          pairing.deviceId,
          matches(
            RegExp(
              r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
            ),
          ),
        );
        expect(pairing.deviceName, 'Studio Mac');
        expect(pairing.lastIp, '192.168.1.20');
        expect(pairing.lastPort, 49152);
        expect(pairing.os, 'macos');
        expect(pairing.lastSsid, isNull);
        expect(pairing.lastPassword, isNull);
        expect(pairing.pairedAt.isBefore(before), isFalse);
      },
    );

    test('uses the given port', () {
      final pairing = DevicePairing.generate(
        deviceName: 'PC',
        localIp: '10.0.0.2',
        port: 50000,
      );
      expect(pairing.lastPort, 50000);
      expect(pairing.os, isNull);
    });

    test('never reuses a key or id', () {
      final pairings = List.generate(
        20,
        (_) => DevicePairing.generate(deviceName: 'd', localIp: '1.1.1.1'),
      );
      expect(pairings.map((p) => p.pairingKey).toSet(), hasLength(20));
      expect(pairings.map((p) => p.deviceId).toSet(), hasLength(20));
    });
  });

  group('JSON (the QR payload)', () {
    test('round-trips every field', () {
      final pairing = DevicePairing(
        deviceId: 'id-1',
        deviceName: 'Desk',
        pairingKey: 'a2V5',
        lastIp: '192.168.0.5',
        lastPort: 49153,
        lastSsid: 'Home',
        lastPassword: 'secret',
        pairedAt: DateTime.utc(2026, 1, 2, 3, 4, 5),
        os: 'windows',
      );

      final decoded = DevicePairing.fromJson(
        jsonDecode(jsonEncode(pairing.toJson())) as Map<String, dynamic>,
      );

      expect(decoded, pairing);
    });

    test('reads a payload without the optional fields', () {
      final pairing = DevicePairing.fromJson({
        'deviceId': 'id-2',
        'deviceName': 'Desk',
        'pairingKey': 'a2V5',
        'lastIp': '192.168.0.5',
        'lastPort': 49152,
        'pairedAt': '2026-01-02T03:04:05.000Z',
      });

      expect(pairing.lastSsid, isNull);
      expect(pairing.lastPassword, isNull);
      expect(pairing.os, isNull);
      expect(pairing.pairedAt, DateTime.utc(2026, 1, 2, 3, 4, 5));
    });

    test('rejects a payload missing a required field', () {
      expect(
        () => DevicePairing.fromJson({
          'deviceId': 'id-3',
          'deviceName': 'Desk',
          'lastIp': '192.168.0.5',
          'lastPort': 49152,
          'pairedAt': '2026-01-02T03:04:05.000Z',
        }),
        throwsA(isA<TypeError>()),
      );
    });
  });
}
