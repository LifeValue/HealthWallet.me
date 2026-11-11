import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/config/app_platform.dart';
import 'package:health_wallet/features/desktop/communication/data/models/device_pairing.dart';
import 'package:health_wallet/features/desktop/communication/data/services/discovery_service.dart';
import 'package:health_wallet/features/desktop/communication/data/services/tcp_service.dart';
import 'package:health_wallet/features/desktop/communication/presentation/bloc/communication_bloc.dart';

import '../../../../../helpers/eventually.dart';
import '../../../../../helpers/log_capture.dart';
import '../../../desktop_test_fakes.dart';
import 'communication_bloc_fakes.dart';

/// The phone looking for its desktop: the saved address, every address
/// discovery finds, then MPC, all within one attempt that can't hang.
void main() {
  final logs = captureLogs();

  late BlocTcpService tcp;
  late FakePairingStorage storage;
  late FakeDiscovery discovery;
  late DevicePairing pairing;

  final defaultTimeout = CommunicationBloc.connectionAttemptTimeout;
  final defaultDelay = CommunicationBloc.initialReconnectDelay;

  setUp(() {
    tcp = BlocTcpService();
    pairing = pairedDesktop();
    storage = FakePairingStorage(pairing);
    discovery = FakeDiscovery();
    // Long enough that neither fires during a test unless it says so.
    CommunicationBloc.connectionAttemptTimeout = const Duration(hours: 1);
    CommunicationBloc.initialReconnectDelay = const Duration(hours: 1);
  });

  tearDown(() async {
    CommunicationBloc.connectionAttemptTimeout = defaultTimeout;
    CommunicationBloc.initialReconnectDelay = defaultDelay;
    await tcp.close();
  });

  /// The phone, paired with [pairing], asked to connect.
  CommunicationBloc connect({FakeMpc? mpc}) {
    final bloc = CommunicationBloc(
      AppPlatform.mobile,
      storage,
      tcp,
      discovery,
      mpcTransport: mpc,
      mpcAvailable: mpc != null,
    );
    addTearDown(bloc.close);
    bloc
      ..emit(bloc.state.copyWith(pairedDevice: pairing))
      ..add(const CommunicationConnectionRequested());
    return bloc;
  }

  /// A desktop that accepts the phone at [ip]:[port] only.
  void desktopAt(String ip, int port) => tcp.onConnect = (i, p) async {
    if (i != ip || p != port) throw StateError('nothing listens at $i:$p');
    tcp.emitState(ConnectionState.connected);
  };

  bool notFound(CommunicationBloc bloc) =>
      bloc.state.connectionStatus == ConnectionStatus.disconnected &&
      bloc.state.issue == LinkIssue.notFound;

  group('every address is tried', () {
    test('the saved address first, then every address discovery finds, '
        'until one is the desktop', () async {
      // A desktop that restarted on another port, with its old Bonjour
      // entry still around.
      discovery.onSearch = () async => [
        found('10.0.0.2', 49152),
        found('desk.local.', 49152),
        found('desk.local.', 50123),
      ];
      desktopAt('desk.local.', 50123);

      final bloc = connect();
      await eventually(
        () => bloc.state.connectionStatus == ConnectionStatus.connected,
      );

      expect(tcp.connectAttempts, [
        '10.0.0.2:49152',
        'desk.local.:49152',
        'desk.local.:50123',
      ]);
      expect(storage.lastConnections, ['desk.local.:50123']);
      expect(discovery.searches, 1);
    });

    test('the saved address answering is enough', () async {
      desktopAt('10.0.0.2', 49152);

      final bloc = connect();
      await eventually(
        () => bloc.state.connectionStatus == ConnectionStatus.connected,
      );

      expect(discovery.searches, 0);
      expect(storage.lastConnections, ['10.0.0.2:49152']);
    });

    test('a desktop that answers no ends the attempt, without trying the '
        'other addresses or again later', () async {
      CommunicationBloc.initialReconnectDelay = const Duration(
        milliseconds: 10,
      );
      discovery.onSearch = () async => [
        found('10.0.0.5', 49152),
        found('10.0.0.6', 49152),
      ];
      tcp.onConnect = (ip, _) async {
        if (ip == '10.0.0.5') throw const LinkException(LinkFailure.unknownKey);
        throw StateError('nothing listens at $ip');
      };
      final mpc = FakeMpc();

      final bloc = connect(mpc: mpc);
      await eventually(() => bloc.state.issue == LinkIssue.keyRejected);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(tcp.connectAttempts, ['10.0.0.2:49152', '10.0.0.5:49152']);
      expect(mpc.connects, 0);
      expect(discovery.searches, 1);
      expect(bloc.state.connectionStatus, ConnectionStatus.disconnected);
    });

    test(
      'a phone without an address tries only what discovery finds',
      () async {
        pairing = pairing.copyWith(lastIp: '');
        discovery.onSearch = () async => [found('10.0.0.5', 49152)];

        final bloc = connect();
        await eventually(() => notFound(bloc));

        expect(tcp.connectAttempts, ['10.0.0.5:49152']);
      },
    );
  });

  group('MPC', () {
    test('is tried last, and connects', () async {
      final mpc = FakeMpc();
      tcp.onConnectOverMpc = () async =>
          tcp.emitState(ConnectionState.connected);

      final bloc = connect(mpc: mpc);
      await eventually(
        () => bloc.state.connectionStatus == ConnectionStatus.connected,
      );

      expect(mpc.connects, 1);
      expect(tcp.mpcHandshakes, 1);
      expect(tcp.mpcCancels, 0);
      expect(mpc.disconnects, 0);
    });

    test('a Mac that declines ends the attempt and stops browsing', () async {
      final mpc = FakeMpc();
      tcp.onConnectOverMpc = () async =>
          throw const LinkException(LinkFailure.declined);

      final bloc = connect(mpc: mpc);
      await eventually(() => bloc.state.issue == LinkIssue.declined);

      expect(tcp.mpcCancels, 1);
      expect(mpc.disconnects, 1);
    });

    test('a Mac not found, or browsing that fails, ends as not found and '
        'stops browsing', () async {
      final mpc = FakeMpc()..onConnect = () async => throw StateError('no MPC');

      final bloc = connect(mpc: mpc);
      await eventually(() => notFound(bloc));

      expect(tcp.mpcHandshakes, 0);
      expect(tcp.mpcCancels, 1);
      expect(mpc.disconnects, 1);
    });
  });

  group('an attempt that hangs', () {
    setUp(
      () => CommunicationBloc.connectionAttemptTimeout = const Duration(
        milliseconds: 200,
      ),
    );

    test('ends as not found, so the phone shows Reconnect and tries '
        'again', () async {
      CommunicationBloc.initialReconnectDelay = const Duration(
        milliseconds: 10,
      );
      // E.g. a Bonjour lookup that never returns.
      discovery.onSearch = () => Completer<List<DiscoveryResult>>().future;

      final bloc = connect();
      await eventually(() => notFound(bloc));
      expect(logs, loggedWarning('no desktop found in time'));

      await eventually(() => discovery.searches == 2);
    });

    test('still gives up after five more tries', () async {
      CommunicationBloc.initialReconnectDelay = const Duration(
        milliseconds: 5,
      );
      discovery.onSearch = () => Completer<List<DiscoveryResult>>().future;

      final bloc = connect();
      // The first attempt and five retries, 5 to 80 ms apart.
      await eventually(() => discovery.searches == 6);
      await eventually(() => notFound(bloc));
      await Future<void>.delayed(const Duration(milliseconds: 300));

      expect(discovery.searches, 6);
      expect(bloc.state.connectionStatus, ConnectionStatus.disconnected);
    });

    test('tries nothing more once given up, whatever returns late', () async {
      final search = Completer<List<DiscoveryResult>>();
      discovery.onSearch = () => search.future;
      final mpc = FakeMpc();

      final bloc = connect(mpc: mpc);
      await eventually(() => notFound(bloc));
      search.complete([found('10.0.0.5', 49152)]);
      await flushEvents();

      expect(tcp.connectAttempts, ['10.0.0.2:49152']);
      expect(mpc.connects, 0);
      expect(notFound(bloc), isTrue);
    });

    test('a hanging address is not followed by the next one once given '
        'up', () async {
      final saved = Completer<void>();
      tcp.onConnect = (ip, port) => saved.future;
      final mpc = FakeMpc();

      final bloc = connect(mpc: mpc);
      await eventually(() => notFound(bloc));
      saved.completeError(StateError('refused, late'));
      await flushEvents();

      expect(tcp.connectAttempts, ['10.0.0.2:49152']);
      expect(discovery.searches, 0);
    });

    test('an address found late is not tried once given up', () async {
      final lookup = Completer<void>();
      discovery.onSearch = () async => [
        found('10.0.0.5', 49152),
        found('10.0.0.6', 49152),
      ];
      tcp.onConnect = (ip, port) async {
        if (ip == '10.0.0.5') await lookup.future;
        throw StateError('nothing listens at $ip');
      };

      final bloc = connect();
      await eventually(() => notFound(bloc));
      lookup.complete();
      await flushEvents();

      expect(tcp.connectAttempts, ['10.0.0.2:49152', '10.0.0.5:49152']);
    });

    test('MPC that never answers is stopped, and its late answer leads '
        'nowhere', () async {
      final browsing = Completer<void>();
      final mpc = FakeMpc()..onConnect = () => browsing.future;

      final bloc = connect(mpc: mpc);
      await eventually(() => notFound(bloc));
      expect(tcp.mpcCancels, 1);
      await eventually(() => mpc.disconnects == 1);

      browsing.complete();
      await flushEvents();
      expect(tcp.mpcHandshakes, 0);
    });

    test('a late MPC failure does not stop a newer attempt\'s '
        'browsing', () async {
      final handshake = Completer<void>();
      tcp.onConnectOverMpc = () => handshake.future;
      final mpc = FakeMpc();

      final bloc = connect(mpc: mpc);
      await eventually(() => notFound(bloc));
      expect(tcp.mpcCancels, 1);

      handshake.completeError(const LinkException(LinkFailure.noAnswer));
      await flushEvents();
      expect(tcp.mpcCancels, 1);
      expect(mpc.disconnects, 1);
    });

    test('a device id read that never returns is given up too', () async {
      storage.localId = () => Completer<String>().future;

      final bloc = connect();
      await eventually(() => notFound(bloc));

      expect(tcp.connectAttempts, isEmpty);
    });

    test(
      'a step that returns after the bloc closed tries nothing more',
      () async {
        CommunicationBloc.connectionAttemptTimeout = const Duration(hours: 1);
        final search = Completer<List<DiscoveryResult>>();
        discovery.onSearch = () => search.future;

        final bloc = connect();
        await eventually(() => discovery.searches == 1);
        await bloc.close();
        search.complete([found('10.0.0.5', 49152)]);
        await flushEvents();

        expect(tcp.connectAttempts, ['10.0.0.2:49152']);
      },
    );
  });
}
