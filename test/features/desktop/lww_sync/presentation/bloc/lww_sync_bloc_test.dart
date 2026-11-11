import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/data/local/app_database.dart';
import 'package:health_wallet/core/services/attachment_file_cleaner.dart';
import 'package:health_wallet/core/services/attachment_references.dart';
import 'package:health_wallet/features/desktop/backup/data/services/backup_service.dart';
import 'package:health_wallet/features/desktop/communication/data/services/message_router.dart';
import 'package:health_wallet/features/desktop/lww_sync/data/services/attachment_sync_service.dart';
import 'package:health_wallet/features/desktop/lww_sync/data/services/change_watcher_service.dart';
import 'package:health_wallet/features/desktop/lww_sync/data/services/lww_sync_service.dart';
import 'package:health_wallet/features/desktop/lww_sync/presentation/bloc/lww_sync_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../lww_sync_test_helpers.dart';

/// A phone or a desktop: its own database, preferences, files and sync.
class _Device {
  _Device._(this.db, this.service, this.link, this.bloc, this.docs);

  final AppDatabase db;
  final LwwSyncService service;
  final LinkedTcpService link;
  final LwwSyncBloc bloc;
  final String docs;

  static Future<_Device> create(String id, TestDirs dirs, String docs) async {
    final db = openTestDatabase();
    final prefs = _MemoryPrefs({'lww_local_device_id': id});
    final service = LwwSyncService(
      db,
      prefs,
      AttachmentSyncService(FakePathResolver(docs)),
      AttachmentFileCleaner(
        db,
        FakePathResolver(docs),
        AttachmentReferences(db),
        LegacyAttachmentFolders(FakePathResolver(docs)),
      ),
    );
    final link = LinkedTcpService(id, 'Device $id');
    final bloc = LwwSyncBloc(
      service,
      ChangeWatcherService(db),
      link,
      MessageRouter(link),
    );
    return _Device._(db, service, link, bloc, docs);
  }

  Future<void> dispose() async {
    await bloc.close();
    await link.close();
    await db.close();
  }
}

/// SharedPreferences for one device; the platform mock is shared by all.
class _MemoryPrefs extends Fake implements SharedPreferences {
  _MemoryPrefs(Map<String, Object> initial) : _values = {...initial};

  final Map<String, Object> _values;

  @override
  String? getString(String key) => _values[key] as String?;

  @override
  Future<bool> setString(String key, String value) async {
    _values[key] = value;
    return true;
  }

  @override
  Future<bool> remove(String key) async {
    _values.remove(key);
    return true;
  }
}

/// Both devices connected, in sync and idle, with nothing on the wire: every
/// digest sent was answered, every batch acknowledged.
bool _quiet(_Device a, _Device b) =>
    a.link.inFlight == 0 &&
    b.link.inFlight == 0 &&
    [a, b].every(
      (d) =>
          d.bloc.state.isSynced &&
          d.bloc.state.syncStatus == LwwSyncStatus.idle,
    );

void main() {
  late TestDirs dirs;
  late _Device phone;
  late _Device desktop;

  setUp(() async {
    dirs = await TestDirs.create();
    final phoneDocs = '${dirs.root.path}/phone';
    final desktopDocs = '${dirs.root.path}/desktop';
    await Directory(phoneDocs).create(recursive: true);
    await Directory(desktopDocs).create(recursive: true);
    phone = await _Device.create('phone-a', dirs, phoneDocs);
    desktop = await _Device.create('desktop-z', dirs, desktopDocs);
    // Never reached, so a busy machine never times out a real answer; the
    // tests that drop answers shorten it once nothing else is waiting.
    LwwSyncBloc.ackTimeout = const Duration(hours: 1);
    LwwSyncBloc.settleDelay = Duration.zero;
    LwwSyncBloc.settleFallback = const Duration(hours: 1);
  });

  tearDown(() async {
    await phone.dispose();
    await desktop.dispose();
    await dirs.dispose();
  });

  Future<void> start() async {
    phone.bloc.add(const LwwSyncInitialised());
    desktop.bloc.add(const LwwSyncInitialised());
    await Future.wait([phone.bloc.initialised, desktop.bloc.initialised]);
  }

  Future<void> connect() async {
    LinkedTcpService.link(phone.link, desktop.link);
    await eventually(() => _quiet(phone, desktop), reason: 'both in sync');
  }

  Future<String?> titleOn(_Device d, String id) async =>
      (await fetchRow(d.db, 'fhir_resource', id))?['title'] as String?;

  test('different tables on the two devices converge on connecting, and '
      'both then say in sync', () async {
    await insertFhir(phone.db, id: 'p', title: 'from phone');
    await insertFhir(desktop.db, id: 'd', title: 'from desktop');
    await insertFhir(phone.db, id: 'both', updatedAt: ms(at(1)), title: 'old');
    await insertFhir(
      desktop.db,
      id: 'both',
      updatedAt: ms(at(2)),
      title: 'new',
    );
    await start();
    await connect();

    expect(await titleOn(desktop, 'p'), 'from phone');
    expect(await titleOn(phone, 'd'), 'from desktop');
    expect(await titleOn(phone, 'both'), 'new');
    expect(
      await phone.service.computeDigest(),
      await desktop.service.computeDigest(),
    );
    expect(phone.bloc.state.pendingChangeCount, 0);
    expect(phone.bloc.state.lastSyncPeerName, 'Device desktop-z');
  });

  test('an edit made while connected arrives, and both sides return to in '
      'sync instead of staying out of it', () async {
    await start();
    await connect();

    await insertFhir(phone.db, id: 'new', title: 'scan');
    notifySyncedTablesWritten(phone.db);
    await eventually(() => desktop.bloc.state.recordsVersion > 0);
    expect(await titleOn(desktop, 'new'), 'scan');
    await eventually(() => _quiet(phone, desktop), reason: 'in sync again');
  });

  test('Sync Now with nothing to send still checks with the other device and '
      'counts as a sync on both', () async {
    await insertFhir(phone.db, id: 'same', updatedAt: ms(at(1)));
    await insertFhir(desktop.db, id: 'same', updatedAt: ms(at(1)));
    await start();
    // Idle afterwards, so showing the check is a change of status.
    await connect();
    final phoneStamp = phone.bloc.state.lastSyncTime!;
    final desktopStamp = desktop.bloc.state.lastSyncTime!;

    final statuses = <LwwSyncStatus>[];
    final sub = phone.bloc.stream.listen((s) => statuses.add(s.syncStatus));
    addTearDown(sub.cancel);
    phone.bloc.add(const SyncTriggered(userRequested: true));

    await eventually(
      () =>
          phone.bloc.state.lastSyncTime != phoneStamp &&
          desktop.bloc.state.lastSyncTime != desktopStamp &&
          _quiet(phone, desktop),
      reason: 'both stamped by the check, and the check answered',
    );
    expect(phone.bloc.state.lastSyncTime!.isAfter(phoneStamp), isTrue);
    expect(desktop.bloc.state.lastSyncTime!.isAfter(desktopStamp), isTrue);
    expect(statuses, contains(LwwSyncStatus.syncing), reason: 'it shows');
    expect(phone.bloc.state.isSynced, isTrue);
    expect(phone.bloc.state.sentRows, 0);
  });

  test('a check the other device never answers ends with an error', () async {
    await start();
    await connect();
    // Short only now: the answers it would cut off are all dropped.
    LwwSyncBloc.ackTimeout = const Duration(milliseconds: 50);
    desktop.link.dropTypes.add('sync.digest');

    phone.bloc.add(const SyncTriggered());

    await eventually(
      () => phone.bloc.state.syncStatus == LwwSyncStatus.error,
    );
  });

  test('an edit sent into a dropped link is sent again, not lost', () async {
    await start();
    await connect();

    phone.link.dropTypes.add('sync.batch');
    await insertFhir(phone.db, id: 'lost', title: 'first try');
    notifySyncedTablesWritten(phone.db);
    await eventually(() => phone.link.sentOfType('sync.batch').isNotEmpty);
    expect(phone.bloc.state.pendingChangeCount, 1);

    phone.link.unlink();
    phone.link.dropTypes.clear();
    await eventually(() => !phone.bloc.state.connected);
    expect(phone.bloc.state.pendingChangeCount, 1, reason: 'still waiting');

    await connect();
    expect(await titleOn(desktop, 'lost'), 'first try');
    expect(phone.bloc.state.pendingChangeCount, 0);
  });

  test(
    'changes made offline wait in the outbox and go out on reconnect',
    () async {
      await start();
      await connect();
      phone.link.unlink();
      await eventually(() => !phone.bloc.state.connected);

      await insertFhir(phone.db, id: 'offline-1');
      await insertNote(
        phone.db,
        content: 'offline note',
        resourceId: 'offline-1',
      );
      notifySyncedTablesWritten(phone.db);
      await eventually(() => phone.bloc.state.pendingChangeCount == 2);
      expect(phone.bloc.state.isSynced, isFalse);

      await connect();
      expect(
        await fetchRow(desktop.db, 'fhir_resource', 'offline-1'),
        isNotNull,
      );
      expect(await countRows(desktop.db, 'record_notes'), 1);
    },
  );

  test(
    'receiving rows does not skip a local edit made at the same time',
    () async {
      await start();
      await connect();

      await insertFhir(desktop.db, id: 'from-desk');
      await insertFhir(phone.db, id: 'from-phone');
      notifySyncedTablesWritten(desktop.db);
      notifySyncedTablesWritten(phone.db);
      await eventually(
        () async =>
            await fetchRow(desktop.db, 'fhir_resource', 'from-phone') != null &&
            await fetchRow(phone.db, 'fhir_resource', 'from-desk') != null,
      );
      await eventually(() => _quiet(phone, desktop), reason: 'in sync');
    },
  );

  test('a batch nobody acknowledges is not counted as delivered', () async {
    await start();
    await connect();

    // Short only while the acks are dropped, long again for the resend.
    LwwSyncBloc.ackTimeout = const Duration(milliseconds: 50);
    desktop.link.dropTypes.add('sync.ack');
    await insertFhir(phone.db, id: 'unacked');
    notifySyncedTablesWritten(phone.db);
    await eventually(
      () => phone.bloc.state.syncStatus == LwwSyncStatus.error,
    );
    expect(phone.bloc.state.pendingChangeCount, 1);
    expect(phone.bloc.state.isSynced, isFalse);

    LwwSyncBloc.ackTimeout = const Duration(hours: 1);
    desktop.link.dropTypes.clear();
    phone.bloc.add(const SyncTriggered());
    await eventually(() => phone.bloc.state.pendingChangeCount == 0);
  });

  test('missing attachment files follow on request, in chunks', () async {
    await File('${phone.docs}/report.pdf').writeAsBytes(
      List.generate(LwwSyncService.fileChunkBytes + 99, (i) => i % 256),
    );
    await insertFhir(
      phone.db,
      id: 'doc',
      resourceType: 'DocumentReference',
      raw: documentReferenceRaw([
        {'url': 'file://report.pdf', 'title': 'Report'},
      ]),
    );
    await start();
    await connect();

    await eventually(() => File('${desktop.docs}/report.pdf').existsSync());
    expect(
      File('${desktop.docs}/report.pdf').lengthSync(),
      LwwSyncService.fileChunkBytes + 99,
    );
    expect(phone.link.sentOfType('sync.file_chunk'), hasLength(2));
    expect(
      phone.link.sent.every(
        (m) =>
            !jsonEncode(m.payload).contains('"data"') ||
            m.type == 'sync.file_chunk',
      ),
      isTrue,
      reason: 'no file travels inside a row',
    );
  });

  test('a peer that is not the last one starts over', () async {
    await insertFhir(phone.db, id: 'a');
    await start();
    await connect();
    phone.link.unlink();

    final otherDesktop = await _Device.create(
      'desktop-y',
      dirs,
      '${dirs.root.path}/phone',
    );
    otherDesktop.bloc.add(const LwwSyncInitialised());
    await otherDesktop.bloc.initialised;
    LinkedTcpService.link(phone.link, otherDesktop.link);
    await eventually(() => _quiet(phone, otherDesktop));
    expect(await fetchRow(otherDesktop.db, 'fhir_resource', 'a'), isNotNull);
    expect(phone.bloc.state.lastSyncPeerName, 'Device desktop-y');
    await otherDesktop.dispose();
  });

  test('waitUntilDrained returns once every change was acknowledged', () async {
    await start();
    await connect();
    await insertFhir(phone.db, id: 'before-backup');
    expect(await phone.bloc.waitUntilDrained(), isTrue);
    expect(
      await fetchRow(desktop.db, 'fhir_resource', 'before-backup'),
      isNotNull,
    );
  });

  Future<void> insertBulk(int count) async {
    await phone.db.transaction(() async {
      for (var i = 0; i < count; i++) {
        await insertFhir(phone.db, id: 'bulk-$i');
      }
    });
    notifySyncedTablesWritten(phone.db);
  }

  test('lists reload once per burst of received rows, however long the '
      'batches take', () async {
    // After the last batch of a run the lists reload at once; after one that
    // says more follow, only an hour later.
    LwwSyncBloc.settleDelay = Duration.zero;
    LwwSyncBloc.settleFallback = const Duration(hours: 1);
    await start();
    await connect();
    final before = desktop.bloc.state.recordsVersion;
    // The phone sends the second batch only once the first is acknowledged;
    // holding the ack stands for a slow link or a busy device.
    desktop.link.holdTypes.add('sync.ack');
    // One write of two batches' worth: the first says more follow, so the
    // desktop waits for the second.
    await insertBulk(LwwSyncService.maxBatchRows * 2);
    await eventually(
      () => desktop.bloc.state.receivedRows == LwwSyncService.maxBatchRows,
      reason: 'the first batch applied',
    );
    // Enough turns of the event loop for a reload due at once to happen.
    await pumpEventQueue();
    expect(desktop.bloc.state.recordsVersion, before, reason: 'more follow');

    desktop.link.releaseHeld();
    await eventually(() => desktop.bloc.state.recordsVersion > before);
    await eventually(() => _quiet(phone, desktop), reason: 'all sent');
    await pumpEventQueue();
    expect(desktop.bloc.state.recordsVersion, before + 1);
    expect(
      await countRows(desktop.db, 'fhir_resource'),
      LwwSyncService.maxBatchRows * 2,
    );
  });

  test(
    'lists still reload when the batches said to follow never come',
    () async {
      // Only the wait for batches said to follow can reload the lists.
      LwwSyncBloc.settleDelay = const Duration(hours: 1);
      LwwSyncBloc.settleFallback = Duration.zero;
      await start();
      await connect();
      final before = desktop.bloc.state.recordsVersion;
      // The phone waits for an ack that never comes, so it never sends the
      // second batch.
      desktop.link.dropTypes.add('sync.ack');
      await insertBulk(LwwSyncService.maxBatchRows * 2);
      await eventually(() => desktop.bloc.state.recordsVersion == before + 1);
      expect(
        await countRows(desktop.db, 'fhir_resource'),
        LwwSyncService.maxBatchRows,
      );
    },
  );

  test('a peer that sends something unreadable gets a failed ack, and '
      'nothing is stuck syncing', () async {
    await start();
    await connect();
    await desktop.link.sendData('sync.batch', {'id': 7, 'tables': 'nonsense'});
    await eventually(() => phone.link.sentOfType('sync.ack').isNotEmpty);
    final ack = phone.link.sentOfType('sync.ack').last.payload;
    expect(ack, {'id': 7, 'ok': false});
    expect(phone.bloc.state.syncStatus, isNot(LwwSyncStatus.syncing));
  });
}
