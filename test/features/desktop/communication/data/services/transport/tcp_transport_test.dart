import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/features/desktop/communication/data/services/tcp_service.dart'
    as tcp;
import 'package:health_wallet/features/desktop/communication/data/services/transport/communication_service.dart';
import 'package:health_wallet/features/desktop/communication/data/services/transport/tcp_transport.dart';

import '../../../../desktop_test_fakes.dart';

void main() {
  late FakeTcpService service;
  late TcpTransport transport;

  setUp(() {
    service = FakeTcpService();
    transport = TcpTransport(service);
  });

  tearDown(() => service.close());

  test('is the TCP transport', () {
    expect(transport.transportType, TransportType.tcp);
  });

  test('maps every connection state', () {
    const pairs = {
      tcp.ConnectionState.disconnected: CommunicationState.disconnected,
      tcp.ConnectionState.connecting: CommunicationState.connecting,
      tcp.ConnectionState.connected: CommunicationState.connected,
    };
    for (final MapEntry(:key, :value) in pairs.entries) {
      service.state = key;
      expect(transport.currentState, value);
    }
  });

  test('stateStream follows the service', () async {
    final states = transport.stateStream.take(3).toList();
    service
      ..emitState(tcp.ConnectionState.connecting)
      ..emitState(tcp.ConnectionState.connected)
      ..emitState(tcp.ConnectionState.disconnected);

    expect(await states, [
      CommunicationState.connecting,
      CommunicationState.connected,
      CommunicationState.disconnected,
    ]);
  });

  test('dataStream prefixes each payload with its type code', () async {
    final data = transport.dataStream.take(2).toList();
    service
      ..deliverRaw(
        tcp.TcpMessage(
          type: tcp.MessageType.data,
          payload: Uint8List.fromList([1, 2, 3]),
        ),
      )
      ..deliverRaw(
        tcp.TcpMessage(type: tcp.MessageType.ping, payload: Uint8List(0)),
      );

    expect(await data, [
      [0x05, 1, 2, 3],
      [0x03],
    ]);
  });

  test('server, connect and send are not supported through this wrapper', () {
    expect(
      () => transport.startServer(port: 1),
      throwsA(isA<UnimplementedError>()),
    );
    expect(
      () => transport.connect(address: 'a', port: 1),
      throwsA(isA<UnimplementedError>()),
    );
    expect(
      () => transport.send(Uint8List(1)),
      throwsA(isA<UnimplementedError>()),
    );
  });

  test('disconnect and dispose delegate to the service', () async {
    await transport.disconnect();
    await transport.dispose();

    expect(service.disconnectCalls, 1);
    expect(service.stopServerCalls, 1);
  });
}
