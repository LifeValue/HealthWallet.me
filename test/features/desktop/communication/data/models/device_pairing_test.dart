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

  group('the pairing QR code', () {
    final pairing = DevicePairing.generate(
      deviceName: 'Studio Mac',
      localIp: '192.168.1.20',
      os: 'macos',
    );

    Map<String, dynamic> payload() =>
        jsonDecode(pairing.toQrPayload()) as Map<String, dynamic>;

    test('round-trips what the phone needs, with the protocol version', () {
      expect(payload()['v'], 2);
      final parsed = DevicePairing.parseQr(pairing.toQrPayload());
      expect(parsed, isA<ValidPairingQr>());
      final scanned = (parsed as ValidPairingQr).pairing;
      expect(scanned.deviceId, pairing.deviceId);
      expect(scanned.pairingKey, pairing.pairingKey);
      expect(scanned.lastIp, '192.168.1.20');
      expect(scanned.lastPort, 49152);
      expect(scanned.deviceName, 'Studio Mac');
    });

    test('a code from an older desktop is recognised as such', () {
      final old = payload()..remove('v');
      expect(DevicePairing.parseQr(jsonEncode(old)), isA<OutdatedPairingQr>());
    });

    test('a short, empty or non-base64 key is refused', () {
      for (final key in ['', 'a2V5a2V5', 'not base64!', 'AAAA']) {
        final bad = payload()..['pairing_key'] = key;
        expect(
          DevicePairing.parseQr(jsonEncode(bad)),
          isA<InvalidPairingQr>(),
          reason: key,
        );
      }
    });

    test('a missing address or an impossible port is refused', () {
      for (final change in <void Function(Map<String, dynamic>)>[
        (j) => j.remove('ip'),
        (j) => j['port'] = 0,
        (j) => j['port'] = 70000,
        (j) => j['port'] = '49152',
        (j) => j['device_id'] = '',
      ]) {
        final bad = payload();
        change(bad);
        expect(DevicePairing.parseQr(jsonEncode(bad)), isA<InvalidPairingQr>());
      }
    });

    test('anything else is not a pairing code', () {
      expect(DevicePairing.parseQr('https://example.org'), isA<NotPairingQr>());
      expect(
        DevicePairing.parseQr(jsonEncode({'token': 'x'})),
        isA<NotPairingQr>(),
      );
    });

    test('the keys a phone may use: the current one, then the next', () {
      expect(pairing.acceptedKeys, [pairing.pairingKey]);
      final moving = pairing.copyWith(pendingKey: 'next');
      expect(moving.acceptedKeys, [pairing.pairingKey, 'next']);
    });
  });
}
