import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/config/app_platform.dart';
import 'package:health_wallet/features/desktop/communication/data/services/discovery_service.dart';
import 'package:health_wallet/features/desktop/communication/data/services/pairing_storage_service.dart';
import 'package:health_wallet/features/desktop/communication/data/services/transport/communication_service.dart';
import 'package:health_wallet/features/desktop/communication/presentation/bloc/communication_bloc.dart';

import '../../../desktop_test_fakes.dart';

class _UnusedPairingStorage extends Fake implements PairingStorageService {}

class _UnusedDiscoveryService extends Fake implements DiscoveryService {}

/// Adds what the bloc's constructor wires up on top of [FakeTcpService].
class _BlocTcpService extends FakeTcpService {
  final _pendingClients = StreamController<String>.broadcast();

  @override
  Stream<String> get pendingClients => _pendingClients.stream;

  @override
  void setMpcTransport(CommunicationService? transport) {}

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
}
