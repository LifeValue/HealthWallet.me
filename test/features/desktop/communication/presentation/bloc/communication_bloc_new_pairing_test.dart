import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/config/app_platform.dart';
import 'package:health_wallet/features/desktop/communication/data/models/device_pairing.dart';
import 'package:health_wallet/features/desktop/communication/data/services/discovery_service.dart';
import 'package:health_wallet/features/desktop/communication/data/services/tcp_service.dart';
import 'package:health_wallet/features/desktop/communication/presentation/bloc/communication_bloc.dart';

import 'communication_bloc_fakes.dart';

/// [BlocTcpService] that also records the key each attempt used.
class _KeyTcpService extends BlocTcpService {
  final keysTried = <String>[];

  @override
  Future<void> connectToServer({
    required String ip,
    required int port,
    required String pairingKey,
    required String expectedDeviceId,
    required String localDeviceId,
    Duration timeout = const Duration(seconds: 10),
  }) {
    keysTried.add(pairingKey);
    return super.connectToServer(
      ip: ip,
      port: port,
      pairingKey: pairingKey,
      expectedDeviceId: expectedDeviceId,
      localDeviceId: localDeviceId,
      timeout: timeout,
    );
  }
}

/// A QR code scanned on the phone while it is still trying to reach the
/// desktop with the key it had: the running attempt is given up and the new
/// key is tried.
void main() {
  late _KeyTcpService tcp;
  late FakePairingStorage storage;
  late FakeDiscovery discovery;
  late DevicePairing oldPairing;
  late DevicePairing newPairing;

  final defaultTimeout = CommunicationBloc.connectionAttemptTimeout;
  final defaultDelay = CommunicationBloc.initialReconnectDelay;

  setUp(() {
    tcp = _KeyTcpService();
    oldPairing = pairedDesktop();
    // The desktop restarted and its user made a new QR code.
    newPairing = oldPairing.copyWith(pairingKey: DevicePairing.newKey());
    storage = FakePairingStorage(oldPairing);
    discovery = FakeDiscovery();
    CommunicationBloc.connectionAttemptTimeout = const Duration(seconds: 60);
    CommunicationBloc.initialReconnectDelay = const Duration(seconds: 3);
  });

  tearDown(() async {
    CommunicationBloc.connectionAttemptTimeout = defaultTimeout;
    CommunicationBloc.initialReconnectDelay = defaultDelay;
    await tcp.close();
  });

  /// The phone, paired with [oldPairing], trying to connect. Built inside
  /// the fake zone so its timers belong to it.
  CommunicationBloc connect(FakeAsync async) {
    final bloc =
        CommunicationBloc(
            AppPlatform.mobile,
            storage,
            tcp,
            discovery,
            mpcAvailable: false,
          )
          ..emit(DesktopSyncState(pairedDevice: oldPairing))
          ..add(const CommunicationConnectionRequested());
    async.flushMicrotasks();
    return bloc;
  }

  void settle(FakeAsync async) => async
    ..flushMicrotasks()
    ..elapse(Duration.zero)
    ..flushMicrotasks();

  void close(FakeAsync async, CommunicationBloc bloc) {
    bloc.close();
    async.flushMicrotasks();
  }

  /// The desktop accepts only the new key; the old one waits on [oldAnswer].
  void desktopWithNewKey(Completer<void> oldAnswer) =>
      tcp.onConnect = (ip, port) async {
        if (tcp.keysTried.last == oldPairing.pairingKey) {
          await oldAnswer.future;
          return;
        }
        tcp.emitState(ConnectionState.connected);
      };

  group('a QR code scanned while an attempt runs', () {
    test('is tried even when the old attempt then hears "unknown key"', () {
      fakeAsync((async) {
        final oldAnswer = Completer<void>();
        desktopWithNewKey(oldAnswer);
        final bloc = connect(async);
        expect(tcp.keysTried, [oldPairing.pairingKey]);

        bloc.add(CommunicationPairingCompleted(pairing: newPairing));
        settle(async);
        // The old attempt reaches the desktop, which no longer knows its key.
        oldAnswer.completeError(const LinkException(LinkFailure.unknownKey));
        settle(async);

        expect(tcp.keysTried.last, newPairing.pairingKey);
        expect(bloc.state.connectionStatus, ConnectionStatus.connected);
        expect(bloc.state.issue, isNull);
        expect(bloc.state.pairedDevice, newPairing);
        close(async, bloc);
      });
    });

    test('ends the old attempt at once, whatever step it waits on', () {
      fakeAsync((async) {
        // E.g. a connection to the old address that never answers.
        final oldAnswer = Completer<void>();
        desktopWithNewKey(oldAnswer);
        final bloc = connect(async);

        bloc.add(CommunicationPairingCompleted(pairing: newPairing));
        settle(async);

        expect(tcp.keysTried, [oldPairing.pairingKey, newPairing.pairingKey]);
        expect(bloc.state.connectionStatus, ConnectionStatus.connected);

        // Its late answer changes nothing.
        oldAnswer.completeError(const LinkException(LinkFailure.unknownKey));
        settle(async);
        expect(bloc.state.connectionStatus, ConnectionStatus.connected);
        expect(bloc.state.issue, isNull);
        expect(discovery.searches, 0);
        close(async, bloc);
      });
    });

    test('the attempt with the new key still gives up after 60 s and tries '
        'again', () {
      fakeAsync((async) {
        // Neither key reaches the desktop: every step hangs.
        tcp.onConnect = (ip, port) => Completer<void>().future;
        final bloc = connect(async);

        async.elapse(const Duration(seconds: 30));
        bloc.add(CommunicationPairingCompleted(pairing: newPairing));
        settle(async);
        expect(tcp.keysTried, [oldPairing.pairingKey, newPairing.pairingKey]);

        async.elapse(const Duration(seconds: 59));
        expect(bloc.state.connectionStatus, ConnectionStatus.discovering);

        async.elapse(const Duration(seconds: 1));
        expect(bloc.state.issue, LinkIssue.notFound);
        expect(bloc.state.connectionStatus, ConnectionStatus.disconnected);

        async.elapse(const Duration(seconds: 3));
        expect(tcp.keysTried, [
          oldPairing.pairingKey,
          newPairing.pairingKey,
          newPairing.pairingKey,
        ]);
        close(async, bloc);
      });
    });

    test('the same QR code scanned again leaves the attempt running', () {
      fakeAsync((async) {
        final answer = Completer<void>();
        tcp.onConnect = (ip, port) async {
          await answer.future;
          tcp.emitState(ConnectionState.connected);
        };
        final bloc = connect(async);

        bloc.add(CommunicationPairingCompleted(pairing: oldPairing));
        settle(async);
        expect(tcp.keysTried, [oldPairing.pairingKey]);

        answer.complete();
        settle(async);
        expect(bloc.state.connectionStatus, ConnectionStatus.connected);
        expect(tcp.keysTried, [oldPairing.pairingKey]);
        close(async, bloc);
      });
    });
  });

  test('a QR code scanned with no attempt running is tried', () {
    fakeAsync((async) {
      discovery.onSearch = () async => const <DiscoveryResult>[];
      tcp.onConnect = (ip, port) async {
        if (tcp.keysTried.last == oldPairing.pairingKey) {
          throw const LinkException(LinkFailure.unknownKey);
        }
        tcp.emitState(ConnectionState.connected);
      };
      final bloc = connect(async);
      settle(async);
      expect(bloc.state.issue, LinkIssue.keyRejected);

      bloc.add(CommunicationPairingCompleted(pairing: newPairing));
      settle(async);

      expect(tcp.keysTried, [oldPairing.pairingKey, newPairing.pairingKey]);
      expect(bloc.state.connectionStatus, ConnectionStatus.connected);
      expect(bloc.state.issue, isNull);
      close(async, bloc);
    });
  });
}
