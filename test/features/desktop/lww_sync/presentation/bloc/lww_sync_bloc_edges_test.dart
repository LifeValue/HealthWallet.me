import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/features/desktop/communication/data/services/message_router.dart';
import 'package:health_wallet/features/desktop/communication/data/services/tcp_service.dart';
import 'package:health_wallet/features/desktop/lww_sync/data/services/change_watcher_service.dart';
import 'package:health_wallet/features/desktop/lww_sync/data/services/lww_sync_service.dart';
import 'package:health_wallet/features/desktop/lww_sync/domain/entity/sync_batch.dart';
import 'package:health_wallet/features/desktop/lww_sync/presentation/bloc/lww_sync_bloc.dart';

import '../../../../../helpers/log_capture.dart';

/// The sync service as the bloc sees it, with every answer set by the test,
/// so the bloc's handling of failures and odd messages can be driven without
/// a database or files.
class _FakeSync extends Fake implements LwwSyncService {
  SyncPeerState? stored;
  final batches = <SyncBatch>[];
  int pending = 0;
  AppliedBatch applied = const AppliedBatch({});
  Error? applyError;

  /// While set, applying a batch waits for it.
  Completer<void>? applyGate;
  List<String> missing = const [];
  final files = <String, File?>{};
  final fileErrors = <String, Exception>{};
  final fileRequests = <String>[];
  Error? saveChunkError;
  final savedChunks = <FileChunk>[];
  final discarded = <String>[];
  final pruned = <int>[];

  @override
  Future<void> discardAllPartials() async {}

  @override
  Future<int> backfillExistingRows() async => 0;

  @override
  Future<int> fixBrokenAttachmentUrls([Iterable<String>? documentIds]) async =>
      0;

  @override
  Future<int> cleanupTombstones() async => 0;

  @override
  SyncPeerState? loadPeerState() => stored;

  @override
  Future<SyncPeerState> peerStateFor(String peerId, {String? peerName}) async =>
      stored ??= SyncPeerState(peerId: peerId, ackedSeq: 0, peerName: peerName);

  @override
  Future<void> savePeerState(SyncPeerState state) async => stored = state;

  @override
  Future<int> pendingCount(int afterSeq) async => pending;

  @override
  Future<void> pruneOutbox(int upToSeq) async => pruned.add(upToSeq);

  @override
  Future<SyncBatch?> nextBatch(int afterSeq) async {
    for (final batch in batches) {
      if (batch.id > afterSeq) return batch;
    }
    return null;
  }

  @override
  Future<Map<String, TableDigest>> computeDigest() async => {
    for (final table in LwwSyncService.syncedTables)
      table: const TableDigest(count: 0, hash: 'empty'),
  };

  @override
  Future<Map<String, int>> manifest(String table) async => {};

  @override
  Future<List<String>> missingAttachmentPaths([
    Iterable<String>? documentIds,
  ]) async => missing;

  @override
  Future<AppliedBatch> applyBatch(SyncBatch batch) async {
    await applyGate?.future;
    if (applyError != null) throw applyError!;
    return applied;
  }

  @override
  Future<File?> fileForRequest(String path) async {
    fileRequests.add(path);
    final error = fileErrors[path];
    if (error != null) throw error;
    return files[path];
  }

  @override
  Stream<FileChunk> readChunks(String path, File file) => Stream.value(
    FileChunk(path: path, offset: 0, total: 3, bytes: Uint8List(3)),
  );

  @override
  Future<String?> saveChunk(FileChunk chunk) async {
    savedChunks.add(chunk);
    if (saveChunkError != null) throw saveChunkError!;
    return null;
  }

  @override
  Future<void> discardPartial(String path) async => discarded.add(path);
}

/// The link to the peer: records what is sent and refuses the message types
/// in [refused] as a dropped link would.
class _FakeLink extends Fake implements TcpService {
  bool connected = false;
  final refused = <String>{};
  final sent = <({String type, Map<String, dynamic> payload})>[];

  List<Map<String, dynamic>> sentOfType(String type) => [
    for (final m in sent)
      if (m.type == type) m.payload,
  ];

  @override
  bool get isConnected => connected;

  @override
  PeerInfo? get peer =>
      connected ? const PeerInfo(deviceId: 'desk', name: 'Desk') : null;

  @override
  Stream<ConnectionState> get connectionState => const Stream.empty();

  @override
  Future<void> sendData(String type, Map<String, dynamic> payload) async {
    if (!connected || refused.contains(type)) {
      throw const LinkNotConnectedException();
    }
    sent.add((type: type, payload: payload));
  }
}

class _FakeRouter extends Fake implements MessageRouter {
  final _controllers = <String, StreamController<Map<String, dynamic>>>{};

  @override
  Stream<Map<String, dynamic>> on(String type) =>
      (_controllers[type] ??= StreamController.broadcast()).stream;
}

class _FakeWatcher extends Fake implements ChangeWatcherService {
  bool watching = false;

  @override
  void startWatching(void Function() onChanged) => watching = true;

  @override
  void stopWatching() => watching = false;
}

const _rows = {
  'fhir_resource': [
    {'id': 'r1'},
  ],
};

void main() {
  final logs = captureLogs();

  late _FakeSync sync;
  late _FakeLink link;
  late _FakeWatcher watcher;
  late LwwSyncBloc bloc;

  /// Runs [body] on fake time with a fresh bloc, closing it afterwards.
  void run(void Function(FakeAsync async) body) {
    fakeAsync((async) {
      sync = _FakeSync();
      link = _FakeLink();
      watcher = _FakeWatcher();
      bloc = LwwSyncBloc(sync, watcher, link, _FakeRouter());
      body(async);
      unawaited(bloc.close());
      async.flushMicrotasks();
    });
  }

  /// Starts the bloc with the peer already connected.
  void startConnected(FakeAsync async) {
    link.connected = true;
    bloc.add(const LwwSyncInitialised());
    async.flushMicrotasks();
  }

  void receive(FakeAsync async, String type, Map<String, dynamic> payload) {
    bloc.add(LwwMessageReceived(type: type, payload: payload));
    async.flushMicrotasks();
  }

  test('a peer already connected when the bloc starts is compared with at '
      'once', () {
    run((async) {
      startConnected(async);

      expect(watcher.watching, isTrue);
      expect(bloc.state.connected, isTrue);
      expect(bloc.state.lastSyncPeerName, 'Desk');
      expect(link.sentOfType('sync.digest'), [
        containsPair('reply', false),
      ]);
    });
  });

  test('an event that fails sets the error and clears sending and '
      'receiving', () {
    run((async) {
      startConnected(async);
      sync.applyError = StateError('disk full');

      receive(
        async,
        'sync.batch',
        const SyncBatch(id: 7, deviceId: 'desk', tables: _rows).toJson(),
      );

      expect(bloc.state.syncStatus, LwwSyncStatus.error);
      expect(bloc.state.error, contains('disk full'));
      expect(bloc.state.receiving, isFalse);
      expect(bloc.state.sending, isFalse);
      expect(logs, loggedWarning('LwwMessageReceived failed'));
      // Not acknowledged, so the peer sends it again.
      expect(link.sentOfType('sync.ack'), isEmpty);

      // The batch is no longer being applied: shutting down doesn't wait.
      var shutDown = false;
      bloc.shutdown().then((_) => shutDown = true);
      async.flushMicrotasks();
      expect(shutDown, isTrue);
    });
  });

  test('files still awaited when the link drops have their partial copy '
      'discarded', () {
    run((async) {
      sync.missing = ['scans/a.pdf'];
      startConnected(async);
      expect(link.sentOfType('sync.file_request'), [
        {
          'paths': ['scans/a.pdf'],
        },
      ]);

      link.connected = false;
      bloc.add(const ConnectionChanged(isConnected: false));
      async.flushMicrotasks();

      expect(sync.discarded, ['scans/a.pdf']);
      expect(bloc.state.connected, isFalse);
    });
  });

  test('a batch of only deleted rows is acknowledged here without being '
      'sent', () {
    run((async) {
      sync.batches.add(const SyncBatch(id: 3, deviceId: 'me', tables: {}));

      startConnected(async);

      expect(link.sentOfType('sync.batch'), isEmpty);
      expect(sync.pruned, [3]);
      expect(sync.stored?.ackedSeq, 3);
      expect(bloc.state.sending, isFalse);
    });
  });

  test('a batch the link refuses marks the bloc disconnected and keeps it '
      'unsent', () {
    run((async) {
      sync.batches.add(const SyncBatch(id: 4, deviceId: 'me', tables: _rows));
      link.refused.add('sync.batch');

      startConnected(async);

      expect(bloc.state.connected, isFalse);
      expect(bloc.state.sending, isFalse);
      expect(bloc.state.sentRows, 0);
      expect(sync.pruned, isEmpty);
    });
  });

  test('a message that may be lost is logged when the link refuses it, not '
      'failed', () {
    run((async) {
      link.refused.add('sync.digest');

      startConnected(async);

      expect(logs, loggedWarning('sync.digest not sent: not connected'));
      expect(bloc.state.connected, isTrue);
      expect(bloc.state.syncStatus, isNot(LwwSyncStatus.error));
    });
  });

  group('an ack saying the peer could not apply the batch', () {
    const rejected = 'the other device could not save some changes';

    /// The peer's digest: the same tables as this side's, or with
    /// `fhir_resource` differing.
    Map<String, dynamic> peerDigest({required bool matching}) => {
      'reply': true,
      'tables': {
        for (final table in LwwSyncService.syncedTables)
          table: matching || table != 'fhir_resource'
              ? {'count': 0, 'hash': 'empty'}
              : {'count': 1, 'hash': 'theirs'},
      },
    };

    /// Connects with batch 5 in flight, which the peer then fails to save,
    /// and with [later] batches waiting behind it.
    void peerRejectsBatch5(
      FakeAsync async, {
      List<SyncBatch> later = const [],
    }) {
      sync.batches
        ..add(const SyncBatch(id: 5, deviceId: 'me', tables: _rows))
        ..addAll(later);
      startConnected(async);
      expect(link.sentOfType('sync.batch'), hasLength(1));
      receive(async, 'sync.ack', {'id': 5, 'ok': false});
    }

    void expectRejectedShown() {
      expect(bloc.state.syncStatus, LwwSyncStatus.error);
      expect(bloc.state.error, rejected);
    }

    test('shows the error, moves on past the batch and checks again with '
        'the peer', () {
      run((async) {
        peerRejectsBatch5(async);

        expect(logs, loggedWarning('could not apply batch 5'));
        expectRejectedShown();
        expect(sync.pruned, [5]);
        expect(sync.stored?.ackedSeq, 5);
        // The one sent on connecting, then the check after sending.
        expect(link.sentOfType('sync.digest'), [
          containsPair('reply', false),
          containsPair('reply', false),
        ]);
      });
    });

    test('keeps the error when the peer answers the check with tables that '
        'still differ, and clears it once they match', () {
      run((async) {
        peerRejectsBatch5(async);

        receive(async, 'sync.digest', peerDigest(matching: false));
        expectRejectedShown();
        expect(bloc.state.tablesMatch, isFalse);
        // The rows go back and forth again all the same.
        expect(link.sentOfType('sync.manifest'), [
          containsPair('table', 'fhir_resource'),
        ]);

        receive(async, 'sync.digest', peerDigest(matching: true));
        expect(bloc.state.syncStatus, LwwSyncStatus.idle);
        expect(bloc.state.error, isNull);
        expect(bloc.state.tablesMatch, isTrue);
      });
    });

    test('keeps the error when a later batch is saved', () {
      run((async) {
        peerRejectsBatch5(
          async,
          later: const [SyncBatch(id: 6, deviceId: 'me', tables: _rows)],
        );
        expect(link.sentOfType('sync.batch'), hasLength(2));
        expectRejectedShown();

        receive(async, 'sync.ack', {'id': 6, 'ok': true});
        expectRejectedShown();
        expect(sync.stored?.ackedSeq, 6);
      });
    });

    test('keeps the error through a reconnect, as long as the tables were '
        'not compared', () {
      run((async) {
        peerRejectsBatch5(async);

        link.connected = false;
        bloc.add(const ConnectionChanged(isConnected: false));
        async.flushMicrotasks();
        expectRejectedShown();

        link.connected = true;
        bloc.add(const ConnectionChanged(isConnected: true));
        async.flushMicrotasks();
        expectRejectedShown();

        receive(async, 'sync.digest', peerDigest(matching: true));
        expect(bloc.state.syncStatus, LwwSyncStatus.idle);
        expect(bloc.state.error, isNull);
      });
    });

    test('Sync Now clears the error and checks again; a sync started by the '
        'app keeps it', () {
      run((async) {
        peerRejectsBatch5(async);

        bloc.add(const SyncTriggered());
        async.flushMicrotasks();
        expectRejectedShown();

        final digests = link.sentOfType('sync.digest').length;
        bloc.add(const SyncTriggered(userRequested: true));
        async.flushMicrotasks();
        expect(bloc.state.syncStatus, LwwSyncStatus.syncing);
        expect(bloc.state.error, isNull);
        expect(link.sentOfType('sync.digest'), hasLength(digests + 1));

        receive(async, 'sync.digest', peerDigest(matching: true));
        expect(bloc.state.syncStatus, LwwSyncStatus.idle);
      });
    });
  });

  test('a file the peer does not have is no longer awaited', () {
    run((async) {
      sync.missing = ['scans/a.pdf'];
      startConnected(async);

      receive(async, 'sync.file_missing', {'path': 'scans/a.pdf'});

      expect(logs, loggedWarning('has no file for an attachment'));
      expect(sync.discarded, ['scans/a.pdf']);

      // Neither a repeat nor a path never asked for changes anything.
      receive(async, 'sync.file_missing', {'path': 'scans/a.pdf'});
      receive(async, 'sync.file_missing', {'path': 'other.pdf'});
      receive(async, 'sync.file_missing', {'path': 42});
      expect(sync.discarded, ['scans/a.pdf']);

      // Nothing else awaited: a chunk for it is ignored.
      receive(async, 'sync.file_chunk', {
        'path': 'scans/a.pdf',
        'offset': 0,
        'total': 3,
        'data': 'AAAA',
      });
      expect(sync.savedChunks, isEmpty);
    });
  });

  test('a requested file this side does not have is answered with '
      'file_missing', () {
    run((async) {
      startConnected(async);

      receive(async, 'sync.file_request', {
        'paths': ['gone.pdf'],
      });

      expect(link.sentOfType('sync.file_missing'), [
        {'path': 'gone.pdf'},
      ]);
    });
  });

  test('serving files stops when the link drops', () {
    run((async) {
      sync.files['a.pdf'] = File('a.pdf');
      sync.files['b.pdf'] = File('b.pdf');
      startConnected(async);
      link.refused.add('sync.file_chunk');

      receive(async, 'sync.file_request', {
        'paths': ['a.pdf', 'b.pdf'],
      });

      expect(sync.fileRequests, ['a.pdf']);
      expect(link.sentOfType('sync.file_chunk'), isEmpty);
    });
  });

  test('a file that fails to be read is logged and the next one is still '
      'served', () {
    run((async) {
      sync.fileErrors['bad.pdf'] = const FileSystemException('unreadable');
      sync.files['good.pdf'] = File('good.pdf');
      startConnected(async);

      receive(async, 'sync.file_request', {
        'paths': ['bad.pdf', 7, 'good.pdf'],
      });

      expect(logs, loggedWarning('sending an attachment failed'));
      expect(sync.fileRequests, ['bad.pdf', 'good.pdf']);
      expect(link.sentOfType('sync.file_chunk'), [
        {'path': 'good.pdf', 'offset': 0, 'total': 3, 'data': 'AAAA'},
      ]);
    });
  });

  test('a received chunk that cannot be saved drops the file', () {
    run((async) {
      sync.missing = ['scans/a.pdf'];
      sync.saveChunkError = StateError('file chunk at 4, expected 0');
      startConnected(async);

      final chunk = {
        'path': 'scans/a.pdf',
        'offset': 4,
        'total': 8,
        'data': 'AAAA',
      };
      receive(async, 'sync.file_chunk', chunk);

      expect(logs, loggedWarning('a received attachment was dropped'));
      expect(sync.discarded, ['scans/a.pdf']);
      expect(sync.savedChunks, hasLength(1));

      // No longer awaited: later chunks for it are ignored.
      receive(async, 'sync.file_chunk', chunk);
      expect(sync.savedChunks, hasLength(1));
    });
  });

  test('shutdown waits for a batch being applied to finish', () {
    run((async) {
      startConnected(async);
      sync.applyGate = Completer<void>();
      receive(
        async,
        'sync.batch',
        const SyncBatch(id: 8, deviceId: 'desk', tables: _rows).toJson(),
      );

      var shutDown = false;
      bloc.shutdown().then((_) => shutDown = true);
      async.flushMicrotasks();
      expect(shutDown, isFalse);

      sync.applyGate!.complete();
      async.flushMicrotasks();
      expect(shutDown, isTrue);
      expect(link.sentOfType('sync.ack'), [
        {'id': 8, 'ok': true},
      ]);
    });
  });

  test('shutdown gives up on a batch that takes longer than four '
      'seconds', () {
    run((async) {
      startConnected(async);
      sync.applyGate = Completer<void>();
      receive(
        async,
        'sync.batch',
        const SyncBatch(id: 9, deviceId: 'desk', tables: _rows).toJson(),
      );

      var shutDown = false;
      bloc.shutdown().then((_) => shutDown = true);
      async.elapse(const Duration(seconds: 3));
      expect(shutDown, isFalse);

      async.elapse(const Duration(seconds: 1));
      expect(shutDown, isTrue);
      sync.applyGate!.complete();
    });
  });

  test('a match check the peer never answers returns false once the timeout '
      'is up, not before', () {
    run((async) {
      startConnected(async);
      bool? matched;
      bloc
          .syncAndConfirmMatch(timeout: const Duration(seconds: 10))
          .then((m) => matched = m);
      async.flushMicrotasks();
      // On connecting, after the drain, and the fresh one for the check.
      expect(link.sentOfType('sync.digest'), hasLength(3));

      async.elapse(const Duration(seconds: 9));
      expect(matched, isNull);

      async.elapse(const Duration(seconds: 1));
      expect(matched, isFalse);
      expect(logs, loggedWarning('the tables did not match within'));
    });
  });

  test('a match check returns false once the timeout is up when the '
      'changes are never acknowledged, without comparing', () {
    run((async) {
      sync.batches.add(const SyncBatch(id: 4, deviceId: 'me', tables: _rows));
      startConnected(async);
      expect(link.sentOfType('sync.batch'), hasLength(1));
      bool? matched;
      bloc
          .syncAndConfirmMatch(timeout: const Duration(seconds: 10))
          .then((m) => matched = m);
      async.flushMicrotasks();

      async.elapse(const Duration(seconds: 9));
      expect(matched, isNull);

      async.elapse(const Duration(seconds: 1));
      expect(matched, isFalse);
      expect(logs, loggedWarning('changes still waiting for the other device'));
      // Only the digest sent on connecting.
      expect(link.sentOfType('sync.digest'), hasLength(1));
    });
  });

  test('closing the bloc answers a match check still waiting with no '
      'match', () {
    run((async) {
      startConnected(async);
      bool? matched;
      bloc.syncAndConfirmMatch().then((m) => matched = m);
      async.flushMicrotasks();
      // On connecting, after the drain, and the fresh one for the check;
      // nobody answered.
      expect(link.sentOfType('sync.digest'), hasLength(3));
      expect(matched, isNull);

      unawaited(bloc.close());
      async.flushMicrotasks();

      expect(matched, isFalse);
    });
  });
}
