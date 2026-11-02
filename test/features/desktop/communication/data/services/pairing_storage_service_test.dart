import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/features/desktop/communication/data/models/device_pairing.dart';
import 'package:health_wallet/features/desktop/communication/data/services/pairing_storage_service.dart';
import 'package:health_wallet/features/desktop/communication/data/services/secret_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../desktop_test_fakes.dart';

class _FakeSecretStore implements SecretStore {
  final values = <String, String>{};
  bool failing = false;

  @override
  Future<String?> read(String key) async {
    if (failing) throw StateError('keychain locked');
    return values[key];
  }

  @override
  Future<void> write(String key, String value) async {
    if (failing) throw StateError('keychain locked');
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    if (failing) throw StateError('keychain locked');
    values.remove(key);
  }
}

void main() {
  final key = testPairingKey();
  final pairing = DevicePairing(
    deviceId: 'desk-1',
    deviceName: 'Desk',
    pairingKey: key,
    lastIp: '192.168.1.10',
    lastPort: 49152,
    pairedAt: DateTime.utc(2026, 3, 4),
    os: 'macos',
  );

  late SharedPreferences prefs;
  late _FakeSecretStore secrets;
  late PairingStorageService storage;

  Future<void> start([Map<String, Object> values = const {}]) async {
    SharedPreferences.setMockInitialValues(values);
    prefs = await SharedPreferences.getInstance();
    secrets = _FakeSecretStore();
    storage = PairingStorageService(prefs, secrets);
  }

  test('starts empty', () async {
    await start();
    expect(await storage.load(), isNull);
    expect(storage.hasPairing, isFalse);
  });

  test('keeps the keys in the secret store, never in preferences', () async {
    await start();
    await storage.savePairing(
      pairing.copyWith(pendingKey: testPairingKey(seed: 3)),
    );

    final raw = prefs.getString('device_pairing')!;
    expect(raw, isNot(contains(key)));
    expect(jsonDecode(raw)['deviceId'], 'desk-1');
    expect(secrets.values.values, contains(key));

    final reloaded = PairingStorageService(prefs, secrets);
    expect(await reloaded.load(), storage.loadPairing());
    expect(reloaded.loadPairing()?.pendingKey, testPairingKey(seed: 3));
  });

  test('moves a key an older version kept in preferences', () async {
    await start({'device_pairing': jsonEncode(pairing.toJson())});
    expect(prefs.getString('device_pairing'), contains(key));

    expect(await storage.load(), pairing);
    expect(prefs.getString('device_pairing'), isNot(contains(key)));
    expect(secrets.values.values, contains(key));
  });

  test('a pairing whose key is gone (a restored backup) is dropped', () async {
    final json = pairing.toJson()..remove('pairingKey');
    await start({'device_pairing': jsonEncode(json)});

    expect(await storage.load(), isNull);
    expect(prefs.containsKey('device_pairing'), isFalse);
  });

  test('without a working secret store the key stays usable', () async {
    await start();
    secrets.failing = true;
    await storage.savePairing(pairing);

    final reloaded = PairingStorageService(prefs, _FakeSecretStore());
    expect((await reloaded.load())?.pairingKey, key);
  });

  test('clearPairing removes the pairing and its keys', () async {
    await start();
    await storage.savePairing(pairing);
    await storage.clearPairing();

    expect(storage.loadPairing(), isNull);
    expect(prefs.containsKey('device_pairing'), isFalse);
    expect(secrets.values, isEmpty);
  });

  test('the local device id is the one the LWW sync uses', () async {
    await start({'lww_local_device_id': 'device-42'});
    expect(await storage.localDeviceId(), 'device-42');

    await start();
    final created = await storage.localDeviceId();
    expect(created, isNotEmpty);
    expect(prefs.getString('lww_local_device_id'), created);
  });

  test('updateLastConnection saves a verified address', () async {
    await start();
    await storage.savePairing(pairing);
    await storage.updateLastConnection(ip: '10.0.0.5', port: 50000);

    final reloaded = PairingStorageService(prefs, secrets);
    final loaded = await reloaded.load();
    expect(loaded?.lastIp, '10.0.0.5');
    expect(loaded?.lastPort, 50000);
  });
}
