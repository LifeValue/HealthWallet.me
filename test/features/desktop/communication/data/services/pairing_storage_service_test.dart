import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/features/desktop/communication/data/models/device_pairing.dart';
import 'package:health_wallet/features/desktop/communication/data/services/pairing_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final pairing = DevicePairing(
    deviceId: 'desk-1',
    deviceName: 'Desk',
    pairingKey: 'a2V5a2V5',
    lastIp: '192.168.1.10',
    lastPort: 49152,
    pairedAt: DateTime.utc(2026, 3, 4),
    os: 'macos',
  );

  late SharedPreferences prefs;
  late PairingStorageService storage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    storage = PairingStorageService(prefs);
  });

  test('starts empty', () {
    expect(storage.hasPairing, isFalse);
    expect(storage.loadPairing(), isNull);
    expect(storage.localDeviceId, isNull);
  });

  test('saves and loads a pairing under device_pairing', () async {
    await storage.savePairing(pairing);

    expect(storage.hasPairing, isTrue);
    expect(storage.loadPairing(), pairing);
    final raw = jsonDecode(prefs.getString('device_pairing')!);
    expect(raw['pairingKey'], 'a2V5a2V5');
  });

  test('a new pairing replaces the old one', () async {
    await storage.savePairing(pairing);
    await storage.savePairing(pairing.copyWith(deviceId: 'desk-2'));

    expect(storage.loadPairing()!.deviceId, 'desk-2');
  });

  test('clearPairing removes it', () async {
    await storage.savePairing(pairing);
    await storage.clearPairing();

    expect(storage.hasPairing, isFalse);
    expect(storage.loadPairing(), isNull);
  });

  test('stores the local device id separately from the pairing', () async {
    await storage.saveLocalDeviceId('phone-9');
    await storage.savePairing(pairing);
    await storage.clearPairing();

    expect(storage.localDeviceId, 'phone-9');
  });

  test('updateLastConnection changes only the address', () async {
    await storage.savePairing(pairing);
    await storage.updateLastConnection(ip: '10.0.0.7', port: 50001);

    final updated = storage.loadPairing()!;
    expect(updated.lastIp, '10.0.0.7');
    expect(updated.lastPort, 50001);
    expect(updated.copyWith(lastIp: pairing.lastIp, lastPort: 49152), pairing);
  });

  test('updateLastConnection without a pairing does nothing', () async {
    await storage.updateLastConnection(ip: '10.0.0.7', port: 50001);

    expect(storage.hasPairing, isFalse);
  });

  test(
    'a corrupted stored value throws instead of returning a bad pairing',
    () async {
      await prefs.setString('device_pairing', '{not json');

      expect(storage.loadPairing, throwsFormatException);
    },
  );
}
