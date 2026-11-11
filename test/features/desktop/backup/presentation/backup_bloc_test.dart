import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart' hide ConnectionState;
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/config/app_platform.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/l10n/app_strings_provider.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/features/desktop/backup/data/services/backup_service.dart';
import 'package:health_wallet/features/desktop/backup/data/services/safety_copy_expiry_scheduler.dart';
import 'package:health_wallet/features/desktop/backup/domain/entity/backup_entry.dart';
import 'package:health_wallet/features/desktop/backup/domain/entity/restore_result.dart';
import 'package:health_wallet/features/desktop/backup/presentation/bloc/backup_bloc.dart';
import 'package:health_wallet/features/desktop/communication/data/services/tcp_service.dart';
import 'package:health_wallet/features/desktop/lww_sync/presentation/bloc/lww_sync_bloc.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../desktop_test_fakes.dart';

/// Keeps backups in memory and writes what was called, in order, to [calls].
class FakeBackupService extends Fake implements BackupService {
  FakeBackupService(this.calls);

  final List<String> calls;
  final backups = <BackupEntry>[];
  bool userSelectedPath = true;

  /// Thrown by the next [createSnapshot] whose `isSafetyCopy` matches.
  Exception? snapshotError;
  Exception? safetyError;

  /// Thrown by [restoreFromFile], as when the transaction didn't commit.
  Exception? restoreError;
  RestoreResult restoreResult = const RestoreResult(hadFiles: true);

  /// Completes [restoreFromFile] when set; the test decides when.
  Completer<void>? restoreGate;

  /// Where snapshots write a small `.db`, so it can be sent to the phone;
  /// without it they write nothing.
  Directory? dir;

  final snapshots = <({String? name, bool isSafetyCopy, String? keepId})>[];
  final restoredPaths = <String>[];
  var _nextId = 100;

  BackupEntry add(String id, {String name = '', bool hasFiles = true}) {
    final entry = BackupEntry(
      id: id,
      name: name,
      timestamp: DateTime(2026, 10, 1).add(Duration(minutes: backups.length)),
      sizeBytes: 10,
      recordCount: 3,
      checksum: 'c$id',
      filePath: '/backups/$id.db',
      formatVersion: hasFiles ? BackupEntry.filesFormat : 1,
    );
    backups.add(entry);
    return entry;
  }

  @override
  Future<List<BackupEntry>> listBackups() async {
    calls.add('list');
    return [...backups]..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  @override
  Future<String> getBackupPath() async => '/backups';

  @override
  Future<bool> hasUserSelectedPath() async => userSelectedPath;

  @override
  Future<void> cleanUpOnStartup() async => calls.add('cleanUp');

  @override
  Future<BackupEntry> createSnapshot({
    String? name,
    bool isSafetyCopy = false,
    String? keepId,
  }) async {
    calls.add(isSafetyCopy ? 'safetyCopy' : 'snapshot');
    snapshots.add((name: name, isSafetyCopy: isSafetyCopy, keepId: keepId));
    final error = isSafetyCopy ? safetyError : snapshotError;
    if (error != null) throw error;
    final id = '${_nextId++}';
    final folder = dir;
    final path = folder != null ? '${folder.path}/$id.db' : '/backups/$id.db';
    if (folder != null) await File(path).writeAsBytes(List.filled(100, 1));
    final entry = BackupEntry(
      id: id,
      name: name ?? '',
      timestamp: DateTime(2026, 11, 3).add(Duration(minutes: _nextId)),
      sizeBytes: 10,
      recordCount: 3,
      checksum: 'c$id',
      filePath: path,
      formatVersion: BackupEntry.filesFormat,
      isSafetyCopy: isSafetyCopy,
    );
    backups.add(entry);
    return entry;
  }

  @override
  Future<RestoreResult> restoreFromFile(String backupPath) async {
    calls.add('restore');
    restoredPaths.add(backupPath);
    await restoreGate?.future;
    if (restoreError case final error?) throw error;
    return restoreResult;
  }
}

/// The parts of [LwwSyncBloc] a restore uses, writing to the same [calls].
class FakeLwwSyncBloc extends Fake implements LwwSyncBloc {
  FakeLwwSyncBloc(this.calls);

  final List<String> calls;
  bool connected = true;

  /// What [syncAndConfirmMatch] answers, once [matchGate] (if any) is done.
  bool matches = true;
  Completer<void>? matchGate;

  /// Thrown by [syncAndConfirmMatch] when set.
  Exception? syncError;
  bool paused = false;

  @override
  LwwSyncState get state => LwwSyncState(connected: connected);

  @override
  Future<bool> syncAndConfirmMatch({
    Duration timeout = const Duration(seconds: 60),
  }) async {
    calls.add('sync');
    await matchGate?.future;
    if (syncError case final error?) throw error;
    return matches;
  }

  @override
  Future<void> pauseApplying() async {
    calls.add('pause');
    paused = true;
  }

  @override
  void resumeApplying() {
    calls.add('resume');
    paused = false;
  }

  @override
  void add(LwwSyncEvent event) {
    calls.add(event is LwwLocalChanged ? 'localChanged' : '$event');
  }
}

void main() {
  const locale = Locale('ro');
  final ro = lookupAppLocalizations(locale);
  late FakeTcpService tcp;
  late BackupBloc bloc;

  BackupBloc buildBloc(AppPlatform platform, [BackupService? service]) {
    getIt.registerSingleton<AppPlatform>(platform);
    return BackupBloc(
      service ?? FakeBackupService([]),
      tcp,
      AppStringsProvider.forLocale(locale),
    );
  }

  // The app's localization delegates load it; a bare bloc test must.
  setUpAll(() => initializeDateFormatting('ro'));

  setUp(() => tcp = FakeTcpService());

  tearDown(() async {
    await bloc.close();
    await tcp.close();
    await getIt.unregister<AppPlatform>();
    if (getIt.isRegistered<LwwSyncBloc>()) {
      await getIt.unregister<LwwSyncBloc>();
    }
  });

  group('on the phone, a desktop backup error', () {
    setUp(() => bloc = buildBloc(AppPlatform.mobile));

    Future<String?> errorFor(Map<String, dynamic> payload) async {
      tcp.deliver('backup.error', payload);
      await bloc.stream.firstWhere((s) => s.error != null);
      return bloc.state.error;
    }

    test('with the no-location code is shown in the app language', () async {
      expect(
        await errorFor({'code': BackupBloc.noBackupLocationCode}),
        ro.desktopNoBackupLocation,
      );
    });

    test('from a desktop without the code is the no-location case', () async {
      expect(
        await errorFor({'error': 'No backup location set on desktop.'}),
        ro.desktopNoBackupLocation,
      );
    });

    test('with an unknown code is a generic backup failure', () async {
      expect(await errorFor({'code': 'disk_full'}), ro.desktopBackupFailed);
    });

    test('with the backup-failed code is a backup failure', () async {
      expect(
        await errorFor({'code': BackupBloc.backupFailedCode}),
        ro.desktopBackupFailed,
      );
    });
  });

  group('on the phone, the desktop\'s backup folder', () {
    setUp(() => bloc = buildBloc(AppPlatform.mobile));

    test('is unknown until the desktop reports it', () async {
      expect(bloc.state.desktopBackupReady, isNull);

      tcp.deliver('backup.status', {'ready': false, 'count': 0});
      await bloc.stream.firstWhere((s) => s.desktopBackupReady != null);
      expect(bloc.state.desktopBackupReady, isFalse);
    });

    test(
      'is unknown again, and no backup is running, once the link drops',
      () async {
        tcp.deliver('backup.status', {'ready': true, 'count': 1});
        await bloc.stream.firstWhere((s) => s.desktopBackupReady == true);
        tcp.deliver('backup.status', {'ready': true, 'backing_up': true});
        await bloc.stream.firstWhere((s) => s.isBackingUp);

        tcp.emitState(ConnectionState.disconnected);
        await bloc.stream.firstWhere((s) => !s.isBackingUp);
        expect(bloc.state.desktopBackupReady, isNull);
      },
    );

    test('an unreadable message is skipped and the next one still '
        'counts', () async {
      tcp.deliverRaw(
        TcpMessage.fromString(type: MessageType.data, data: 'not json'),
      );
      tcp.deliver('backup.status', {'ready': true, 'count': 2});

      await bloc.stream.firstWhere((s) => s.desktopBackupReady != null);
      expect(bloc.state.desktopBackupCount, 2);
    });
  });

  test(
    'the desktop answers a backup request without a folder with the code',
    () async {
      bloc = buildBloc(AppPlatform.desktop);

      tcp.deliver('backup.request', {});
      await pumpEventQueue();

      final sent = tcp.sentOf('backup.error').single;
      expect(sent['code'], BackupBloc.noBackupLocationCode);
      // Phones from before the code show this text.
      expect(sent['error'], startsWith('No backup location set on desktop.'));
    },
  );

  group('on the desktop', () {
    late List<String> calls;
    late FakeBackupService service;
    late FakeLwwSyncBloc sync;

    setUp(() async {
      calls = [];
      service = FakeBackupService(calls)..add('b1', name: 'October');
      sync = FakeLwwSyncBloc(calls);
      getIt.registerSingleton<LwwSyncBloc>(sync);
      bloc = buildBloc(AppPlatform.desktop, service);
      bloc.add(const BackupHistoryLoaded());
      await bloc.stream.firstWhere((s) => s.hasUserSelectedPath);
      calls.clear();
    });

    Future<List<BackupState>> restore(String id) async {
      final states = <BackupState>[];
      final sub = bloc.stream.listen(states.add);
      bloc.add(RestoreRequested(backupId: id));
      await bloc.stream.firstWhere((s) => !s.isRestoring);
      await pumpEventQueue();
      await sub.cancel();
      return states;
    }

    group('the first history load', () {
      test('cleans up before listing, once', () async {
        // The set-up already loaded it once.
        bloc.add(const BackupHistoryLoaded());
        await pumpEventQueue();

        expect(calls, ['list']);
      });

      test('cleans up leftovers and expired safety copies first', () async {
        final fresh = FakeBackupService(calls);
        final freshBloc = BackupBloc(
          fresh,
          tcp,
          AppStringsProvider.forLocale(locale),
        );
        addTearDown(freshBloc.close);

        freshBloc.add(const BackupHistoryLoaded());
        await freshBloc.stream.first;

        expect(calls, ['cleanUp', 'list']);
      });
    });

    group('a restore with the phone connected', () {
      test('syncs, holds received changes, makes the safety copy, restores, '
          'then sends the restored rows and resumes', () async {
        await restore('b1');

        expect(calls, [
          'list',
          'sync',
          'pause',
          'safetyCopy',
          'restore',
          'localChanged',
          'list',
          'resume',
        ]);
        expect(service.restoredPaths, ['/backups/b1.db']);
        expect(sync.paused, isFalse);
      });

      test('names the safety copy "Before restore" with the date and time, '
          'in the app language', () async {
        await restore('b1');

        final safety = service.snapshots.single;
        expect(safety.isSafetyCopy, isTrue);
        expect(
          safety.name,
          matches(
            RegExp(
              '^${RegExp.escape(ro.backupSafetyName('X')).replaceAll('X', '.+')}\$',
            ),
          ),
        );
        expect(safety.name, contains(':'));
      });

      test(
        'stays restoring until it is done, without showing a backup',
        () async {
          final states = await restore('b1');

          expect(states.first.isRestoring, isTrue);
          expect(
            states.sublist(0, states.length - 1).every((s) => s.isRestoring),
            isTrue,
          );
          expect(states.any((s) => s.isBackingUp), isFalse);
          final last = states.last;
          expect(last.isRestoring, isFalse);
          expect(last.error, isNull);
          expect(last.restoreNotice, isNull);
          expect(last.progress, 1.0);
          // The safety copy is listed.
          expect(last.backupHistory.first.isSafetyCopy, isTrue);
        },
      );

      test('tells the phone the new backup count, without sending it the '
          'safety copy', () async {
        await restore('b1');

        expect(tcp.sentOf('backup.status').last['count'], 2);
        expect(tcp.sentOf('backup_start'), isEmpty);
      });

      test('the safety copy keeps the backup being restored from the expiry '
          'sweep', () async {
        service.add('old-safety', name: 'Before restore');

        await restore('old-safety');

        final safety = service.snapshots.single;
        expect(safety.isSafetyCopy, isTrue);
        expect(safety.keepId, 'old-safety');
        expect(service.restoredPaths, ['/backups/old-safety.db']);
      });

      test('a sync that throws still restores, and says the phone is '
          'offline', () async {
        sync.syncError = const SocketException('link dropped');

        final states = await restore('b1');

        expect(calls, [
          'list',
          'sync',
          'pause',
          'safetyCopy',
          'restore',
          'localChanged',
          'list',
          'resume',
        ]);
        expect(sync.paused, isFalse);
        expect(states.last.isRestoring, isFalse);
        expect(states.last.error, isNull);
        expect(states.last.restoreNotice, ro.backupRestorePhoneOffline);
      });

      test('says the phone is offline when the tables did not match', () async {
        sync.matches = false;

        final states = await restore('b1');

        expect(calls, contains('restore'));
        expect(states.last.error, isNull);
        expect(states.last.restoreNotice, ro.backupRestorePhoneOffline);
      });
    });

    test(
      'a restore with the phone not connected does not wait for it',
      () async {
        sync.connected = false;

        final states = await restore('b1');

        expect(calls, isNot(contains('sync')));
        expect(calls, containsAllInOrder(['pause', 'safetyCopy', 'restore']));
        expect(states.last.restoreNotice, isNull);
      },
    );

    test(
      'files that could not be restored are counted in the notice',
      () async {
        sync.matches = false;
        service.restoreResult = const RestoreResult(
          hadFiles: true,
          filesNotRestored: 2,
        );

        final states = await restore('b1');

        expect(
          states.last.restoreNotice,
          '${ro.backupRestorePhoneOffline}\n\n${ro.backupFilesNotRestored(2)}',
        );
      },
    );

    test('without a safety copy nothing is restored', () async {
      service.safetyError = const FileSystemException(
        'No space left on device',
      );

      final states = await restore('b1');

      expect(calls, isNot(contains('restore')));
      expect(calls, isNot(contains('localChanged')));
      expect(calls.last, 'resume');
      expect(states.last.error, ro.backupSafetyFailed);
      expect(states.last.isRestoring, isFalse);
    });

    test('a restore that did not commit shows the failure, keeps the safety '
        'copy listed and resumes sync', () async {
      service.restoreError = const FileSystemException('rolled back');

      final states = await restore('b1');

      expect(calls, isNot(contains('localChanged')));
      expect(calls.last, 'resume');
      expect(states.last.error, ro.backupRestoreFailed);
      expect(states.last.backupHistory.first.isSafetyCopy, isTrue);
    });

    test('a backup that is gone fails before anything is paused', () async {
      final states = await restore('missing');

      expect(calls, ['list']);
      expect(states.last.error, ro.desktopBackupActionFailed);
      expect(states.last.isRestoring, isFalse);
    });

    test('received changes are held while the restore runs', () async {
      service.restoreGate = Completer<void>();

      bloc.add(const RestoreRequested(backupId: 'b1'));
      await pumpEventQueue();
      expect(sync.paused, isTrue);

      service.restoreGate!.complete();
      await bloc.stream.firstWhere((s) => !s.isRestoring);
      await pumpEventQueue();
      expect(sync.paused, isFalse);
    });

    group('while a restore runs', () {
      setUp(() {
        service.restoreGate = Completer<void>();
        bloc.add(const RestoreRequested(backupId: 'b1'));
      });

      Future<void> finish() async {
        service.restoreGate!.complete();
        await bloc.stream.firstWhere((s) => !s.isRestoring);
        await pumpEventQueue();
      }

      test('the phone\'s backup request is refused', () async {
        await pumpEventQueue();
        expect(bloc.state.isRestoring, isTrue);

        tcp.deliver('backup.request', {});
        await pumpEventQueue();

        final sent = tcp.sentOf('backup.error').single;
        expect(sent['code'], BackupBloc.restoreInProgressCode);
        expect(sent['error'], isA<String>());
        expect(service.snapshots.where((s) => !s.isSafetyCopy), isEmpty);
        await finish();
      });

      test('a second restore is ignored', () async {
        await pumpEventQueue();
        bloc.add(const RestoreRequested(backupId: 'b1'));
        await finish();

        expect(service.restoredPaths, hasLength(1));
      });

      test('a backup is not started', () async {
        await pumpEventQueue();
        bloc.add(const BackupRequested(name: 'nightly'));
        await finish();

        expect(service.snapshots.where((s) => !s.isSafetyCopy), isEmpty);
      });
    });

    group('a backup that fails', () {
      setUp(
        () => service.snapshotError = const FileSystemException(
          'No space left on device',
        ),
      );

      test('the phone asked for is reported to it as backup_failed', () async {
        tcp.deliver('backup.request', {});
        await bloc.stream.firstWhere((s) => s.error != null);
        await pumpEventQueue();

        final sent = tcp.sentOf('backup.error').single;
        expect(sent['code'], BackupBloc.backupFailedCode);
        expect(sent['error'], isA<String>());
        expect(bloc.state.error, ro.desktopBackupFailed);
        expect(bloc.state.isBackingUp, isFalse);
      });

      test('made on the desktop is not reported to the phone', () async {
        bloc.add(const BackupRequested(name: 'nightly'));
        await bloc.stream.firstWhere((s) => s.error != null);
        await pumpEventQueue();

        expect(tcp.sentOf('backup.error'), isEmpty);
        expect(bloc.state.error, ro.desktopBackupFailed);
      });
    });

    test('the phone\'s backup request makes a backup named for the phone '
        'and sends it', () async {
      final dir = await Directory.systemTemp.createTemp('backup_bloc_test');
      addTearDown(() => dir.delete(recursive: true));
      service.dir = dir;

      tcp.deliver('backup.request', {});
      await bloc.stream.firstWhere((s) => s.progress == 1.0);
      await pumpEventQueue();

      final made = service.snapshots.single;
      expect(made.isSafetyCopy, isFalse);
      expect(made.name, startsWith(ro.desktopRemoteBackupName('')));
      expect(tcp.sentOf('backup_start'), hasLength(1));
      expect(tcp.sentOf('backup_complete'), hasLength(1));
      expect(tcp.sentOf('backup.error'), isEmpty);
      expect(bloc.state.error, isNull);
    });
  });

  group('on the desktop, with the safety copy expiry scheduler', () {
    late List<String> calls;
    late FakeBackupService service;
    late FakeExpiryScheduler expiry;

    setUp(() async {
      calls = [];
      service = FakeBackupService(calls)
        ..add('b1', name: 'October')
        ..add('s1', name: 'Before restore');
      expiry = FakeExpiryScheduler(calls);
      getIt.registerSingleton<LwwSyncBloc>(FakeLwwSyncBloc(calls));
      getIt.registerSingleton<AppPlatform>(AppPlatform.desktop);
      bloc = BackupBloc(
        service,
        tcp,
        AppStringsProvider.forLocale(locale),
        expiry: expiry,
      );
      bloc.add(const BackupHistoryLoaded());
      await bloc.stream.firstWhere((s) => s.hasUserSelectedPath);
      calls.clear();
    });

    test('a restore keeps the backup it restores from the expiry until it '
        'is over', () async {
      bloc.add(const RestoreRequested(backupId: 's1'));
      await bloc.stream.firstWhere((s) => !s.isRestoring);
      await pumpEventQueue();

      expect(calls.first, 'list');
      expect(calls[1], 'keep s1');
      expect(calls.indexOf('restore'), greaterThan(1));
      expect(calls.last, 'release s1');
    });

    test('copies the scheduler deleted leave the list, and the selection '
        'when it was one of them', () async {
      bloc.add(BackupSelected(service.backups.last));
      await bloc.stream.firstWhere((s) => s.selectedBackup?.id == 's1');
      service.backups.removeWhere((b) => b.id == 's1');

      expiry.expire(1);
      final shown = await bloc.stream.firstWhere(
        (s) => s.backupHistory.length == 1,
      );

      expect(shown.backupHistory.single.id, 'b1');
      expect(shown.selectedBackup, isNull);
    });

    test('a selection the scheduler did not delete stays', () async {
      bloc.add(BackupSelected(service.backups.first));
      await bloc.stream.firstWhere((s) => s.selectedBackup?.id == 'b1');
      service.backups.removeWhere((b) => b.id == 's1');

      expiry.expire(1);
      final shown = await bloc.stream.firstWhere(
        (s) => s.backupHistory.length == 1,
      );

      expect(shown.selectedBackup?.id, 'b1');
    });

    test('stops listening to the scheduler once closed', () async {
      await bloc.close();

      expect(expiry.hasListener, isFalse);
    });
  });
}

/// Records the backups a restore keeps, in the same [calls], and lets a test
/// say that copies expired.
class FakeExpiryScheduler extends Fake implements SafetyCopyExpiryScheduler {
  FakeExpiryScheduler(this.calls);

  final List<String> calls;
  final _expired = StreamController<int>.broadcast();

  bool get hasListener => _expired.hasListener;

  void expire(int count) => _expired.add(count);

  @override
  Stream<int> get expired => _expired.stream;

  @override
  Future<T> keepWhile<T>(String backupId, Future<T> Function() work) async {
    calls.add('keep $backupId');
    try {
      return await work();
    } finally {
      calls.add('release $backupId');
    }
  }
}
