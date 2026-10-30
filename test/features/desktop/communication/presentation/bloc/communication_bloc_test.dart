import 'dart:async';
import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/config/app_platform.dart';
import 'package:health_wallet/features/desktop/communication/data/services/discovery_service.dart';
import 'package:health_wallet/features/desktop/communication/data/services/pairing_storage_service.dart';
import 'package:health_wallet/features/desktop/communication/data/services/tcp_service.dart'
    show ConnectionState;
import 'package:health_wallet/features/desktop/communication/data/services/transport/communication_service.dart';
import 'package:health_wallet/features/desktop/communication/presentation/bloc/communication_bloc.dart';

import '../../../desktop_test_fakes.dart';

class _UnusedPairingStorage extends Fake implements PairingStorageService {}

class _UnusedDiscoveryService extends Fake implements DiscoveryService {}

/// An IPv4 address bound to a network interface.
class _Address extends Fake implements InterfaceAddress {
  _Address(this.address);

  @override
  final String address;
}

/// A network interface with one IPv4 address.
class _Interface extends Fake implements NetworkInterface {
  _Interface(this.name, String address) : addresses = [_Address(address)];

  @override
  final String name;

  @override
  final List<InterfaceAddress> addresses;
}

final _wifi = _Interface('en0', '192.168.1.20');
final _vpn = _Interface('utun4', '10.212.134.7');

/// Adds what the bloc's constructor wires up on top of [FakeTcpService].
class _BlocTcpService extends FakeTcpService {
  final _pendingClients = StreamController<String>.broadcast();

  @override
  Stream<String> get pendingClients => _pendingClients.stream;

  @override
  void setMpcTransport(CommunicationService? transport) {}

  @override
  void setUseMpc(bool value) {}

  @override
  Future<void> close() async {
    await _pendingClients.close();
    await super.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // MpcTransport, created on iOS and macOS hosts, listens on the airdrop
  // channels; answer them so the constructor does not hit a missing plugin.
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('dev.lifevalue.airdrop'),
          (_) async => null,
        );
  });

  late _BlocTcpService tcp;

  setUp(() => tcp = _BlocTcpService());
  tearDown(() => tcp.close());

  CommunicationBloc build(AppPlatform platform) => CommunicationBloc(
    platform,
    _UnusedPairingStorage(),
    tcp,
    _UnusedDiscoveryService(),
  );

  // The two seeds cover either host: an ungated check would flip a false flag
  // on a machine with a VPN and a true one on a machine without.
  group('CommunicationVpnChecked', () {
    blocTest<CommunicationBloc, DesktopSyncState>(
      'does nothing on the phone',
      build: () => build(AppPlatform.mobile),
      act: (bloc) => bloc.add(const CommunicationVpnChecked()),
      expect: () => <DesktopSyncState>[],
    );

    blocTest<CommunicationBloc, DesktopSyncState>(
      'leaves a VPN flag the phone already holds untouched',
      build: () => build(AppPlatform.mobile),
      seed: () => const DesktopSyncState(vpnDetected: true),
      act: (bloc) => bloc.add(const CommunicationVpnChecked()),
      expect: () => <DesktopSyncState>[],
      verify: (bloc) => expect(bloc.state.vpnDetected, isTrue),
    );
  });

  group('VPN recheck', () {
    const interval = Duration(milliseconds: 20);
    // Long enough for a few rechecks.
    const wait = Duration(milliseconds: 120);

    late List<NetworkInterface> interfaces;
    late int lookups;

    setUp(() {
      interfaces = [_wifi];
      lookups = 0;
    });

    CommunicationBloc buildWithInterfaces(AppPlatform platform) =>
        CommunicationBloc(
          platform,
          _UnusedPairingStorage(),
          tcp,
          _UnusedDiscoveryService(),
          vpnRecheckInterval: interval,
          listInterfaces: () async {
            lookups++;
            return interfaces;
          },
        );

    test(
      'shows the notice soon after a VPN turns on, also while connected',
      () async {
        final bloc = buildWithInterfaces(AppPlatform.desktop);
        addTearDown(bloc.close);
        bloc.emit(
          bloc.state.copyWith(connectionStatus: ConnectionStatus.connected),
        );

        interfaces = [_wifi, _vpn];
        await Future<void>.delayed(wait);

        expect(bloc.state.vpnDetected, isTrue);
        expect(bloc.state.connectionStatus, ConnectionStatus.connected);
      },
    );

    test('hides the notice soon after the VPN turns off', () async {
      interfaces = [_wifi, _vpn];
      final bloc = buildWithInterfaces(AppPlatform.desktop);
      addTearDown(bloc.close);
      await Future<void>.delayed(wait);
      expect(bloc.state.vpnDetected, isTrue);

      interfaces = [_wifi];
      await Future<void>.delayed(wait);

      expect(bloc.state.vpnDetected, isFalse);
    });

    test('does not recheck on the phone', () async {
      final bloc = buildWithInterfaces(AppPlatform.mobile);
      addTearDown(bloc.close);

      await Future<void>.delayed(wait);

      expect(lookups, 0);
    });

    test('stops rechecking once closed', () async {
      final bloc = buildWithInterfaces(AppPlatform.desktop);
      await Future<void>.delayed(wait);
      await bloc.close();
      final afterClose = lookups;

      await Future<void>.delayed(wait);

      expect(lookups, afterClose);
    });

    test('checks again when a phone disconnects, as a full-tunnel VPN '
        'drops the link', () async {
      final bloc = CommunicationBloc(
        AppPlatform.desktop,
        _UnusedPairingStorage(),
        tcp,
        _UnusedDiscoveryService(),
        // Too long to tick during the test: only the disconnect checks.
        vpnRecheckInterval: const Duration(hours: 1),
        listInterfaces: () async {
          lookups++;
          return interfaces;
        },
      );
      addTearDown(bloc.close);
      bloc.emit(
        bloc.state.copyWith(connectionStatus: ConnectionStatus.connected),
      );
      interfaces = [_wifi, _vpn];

      tcp.emitState(ConnectionState.disconnected);
      await flushEvents();

      expect(lookups, 1);
      expect(bloc.state.connectionStatus, ConnectionStatus.disconnected);
      expect(bloc.state.vpnDetected, isTrue);
    });

    test('a failed interface lookup keeps the last answer', () async {
      final bloc = CommunicationBloc(
        AppPlatform.desktop,
        _UnusedPairingStorage(),
        tcp,
        _UnusedDiscoveryService(),
        vpnRecheckInterval: const Duration(hours: 1),
        listInterfaces: () async {
          lookups++;
          throw const SocketException('Network interfaces unavailable');
        },
      );
      addTearDown(bloc.close);
      bloc.emit(bloc.state.copyWith(vpnDetected: true));

      bloc.add(const CommunicationVpnChecked());
      await flushEvents();

      expect(lookups, 1);
      expect(bloc.state.vpnDetected, isTrue);
    });
  });

  test('without an injected lookup, the check reads the real '
      'interfaces', () async {
    final bloc = CommunicationBloc(
      AppPlatform.desktop,
      _UnusedPairingStorage(),
      tcp,
      _UnusedDiscoveryService(),
      vpnRecheckInterval: const Duration(hours: 1),
    );
    addTearDown(bloc.close);
    final checked = bloc.stream.first.timeout(const Duration(seconds: 5));

    bloc.add(const CommunicationVpnChecked());

    // Whether this machine has a VPN is not known here, only that the
    // check finished with an answer.
    expect((await checked).vpnDetected, isA<bool>());
  });
}
