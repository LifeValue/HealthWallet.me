import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/features/desktop/lww_sync/data/services/offline_queue_service.dart';
import 'package:health_wallet/features/desktop/lww_sync/domain/entity/sync_delta.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../lww_sync_test_helpers.dart';

void main() {
  const queueKey = 'lww_offline_queue';

  late SharedPreferences prefs;
  late FakeTcpService tcp;
  late OfflineQueueService queue;

  SyncDelta delta(String table, int minute, {String id = 'row'}) => SyncDelta(
    tableName: table,
    rows: [
      {'id': '$id-$minute', 'updated_at': ms(at(minute))},
    ],
    deviceId: 'device-a',
    timestamp: at(minute),
  );

  List<String> sentRowIds() => [
    for (final m in tcp.sent)
      ((m.payload['rows'] as List).single as Map)['id'] as String,
  ];

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    tcp = FakeTcpService();
    queue = OfflineQueueService(prefs, tcp);
  });

  tearDown(() => tcp.close());

  group('replace', () {
    List<Map<String, dynamic>> queuedRows(String table) => [
      for (final d in jsonDecode(prefs.getString(queueKey)!) as List)
        if ((d as Map)['tableName'] == table)
          for (final r in d['rows'] as List) r as Map<String, dynamic>,
    ];

    test('keeps one delta per table, merging rows by id', () async {
      await queue.replace(delta('fhir_resource', 1, id: 'a'));
      await queue.replace(delta('sources', 1, id: 's'));
      await queue.replace(delta('fhir_resource', 2, id: 'b'));

      expect(queue.pendingCount, 2);
      expect(queuedRows('fhir_resource').map((r) => r['id']), [
        'a-1',
        'b-2',
      ]);
      expect(queuedRows('sources').map((r) => r['id']), ['s-1']);
    });

    test('the newer copy of a row wins', () async {
      await queue.replace(
        delta('record_notes', 1).copyWith(
          rows: [
            {'id': 7, 'content': 'old'},
          ],
        ),
      );
      await queue.replace(
        delta('record_notes', 2).copyWith(
          rows: [
            {'id': 7, 'content': 'new'},
          ],
        ),
      );

      expect(queuedRows('record_notes'), [
        {'id': 7, 'content': 'new'},
      ]);
    });
  });

  group('enqueue', () {
    test('persists deltas in order under lww_offline_queue', () async {
      await queue.enqueue(delta('fhir_resource', 1));
      await queue.enqueue(delta('sources', 2));

      expect(queue.pendingCount, 2);
      final stored = jsonDecode(prefs.getString(queueKey)!) as List<dynamic>;
      expect(
        stored.map((e) => (e as Map)['tableName']),
        ['fhir_resource', 'sources'],
      );
    });

    test('survives a new service instance (same preferences)', () async {
      await queue.enqueue(delta('fhir_resource', 1));

      final reopened = OfflineQueueService(prefs, tcp);

      expect(reopened.pendingCount, 1);
    });

    test(
      'does not deduplicate: the same delta queued twice is sent twice',
      () async {
        await queue.enqueue(delta('fhir_resource', 1));
        await queue.enqueue(delta('fhir_resource', 1));

        expect(queue.pendingCount, 2);
        expect(await queue.flush(), 2);
        expect(sentRowIds(), ['row-1', 'row-1']);
      },
    );
  });

  group('flush', () {
    test('returns 0 and sends nothing when the queue is empty', () async {
      expect(await queue.flush(), 0);
      expect(tcp.sent, isEmpty);
    });

    test(
      'sends every delta as sync.delta in FIFO order and empties the queue',
      () async {
        await queue.enqueue(delta('fhir_resource', 1));
        await queue.enqueue(delta('sources', 2));
        await queue.enqueue(delta('record_notes', 3));

        expect(await queue.flush(), 3);

        expect(tcp.sent.map((m) => m.type), everyElement('sync.delta'));
        expect(sentRowIds(), ['row-1', 'row-2', 'row-3']);
        expect(
          SyncDelta.fromJson(tcp.sent.first.payload),
          delta('fhir_resource', 1),
        );
        expect(queue.pendingCount, 0);
      },
    );

    test('stops at the first failure and keeps the rest in order', () async {
      await queue.enqueue(delta('fhir_resource', 1));
      await queue.enqueue(delta('fhir_resource', 2));
      await queue.enqueue(delta('fhir_resource', 3));
      tcp.failAfter = 1;

      expect(await queue.flush(), 1);
      expect(sentRowIds(), ['row-1']);
      expect(queue.pendingCount, 2);

      tcp.failAfter = null;
      expect(await queue.flush(), 2);
      expect(sentRowIds(), ['row-1', 'row-2', 'row-3']);
      expect(queue.pendingCount, 0);
    });

    test('keeps everything when the first send fails', () async {
      await queue.enqueue(delta('fhir_resource', 1));
      await queue.enqueue(delta('sources', 2));
      tcp.failAfter = 0;

      expect(await queue.flush(), 0);
      expect(queue.pendingCount, 2);
    });
  });

  group('acknowledge', () {
    test(
      'drops deltas of that table up to and including the ack timestamp',
      () async {
        await queue.enqueue(delta('fhir_resource', 1));
        await queue.enqueue(delta('fhir_resource', 2));
        await queue.enqueue(delta('fhir_resource', 3));
        await queue.enqueue(delta('sources', 1));

        await queue.acknowledge('fhir_resource', at(2));

        expect(queue.pendingCount, 2);
        expect(await queue.flush(), 2);
        expect(sentRowIds(), ['row-3', 'row-1']);
        expect(
          tcp.sent.map((m) => m.payload['tableName']),
          ['fhir_resource', 'sources'],
        );
      },
    );

    test('leaves the queue alone for a table with nothing queued', () async {
      await queue.enqueue(delta('fhir_resource', 1));

      await queue.acknowledge('record_notes', at(10));

      expect(queue.pendingCount, 1);
    });
  });

  test('clear removes the stored queue', () async {
    await queue.enqueue(delta('fhir_resource', 1));

    await queue.clear();

    expect(queue.pendingCount, 0);
    expect(prefs.containsKey(queueKey), isFalse);
  });

  test('a corrupt stored queue reads as empty and is discarded', () async {
    await prefs.setString(queueKey, '{not json');

    expect(queue.pendingCount, 0);
    expect(prefs.containsKey(queueKey), isFalse);
    expect(await queue.flush(), 0);
  });

  test(
    'a stored queue with an invalid entry is discarded as a whole',
    () async {
      await queue.enqueue(delta('fhir_resource', 1));
      final stored = jsonDecode(prefs.getString(queueKey)!) as List<dynamic>;
      await prefs.setString(queueKey, jsonEncode([...stored, 42]));

      expect(queue.pendingCount, 0);
      expect(prefs.containsKey(queueKey), isFalse);
    },
  );
}
