import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/features/desktop/communication/data/services/discovery_service.dart';
import 'package:health_wallet/features/desktop/communication/data/services/mdns_service.dart';
import 'package:health_wallet/features/desktop/communication/data/services/ssdp_service.dart';

class _FakeSsdp extends Fake implements SsdpService {
  ({String ip, int port, String deviceId})? result;
  Exception? error;
  Exception? advertiseError;
  String? lastExpectedDeviceId;
  final calls = <String>[];

  @override
  Future<({String ip, int port, String deviceId})?> search({
    Duration timeout = const Duration(seconds: 3),
    String? expectedDeviceId,
    (InternetAddress, int)? target,
  }) async {
    calls.add('search');
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
  String? lastToken;
  final calls = <String>[];

  @override
  Future<({String ip, int port})?> search({
    required String token,
    Duration timeout = const Duration(seconds: 3),
  }) async {
    calls.add('search');
    lastToken = token;
    if (error != null) throw error!;
    return result;
  }

  @override
  Future<void> startAdvertising({
    required int port,
    required String token,
  }) async => calls.add('advertise $port $token');

  @override
  Future<void> stopAdvertising() async => calls.add('stop');
}

void main() {
  late _FakeSsdp ssdp;
  late _FakeMdns mdns;
  late DiscoveryService discovery;

  setUp(() {
    ssdp = _FakeSsdp();
    mdns = _FakeMdns();
    discovery = DiscoveryService(ssdp, mdns);
  });

  Future<List<DiscoveryResult>> search() =>
      discovery.discoverViaNetwork(deviceId: 'desk-1', token: 'tok');

  test(
    'asks Bonjour for the pairing token and SSDP for the desktop id',
    () async {
      await search();
      expect(mdns.lastToken, 'tok');
      if (!Platform.isIOS) expect(ssdp.lastExpectedDeviceId, 'desk-1');
    },
  );

  test('returns every candidate, Bonjour first, without duplicates', () async {
    mdns.result = (ip: '10.0.0.2', port: 49152);
    ssdp.result = (ip: '10.0.0.3', port: 49152, deviceId: 'desk-1');
    expect(
      (await search()).map((r) => '${r.method} ${r.ip}'),
      ['mdns 10.0.0.2', 'ssdp 10.0.0.3'],
    );

    ssdp.result = (ip: '10.0.0.2', port: 49152, deviceId: 'desk-1');
    expect((await search()).map((r) => r.method), ['mdns']);
  });

  test('a failing search method is skipped, not fatal', () async {
    mdns.error = Exception('no multicast');
    ssdp.result = (ip: '10.0.0.3', port: 49152, deviceId: 'desk-1');
    expect((await search()).map((r) => r.method), ['ssdp']);

    ssdp.error = Exception('bind failed');
    expect(await search(), isEmpty);
  });

  test('advertises the token over Bonjour and the address over SSDP', () async {
    await discovery.startDesktopAdvertising(
      ip: '10.0.0.9',
      port: 50000,
      deviceId: 'desk-1',
      token: 'tok',
    );
    expect(ssdp.calls, ['advertise 10.0.0.9:50000 desk-1']);
    expect(mdns.calls, ['advertise 50000 tok']);
  });

  test('without an address only Bonjour advertises; SSDP failing is not '
      'fatal', () async {
    await discovery.startDesktopAdvertising(
      ip: null,
      port: 50000,
      deviceId: 'desk-1',
      token: 'tok',
    );
    expect(ssdp.calls, isEmpty);
    expect(mdns.calls, ['advertise 50000 tok']);

    ssdp.advertiseError = Exception('port 1900 taken');
    await discovery.startDesktopAdvertising(
      ip: '10.0.0.9',
      port: 50000,
      deviceId: 'desk-1',
      token: 'tok',
    );
    expect(mdns.calls, hasLength(2));
  });

  test('stopping stops both', () async {
    await discovery.stopDesktopAdvertising();
    expect(ssdp.calls, ['stop']);
    expect(mdns.calls, ['stop']);
  });
}
