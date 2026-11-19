import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/features/desktop/communication/data/services/transport/communication_service.dart';
import 'package:health_wallet/features/desktop/communication/data/services/transport/mpc_transport.dart';

import '../../../../desktop_test_fakes.dart';

const _channel = MethodChannel('dev.lifevalue.airdrop');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late List<MethodCall> calls;
  late Set<String> failing;
  late MpcTransport transport;

  /// Simulates the native side calling into Dart.
  Future<void> fromNative(String method, [Object? arguments]) async {
    await messenger.handlePlatformMessage(
      _channel.name,
      _channel.codec.encodeMethodCall(MethodCall(method, arguments)),
      (_) {},
    );
    await flushEvents();
  }

  setUp(() {
    calls = [];
    failing = {};
    messenger.setMockMethodCallHandler(_channel, (call) async {
      calls.add(call);
      if (failing.contains(call.method)) {
        throw PlatformException(code: 'failed');
      }
      return null;
    });
    transport = MpcTransport();
  });

  tearDown(() async {
    await transport.dispose();
    messenger.setMockMethodCallHandler(_channel, null);
  });

  test('starts disconnected as the MPC transport', () {
    expect(transport.transportType, TransportType.multipeerConnectivity);
    expect(transport.currentState, CommunicationState.disconnected);
  });

  test(
    'startServer advertises the pairing token and goes to connecting',
    () async {
      final states = <CommunicationState>[];
      final sub = transport.stateStream.listen(states.add);

      await transport.startServer(port: 49152, token: 'tok');
      await flushEvents();
      await sub.cancel();

      expect(calls.single.method, 'startDesktopAdvertising');
      expect(calls.single.arguments, {'token': 'tok'});
      expect(states, [CommunicationState.connecting]);
    },
  );

  test('without a token nothing is advertised or browsed', () async {
    await transport.startServer(port: 49152);
    await transport.connect(address: '', port: 0);
    expect(calls, isEmpty);
  });

  test('a failed advertise falls back to disconnected', () async {
    failing.add('startDesktopAdvertising');

    await transport.startServer(port: 49152, token: 'tok');

    expect(transport.currentState, CommunicationState.disconnected);
  });

  test(
    'connect browses for the token and a failed browse falls back to '
    'disconnected',
    () async {
      await transport.connect(address: '', port: 0, token: 'tok');
      expect(calls.single.method, 'startDesktopBrowsing');
      expect(calls.single.arguments, {'token': 'tok'});
      expect(transport.currentState, CommunicationState.connecting);

      failing.add('startDesktopBrowsing');
      await transport.connect(address: '', port: 0, token: 'tok');
      expect(transport.currentState, CommunicationState.disconnected);
    },
  );

  test('a native advertise or browse failure ends the attempt', () async {
    await transport.connect(address: '', port: 0, token: 'tok');
    await fromNative('onSyncError', {'message': 'Browsing failed'});
    expect(transport.currentState, CommunicationState.disconnected);
  });

  test('follows native connect and disconnect events', () async {
    await fromNative('onSyncConnected', {'deviceName': 'Mac'});
    expect(transport.currentState, CommunicationState.connected);

    await fromNative('onSyncDisconnected');
    expect(transport.currentState, CommunicationState.disconnected);
  });

  test('passes received bytes through unchanged', () async {
    final data = transport.dataStream.first;
    await fromNative(
      'onSyncDataReceived',
      Uint8List.fromList([0, 1, 2, 255]),
    );

    expect(await data, [0, 1, 2, 255]);
  });

  test('sends bytes to the native side; a failed send throws', () async {
    await transport.send(Uint8List.fromList([9, 8, 7]));
    expect(calls.single.method, 'sendSyncData');
    expect(calls.single.arguments, {
      'data': [9, 8, 7],
    });

    failing.add('sendSyncData');
    await expectLater(
      transport.send(Uint8List(1)),
      throwsA(isA<PlatformException>()),
    );
  });

  test('disconnect tells the native side even when it fails', () async {
    await fromNative('onSyncConnected', {'deviceName': 'Mac'});
    failing.add('disconnectDesktopSync');

    await transport.disconnect();

    expect(calls.last.method, 'disconnectDesktopSync');
    expect(transport.currentState, CommunicationState.disconnected);
  });
}
