import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/features/desktop/communication/data/models/device_pairing.dart';
import 'package:health_wallet/features/desktop/communication/data/services/discovery_service.dart';
import 'package:health_wallet/features/desktop/communication/data/services/mdns_service.dart';
import 'package:health_wallet/features/desktop/communication/data/services/pairing_storage_service.dart';
import 'package:health_wallet/features/desktop/communication/data/services/ssdp_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeSsdp extends Fake implements SsdpService {
  ({String ip, int port, String deviceId})? result;
  Exception? error;
  Exception? advertiseError;
  String? lastExpectedDeviceId;
  Duration? lastTimeout;
  final calls = <String>[];

  @override
  Future<({String ip, int port, String deviceId})?> search({
    Duration timeout = const Duration(seconds: 3),
    String? expectedDeviceId,
  }) async {
    calls.add('search');
    lastTimeout = timeout;
    lastExpectedDeviceId = expectedDeviceId;
    if (error != null) throw error!;
    return result;
  }

  @override
  Future<void> startAdvertising({
    required String ip,
    required int port,
    required String deviceId,
  }) async {
    calls.add('advertise $ip:$port $deviceId');
    if (advertiseError != null) throw advertiseError!;
  }

  @override
  Future<void> stopAdvertising() async => calls.add('stop');
}

class _FakeMdns extends Fake implements MdnsService {
  ({String ip, int port})? result;
  Exception? error;
  final calls = <String>[];

  @override
  Future<({String ip, int port})?> search({
    Duration timeout = const Duration(seconds: 3),
  }) async {
    calls.add('search');
    if (error != null) throw error!;
    return result;
  }

  @override
  Future<void> startAdvertising({required int port}) async =>
      calls.add('advertise $port');

  @override
  Future<void> stopAdvertising() async => calls.add('stop');
}

void main() {
  final pairing = DevicePairing(
    deviceId: 'desk-1',
    deviceName: 'Desk',
    pairingKey: 'a2V5',
    lastIp: '192.168.1.10',
    lastPort: 49152,
    pairedAt: DateTime.utc(2026),
  );

  late _FakeSsdp ssdp;
  late _FakeMdns mdns;
  late PairingStorageService storage;
  late DiscoveryService discovery;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = PairingStorageService(await SharedPreferences.getInstance());
    ssdp = _FakeSsdp();
    mdns = _FakeMdns();
    discovery = DiscoveryService(ssdp, mdns, storage);
  });

  group('discover', () {
    test('uses the saved address first, without searching', () async {
      await storage.savePairing(pairing);

      final result = await discovery.discover();

      expect(result!.ip, '192.168.1.10');
      expect(result.port, 49152);
      expect(result.method, 'saved-ip');
      expect(ssdp.calls, isEmpty);
      expect(mdns.calls, isEmpty);
    });

    test('without a pairing falls back to the network search', () async {
      mdns.result = (ip: '10.0.0.3', port: 49153);

      final result = await discovery.discover();

      expect(result!.method, 'mdns');
      expect(result.ip, '10.0.0.3');
    });

    test('returns null when every method fails', () async {
      expect(await discovery.discover(), isNull);
    });
  });

  group('discoverViaNetwork', () {
    test('runs mDNS and SSDP and prefers mDNS', () async {
      await storage.savePairing(pairing);
      mdns.result = (ip: '10.0.0.3', port: 49153);
      ssdp.result = (ip: '10.0.0.4', port: 49154, deviceId: 'desk-1');

      final result = await discovery.discoverViaNetwork();

      expect(result!.method, 'mdns');
      expect(mdns.calls, ['search']);
      expect(ssdp.calls, ['search']);
      expect(ssdp.lastTimeout, const Duration(seconds: 3));
    });

    test('filters SSDP answers by the paired device id', () async {
      await storage.savePairing(pairing);

      await discovery.discoverViaNetwork();

      expect(ssdp.lastExpectedDeviceId, 'desk-1');
    });

    test('uses SSDP when mDNS finds nothing and saves the address', () async {
      await storage.savePairing(pairing);
      ssdp.result = (ip: '10.0.0.4', port: 49154, deviceId: 'desk-1');

      final result = await discovery.discoverViaNetwork();

      expect(result!.method, 'ssdp');
      expect(result.ip, '10.0.0.4');
      expect(result.port, 49154);
      final saved = storage.loadPairing()!;
      expect(saved.lastIp, '10.0.0.4');
      expect(saved.lastPort, 49154);
    });

    test('a failing method is treated as not found', () async {
      mdns.error = Exception('bonsoir missing');
      ssdp.result = (ip: '10.0.0.4', port: 49154, deviceId: '');

      expect((await discovery.discoverViaNetwork())!.method, 'ssdp');

      ssdp.error = const FormatException();
      expect(await discovery.discoverViaNetwork(), isNull);
    });

    test('without a pairing searches for any desktop', () async {
      await discovery.discoverViaNetwork();

      expect(ssdp.lastExpectedDeviceId, isNull);
    });
  });

  group('advertising', () {
    test('starts SSDP then mDNS on the same port', () async {
      await discovery.startDesktopAdvertising(
        ip: '10.0.0.2',
        port: 49152,
        deviceId: 'desk-1',
      );

      expect(ssdp.calls, ['advertise 10.0.0.2:49152 desk-1']);
      expect(mdns.calls, ['advertise 49152']);
    });

    test('an SSDP failure does not stop mDNS advertising', () async {
      ssdp.advertiseError = const SocketException('port 1900 in use');

      await discovery.startDesktopAdvertising(
        ip: '10.0.0.2',
        port: 49152,
        deviceId: 'desk-1',
      );

      expect(mdns.calls, ['advertise 49152']);
    });

    test('stop stops both', () async {
      await discovery.stopDesktopAdvertising();

      expect(ssdp.calls, ['stop']);
      expect(mdns.calls, ['stop']);
    });
  });
}
