import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/config/app_platform.dart';
import 'package:health_wallet/features/desktop/communication/data/models/device_pairing.dart';
import 'package:health_wallet/features/desktop/communication/data/services/tcp_service.dart';
import 'package:health_wallet/features/desktop/communication/data/services/transport/communication_service.dart';
import 'package:health_wallet/features/desktop/communication/data/services/transport/transport_selector.dart';
import 'package:health_wallet/features/desktop/communication/presentation/bloc/communication_bloc.dart';

import '../../../../../helpers/eventually.dart';
import '../../../../../helpers/log_capture.dart';
import '../../../desktop_test_fakes.dart';
import 'communication_bloc_fakes.dart';

/// Start-up, pairing, the desktop's server and key change, as the bloc runs
/// them on each side.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final logs = captureLogs();

  late BlocTcpService tcp;
  late FakePairingStorage storage;
  late FakeDiscovery discovery;
  late FakeMpc mpc;
  late List<NetworkInterface> interfaces;
  late int phoneConnects;

  final defaultDelay = CommunicationBloc.initialReconnectDelay;

  setUp(() {
    tcp = BlocTcpService();
    storage = FakePairingStorage();
    discovery = FakeDiscovery();
    mpc = FakeMpc();
    interfaces = [FakeInterface('en0', '192.168.1.20')];
    phoneConnects = 0;
    CommunicationBloc.initialReconnectDelay = const Duration(hours: 1);
  });

  tearDown(() async {
    CommunicationBloc.initialReconnectDelay = defaultDelay;
    await tcp.close();
    await mpc.dispose();
  });

  CommunicationBloc build(AppPlatform platform, {bool withMpc = true}) {
    final bloc = CommunicationBloc(
      platform,
      storage,
      tcp,
      discovery,
      mpcTransport: withMpc ? mpc : null,
      mpcAvailable: withMpc,
      onPhoneConnected: () => phoneConnects++,
      vpnRecheckInterval: const Duration(hours: 1),
      listInterfaces: () async => interfaces,
    );
    addTearDown(bloc.close);
    return bloc;
  }

  /// The desktop, started with [pairing] stored (a new one without).
  Future<CommunicationBloc> desktop([DevicePairing? pairing]) async {
    storage.stored = pairing;
    final bloc = build(AppPlatform.desktop)
      ..add(const CommunicationInitialised());
    await eventually(() => discovery.advertised.isNotEmpty);
    return bloc;
  }

  group('start-up', () {
    test('the desktop makes a pairing, starts its server and advertises '
        'it', () async {
      final bloc = await desktop();

      final pairing = bloc.state.pairedDevice!;
      expect(storage.stored, pairing);
      expect(pairing.lastIp, '192.168.1.20');
      expect(pairing.lastPort, tcp.serverPort);
      expect(tcp.serverStarts.single.port, TcpService.defaultPort);
      final token = discoveryToken(pairing.pairingKey, pairing.deviceId);
      expect(discovery.advertised.single, (
        ip: '192.168.1.20',
        port: tcp.serverPort,
        token: token,
      ));
      expect(mpc.serverStarts.single, (port: tcp.serverPort, token: token));
      expect(bloc.state.networkUnavailable, isFalse);
    });

    test('a desktop whose server does not start says the network is '
        'unavailable', () async {
      tcp.startServerError = const SocketException('Address in use');
      final bloc = build(AppPlatform.desktop)
        ..add(const CommunicationInitialised());

      await eventually(() => bloc.state.networkUnavailable);
      expect(discovery.advertised, isEmpty);
      expect(logs, loggedWarning('the server did not start'));
    });

    test('the desktop checks its address every 30 seconds', () {
      fakeAsync((async) {
        storage.stored = pairedDesktop().copyWith(lastIp: '192.168.1.20');
        // Built here and closed below: its timers belong to this zone.
        final bloc = CommunicationBloc(
          AppPlatform.desktop,
          storage,
          tcp,
          discovery,
          mpcAvailable: false,
          vpnRecheckInterval: const Duration(hours: 1),
          listInterfaces: () async => interfaces,
        )..add(const CommunicationInitialised());
        async.flushMicrotasks();
        expect(discovery.advertised, hasLength(1));

        interfaces = [FakeInterface('en0', '10.1.1.4')];
        async
          ..elapse(const Duration(seconds: 29))
          ..flushMicrotasks();
        expect(bloc.state.pairedDevice!.lastIp, '192.168.1.20');

        async
          ..elapse(const Duration(seconds: 1))
          ..flushMicrotasks();
        expect(bloc.state.pairedDevice!.lastIp, '10.1.1.4');
        expect(discovery.advertised.last.ip, '10.1.1.4');

        bloc.close();
        async.flushMicrotasks();
      });
    });

    test('the phone with a pairing connects to it, without one it waits for '
        'a QR code', () async {
      final unpaired = build(AppPlatform.mobile)
        ..add(const CommunicationInitialised());
      await flushEvents();
      expect(unpaired.state.pairedDevice, isNull);
      expect(tcp.connectAttempts, isEmpty);

      final pairing = pairedDesktop();
      storage.stored = pairing;
      final phone = build(AppPlatform.mobile)
        ..add(const CommunicationInitialised());

      await eventually(() => tcp.connectAttempts.isNotEmpty);
      expect(phone.state.pairedDevice, pairing);
      expect(tcp.connectAttempts.first, '10.0.0.2:49152');
    });

    test('without a transport given, MPC is set up where it exists', () {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('dev.lifevalue.airdrop'),
            (_) async => null,
          );
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('dev.lifevalue.airdrop'),
              null,
            ),
      );

      final bloc = CommunicationBloc(
        AppPlatform.mobile,
        storage,
        tcp,
        discovery,
      );
      addTearDown(bloc.close);

      // Nothing to observe but that it builds on any host.
      expect(TransportSelector.isMpcAvailable(), isA<bool>());
    });
  });

  group('the desktop\'s network', () {
    test('a new address is saved and advertised, the same one changes '
        'nothing', () async {
      final bloc = await desktop(
        pairedDesktop().copyWith(lastIp: '192.168.1.20'),
      );
      final saves = storage.saved.length;

      bloc.add(const CommunicationNetworkChecked());
      await flushEvents();
      expect(storage.saved, hasLength(saves));
      expect(discovery.advertised, hasLength(1));

      interfaces = [FakeInterface('en0', '10.1.1.4')];
      bloc.add(const CommunicationNetworkChecked());
      await eventually(() => discovery.advertised.length == 2);
      expect(storage.stored!.lastIp, '10.1.1.4');
      expect(bloc.state.pairedDevice!.lastIp, '10.1.1.4');
    });

    test('losing every address says so and advertises nothing', () async {
      final bloc = await desktop(
        pairedDesktop().copyWith(lastIp: '192.168.1.20'),
      );

      interfaces = [];
      bloc.add(const CommunicationNetworkChecked());
      await eventually(() => bloc.state.networkUnavailable);

      expect(bloc.state.pairedDevice!.lastIp, isEmpty);
      expect(discovery.advertised, hasLength(1));
    });

    test('before a pairing exists there is nothing to check', () async {
      final bloc = build(AppPlatform.desktop)
        ..add(const CommunicationNetworkChecked());
      await flushEvents();

      expect(bloc.state.pairedDevice, isNull);
      expect(storage.saved, isEmpty);
    });
  });

  group('pairing', () {
    test('a new QR code on the desktop drops the phone and starts a new '
        'pairing', () async {
      final bloc = await desktop(pairedDesktop());
      final old = bloc.state.pairedDevice!;
      bloc.emit(
        bloc.state.copyWith(
          connectedDeviceName: 'Phone',
          pendingApprovalName: 'Other',
          outdatedPhoneSeen: true,
        ),
      );

      bloc.add(const CommunicationPairingRequested());
      await eventually(() => tcp.serverStarts.length == 2);
      await flushEvents();

      final pairing = bloc.state.pairedDevice!;
      expect(tcp.disconnectReasons, ['user']);
      expect(pairing.deviceId, isNot(old.deviceId));
      expect(pairing.pairingKey, isNot(old.pairingKey));
      expect(tcp.serverStarts.last.keys, [pairing.pairingKey]);
      expect(bloc.state.connectedDeviceName, isNull);
      expect(bloc.state.pendingApprovalName, isNull);
      expect(bloc.state.outdatedPhoneSeen, isFalse);
    });

    test('the phone cannot make a pairing', () async {
      final bloc = build(AppPlatform.mobile)
        ..add(const CommunicationPairingRequested());
      await flushEvents();

      expect(bloc.state.pairedDevice, isNull);
      expect(tcp.disconnectReasons, isEmpty);
    });

    test('scanning the same desktop again keeps the link, another one '
        'drops it', () async {
      tcp.state = ConnectionState.connected;
      final pairing = pairedDesktop();
      final bloc = build(AppPlatform.mobile)
        ..emit(DesktopSyncState(pairedDevice: pairing))
        ..add(CommunicationPairingCompleted(pairing: pairing));
      await flushEvents();
      expect(tcp.disconnectReasons, isEmpty);
      expect(mpc.disconnects, 0);

      bloc.add(
        CommunicationPairingCompleted(
          pairing: pairing.copyWith(pairingKey: DevicePairing.newKey()),
        ),
      );
      await eventually(() => tcp.disconnectReasons.isNotEmpty);
      expect(mpc.disconnects, 1);
    });
  });

  group('link state', () {
    test('connecting shows as discovering, once', () async {
      final bloc = build(AppPlatform.mobile);
      final states = <ConnectionStatus>[];
      final sub = bloc.stream.listen((s) => states.add(s.connectionStatus));
      addTearDown(sub.cancel);

      tcp
        ..emitState(ConnectionState.connecting)
        ..emitState(ConnectionState.connecting);
      await flushEvents();

      expect(states, [ConnectionStatus.discovering]);
    });

    test('a desktop reports what the phone it accepted is', () async {
      final bloc = await desktop(pairedDesktop());
      tcp.connectedPeer = const PeerInfo(deviceId: 'p', name: 'Phone A');

      tcp.emitState(ConnectionState.connected);
      await eventually(() => phoneConnects == 1);

      expect(bloc.state.connectionStatus, ConnectionStatus.connected);
      expect(bloc.state.connectedDeviceName, 'Phone A');
    });
  });

  group('moving to a new key', () {
    Future<CommunicationBloc> connectedDesktop({required int keyIndex}) async {
      final bloc = await desktop(
        pairedDesktop().copyWith(
          peerDeviceId: 'p',
          pendingKey: DevicePairing.newKey(),
        ),
      );
      tcp.keyIndex = keyIndex;
      tcp.emitState(ConnectionState.connected);
      await eventually(() => phoneConnects == 1);
      await flushEvents();
      return bloc;
    }

    test('a phone that reconnects with the old key is sent the new one '
        'again', () async {
      final bloc = await connectedDesktop(keyIndex: 0);

      expect(tcp.sentOf('pairing.rekey'), [
        {'key': bloc.state.pairedDevice!.pendingKey},
      ]);
    });

    test('a phone that already uses the new key makes it the only one, '
        'advertised with its token', () async {
      final pending = (await desktop(
        pairedDesktop().copyWith(
          peerDeviceId: 'p',
          pendingKey: DevicePairing.newKey(),
        ),
      )).state.pairedDevice!.pendingKey!;
      await tcp.close();
      tcp = BlocTcpService();
      discovery.advertised.clear();
      final bloc = await connectedDesktop(keyIndex: 1);
      final pairing = bloc.state.pairedDevice!;

      expect(pending, isNotEmpty);
      expect(pairing.pendingKey, isNull);
      expect(tcp.serverKeys, [pairing.pairingKey]);
      expect(storage.stored!.pendingKey, isNull);
      expect(
        discovery.advertised.last.token,
        discoveryToken(pairing.pairingKey, pairing.deviceId),
      );
      expect(tcp.sentOf('pairing.rekey'), isEmpty);
    });

    test('a new key that cannot be sent is sent on the next '
        'connection', () async {
      tcp.onSend = (_, _) async => throw const LinkNotConnectedException();

      await connectedDesktop(keyIndex: 0);

      expect(logs, loggedWarning('new key not sent yet'));
    });

    test('the phone\'s ack makes the new key the only one', () async {
      final bloc = await desktop(
        pairedDesktop().copyWith(
          peerDeviceId: 'p',
          pendingKey: DevicePairing.newKey(),
        ),
      );
      final pending = bloc.state.pairedDevice!.pendingKey;

      tcp.deliver('pairing.rekey_ack', {});
      await eventually(() => bloc.state.pairedDevice!.pendingKey == null);

      expect(bloc.state.pairedDevice!.pairingKey, pending);
    });

    group('on the phone', () {
      late CommunicationBloc phone;
      late DevicePairing pairing;

      setUp(() {
        tcp.state = ConnectionState.connected;
        pairing = pairedDesktop();
        phone = build(AppPlatform.mobile)
          ..emit(DesktopSyncState(pairedDevice: pairing));
      });

      test('takes the new key and confirms it', () async {
        final key = DevicePairing.newKey();

        tcp.deliver('pairing.rekey', {'key': key});
        await eventually(() => tcp.sentOf('pairing.rekey_ack').isNotEmpty);

        expect(phone.state.pairedDevice!.pairingKey, key);
        expect(storage.stored!.pairingKey, key);
      });

      test('a confirmation that cannot be sent is logged', () async {
        tcp.onSend = (_, _) async => throw const LinkNotConnectedException();

        tcp.deliver('pairing.rekey', {'key': DevicePairing.newKey()});
        await eventually(
          () => logs.any((e) => '${e.message}'.contains('not confirmed')),
        );

        expect(logs, loggedWarning('key change not confirmed yet'));
      });

      test('ignores a key it cannot use', () async {
        tcp
          ..deliver('pairing.rekey', {'key': 'short'})
          ..deliver('pairing.rekey', {'key': 42});
        await flushEvents();

        expect(phone.state.pairedDevice, pairing);
        expect(storage.saved, isEmpty);
        expect(
          logs.where(
            (e) => '${e.message}'.contains('ignored an unusable new key'),
          ),
          hasLength(2),
        );
      });
    });

    test('a message for the other side is logged and ignored', () async {
      final bloc = await desktop(pairedDesktop());
      final before = bloc.state;

      tcp.deliver('pairing.rekey', {'key': DevicePairing.newKey()});
      await eventually(
        () => logs.any((e) => '${e.message}'.contains('unexpected')),
      );

      expect(logs, loggedWarning('unexpected pairing.rekey'));
      expect(bloc.state, before);
    });
  });

  group('messages', () {
    test('an unreadable message is logged, others are left to their '
        'services', () async {
      final bloc = build(AppPlatform.mobile);

      tcp
        ..deliverRaw(
          TcpMessage.fromString(type: MessageType.data, data: 'not json'),
        )
        ..deliver('sync.batch', {})
        ..deliverRaw(TcpMessage.fromString(type: MessageType.data, data: '[]'));
      await flushEvents();

      expect(logs, loggedWarning('unreadable message'));
      expect(bloc.state, DesktopSyncState.initial());
    });
  });

  group('desktop', () {
    test(
      'a phone with an older app is noted, other refusals are not',
      () async {
        final bloc = build(AppPlatform.desktop);

        tcp.failures.add(LinkFailure.declined);
        await flushEvents();
        expect(bloc.state.outdatedPhoneSeen, isFalse);

        tcp.failures.add(LinkFailure.version);
        await eventually(() => bloc.state.outdatedPhoneSeen);
      },
    );

    test('advertises over MPC again after an MPC session ends', () async {
      final bloc = await desktop(pairedDesktop());
      final pairing = bloc.state.pairedDevice!;

      mpc.emitState(CommunicationState.connected);
      await flushEvents();
      expect(mpc.serverStarts, hasLength(1));

      mpc.emitState(CommunicationState.disconnected);
      await eventually(() => mpc.serverStarts.length == 2);
      expect(mpc.serverStarts.last, (
        port: pairing.lastPort,
        token: discoveryToken(pairing.pairingKey, pairing.deviceId),
      ));
    });

    test('an MPC session ending before a pairing exists changes '
        'nothing', () async {
      build(AppPlatform.desktop);

      mpc.emitState(CommunicationState.disconnected);
      await flushEvents();

      expect(mpc.serverStarts, isEmpty);
    });

    test('quitting tells the phone it is a shutdown', () async {
      final bloc = build(AppPlatform.desktop);

      await bloc.shutdown();

      expect(tcp.disconnectReasons, ['shutdown']);
    });
  });
}
