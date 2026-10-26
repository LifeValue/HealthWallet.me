import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/features/desktop/lww_sync/domain/entity/sync_delta.dart';

void main() {
  final timestamp = DateTime.utc(2025, 3, 4, 5, 6, 7, 890);
  final delta = SyncDelta(
    tableName: 'fhir_resource',
    rows: [
      {
        'id': 'obs-1',
        'updated_at': 1735732800000,
        'device_id': 'device-a',
        'deleted_at': null,
        'resource_raw': '{"resourceType":"Observation"}',
      },
      {'id': 'obs-2', 'updated_at': 1735732800001, 'score': 1.5},
    ],
    deviceId: 'device-a',
    timestamp: timestamp,
  );

  group('SyncDelta', () {
    test('toJson uses the camelCase keys the peer decodes', () {
      final json = delta.toJson();

      expect(
        json.keys,
        unorderedEquals(<String>[
          'tableName',
          'rows',
          'deviceId',
          'timestamp',
        ]),
      );
      expect(json['tableName'], 'fhir_resource');
      expect(json['deviceId'], 'device-a');
      expect(json['timestamp'], '2025-03-04T05:06:07.890Z');
      expect(json['rows'], delta.rows);
    });

    test('survives a JSON wire round trip unchanged', () {
      final wire = jsonEncode(delta.toJson());
      final decoded = SyncDelta.fromJson(
        jsonDecode(wire) as Map<String, dynamic>,
      );

      expect(decoded, delta);
      expect(
        decoded.timestamp.millisecondsSinceEpoch,
        timestamp.millisecondsSinceEpoch,
      );
      expect(decoded.rows.first['deleted_at'], isNull);
      expect(decoded.rows.first.containsKey('deleted_at'), isTrue);
      expect(decoded.rows.last['score'], 1.5);
    });

    test('keeps an empty row list', () {
      final empty = delta.copyWith(rows: const []);
      final decoded = SyncDelta.fromJson(
        jsonDecode(jsonEncode(empty.toJson())) as Map<String, dynamic>,
      );

      expect(decoded.rows, isEmpty);
      expect(decoded.tableName, 'fhir_resource');
    });

    test('compares by value and copyWith replaces only the given field', () {
      final same = SyncDelta(
        tableName: delta.tableName,
        rows: [
          for (final row in delta.rows) Map<String, dynamic>.from(row),
        ],
        deviceId: delta.deviceId,
        timestamp: delta.timestamp,
      );
      final other = delta.copyWith(deviceId: 'device-b');

      expect(same, delta);
      expect(same.hashCode, delta.hashCode);
      expect(other, isNot(delta));
      expect(other.tableName, delta.tableName);
      expect(other.rows, delta.rows);
      expect(other.deviceId, 'device-b');
      expect(delta.toString(), contains('fhir_resource'));
    });

    test('fromJson rejects a payload without a table name', () {
      expect(
        () => SyncDelta.fromJson({
          'rows': <dynamic>[],
          'deviceId': 'x',
          'timestamp': timestamp.toIso8601String(),
        }),
        throwsA(isA<TypeError>()),
      );
    });
  });
}
