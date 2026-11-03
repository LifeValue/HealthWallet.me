import 'dart:async';
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
import 'package:health_wallet/features/desktop/lww_sync/domain/entity/sync_batch.dart';
import 'package:health_wallet/features/desktop/lww_sync/presentation/bloc/lww_sync_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../lww_sync_test_helpers.dart';

/// The real sync service, except that while [gate] is set a received batch
/// waits at it before it is applied.
class _GatedSyncService extends LwwSyncService {
  _GatedSyncService(
    super.db,
    super.prefs,
    super.attachmentSync,
    super.fileCleaner,
  );

  Completer<void>? gate;
  bool atGate = false;

  @override
  Future<AppliedBatch> applyBatch(SyncBatch batch) async {
    final gate = this.gate;
    if (gate != null) {
      atGate = true;
      await gate.future;
      atGate = false;
    }
    return super.applyBatch(batch);
  }
}

/// A phone or a desktop: its own database, preferences, files and sync.
class _Device {
  _Device._(this.db, this.service, this.link, this.bloc);

  final AppDatabase db;
  final _GatedSyncService service;
  final LinkedTcpService link;
  final LwwSyncBloc bloc;

  static Future<_Device> create(String id, String docs) async {
    await Directory(docs).create(recursive: true);
    final db = openTestDatabase();
    final service = _GatedSyncService(
      db,
      _MemoryPrefs({'lww_local_device_id': id}),
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
    return _Device._(db, service, link, bloc);
  }

  Future<void> dispose() async {
    await bloc.close();
    await link.close();
    await db.close();
  }
}

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

Future<void> _until(bool Function() condition, {String? reason}) async {
  final deadline = DateTime.now().add(const Duration(seconds: 10));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('timed out waiting${reason == null ? '' : ' for $reason'}');
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

Future<void> _untilAsync(
  Future<bool> Function() condition, {
  String? reason,
}) async {
  final deadline = DateTime.now().add(const Duration(seconds: 10));
  while (!await condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('timed out waiting${reason == null ? '' : ' for $reason'}');
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

void main() {
  late TestDirs dirs;
  late _Device phone;
  late _Device desktop;
  late Duration ackTimeout;

  setUp(() async {
    dirs = await TestDirs.create();
    phone = await _Device.create('phone-a', '${dirs.root.path}/phone');
    desktop = await _Device.create('desktop-z', '${dirs.root.path}/desktop');
    ackTimeout = LwwSyncBloc.ackTimeout;
    LwwSyncBloc.ackTimeout = const Duration(seconds: 2);
    LwwSyncBloc.settleDelay = const Duration(milliseconds: 100);
  });

  tearDown(() async {
    LwwSyncBloc.ackTimeout = ackTimeout;
    desktop.bloc.resumeApplying();
    await phone.dispose();
    await desktop.dispose();
    await dirs.dispose();
  });

  Future<void> start() async {
    phone.bloc.add(const LwwSyncInitialised());
    desktop.bloc.add(const LwwSyncInitialised());
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }

  Future<void> connect() async {
    LinkedTcpService.link(phone.link, desktop.link);
    await _until(
      () => phone.bloc.state.isSynced && desktop.bloc.state.isSynced,
      reason: 'both in sync',
    );
  }

  Future<bool> onDesktop(String id) async =>
      await fetchRow(desktop.db, 'fhir_resource', id) != null;

  Iterable<Object?> desktopAcks() =>
      desktop.link.sentOfType('sync.ack').map((m) => m.payload['ok']);

  group('pauseApplying', () {
    test('a batch received while paused waits, and is applied and '
        'acknowledged once applying resumes', () async {
      await start();
      await connect();
      final acksBefore = desktopAcks().length;

      await desktop.bloc.pauseApplying();
      await insertFhir(phone.db, id: 'during-restore', title: 'from phone');
      await _until(
        () => phone.link.sentOfType('sync.batch').isNotEmpty,
        reason: 'the phone sends its change',
      );
      await Future<void>.delayed(const Duration(milliseconds: 300));

      expect(await onDesktop('during-restore'), isFalse, reason: 'held');
      expect(desktopAcks(), hasLength(acksBefore), reason: 'no answer yet');

      desktop.bloc.resumeApplying();

      await _untilAsync(
        () => onDesktop('during-restore'),
        reason: 'applied after resume',
      );
      await _until(() => phone.bloc.state.pendingChangeCount == 0);
      expect(desktopAcks(), everyElement(isTrue), reason: 'never ok:false');
    });

    test('a batch held past the phone\'s ack timeout is sent again and '
        'applied, and nothing is refused', () async {
      LwwSyncBloc.ackTimeout = const Duration(milliseconds: 300);
      await start();
      await connect();

      await desktop.bloc.pauseApplying();
      await insertFhir(phone.db, id: 'slow', title: 'first');
      await _until(
        () => phone.bloc.state.syncStatus == LwwSyncStatus.error,
        reason: 'the phone stops waiting for the ack',
      );
      expect(phone.bloc.state.pendingChangeCount, 1);

      desktop.bloc.resumeApplying();
      await _untilAsync(() => onDesktop('slow'));
      phone.bloc.add(const SyncTriggered());

      await _until(
        () => phone.bloc.state.pendingChangeCount == 0,
        reason: 'the resent batch is acknowledged',
      );
      expect(await countRows(desktop.db, 'fhir_resource'), 1);
      expect(desktopAcks(), isNotEmpty);
      expect(desktopAcks(), everyElement(isTrue), reason: 'never ok:false');
    });

    test('pausing twice needs one resume, and resuming when not paused does '
        'nothing', () async {
      desktop.bloc.resumeApplying();
      await start();
      await connect();

      await desktop.bloc.pauseApplying();
      await desktop.bloc.pauseApplying();
      await insertFhir(phone.db, id: 'twice');
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(await onDesktop('twice'), isFalse);

      desktop.bloc.resumeApplying();
      await _untilAsync(() => onDesktop('twice'));
    });

    test('pausing while a batch is being applied completes only once its '
        'rows are saved, and holds the next batch', () async {
      await start();
      await connect();
      final gate = Completer<void>();
      desktop.service.gate = gate;
      await insertFhir(phone.db, id: 'in-flight');
      await _until(
        () => desktop.service.atGate,
        reason: 'the desktop starts applying',
      );

      var paused = false;
      final pausing = desktop.bloc.pauseApplying().then((_) => paused = true);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(paused, isFalse, reason: 'the batch is still being applied');

      desktop.service.gate = null;
      gate.complete();
      await pausing;
      expect(await onDesktop('in-flight'), isTrue, reason: 'saved first');

      final batchesBefore = phone.link.sentOfType('sync.batch').length;
      await insertFhir(phone.db, id: 'next');
      await _until(
        () => phone.link.sentOfType('sync.batch').length > batchesBefore,
      );
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(await onDesktop('next'), isFalse, reason: 'held');

      desktop.bloc.resumeApplying();
      await _untilAsync(() => onDesktop('next'));
    });

    test('closing the bloc while a batch is held does not hang', () async {
      await start();
      await connect();
      await desktop.bloc.pauseApplying();
      await insertFhir(phone.db, id: 'held');
      await _until(() => phone.link.sentOfType('sync.batch').isNotEmpty);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      await desktop.bloc.close().timeout(const Duration(seconds: 5));
    });
  });

  group('syncAndConfirmMatch', () {
    test('returns false at once when no phone is connected, and sends '
        'nothing', () async {
      await start();

      final watch = Stopwatch()..start();
      expect(await desktop.bloc.syncAndConfirmMatch(), isFalse);
      expect(watch.elapsed, lessThan(const Duration(seconds: 1)));
      expect(desktop.link.sent, isEmpty);
    });

    test('sends what the desktop has waiting, checks with the phone and '
        'returns true once the tables match', () async {
      await start();
      await connect();
      await insertFhir(desktop.db, id: 'desk-edit');
      final digestsBefore = desktop.link.sentOfType('sync.digest').length;

      expect(await desktop.bloc.syncAndConfirmMatch(), isTrue);

      expect(await fetchRow(phone.db, 'fhir_resource', 'desk-edit'), isNotNull);
      expect(desktop.bloc.state.tablesMatch, isTrue);
      expect(desktop.bloc.state.pendingChangeCount, 0);
      expect(
        desktop.link.sentOfType('sync.digest').length,
        greaterThan(digestsBefore),
        reason: 'a fresh comparison, not an old answer',
      );
    });

    test('right after the phone reconnects, waits for the phone\'s offline '
        'records to arrive', () async {
      await start();
      await connect();
      phone.link.unlink();
      await _until(() => !desktop.bloc.state.connected);
      await insertFhir(phone.db, id: 'offline-1', title: 'made offline');
      await insertNote(
        phone.db,
        content: 'offline note',
        resourceId: 'offline-1',
      );

      LinkedTcpService.link(phone.link, desktop.link);
      await _until(() => desktop.bloc.state.connected);

      expect(await desktop.bloc.syncAndConfirmMatch(), isTrue);
      expect(await onDesktop('offline-1'), isTrue);
      expect(await countRows(desktop.db, 'record_notes'), 1);
    });

    test('returns false after the timeout when the phone never answers the '
        'comparison', () async {
      await start();
      await connect();
      phone.link.dropTypes.add('sync.digest');

      final watch = Stopwatch()..start();
      final matched = await desktop.bloc.syncAndConfirmMatch(
        timeout: const Duration(milliseconds: 500),
      );

      expect(matched, isFalse);
      expect(watch.elapsed, lessThan(const Duration(seconds: 2)));
    });

    test('returns false after the timeout when the desktop\'s changes are '
        'never acknowledged', () async {
      await start();
      await connect();
      phone.link.dropTypes.add('sync.ack');
      await insertFhir(desktop.db, id: 'unacked');

      final watch = Stopwatch()..start();
      final matched = await desktop.bloc.syncAndConfirmMatch(
        timeout: const Duration(milliseconds: 500),
      );

      expect(matched, isFalse);
      expect(watch.elapsed, lessThan(const Duration(seconds: 2)));
    });

    test('returns false as soon as the phone disconnects during the '
        'comparison, without waiting for the timeout', () async {
      await start();
      await connect();
      phone.link.dropTypes.add('sync.digest');

      final watch = Stopwatch()..start();
      final matched = desktop.bloc.syncAndConfirmMatch(
        timeout: const Duration(seconds: 8),
      );
      await _until(
        () => !desktop.bloc.state.tablesMatch,
        reason: 'the fresh comparison starts',
      );
      phone.link.unlink();

      expect(await matched, isFalse);
      expect(watch.elapsed, lessThan(const Duration(seconds: 4)));
    });

    test('returns false at once while applying is paused', () async {
      await start();
      await connect();
      await desktop.bloc.pauseApplying();

      final watch = Stopwatch()..start();
      expect(await desktop.bloc.syncAndConfirmMatch(), isFalse);
      expect(watch.elapsed, lessThan(const Duration(seconds: 1)));
    });
  });
}
