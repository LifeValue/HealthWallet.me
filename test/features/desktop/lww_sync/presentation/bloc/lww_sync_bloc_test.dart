import 'dart:convert';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/data/local/app_database.dart';
import 'package:health_wallet/features/desktop/communication/data/services/tcp_service.dart'
    as tcp;
import 'package:health_wallet/features/desktop/lww_sync/data/services/attachment_sync_service.dart';
import 'package:health_wallet/features/desktop/lww_sync/data/services/change_watcher_service.dart';
import 'package:health_wallet/features/desktop/lww_sync/data/services/lww_sync_service.dart';
import 'package:health_wallet/features/desktop/lww_sync/data/services/offline_queue_service.dart';
import 'package:health_wallet/features/desktop/lww_sync/domain/entity/sync_delta.dart';
import 'package:health_wallet/features/desktop/lww_sync/presentation/bloc/lww_sync_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../lww_sync_test_helpers.dart';

class FakeChangeWatcherService extends Fake implements ChangeWatcherService {
  int starts = 0;
  int stops = 0;

  @override
  void startWatching() => starts++;

  @override
  void stopWatching() => stops++;
}

TypeMatcher<LwwSyncState> stateWhere({
  LwwSyncStatus? status,
  Object? currentTable = _unset,
  int? completedTables,
  int? totalTables,
  int? sentRows,
  int? receivedRows,
  bool? isSynced,
  int? pending,
}) {
  var m = isA<LwwSyncState>();
  if (status != null) m = m.having((s) => s.syncStatus, 'status', status);
  if (currentTable != _unset) {
    m = m.having((s) => s.currentTable, 'currentTable', currentTable);
  }
  if (completedTables != null) {
    m = m.having((s) => s.completedTables, 'completed', completedTables);
  }
  if (totalTables != null) {
    m = m.having((s) => s.totalTables, 'total', totalTables);
  }
  if (sentRows != null) m = m.having((s) => s.sentRows, 'sentRows', sentRows);
  if (receivedRows != null) {
    m = m.having((s) => s.receivedRows, 'receivedRows', receivedRows);
  }
  if (isSynced != null) m = m.having((s) => s.isSynced, 'isSynced', isSynced);
  if (pending != null) {
    m = m.having((s) => s.pendingChangeCount, 'pending', pending);
  }
  return m;
}

const _unset = Object();

void main() {
  late TestDirs dirs;
  late AppDatabase db;
  late SharedPreferences prefs;
  late FakeTcpService link;
  late FakeChangeWatcherService watcher;
  late LwwSyncService sync;
  late OfflineQueueService queue;

  final pdfBytes = utf8.encode('%PDF-1.7 fake');

  LwwSyncBloc buildBloc() => LwwSyncBloc(sync, watcher, queue, link);

  SyncDelta remoteDelta(String table, List<Map<String, dynamic>> rows) =>
      SyncDelta(
        tableName: table,
        rows: rows,
        deviceId: 'device-m',
        timestamp: at(100),
      );

  Map<String, dynamic> sourceRow(String id, int updatedAt) => {
    'id': id,
    'label_source': 'remote',
    'platform_type': 'wallet',
    'updated_at': updatedAt,
  };

  List<String> sentTypes() => [for (final m in link.sent) m.type];

  setUp(() async {
    dirs = await TestDirs.create();
    db = openTestDatabase();
    SharedPreferences.setMockInitialValues({
      'lww_local_device_id': 'device-local',
    });
    prefs = await SharedPreferences.getInstance();
    link = FakeTcpService();
    watcher = FakeChangeWatcherService();
    sync = LwwSyncService(
      db,
      prefs,
      AttachmentSyncService(FakePathResolver(dirs.docs.path)),
    );
    queue = OfflineQueueService(prefs, link);
  });

  tearDown(() async {
    await link.close();
    await db.close();
    await dirs.dispose();
  });

  test('starts idle with nothing synced', () {
    final bloc = buildBloc();
    addTearDown(bloc.close);

    expect(bloc.state, const LwwSyncState());
    expect(bloc.state.syncStatus, LwwSyncStatus.idle);
    expect(bloc.state.isSynced, isFalse);
  });

  group('LwwSyncInitialised', () {
    blocTest<LwwSyncBloc, LwwSyncState>(
      'restores last sync time and queue size, then prepares the database',
      setUp: () async {
        await sync.setLastSyncTimestamp(at(3));
        await queue.enqueue(remoteDelta('sources', const []));
        await dropSyncTriggers(db);
        await insertFhir(db, id: 'legacy');
        final old = ms(DateTime.now().subtract(const Duration(days: 45)));
        await insertFhir(db, id: 'tomb', updatedAt: old, deletedAt: old);
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const LwwSyncInitialised()),
      wait: const Duration(milliseconds: 50),
      expect: () => [
        isA<LwwSyncState>()
            .having((s) => s.lastSyncTime, 'lastSyncTime', at(3).toLocal())
            .having((s) => s.pendingChangeCount, 'pending', 1),
      ],
      verify: (_) async {
        expect(watcher.starts, 1);
        expect(
          (await fetchRow(db, 'fhir_resource', 'legacy'))!['updated_at'],
          isNotNull,
          reason: 'backfilled',
        );
        expect(await fetchRow(db, 'fhir_resource', 'tomb'), isNull);
      },
    );

    test('listens to the link until closed, then stops watching', () async {
      final bloc = buildBloc()..add(const LwwSyncInitialised());
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(link.hasListeners, isTrue);
      expect(watcher.stops, 0);

      await bloc.close();

      expect(watcher.stops, 1);
      expect(link.hasListeners, isFalse);
    });
  });

  group('incoming link messages (after LwwSyncInitialised)', () {
    Future<void> init(LwwSyncBloc bloc) async {
      bloc.add(const LwwSyncInitialised());
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }

    blocTest<LwwSyncBloc, LwwSyncState>(
      'sync.delta applies the rows and acknowledges the delta',
      build: buildBloc,
      act: (bloc) async {
        await init(bloc);
        link.receiveData(
          'sync.delta',
          remoteDelta('sources', [sourceRow('s1', ms(at(1)))]).toJson(),
        );
      },
      wait: const Duration(milliseconds: 100),
      verify: (bloc) async {
        expect(
          (await fetchRow(db, 'sources', 's1'))!['label_source'],
          'remote',
        );
        expect(link.sentOfType('sync.ack').single.payload, {
          'table_name': 'sources',
          'timestamp': ms(at(100)),
        });
        expect(bloc.state.receivedRows, 1);
        expect(bloc.state.syncStatus, LwwSyncStatus.idle);
      },
    );

    blocTest<LwwSyncBloc, LwwSyncState>(
      'sync.ack removes acknowledged deltas from the offline queue',
      setUp: () async {
        await queue.enqueue(remoteDelta('sources', const []));
        await queue.enqueue(
          remoteDelta('sources', const []).copyWith(timestamp: at(200)),
        );
      },
      build: buildBloc,
      act: (bloc) async {
        await init(bloc);
        link.receiveData('sync.ack', {
          'table_name': 'sources',
          'timestamp': ms(at(100)),
        });
      },
      wait: const Duration(milliseconds: 50),
      verify: (_) => expect(queue.pendingCount, 1),
    );

    blocTest<LwwSyncBloc, LwwSyncState>(
      'sync.status starts reconciliation and sync.verify reports the result',
      setUp: () => insertSource(db, id: 's', updatedAt: ms(at(1))),
      build: buildBloc,
      act: (bloc) async {
        await init(bloc);
        link.receiveData('sync.status', {
          'fhir_resource': 0,
          'sources': 0,
          'record_notes': 0,
        });
        await Future<void>.delayed(const Duration(milliseconds: 50));
        link.receiveData('sync.verify', {
          'fhir_resource': 0,
          'sources': 1.0,
          'record_notes': 0,
        });
      },
      // Covers the 1 s pause before the reconciliation's own sync.verify.
      wait: const Duration(milliseconds: 1300),
      verify: (bloc) {
        expect(sentTypes(), ['sync.delta', 'sync.verify']);
        expect(bloc.state.isSynced, isTrue);
      },
    );

    blocTest<LwwSyncBloc, LwwSyncState>(
      'sync.file_request answers with the files it has',
      setUp: () => dirs.writeDoc('a.pdf', pdfBytes),
      build: buildBloc,
      act: (bloc) async {
        await init(bloc);
        link.receiveData('sync.file_request', {
          'paths': ['a.pdf', 'missing.pdf'],
        });
      },
      wait: const Duration(milliseconds: 100),
      verify: (_) {
        final data = link.sentOfType('sync.file_data').single.payload;
        expect(data.keys, ['a.pdf']);
        expect(base64Decode(data['a.pdf'] as String), pdfBytes);
      },
    );

    blocTest<LwwSyncBloc, LwwSyncState>(
      'sync.file_request with no known file sends nothing',
      build: buildBloc,
      act: (bloc) async {
        await init(bloc);
        link.receiveData('sync.file_request', {
          'paths': ['missing.pdf'],
        });
      },
      wait: const Duration(milliseconds: 100),
      verify: (_) => expect(link.sent, isEmpty),
    );

    blocTest<LwwSyncBloc, LwwSyncState>(
      'sync.file_data stores the received files',
      build: buildBloc,
      act: (bloc) async {
        await init(bloc);
        link.receiveData('sync.file_data', {'x.pdf': base64Encode(pdfBytes)});
      },
      wait: const Duration(milliseconds: 100),
      verify: (_) async {
        expect(await dirs.docFile('x.pdf').readAsBytes(), pdfBytes);
      },
    );

    blocTest<LwwSyncBloc, LwwSyncState>(
      'a connected link state starts a sync',
      build: buildBloc,
      act: (bloc) async {
        await init(bloc);
        link.emitState(tcp.ConnectionState.connected);
      },
      wait: const Duration(milliseconds: 400),
      verify: (bloc) {
        expect(sentTypes(), ['sync.status', 'sync.status']);
        expect(bloc.state.isSynced, isTrue);
      },
    );

    blocTest<LwwSyncBloc, LwwSyncState>(
      'ignores non-data frames, malformed JSON, unknown types and bad '
      'payloads',
      build: buildBloc,
      act: (bloc) async {
        await init(bloc);
        link
          ..receiveRaw(
            tcp.MessageType.ping,
            jsonEncode({'type': 'sync.verify', 'payload': <String, int>{}}),
          )
          ..receiveRaw(tcp.MessageType.data, '{not json')
          ..receiveData('backup.status', {'ready': true})
          ..receiveData('sync.delta', {'tableName': 'sources'})
          ..receiveData('sync.ack', {'table_name': 'sources'})
          ..receiveData('sync.status', {'sources': 'many'});
      },
      wait: const Duration(milliseconds: 100),
      expect: () => [isA<LwwSyncState>()],
      verify: (bloc) {
        expect(link.sent, isEmpty);
        expect(bloc.state.syncStatus, LwwSyncStatus.idle);
        expect(bloc.state.isSynced, isFalse);
      },
    );
  });

  group('SyncTriggered', () {
    blocTest<LwwSyncBloc, LwwSyncState>(
      'sends each table delta and reports progress table by table',
      setUp: () async {
        await insertFhir(db, id: 'f', updatedAt: ms(at(1)));
        await insertNote(db, id: 1, content: 'n', updatedAt: ms(at(1)));
        await insertNote(db, id: 2, content: 'n', updatedAt: ms(at(1)));
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const SyncTriggered()),
      wait: const Duration(milliseconds: 50),
      expect: () => [
        stateWhere(
          status: LwwSyncStatus.syncing,
          currentTable: null,
          completedTables: 0,
          totalTables: 3,
          sentRows: 0,
          isSynced: false,
        ),
        stateWhere(currentTable: 'fhir_resource', completedTables: 0),
        stateWhere(currentTable: 'fhir_resource', sentRows: 1),
        stateWhere(currentTable: 'sources', completedTables: 1),
        stateWhere(currentTable: 'record_notes', completedTables: 2),
        stateWhere(currentTable: 'record_notes', sentRows: 3),
        stateWhere(
          status: LwwSyncStatus.idle,
          currentTable: null,
          completedTables: 3,
          sentRows: 3,
          isSynced: false,
          pending: 0,
        ).having((s) => s.lastSyncTime, 'lastSyncTime', isNotNull),
      ],
      verify: (bloc) async {
        expect(sentTypes(), ['sync.delta', 'sync.delta', 'sync.status']);
        expect(link.sent[1].payload['tableName'], 'record_notes');
        expect(link.sent.last.payload, {
          'fhir_resource': 1,
          'sources': 0,
          'record_notes': 2,
        });
        expect(
          (await sync.getLastSyncTimestamp())!.millisecondsSinceEpoch,
          bloc.state.lastSyncTime!.millisecondsSinceEpoch,
        );
      },
    );

    blocTest<LwwSyncBloc, LwwSyncState>(
      'only sends rows changed since the last sync time in state',
      setUp: () async {
        await insertFhir(db, id: 'old', updatedAt: ms(at(1)));
        await insertFhir(db, id: 'new', updatedAt: ms(at(6)));
      },
      build: buildBloc,
      seed: () => LwwSyncState(lastSyncTime: at(5)),
      act: (bloc) => bloc.add(const SyncTriggered()),
      wait: const Duration(milliseconds: 50),
      verify: (_) {
        final delta = SyncDelta.fromJson(link.sent.first.payload);
        expect(delta.rows.map((r) => r['id']), ['new']);
      },
    );

    blocTest<LwwSyncBloc, LwwSyncState>(
      'with nothing to send it ends synced',
      build: buildBloc,
      act: (bloc) => bloc.add(const SyncTriggered()),
      wait: const Duration(milliseconds: 50),
      expect: () => [
        stateWhere(status: LwwSyncStatus.syncing),
        stateWhere(currentTable: 'fhir_resource'),
        stateWhere(currentTable: 'sources'),
        stateWhere(currentTable: 'record_notes'),
        stateWhere(status: LwwSyncStatus.idle, isSynced: true, sentRows: 0),
      ],
      verify: (_) => expect(sentTypes(), ['sync.status']),
    );

    blocTest<LwwSyncBloc, LwwSyncState>(
      'queues deltas while disconnected',
      setUp: () async {
        link.connected = false;
        await insertFhir(db, id: 'f', updatedAt: ms(at(1)));
        await insertSource(db, id: 's', updatedAt: ms(at(1)));
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const SyncTriggered()),
      wait: const Duration(milliseconds: 50),
      verify: (bloc) {
        expect(link.sent, isEmpty);
        expect(queue.pendingCount, 2);
        expect(bloc.state.pendingChangeCount, 2);
        expect(bloc.state.sentRows, 2);
        expect(bloc.state.syncStatus, LwwSyncStatus.idle);
      },
    );

    blocTest<LwwSyncBloc, LwwSyncState>(
      'is ignored while a sync is already running',
      setUp: () => insertFhir(db, id: 'f', updatedAt: ms(at(1))),
      build: buildBloc,
      seed: () => const LwwSyncState(syncStatus: LwwSyncStatus.syncing),
      act: (bloc) => bloc.add(const SyncTriggered()),
      wait: const Duration(milliseconds: 50),
      expect: () => <LwwSyncState>[],
      verify: (_) => expect(link.sent, isEmpty),
    );

    blocTest<LwwSyncBloc, LwwSyncState>(
      'a send failure ends in the error state without moving the last sync '
      'time',
      setUp: () async {
        link.failAfter = 0;
        await insertFhir(db, id: 'f', updatedAt: ms(at(1)));
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const SyncTriggered()),
      wait: const Duration(milliseconds: 50),
      expect: () => [
        stateWhere(status: LwwSyncStatus.syncing),
        stateWhere(currentTable: 'fhir_resource'),
        stateWhere(
          status: LwwSyncStatus.error,
          currentTable: null,
        ).having((s) => s.error, 'error', contains('link dropped')),
      ],
      verify: (_) async {
        expect(await sync.getLastSyncTimestamp(), isNull);
        expect(queue.pendingCount, 0, reason: 'the failed delta is not kept');
      },
    );

    blocTest<LwwSyncBloc, LwwSyncState>(
      'a new sync clears a previous error',
      build: buildBloc,
      seed: () => const LwwSyncState(
        syncStatus: LwwSyncStatus.error,
        error: 'old failure',
      ),
      act: (bloc) => bloc.add(const SyncTriggered()),
      wait: const Duration(milliseconds: 50),
      verify: (bloc) {
        expect(bloc.state.error, isNull);
        expect(bloc.state.syncStatus, LwwSyncStatus.idle);
      },
    );
  });

  group('DeltaReceived', () {
    blocTest<LwwSyncBloc, LwwSyncState>(
      'applies newer rows, keeps newer local rows and acknowledges',
      setUp: () async {
        await insertSource(db, id: 'keep', updatedAt: ms(at(9)));
        await insertSource(db, id: 'take', updatedAt: ms(at(1)));
      },
      build: buildBloc,
      act: (bloc) => bloc.add(
        DeltaReceived(
          delta: remoteDelta('sources', [
            sourceRow('keep', ms(at(5))),
            sourceRow('take', ms(at(5))),
            sourceRow('new', ms(at(5))),
          ]),
        ),
      ),
      wait: const Duration(milliseconds: 50),
      expect: () => [
        stateWhere(
          status: LwwSyncStatus.syncing,
          currentTable: 'sources',
          isSynced: false,
        ),
        stateWhere(receivedRows: 2),
        stateWhere(
          status: LwwSyncStatus.idle,
          currentTable: null,
        ).having((s) => s.lastSyncTime, 'lastSyncTime', isNotNull),
      ],
      verify: (bloc) async {
        expect((await fetchRow(db, 'sources', 'keep'))!['label_source'], null);
        expect(
          (await fetchRow(db, 'sources', 'take'))!['label_source'],
          'remote',
        );
        expect(sentTypes(), ['sync.ack']);
        expect(
          (await sync.getLastSyncTimestamp())!.millisecondsSinceEpoch,
          bloc.state.lastSyncTime!.millisecondsSinceEpoch,
        );
      },
    );

    blocTest<LwwSyncBloc, LwwSyncState>(
      'accumulates received rows across deltas and skips the ack offline',
      setUp: () => link.connected = false,
      build: buildBloc,
      seed: () => const LwwSyncState(receivedRows: 4),
      act: (bloc) => bloc.add(
        DeltaReceived(
          delta: remoteDelta('sources', [sourceRow('s', ms(at(1)))]),
        ),
      ),
      wait: const Duration(milliseconds: 50),
      verify: (bloc) {
        expect(bloc.state.receivedRows, 5);
        expect(link.sent, isEmpty);
      },
    );

    blocTest<LwwSyncBloc, LwwSyncState>(
      'a fhir_resource delta also repairs broken attachment urls',
      setUp: () async {
        await dirs.writeDoc('scan.pdf', pdfBytes);
        await insertFhir(
          db,
          id: 'doc',
          updatedAt: ms(at(1)),
          resourceType: 'DocumentReference',
          raw: documentReferenceRaw([
            {'url': 'file:///old/container/Documents/scan.pdf'},
          ]),
        );
      },
      build: buildBloc,
      act: (bloc) => bloc.add(
        DeltaReceived(
          delta: remoteDelta('fhir_resource', [
            {
              'id': 'obs',
              'resource_raw': '{}',
              'resource_type': 'Observation',
              'updated_at': ms(at(1)),
            },
          ]),
        ),
      ),
      wait: const Duration(milliseconds: 50),
      verify: (_) async {
        expect(await fetchRow(db, 'fhir_resource', 'obs'), isNotNull);
        expect(
          (await fetchRow(db, 'fhir_resource', 'doc'))!['resource_raw'],
          contains('"file://scan.pdf"'),
        );
      },
    );

    blocTest<LwwSyncBloc, LwwSyncState>(
      'a delta that cannot be applied ends in the error state, unacknowledged',
      build: buildBloc,
      act: (bloc) => bloc.add(
        DeltaReceived(
          delta: remoteDelta('sources', [
            {...sourceRow('s', ms(at(1))), 'column_from_v99': 1},
          ]),
        ),
      ),
      wait: const Duration(milliseconds: 50),
      expect: () => [
        stateWhere(status: LwwSyncStatus.syncing),
        stateWhere(
          status: LwwSyncStatus.error,
          currentTable: null,
        ).having((s) => s.error, 'error', contains('column_from_v99')),
      ],
      verify: (_) => expect(link.sent, isEmpty),
    );
  });

  group('ConnectionChanged', () {
    blocTest<LwwSyncBloc, LwwSyncState>(
      'connected: resets counters, sends counts, flushes the queue, syncs',
      setUp: () async {
        await queue.enqueue(
          remoteDelta('sources', [sourceRow('queued', ms(at(1)))]),
        );
        await insertSource(db, id: 's', updatedAt: ms(at(1)));
      },
      build: buildBloc,
      seed: () => const LwwSyncState(
        isSynced: true,
        sentRows: 5,
        receivedRows: 2,
        pendingChangeCount: 1,
      ),
      act: (bloc) => bloc.add(const ConnectionChanged(isConnected: true)),
      wait: const Duration(milliseconds: 400),
      verify: (bloc) {
        expect(bloc.state.pendingChangeCount, 0);
        expect(sentTypes(), [
          'sync.status',
          'sync.delta',
          'sync.delta',
          'sync.status',
        ]);
        expect(link.sent.first.payload, {
          'fhir_resource': 0,
          'sources': 1,
          'record_notes': 0,
        });
        final flushed = SyncDelta.fromJson(link.sent[1].payload);
        expect(flushed.rows.single['id'], 'queued');
        final synced = SyncDelta.fromJson(link.sent[2].payload);
        expect(synced.rows.single['id'], 's');
        expect(bloc.state.receivedRows, 0);
        expect(bloc.state.sentRows, 1);
      },
    );

    blocTest<LwwSyncBloc, LwwSyncState>(
      'connected: emits the counter reset first',
      build: buildBloc,
      seed: () => const LwwSyncState(isSynced: true, sentRows: 5),
      act: (bloc) => bloc.add(const ConnectionChanged(isConnected: true)),
      wait: const Duration(milliseconds: 400),
      expect: () => [
        stateWhere(isSynced: false, sentRows: 0, receivedRows: 0),
        stateWhere(status: LwwSyncStatus.syncing),
        stateWhere(currentTable: 'fhir_resource'),
        stateWhere(currentTable: 'sources'),
        stateWhere(currentTable: 'record_notes'),
        stateWhere(status: LwwSyncStatus.idle, isSynced: true),
      ],
    );

    blocTest<LwwSyncBloc, LwwSyncState>(
      'connected: a failing status send does not stop the queue flush',
      setUp: () async {
        await queue.enqueue(remoteDelta('sources', const []));
        link.failAfter = 0;
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const ConnectionChanged(isConnected: true)),
      wait: const Duration(milliseconds: 400),
      verify: (bloc) {
        expect(queue.pendingCount, 1);
        expect(bloc.state.pendingChangeCount, 1);
      },
    );

    blocTest<LwwSyncBloc, LwwSyncState>(
      'disconnected: marks not synced and shows the queue size',
      setUp: () async {
        await queue.enqueue(remoteDelta('sources', const []));
        await queue.enqueue(remoteDelta('fhir_resource', const []));
      },
      build: buildBloc,
      seed: () => const LwwSyncState(isSynced: true),
      act: (bloc) => bloc.add(const ConnectionChanged(isConnected: false)),
      expect: () => [
        stateWhere(isSynced: false, pending: 0),
        stateWhere(isSynced: false, pending: 2),
      ],
      verify: (_) => expect(link.sent, isEmpty),
    );
  });

  group('TableStatusReceived', () {
    blocTest<LwwSyncBloc, LwwSyncState>(
      'resends whole tables whose counts differ, then sends sync.verify',
      setUp: () async {
        await sync.setLastSyncTimestamp(at(50));
        await insertFhir(db, id: 'f1', updatedAt: ms(at(1)));
        await insertFhir(db, id: 'f2', updatedAt: ms(at(2)));
        await insertSource(db, id: 's', updatedAt: ms(at(1)));
      },
      build: buildBloc,
      act: (bloc) => bloc.add(
        const TableStatusReceived(
          remoteCounts: {'fhir_resource': 1, 'sources': 1, 'record_notes': 7},
        ),
      ),
      wait: const Duration(milliseconds: 1300),
      expect: () => [
        stateWhere(
          status: LwwSyncStatus.syncing,
          currentTable: 'fhir_resource',
        ),
        stateWhere(sentRows: 2),
        stateWhere(status: LwwSyncStatus.idle, currentTable: null),
      ],
      verify: (_) async {
        expect(sentTypes(), ['sync.delta', 'sync.verify']);
        final delta = SyncDelta.fromJson(link.sent.first.payload);
        expect(delta.tableName, 'fhir_resource');
        expect(
          delta.rows.map((r) => r['id']),
          unorderedEquals(['f1', 'f2']),
          reason: 'rows older than the last sync are included',
        );
        expect(link.sent.last.payload, {
          'fhir_resource': 2,
          'sources': 1,
          'record_notes': 0,
        });
        expect(
          (await sync.getLastSyncTimestamp())!.isAfter(at(50)),
          isTrue,
        );
      },
    );

    blocTest<LwwSyncBloc, LwwSyncState>(
      'matching counts send nothing but the verify',
      setUp: () async {
        await sync.setLastSyncTimestamp(at(50));
        await insertSource(db, id: 's', updatedAt: ms(at(1)));
      },
      build: buildBloc,
      act: (bloc) => bloc.add(
        const TableStatusReceived(
          remoteCounts: {'fhir_resource': 0, 'sources': 1},
        ),
      ),
      wait: const Duration(milliseconds: 1300),
      // Only the closing "idle" emission, identical to the initial state.
      expect: () => [stateWhere(status: LwwSyncStatus.idle, sentRows: 0)],
      verify: (_) async {
        expect(sentTypes(), ['sync.verify']);
        expect(await sync.getLastSyncTimestamp(), at(50).toLocal());
      },
    );

    blocTest<LwwSyncBloc, LwwSyncState>(
      'offline it neither sends the delta nor the verify',
      setUp: () async {
        link.connected = false;
        await insertSource(db, id: 's', updatedAt: ms(at(1)));
      },
      build: buildBloc,
      act: (bloc) => bloc.add(
        const TableStatusReceived(remoteCounts: {'sources': 3}),
      ),
      wait: const Duration(milliseconds: 1300),
      expect: () => [
        stateWhere(status: LwwSyncStatus.syncing, currentTable: 'sources'),
        stateWhere(status: LwwSyncStatus.idle, currentTable: null),
      ],
      verify: (_) async {
        expect(link.sent, isEmpty);
        expect(await sync.getLastSyncTimestamp(), isNull);
      },
    );
  });

  group('SyncVerifyReceived', () {
    blocTest<LwwSyncBloc, LwwSyncState>(
      'matching counts mark the devices as synced',
      setUp: () => insertSource(db, id: 's', updatedAt: ms(at(1))),
      build: buildBloc,
      act: (bloc) => bloc.add(
        const SyncVerifyReceived(
          remoteCounts: {'fhir_resource': 0, 'sources': 1, 'record_notes': 0},
        ),
      ),
      wait: const Duration(milliseconds: 50),
      expect: () => [stateWhere(isSynced: true)],
      verify: (_) => expect(link.sent, isEmpty),
    );

    blocTest<LwwSyncBloc, LwwSyncState>(
      'a count mismatch marks the devices as not synced',
      build: buildBloc,
      seed: () => const LwwSyncState(isSynced: true),
      act: (bloc) => bloc.add(
        const SyncVerifyReceived(remoteCounts: {'record_notes': 1}),
      ),
      wait: const Duration(milliseconds: 50),
      expect: () => [stateWhere(isSynced: false)],
    );

    blocTest<LwwSyncBloc, LwwSyncState>(
      'requests attachment files that are missing locally',
      setUp: () => insertFhir(
        db,
        id: 'doc',
        updatedAt: ms(at(1)),
        resourceType: 'DocumentReference',
        raw: documentReferenceRaw([
          {'url': 'file://lost.pdf'},
        ]),
      ),
      build: buildBloc,
      act: (bloc) => bloc.add(
        const SyncVerifyReceived(remoteCounts: {'fhir_resource': 1}),
      ),
      wait: const Duration(milliseconds: 50),
      verify: (_) {
        expect(link.sentOfType('sync.file_request').single.payload, {
          'paths': ['lost.pdf'],
        });
      },
    );

    blocTest<LwwSyncBloc, LwwSyncState>(
      'does not request files while offline',
      setUp: () async {
        link.connected = false;
        await insertFhir(
          db,
          id: 'doc',
          updatedAt: ms(at(1)),
          resourceType: 'DocumentReference',
          raw: documentReferenceRaw([
            {'url': 'file://lost.pdf'},
          ]),
        );
      },
      build: buildBloc,
      act: (bloc) => bloc.add(
        const SyncVerifyReceived(remoteCounts: {'fhir_resource': 1}),
      ),
      wait: const Duration(milliseconds: 50),
      verify: (_) => expect(link.sent, isEmpty),
    );
  });

  group('known issues', () {
    blocTest<LwwSyncBloc, LwwSyncState>(
      'KNOWN ISSUE: receiving any delta moves the last sync time past an '
      'unsent local edit, which is then never sent',
      setUp: () async {
        await sync.setLastSyncTimestamp(at(0));
        // Edited locally two seconds ago, after the last sync, not yet sent
        // (the change watcher's debounce had not fired, or the link was down).
        await insertFhir(
          db,
          id: 'local-edit',
          updatedAt: ms(DateTime.now().subtract(const Duration(seconds: 2))),
        );
      },
      build: buildBloc,
      seed: () => LwwSyncState(lastSyncTime: at(0)),
      act: (bloc) async {
        bloc.add(
          DeltaReceived(
            delta: remoteDelta('sources', [sourceRow('s', ms(at(1)))]),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));
        bloc.add(const SyncTriggered());
      },
      wait: const Duration(milliseconds: 100),
      verify: (_) async {
        expect(link.sentOfType('sync.delta'), isEmpty);
        // The edit is still only local, and the row counts match, so neither
        // incremental sync nor count reconciliation will ever send it.
        expect(await fetchRow(db, 'fhir_resource', 'local-edit'), isNotNull);
      },
    );

    blocTest<LwwSyncBloc, LwwSyncState>(
      'KNOWN ISSUE: an offline sync advances the last sync time, so changes '
      'live only in the offline queue that mobile clears on start',
      setUp: () async {
        link.connected = false;
        await insertFhir(db, id: 'offline-edit', updatedAt: ms(at(1)));
      },
      build: buildBloc,
      act: (bloc) async {
        bloc.add(const SyncTriggered());
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(queue.pendingCount, 1);
        // lib/main.dart removes lww_offline_queue on every mobile start.
        await queue.clear();
        link.connected = true;
        bloc.add(const SyncTriggered());
      },
      wait: const Duration(milliseconds: 100),
      verify: (_) {
        expect(link.sentOfType('sync.delta'), isEmpty);
        expect(sentTypes(), ['sync.status']);
      },
    );
  });
}
