import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/features/desktop/communication/data/services/message_router.dart';
import 'package:health_wallet/features/desktop/communication/data/services/tcp_service.dart';

import '../../../desktop_test_fakes.dart';

void main() {
  late FakeTcpService tcp;
  late MessageRouter router;

  setUp(() {
    tcp = FakeTcpService();
    router = MessageRouter(tcp);
  });

  tearDown(() async {
    router.dispose();
    await tcp.close();
  });

  Future<List<Map<String, dynamic>>> collect(
    String type,
    void Function() act,
  ) async {
    final received = <Map<String, dynamic>>[];
    final sub = router.on(type).listen(received.add);
    act();
    await flushEvents();
    await sub.cancel();
    return received;
  }

  test('routes a data envelope to listeners of its type only', () async {
    final other = <Map<String, dynamic>>[];
    final otherSub = router.on('sync.ack').listen(other.add);

    final received = await collect('sync.delta', () {
      tcp.deliver('sync.delta', {'table': 'sources', 'rows': <dynamic>[]});
    });

    await otherSub.cancel();
    expect(received, [
      {'table': 'sources', 'rows': <dynamic>[]},
    ]);
    expect(other, isEmpty);
  });

  test('keeps the order messages arrived in', () async {
    final received = await collect('backup.chunk', () {
      for (var i = 0; i < 50; i++) {
        tcp.deliver('backup.chunk', {'seq': i});
      }
    });

    expect(received.map((p) => p['seq']), List.generate(50, (i) => i));
  });

  test('delivers to every listener of a type', () async {
    final first = <Map<String, dynamic>>[];
    final second = <Map<String, dynamic>>[];
    final a = router.on('handover.accept').listen(first.add);
    final b = router.on('handover.accept').listen(second.add);

    tcp.deliver('handover.accept', {'session_id': 's'});
    await flushEvents();
    await a.cancel();
    await b.cancel();

    expect(first, hasLength(1));
    expect(second, hasLength(1));
  });

  test('a missing payload becomes an empty map', () async {
    final received = await collect('backup.request', () {
      tcp.deliverRaw(
        TcpMessage.fromString(
          type: MessageType.data,
          data: jsonEncode({'type': 'backup.request'}),
        ),
      );
    });

    expect(received, [<String, dynamic>{}]);
  });

  test('messages with no listener yet are dropped, not queued', () async {
    tcp.deliver('handover.offer', {'session_id': 'early'});
    await flushEvents();

    final received = await collect('handover.offer', () {
      tcp.deliver('handover.offer', {'session_id': 'late'});
    });

    expect(received, [
      {'session_id': 'late'},
    ]);
  });

  test('ignores non-data frames', () async {
    final received = await collect('x', () {
      for (final type in [
        MessageType.hello,
        MessageType.ack,
        MessageType.ping,
        MessageType.pong,
        MessageType.kill,
      ]) {
        tcp.deliverRaw(
          TcpMessage.fromString(
            type: type,
            data: jsonEncode({'type': 'x', 'payload': <String, dynamic>{}}),
          ),
        );
      }
    });

    expect(received, isEmpty);
  });

  test('survives malformed envelopes and keeps routing', () async {
    final malformed = <TcpMessage>[
      TcpMessage(type: MessageType.data, payload: Uint8List(0)),
      TcpMessage.fromString(type: MessageType.data, data: 'not json'),
      TcpMessage.fromString(type: MessageType.data, data: '[1, 2]'),
      TcpMessage.fromString(type: MessageType.data, data: '{"payload": {}}'),
      TcpMessage.fromString(type: MessageType.data, data: '{"type": 5}'),
      TcpMessage.fromString(
        type: MessageType.data,
        data: '{"type": "x", "payload": [1]}',
      ),
      // Invalid UTF-8.
      TcpMessage(
        type: MessageType.data,
        payload: Uint8List.fromList([0xC3, 0x28]),
      ),
    ];

    final received = await collect('x', () {
      malformed.forEach(tcp.deliverRaw);
      tcp.deliver('x', {'ok': true});
    });

    expect(received, [
      {'ok': true},
    ]);
  });

  test('unknown types are ignored', () async {
    final received = await collect('known', () {
      tcp.deliver('unknown.type', {'a': 1});
      tcp.deliver('known', {'b': 2});
    });

    expect(received, [
      {'b': 2},
    ]);
  });

  test('dispose closes every stream and stops routing', () async {
    final stream = router.on('sync.delta');
    final done = expectLater(stream, emitsDone);

    router.dispose();
    tcp.deliver('sync.delta', {});
    await done;
  });

  test('a router disposed early no longer receives anything', () async {
    router.dispose();

    final received = await collect('a', () => tcp.deliver('a', {'n': 1}));
    expect(received, isEmpty);
  });
}
