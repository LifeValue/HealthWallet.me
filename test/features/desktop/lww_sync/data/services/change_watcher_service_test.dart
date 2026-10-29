import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/data/local/app_database.dart';
import 'package:health_wallet/features/desktop/lww_sync/data/services/attachment_sync_service.dart';
import 'package:health_wallet/features/desktop/lww_sync/data/services/change_watcher_service.dart';
import 'package:health_wallet/features/desktop/lww_sync/data/services/lww_sync_service.dart';
import 'package:health_wallet/features/desktop/lww_sync/data/services/offline_queue_service.dart';
import 'package:health_wallet/features/desktop/lww_sync/domain/entity/sync_delta.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../lww_sync_test_helpers.dart';

/// The watcher listens to drift table streams and debounces with a 500 ms
/// [Timer]. Drift's stream store keeps scheduling timers after a listener is
/// cancelled, which never settles under `fakeAsync`/`testWidgets`, so these
/// tests run in real time. They wait for an observable outcome (a send, a
/// queued delta) rather than for a fixed delay; a fixed wait is only used to
/// assert that something does *not* happen, which cannot produce a false
/// failure on a slow machine.
void main() {
  late AppDatabase db;
  late SharedPreferences prefs;
  late FakeTcpService tcp;
  late LwwSyncService sync;
  late OfflineQueueService queue;
  late ChangeWatcherService watcher;

  const quietPeriod = Duration(milliseconds: 900);

  Future<void> setUpWatcher({
    bool connected = true,
    int? lastSync,
    String documentsPath = '/nonexistent',
  }) async {
    SharedPreferences.setMockInitialValues({
      'lww_local_device_id': 'device-local',
      'lww_last_sync_timestamp': ?lastSync,
    });
    prefs = await SharedPreferences.getInstance();
    db = openTestDatabase();
    tcp = FakeTcpService(connected: connected);
    sync = LwwSyncService(
      db,
      prefs,
      AttachmentSyncService(FakePathResolver(documentsPath)),
    );
    queue = OfflineQueueService(prefs, tcp);
    watcher = ChangeWatcherService(db, sync, tcp, queue);
    addTearDown(() async {
      watcher.dispose();
      await db.close();
      await tcp.close();
    });
  }

  Future<void> waitUntil(bool Function() condition) async {
    final deadline = DateTime.now().add(const Duration(seconds: 10));
    while (!condition()) {
      if (DateTime.now().isAfter(deadline)) {
        fail('condition not met within 10 s');
      }
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    // Let the rest of the send loop (queueing, last-sync update) finish.
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }

  List<String> sentTables() => [
    for (final m in tcp.sentOfType('sync.delta'))
      m.payload['tableName'] as String,
  ];

  test(
    'on start, sends what changed since the last sync after the debounce',
    () async {
      await setUpWatcher(lastSync: ms(at(0)));
      await insertFhir(db, id: 'f', updatedAt: ms(at(1)));
      await insertSource(db, id: 's', updatedAt: ms(at(2)));
      await insertFhir(db, id: 'old', updatedAt: ms(at(-1)));

      watcher.startWatching();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(tcp.sent, isEmpty, reason: 'still inside the debounce window');

      await waitUntil(() => tcp.sent.length == 2);

      expect(sentTables(), ['fhir_resource', 'sources']);
      final fhir = SyncDelta.fromJson(tcp.sent.first.payload);
      expect(fhir.rows.map((r) => r['id']), ['f']);
      expect(fhir.deviceId, 'device-local');
      expect(
        (await sync.getLastSyncTimestamp())!.isAfter(at(2)),
        isTrue,
        reason: 'a successful send advances the last sync time',
      );
      expect(queue.pendingCount, 0);
    },
  );

  test('starting twice still sends one round', () async {
    await setUpWatcher();
    await insertFhir(db, id: 'f', updatedAt: 1);

    watcher
      ..startWatching()
      ..startWatching();
    await waitUntil(() => tcp.sent.isNotEmpty);
    await Future<void>.delayed(quietPeriod);

    expect(sentTables(), ['fhir_resource']);
  });

  test('coalesces a burst of changes into one round of sends', () async {
    await setUpWatcher(lastSync: ms(at(0)));
    watcher.startWatching();
    await Future<void>.delayed(quietPeriod);
    expect(tcp.sent, isEmpty);

    for (final id in ['f0', 'f1', 'f2']) {
      await db
          .into(db.fhirResource)
          .insert(FhirResourceCompanion.insert(id: id, resourceRaw: '{}'));
    }
    await waitUntil(() => tcp.sent.isNotEmpty);
    await Future<void>.delayed(quietPeriod);

    expect(sentTables(), ['fhir_resource']);
    expect(
      SyncDelta.fromJson(tcp.sent.single.payload).rows.map((r) => r['id']),
      unorderedEquals(['f0', 'f1', 'f2']),
    );
  });

  // Changes below go through drift's API, as the app's repositories do: only
  // those notify drift's table streams.

  test('reacts to a record_notes change', () async {
    await setUpWatcher(lastSync: ms(at(0)));
    watcher.startWatching();
    await Future<void>.delayed(quietPeriod);
    expect(tcp.sent, isEmpty, reason: 'nothing changed since the last sync');

    await db
        .into(db.recordNotes)
        .insert(
          RecordNotesCompanion.insert(
            resourceId: 'obs-1',
            content: 'n',
            timestamp: DateTime.now(),
          ),
        );
    await waitUntil(() => tcp.sent.isNotEmpty);

    expect(sentTables(), ['record_notes']);
    expect(
      SyncDelta.fromJson(tcp.sent.single.payload).rows.single['content'],
      'n',
    );
  });

  test('reacts to a sources change', () async {
    await setUpWatcher(lastSync: ms(at(0)));
    watcher.startWatching();
    await Future<void>.delayed(quietPeriod);

    await db.into(db.sources).insert(SourcesCompanion.insert(id: 's'));
    await waitUntil(() => tcp.sent.isNotEmpty);

    expect(sentTables(), ['sources']);
  });

  test('reacts to a fhir_resource update', () async {
    await setUpWatcher(lastSync: ms(at(0)));
    await insertFhir(db, id: 'f', updatedAt: ms(at(-5)), title: 'before');
    watcher.startWatching();
    await Future<void>.delayed(quietPeriod);
    expect(tcp.sent, isEmpty);

    await (db.update(db.fhirResource)..where((r) => r.id.equals('f'))).write(
      const FhirResourceCompanion(title: Value('after')),
    );
    await waitUntil(() => tcp.sent.isNotEmpty);

    final row = SyncDelta.fromJson(tcp.sent.single.payload).rows.single;
    expect(row['title'], 'after');
    expect(row['updated_at'] as int, greaterThan(ms(at(0))));
  });

  test(
    'does not notice writes made with raw SQL (no drift notification)',
    () async {
      await setUpWatcher(lastSync: ms(at(0)));
      watcher.startWatching();
      await Future<void>.delayed(quietPeriod);

      await insertFhir(db, id: 'raw', updatedAt: ms(at(1)));
      await Future<void>.delayed(quietPeriod);

      expect(tcp.sent, isEmpty);
    },
  );

  test('a processing_sessions change is checked but never sent', () async {
    await setUpWatcher(lastSync: ms(at(0)));
    watcher.startWatching();
    await Future<void>.delayed(quietPeriod);

    await db
        .into(db.processingSessions)
        .insert(ProcessingSessionsCompanion.insert(id: 'p'));
    await Future<void>.delayed(quietPeriod);

    expect(tcp.sent, isEmpty);
    expect(queue.pendingCount, 0);
    expect(await sync.getLastSyncTimestamp(), at(0).toLocal());
  });

  test(
    'queues deltas while disconnected and keeps the last sync time',
    () async {
      await setUpWatcher(connected: false, lastSync: ms(at(0)));
      await insertFhir(db, id: 'f', updatedAt: ms(at(1)));
      await insertNote(db, id: 1, content: 'n', updatedAt: ms(at(1)));

      watcher.startWatching();
      await waitUntil(() => queue.pendingCount == 2);

      expect(tcp.sent, isEmpty);
      expect(await sync.getLastSyncTimestamp(), at(0).toLocal());
    },
  );

  test(
    'a device that never synced queues nothing while disconnected',
    () async {
      await setUpWatcher(connected: false);
      await insertFhir(db, id: 'f', updatedAt: ms(at(1)));
      await insertNote(db, id: 1, content: 'n', updatedAt: ms(at(1)));

      watcher.startWatching();
      await Future<void>.delayed(quietPeriod);

      expect(
        queue.pendingCount,
        0,
        reason: 'its first connection sends everything anyway',
      );
      expect(prefs.getString('lww_offline_queue'), isNull);
      expect(await sync.getLastSyncTimestamp(), isNull);
    },
  );

  test('a new change replaces the queued delta of its table', () async {
    await setUpWatcher(connected: false, lastSync: ms(at(0)));
    await insertFhir(db, id: 'f', updatedAt: ms(at(1)));
    watcher.startWatching();
    await waitUntil(() => queue.pendingCount == 1);

    await db
        .into(db.fhirResource)
        .insert(FhirResourceCompanion.insert(id: 'g', resourceRaw: '{}'));
    await Future<void>.delayed(quietPeriod);

    expect(queue.pendingCount, 1);
    final queued = SyncDelta.fromJson(
      ((jsonDecode(prefs.getString('lww_offline_queue')!) as List).single)
          as Map<String, dynamic>,
    );
    expect(queued.rows.map((r) => r['id']), unorderedEquals(['f', 'g']));
  });

  test('queued deltas leave attachment files out', () async {
    final docs = Directory.systemTemp.createTempSync('watcher_docs');
    addTearDown(() => docs.deleteSync(recursive: true));
    File('${docs.path}/scan.pdf').writeAsBytesSync(List.filled(64, 1));
    await setUpWatcher(
      connected: false,
      lastSync: ms(at(0)),
      documentsPath: docs.path,
    );
    await insertFhir(
      db,
      id: 'doc',
      resourceType: 'DocumentReference',
      updatedAt: ms(at(1)),
      raw: jsonEncode({
        'resourceType': 'DocumentReference',
        'content': [
          {
            'attachment': {
              'contentType': 'application/pdf',
              'url': 'file://scan.pdf',
            },
          },
        ],
      }),
    );

    watcher.startWatching();
    await waitUntil(() => queue.pendingCount == 1);

    final queued = SyncDelta.fromJson(
      ((jsonDecode(prefs.getString('lww_offline_queue')!) as List).single)
          as Map<String, dynamic>,
    );
    final raw = jsonDecode(
      queued.rows.single['resource_raw'] as String,
    ) as Map<String, dynamic>;
    expect(
      (raw['content'] as List).single['attachment'],
      isNot(contains('data')),
      reason: 'the receiver asks for missing files once connected',
    );
  });

  test('queues only the deltas whose send failed', () async {
    await setUpWatcher(lastSync: ms(at(0)));
    await insertFhir(db, id: 'f', updatedAt: ms(at(1)));
    await insertSource(db, id: 's', updatedAt: ms(at(1)));
    tcp.failAfter = 1;

    watcher.startWatching();
    await waitUntil(() => queue.pendingCount == 1);

    expect(sentTables(), ['fhir_resource']);
    expect(
      (await sync.getLastSyncTimestamp())!.isAfter(at(0)),
      isTrue,
      reason: 'one delta went out, so the last sync time advances',
    );
  });

  test('does not advance the last sync time when every send fails', () async {
    await setUpWatcher(lastSync: ms(at(0)));
    await insertFhir(db, id: 'f', updatedAt: ms(at(1)));
    tcp.failAfter = 0;

    watcher.startWatching();
    await waitUntil(() => queue.pendingCount == 1);

    expect(tcp.sent, isEmpty);
    expect(await sync.getLastSyncTimestamp(), at(0).toLocal());
  });

  test(
    'stopWatching cancels a pending debounce and ignores later changes',
    () async {
      await setUpWatcher(lastSync: ms(at(0)));
      await insertFhir(db, id: 'f', updatedAt: ms(at(1)));

      watcher.startWatching();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      watcher.stopWatching();
      await insertFhir(db, id: 'g', updatedAt: ms(at(2)));
      await Future<void>.delayed(quietPeriod);
      expect(tcp.sent, isEmpty);

      watcher.startWatching();
      await waitUntil(() => tcp.sent.isNotEmpty);
      expect(
        SyncDelta.fromJson(tcp.sent.single.payload).rows.map((r) => r['id']),
        unorderedEquals(['f', 'g']),
        reason: 'it can be restarted and picks up what it missed',
      );
    },
  );
}
