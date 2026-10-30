import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/config/app_platform.dart';
import 'package:health_wallet/features/desktop/communication/data/models/device_pairing.dart';
import 'package:health_wallet/features/desktop/communication/data/services/discovery_service.dart';
import 'package:health_wallet/features/desktop/communication/data/services/pairing_storage_service.dart';
import 'package:health_wallet/features/desktop/communication/data/services/secret_store.dart';
import 'package:health_wallet/features/desktop/communication/data/services/tcp_service.dart';
import 'package:health_wallet/features/desktop/communication/presentation/bloc/communication_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MemorySecrets implements SecretStore {
  final values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
  @override
  Future<void> delete(String key) async => values.remove(key);
}

class _MemoryPrefs extends Fake implements SharedPreferences {
  final _values = <String, Object>{};

  @override
  String? getString(String key) => _values[key] as String?;
  @override
  Future<bool> setString(String key, String value) async {
    _values[key] = value;
    return true;
  }

  @override
  Future<bool> remove(String key) async {
    _values.remove(key);
    return true;
  }
}

/// No network discovery: the phone uses the address it knows.
class _NoDiscovery extends Fake implements DiscoveryService {
  @override
  Future<List<DiscoveryResult>> discoverViaNetwork({
    required String deviceId,
    required String token,
  }) async => const [];

  @override
  Future<void> startDesktopAdvertising({
    required String? ip,
    required int port,
    required String deviceId,
    required String token,
  }) async {}
}

const _fast = LinkTimings(
  handshake: Duration(seconds: 2),
  pingInterval: Duration(milliseconds: 200),
  clientIdle: Duration(seconds: 3),
  serverIdle: Duration(seconds: 3),
);

class _Device {
  _Device(this.platform, String name)
    : tcp = TcpService()
        ..timings = _fast
        ..deviceDisplayName = name,
      storage = PairingStorageService(_MemoryPrefs(), _MemorySecrets()) {
    bloc = CommunicationBloc(
      platform,
      storage,
      tcp,
      _NoDiscovery(),
      mpcAvailable: false,
    );
  }

  final AppPlatform platform;
  final TcpService tcp;
  final PairingStorageService storage;
  late final CommunicationBloc bloc;

  DesktopSyncState get state => bloc.state;

  Future<void> dispose() async {
    await bloc.close();
    await tcp.stopServer();
    tcp.dispose();
  }
}

Future<void> until(bool Function() condition, {String? reason}) async {
  final deadline = DateTime.now().add(const Duration(seconds: 10));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('timed out waiting${reason == null ? '' : ' for $reason'}');
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

void main() {
  late _Device desktop;
  final phones = <_Device>[];

  _Device phone(String name) {
    final device = _Device(AppPlatform.mobile, name);
    phones.add(device);
    return device;
  }

  setUp(() async {
    CommunicationBloc.initialReconnectDelay = const Duration(milliseconds: 200);
    desktop = _Device(AppPlatform.desktop, 'Desk');
    desktop.bloc.add(const CommunicationInitialised());
    await until(() => desktop.state.pairedDevice != null);
    // A free port, since 49152 may be taken on this machine.
    await until(() => desktop.state.pairedDevice!.lastPort > 0);
  });

  tearDown(() async {
    for (final p in phones) {
      await p.dispose();
    }
    phones.clear();
    await desktop.dispose();
  });

  /// What the phone reads from the desktop's QR code.
  DevicePairing scan() {
    final qr = DevicePairing.parseQr(desktop.state.pairedDevice!.toQrPayload());
    return (qr as ValidPairingQr).pairing.copyWith(lastIp: '127.0.0.1');
  }

  Future<void> pair(_Device device, [DevicePairing? pairing]) async {
    device.bloc.add(CommunicationPairingCompleted(pairing: pairing ?? scan()));
  }

  test('the first phone pairs, and both move to a key the QR code never '
      'showed', () async {
    final shownKey = desktop.state.pairedDevice!.pairingKey;
    final first = phone('Phone A');
    await pair(first);
    await until(
      () =>
          first.state.connectionStatus == ConnectionStatus.connected &&
          desktop.state.connectionStatus == ConnectionStatus.connected,
    );
    expect(
      first.state.connectedDeviceName,
      desktop.state.pairedDevice!.deviceName,
    );
    expect(desktop.state.connectedDeviceName, 'Phone A');

    await until(
      () =>
          desktop.state.pairedDevice!.pendingKey == null &&
          desktop.state.pairedDevice!.pairingKey != shownKey,
    );
    expect(desktop.state.pairedDevice!.peerDeviceName, 'Phone A');
    expect(
      first.state.pairedDevice!.pairingKey,
      desktop.state.pairedDevice!.pairingKey,
    );

    // Someone who photographed the QR code can't use it any more.
    final stranger = phone('Stranger');
    await pair(stranger, scan().copyWith(pairingKey: shownKey));
    await until(() => stranger.state.issue == LinkIssue.keyRejected);
    expect(stranger.state.connectionStatus, ConnectionStatus.disconnected);
  });

  test(
    'another phone with the key waits for the desktop user, who decides',
    () async {
      final first = phone('Phone A');
      await pair(first);
      await until(
        () =>
            desktop.state.pairedDevice!.peerDeviceId != null &&
            desktop.state.pairedDevice!.pendingKey == null,
      );
      first.bloc.add(const CommunicationManualDisconnect());
      await until(
        () => desktop.state.connectionStatus != ConnectionStatus.connected,
      );

      // A second phone that got the current key (e.g. scanned before the move).
      final second = phone('Phone B');
      await pair(second, scan());
      await until(
        () =>
            second.state.connectionStatus == ConnectionStatus.awaitingApproval,
      );
      await until(() => desktop.state.pendingApprovalName == 'Phone B');
      expect(desktop.state.connectionStatus, isNot(ConnectionStatus.connected));

      desktop.bloc.add(const CommunicationApprovalAnswered(accepted: false));
      await until(() => second.state.issue == LinkIssue.declined);

      final third = phone('Phone C');
      await pair(third, scan());
      await until(() => desktop.state.pendingApprovalName == 'Phone C');
      desktop.bloc.add(const CommunicationApprovalAnswered(accepted: true));
      await until(
        () => third.state.connectionStatus == ConnectionStatus.connected,
      );
      expect(desktop.state.pairedDevice!.peerDeviceName, 'Phone C');
    },
  );

  test('a phone reconnects by itself after the desktop comes back', () async {
    final first = phone('Phone A');
    await pair(first);
    await until(
      () => first.state.connectionStatus == ConnectionStatus.connected,
    );

    final pairing = desktop.state.pairedDevice!;
    await desktop.tcp.stopServer();
    await until(
      () => first.state.connectionStatus != ConnectionStatus.connected,
    );
    await desktop.tcp.startServer(
      pairingKeys: pairing.acceptedKeys,
      deviceId: pairing.deviceId,
      deviceName: pairing.deviceName,
      pairedPeerId: pairing.peerDeviceId,
      port: pairing.lastPort,
    );
    await until(
      () => first.state.connectionStatus == ConnectionStatus.connected,
      reason: 'reconnected',
    );
    expect(first.state.pairedDevice, isNotNull, reason: 'pairing kept');
  });

  test(
    'when the desktop user disconnects, the phone stays disconnected',
    () async {
      final first = phone('Phone A');
      await pair(first);
      await until(
        () => first.state.connectionStatus == ConnectionStatus.connected,
      );

      desktop.bloc.add(const CommunicationManualDisconnect());
      await until(
        () => first.state.connectionStatus == ConnectionStatus.disconnected,
      );
      await Future<void>.delayed(CommunicationBloc.initialReconnectDelay * 4);
      expect(first.state.connectionStatus, ConnectionStatus.disconnected);
    },
  );

  test('scanning another desktop while connected leaves the old one', () async {
    final first = phone('Phone A');
    await pair(first);
    await until(
      () => desktop.state.connectionStatus == ConnectionStatus.connected,
    );

    final other = DevicePairing.generate(
      deviceName: 'Other',
      localIp: '127.0.0.1',
    ).copyWith(lastPort: 1);
    await pair(first, other);
    await until(
      () => desktop.state.connectionStatus != ConnectionStatus.connected,
    );
    expect(first.state.pairedDevice!.deviceId, other.deviceId);
  });
}
