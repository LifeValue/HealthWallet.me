import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/widgets.dart' hide ConnectionState;
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/config/app_platform.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/l10n/app_strings_provider.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/features/desktop/backup/data/services/backup_service.dart';
import 'package:health_wallet/features/desktop/backup/domain/entity/backup_entry.dart';
import 'package:health_wallet/features/desktop/backup/domain/entity/restore_result.dart';
import 'package:health_wallet/features/desktop/backup/presentation/bloc/backup_bloc.dart';
import 'package:health_wallet/features/desktop/communication/data/services/tcp_service.dart';
import 'package:health_wallet/features/desktop/lww_sync/presentation/bloc/lww_sync_bloc.dart';
import 'package:health_wallet/features/home/presentation/bloc/home_bloc.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../desktop_test_fakes.dart';

/// Keeps backups in memory, writes what was called to [calls] and fails
/// the calls a test asks it to.
class _FakeBackupService extends Fake implements BackupService {
  final calls = <String>[];
  final backups = <BackupEntry>[];
  bool userSelectedPath = true;
  String path = '/backups';

  /// Thrown by the matching call when set.
  Exception? listError;
  Exception? deleteError;
  Exception? setDirectoryError;
  Exception? resetDirectoryError;
  Exception? snapshotError;

  /// Completes [createSnapshot] when set; the test decides when.
  Completer<void>? snapshotGate;

  /// Runs inside [restoreFromFile], after the restore "committed".
  void Function()? onRestore;
  RestoreResult restoreResult = const RestoreResult(hadFiles: true);

  /// Where snapshots write their `.db`, of [snapshotBytes] bytes.
  Directory? dir;
  int snapshotBytes = 100;

  final snapshotNames = <String?>[];
  var _nextId = 100;

  BackupEntry add(String id, {int minutes = 0}) {
    final entry = BackupEntry(
      id: id,
      name: 'Backup $id',
      timestamp: DateTime.utc(2026, 10, 1).add(Duration(minutes: minutes)),
      sizeBytes: 10,
      recordCount: 3,
      checksum: 'c$id',
      filePath: '/backups/$id.db',
      formatVersion: BackupEntry.filesFormat,
    );
    backups.add(entry);
    return entry;
  }

  @override
  Future<List<BackupEntry>> listBackups() async {
    calls.add('list');
    if (listError case final error?) throw error;
    return [...backups]..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  @override
  Future<String> getBackupPath() async => path;

  @override
  Future<bool> hasUserSelectedPath() async => userSelectedPath;

  @override
  Future<void> cleanUpOnStartup() async => calls.add('cleanUp');

  @override
  Future<void> deleteBackup(String backupId) async {
    calls.add('delete $backupId');
    if (deleteError case final error?) throw error;
    backups.removeWhere((b) => b.id == backupId);
  }

  @override
  Future<void> setBackupDirectory(String newPath) async {
    calls.add('setDirectory $newPath');
    if (setDirectoryError case final error?) throw error;
    path = newPath;
    userSelectedPath = true;
  }

  @override
  Future<void> resetBackupDirectory() async {
    calls.add('resetDirectory');
    if (resetDirectoryError case final error?) throw error;
    path = '/default-backups';
    userSelectedPath = false;
  }

  @override
  Future<BackupEntry> createSnapshot({
    String? name,
    bool isSafetyCopy = false,
    String? keepId,
  }) async {
    calls.add(isSafetyCopy ? 'safetyCopy' : 'snapshot');
    if (!isSafetyCopy) snapshotNames.add(name);
    await snapshotGate?.future;
    if (!isSafetyCopy && snapshotError != null) throw snapshotError!;
    final id = '${_nextId++}';
    final folder = dir;
    final filePath = folder != null
        ? '${folder.path}/$id.db'
        : '/backups/$id.db';
    if (folder != null) {
      await File(
        filePath,
      ).writeAsBytes(List.generate(snapshotBytes, (i) => i % 251));
    }
    final entry = BackupEntry(
      id: id,
      name: name ?? '',
      timestamp: DateTime.utc(2026, 11, 3).add(Duration(minutes: _nextId)),
      sizeBytes: snapshotBytes,
      recordCount: 7,
      checksum: 'c$id',
      filePath: filePath,
      formatVersion: BackupEntry.filesFormat,
      isSafetyCopy: isSafetyCopy,
    );
    backups.add(entry);
    return entry;
  }

  @override
  Future<RestoreResult> restoreFromFile(String backupPath) async {
    calls.add('restore');
    onRestore?.call();
    return restoreResult;
  }
}

/// The parts of [LwwSyncBloc] the backup bloc uses.
class _FakeLwwSyncBloc extends Fake implements LwwSyncBloc {
  bool connected = false;
  bool drained = true;
  int drainWaits = 0;
  bool addThrows = false;
  final added = <LwwSyncEvent>[];

  @override
  LwwSyncState get state => LwwSyncState(connected: connected);

  @override
  Future<bool> waitUntilDrained({
    Duration timeout = const Duration(seconds: 30),
  }) async {
    drainWaits++;
    return drained;
  }

  @override
  Future<bool> syncAndConfirmMatch({
    Duration timeout = const Duration(seconds: 60),
  }) async => true;

  @override
  Future<void> pauseApplying() async {}

  @override
  void resumeApplying() {}

  @override
  void add(LwwSyncEvent event) {
    if (addThrows) throw StateError('sync bloc closed');
    added.add(event);
  }
}

/// Records the events the restore sends to the records screen.
class _FakeHomeBloc extends Fake implements HomeBloc {
  final events = <HomeEvent>[];

  @override
  void add(HomeEvent event) => events.add(event);
}

void main() {
  const locale = Locale('ro');
  final ro = lookupAppLocalizations(locale);
  late FakeTcpService tcp;
  late _FakeBackupService service;
  late _FakeLwwSyncBloc sync;

  BackupBloc buildBloc() =>
      BackupBloc(service, tcp, AppStringsProvider.forLocale(locale));

  // The app's localization delegates load it; a bare bloc test must.
  setUpAll(() => initializeDateFormatting('ro'));

  setUp(() {
    tcp = FakeTcpService();
    service = _FakeBackupService();
    sync = _FakeLwwSyncBloc();
    getIt.registerSingleton<LwwSyncBloc>(sync);
  });

  tearDown(() async {
    await tcp.close();
    await getIt.reset();
  });

  group('on the desktop', () {
    setUp(() => getIt.registerSingleton<AppPlatform>(AppPlatform.desktop));

    group('loading the history', () {
      blocTest<BackupBloc, BackupState>(
        'shows the backups, newest first, with the folder and whether the '
        'user chose it',
        setUp: () {
          service
            ..add('old')
            ..add('new', minutes: 5)
            ..userSelectedPath = false;
        },
        build: buildBloc,
        act: (bloc) => bloc.add(const BackupHistoryLoaded()),
        expect: () => [
          isA<BackupState>()
              .having(
                (s) => s.backupHistory.map((b) => b.id),
                'history',
                ['new', 'old'],
              )
              .having((s) => s.backupPath, 'path', '/backups')
              .having((s) => s.hasUserSelectedPath, 'user path', isFalse)
              .having((s) => s.error, 'error', isNull),
        ],
      );

      blocTest<BackupBloc, BackupState>(
        'tells the connected phone whether a folder is set, the count and '
        'the newest backup',
        setUp: () => service
          ..add('old')
          ..add('new', minutes: 5),
        build: buildBloc,
        act: (bloc) => bloc.add(const BackupHistoryLoaded()),
        verify: (_) {
          expect(tcp.sentOf('backup.status'), [
            {
              'ready': true,
              'count': 2,
              'last_backup': DateTime.utc(
                2026,
                10,
                1,
                0,
                5,
              ).toIso8601String(),
            },
          ]);
        },
      );

      blocTest<BackupBloc, BackupState>(
        'without backups the status has no last backup',
        build: buildBloc,
        act: (bloc) => bloc.add(const BackupHistoryLoaded()),
        verify: (_) {
          expect(tcp.sentOf('backup.status'), [
            {'ready': true, 'count': 0},
          ]);
        },
      );

      blocTest<BackupBloc, BackupState>(
        'sends nothing while no phone is connected',
        setUp: () => tcp.state = ConnectionState.disconnected,
        build: buildBloc,
        act: (bloc) => bloc.add(const BackupHistoryLoaded()),
        verify: (_) => expect(tcp.sent, isEmpty),
      );

      blocTest<BackupBloc, BackupState>(
        'a status the link drops is logged, not thrown',
        setUp: () =>
            tcp.onSend = (type, _) async =>
                throw const LinkNotConnectedException(),
        build: buildBloc,
        act: (bloc) => bloc.add(const BackupHistoryLoaded()),
        expect: () => [
          isA<BackupState>().having((s) => s.error, 'error', isNull),
        ],
        verify: (_) => expect(tcp.sentOf('backup.status'), hasLength(1)),
      );

      blocTest<BackupBloc, BackupState>(
        'that fails shows the localized failure and tells the phone nothing',
        setUp: () => service.listError = const FileSystemException('denied'),
        build: buildBloc,
        act: (bloc) => bloc.add(const BackupHistoryLoaded()),
        expect: () => [
          isA<BackupState>()
              .having((s) => s.error, 'error', ro.desktopBackupActionFailed)
              .having((s) => s.backupHistory, 'history', isEmpty),
        ],
        verify: (_) {
          expect(service.calls, ['cleanUp', 'list']);
          expect(tcp.sent, isEmpty);
        },
      );

      blocTest<BackupBloc, BackupState>(
        'a later successful load clears the earlier failure',
        setUp: () => service.listError = const FileSystemException('denied'),
        build: buildBloc,
        act: (bloc) async {
          bloc.add(const BackupHistoryLoaded());
          await bloc.stream.first;
          service.listError = null;
          bloc.add(const BackupHistoryLoaded());
        },
        skip: 1,
        expect: () => [
          isA<BackupState>().having((s) => s.error, 'error', isNull),
        ],
        verify: (_) => expect(service.calls, ['cleanUp', 'list', 'list']),
      );
    });

    group('selecting a backup', () {
      late BackupEntry entry;
      setUp(() => entry = service.add('b1'));

      blocTest<BackupBloc, BackupState>(
        'shows it, and selecting none clears it',
        build: buildBloc,
        act: (bloc) => bloc
          ..add(BackupSelected(entry))
          ..add(const BackupSelected(null)),
        expect: () => [
          isA<BackupState>().having((s) => s.selectedBackup, 'selected', entry),
          isA<BackupState>().having(
            (s) => s.selectedBackup,
            'selected',
            isNull,
          ),
        ],
      );
    });

    group('deleting a backup', () {
      late BackupEntry first;
      late BackupEntry second;
      setUp(() {
        first = service.add('b1');
        second = service.add('b2', minutes: 1);
      });

      blocTest<BackupBloc, BackupState>(
        'removes it from the list and clears it when it was selected',
        build: buildBloc,
        seed: () => BackupState(
          backupHistory: [second, first],
          selectedBackup: first,
          error: 'earlier',
        ),
        act: (bloc) => bloc.add(const BackupDeleted(backupId: 'b1')),
        expect: () => [
          isA<BackupState>()
              .having((s) => s.backupHistory, 'history', [second])
              .having((s) => s.selectedBackup, 'selected', isNull)
              .having((s) => s.error, 'error', isNull),
        ],
        verify: (_) => expect(service.calls, ['delete b1', 'list']),
      );

      blocTest<BackupBloc, BackupState>(
        'keeps another selected backup selected',
        build: buildBloc,
        seed: () =>
            BackupState(backupHistory: [second, first], selectedBackup: second),
        act: (bloc) => bloc.add(const BackupDeleted(backupId: 'b1')),
        expect: () => [
          isA<BackupState>()
              .having((s) => s.backupHistory, 'history', [second])
              .having((s) => s.selectedBackup, 'selected', second),
        ],
      );

      blocTest<BackupBloc, BackupState>(
        'that fails keeps the list and shows the failure',
        setUp: () => service.deleteError = const FileSystemException('busy'),
        build: buildBloc,
        seed: () => BackupState(backupHistory: [second, first]),
        act: (bloc) => bloc.add(const BackupDeleted(backupId: 'b1')),
        expect: () => [
          isA<BackupState>()
              .having((s) => s.backupHistory, 'history', [second, first])
              .having((s) => s.error, 'error', ro.desktopBackupActionFailed),
        ],
        verify: (_) => expect(service.calls, ['delete b1']),
      );
    });

    group('choosing the backup folder', () {
      blocTest<BackupBloc, BackupState>(
        'lists that folder, marks it chosen, clears the selection and tells '
        'the phone backups can be made',
        setUp: () => service
          ..userSelectedPath = false
          ..add('there'),
        build: buildBloc,
        seed: () => BackupState(
          selectedBackup: service.backups.first,
          error: 'earlier',
        ),
        act: (bloc) => bloc.add(const BackupLocationChanged('/Volumes/USB')),
        expect: () => [
          isA<BackupState>()
              .having((s) => s.backupPath, 'path', '/Volumes/USB')
              .having((s) => s.hasUserSelectedPath, 'user path', isTrue)
              .having((s) => s.backupHistory.single.id, 'history', 'there')
              .having((s) => s.selectedBackup, 'selected', isNull)
              .having((s) => s.error, 'error', isNull),
        ],
        verify: (_) {
          expect(service.calls, ['setDirectory /Volumes/USB', 'list']);
          expect(tcp.sentOf('backup.status').single['ready'], isTrue);
        },
      );

      blocTest<BackupBloc, BackupState>(
        'that fails keeps the old folder and shows the failure',
        setUp: () =>
            service.setDirectoryError = const FileSystemException('read-only'),
        build: buildBloc,
        seed: () => const BackupState(backupPath: '/backups'),
        act: (bloc) => bloc.add(const BackupLocationChanged('/Volumes/USB')),
        expect: () => [
          isA<BackupState>()
              .having((s) => s.backupPath, 'path', '/backups')
              .having((s) => s.error, 'error', ro.desktopBackupActionFailed),
        ],
        verify: (_) => expect(tcp.sent, isEmpty),
      );
    });

    group('resetting the backup folder', () {
      blocTest<BackupBloc, BackupState>(
        'goes back to the default folder, not chosen, and tells the phone '
        'no folder is set',
        build: buildBloc,
        seed: () => const BackupState(
          backupPath: '/Volumes/USB',
          hasUserSelectedPath: true,
          error: 'earlier',
        ),
        act: (bloc) => bloc.add(const BackupLocationReset()),
        expect: () => [
          isA<BackupState>()
              .having((s) => s.backupPath, 'path', '/default-backups')
              .having((s) => s.hasUserSelectedPath, 'user path', isFalse)
              .having((s) => s.selectedBackup, 'selected', isNull)
              .having((s) => s.error, 'error', isNull),
        ],
        verify: (_) {
          expect(service.calls, ['resetDirectory', 'list']);
          expect(tcp.sentOf('backup.status').single, {
            'ready': false,
            'count': 0,
          });
        },
      );

      blocTest<BackupBloc, BackupState>(
        'that fails keeps the chosen folder and shows the failure',
        setUp: () =>
            service.resetDirectoryError = const FileSystemException('denied'),
        build: buildBloc,
        seed: () => const BackupState(
          backupPath: '/Volumes/USB',
          hasUserSelectedPath: true,
        ),
        act: (bloc) => bloc.add(const BackupLocationReset()),
        expect: () => [
          isA<BackupState>()
              .having((s) => s.backupPath, 'path', '/Volumes/USB')
              .having((s) => s.hasUserSelectedPath, 'user path', isTrue)
              .having((s) => s.error, 'error', ro.desktopBackupActionFailed),
        ],
      );
    });

    group('a backup made on the desktop', () {
      late Directory dir;

      setUp(() async {
        dir = await Directory.systemTemp.createTemp('backup_bloc_coverage');
        service.dir = dir;
      });

      tearDown(() => dir.delete(recursive: true));

      test('is sent to the connected phone in 64 KiB chunks that rebuild '
          'the file', () async {
        // Two full chunks and a partial one.
        service.snapshotBytes = 64 * 1024 * 2 + 10;
        final bloc = buildBloc();
        addTearDown(bloc.close);
        final states = <BackupState>[];
        final sub = bloc.stream.listen(states.add);

        bloc.add(const BackupRequested(name: 'nightly'));
        await bloc.stream.firstWhere((s) => s.progress == 1.0);
        await pumpEventQueue();
        await sub.cancel();

        final start = tcp.sentOf('backup_start').single;
        expect(start['id'], '100');
        expect(start['totalChunks'], 3);
        expect(start['sizeBytes'], service.snapshotBytes);
        expect(start['recordCount'], 7);
        expect(start['checksum'], 'c100');

        final chunks = tcp.sentOf('backup_chunk');
        expect(chunks.map((c) => c['index']), [0, 1, 2]);
        final rebuilt = chunks
            .expand((c) => base64Decode(c['data'] as String))
            .toList();
        expect(rebuilt, await File('${dir.path}/100.db').readAsBytes());

        expect(tcp.sentOf('backup_complete').single, {
          'id': '100',
          'checksum': 'c100',
        });
        expect(service.snapshotNames, ['nightly']);

        final progress = states.map((s) => s.progress).toList();
        expect(progress.first, 0.0);
        expect(progress, containsAllInOrder([0.0, 0.3, 1.0]));
        for (var i = 1; i < progress.length; i++) {
          expect(progress[i], greaterThanOrEqualTo(progress[i - 1]));
        }
        expect(states.first.isBackingUp, isTrue);
        expect(states.last.isBackingUp, isFalse);
        expect(states.last.backupHistory.single.id, '100');
        // The phone hears the new count after the file.
        expect(tcp.sent.last.type, 'backup.status');
        expect(tcp.sent.last.payload['count'], 1);
      });

      test('with no phone connected is only made locally', () async {
        tcp.state = ConnectionState.disconnected;
        final bloc = buildBloc();
        addTearDown(bloc.close);

        bloc.add(const BackupRequested());
        await bloc.stream.firstWhere((s) => s.progress == 1.0);

        expect(tcp.sent, isEmpty);
        expect(bloc.state.isBackingUp, isFalse);
        expect(bloc.state.backupHistory, hasLength(1));
        expect(service.snapshotNames, [null]);
      });

      blocTest<BackupBloc, BackupState>(
        'clears the earlier error and restore notice when it starts',
        setUp: () => tcp.state = ConnectionState.disconnected,
        build: buildBloc,
        seed: () => const BackupState(error: 'old', restoreNotice: 'notice'),
        act: (bloc) => bloc.add(const BackupRequested()),
        // The snapshot writes a real file.
        wait: const Duration(milliseconds: 200),
        expect: () => [
          isA<BackupState>()
              .having((s) => s.isBackingUp, 'backing up', isTrue)
              .having((s) => s.progress, 'progress', 0.0)
              .having((s) => s.error, 'error', isNull)
              .having((s) => s.restoreNotice, 'notice', isNull),
          isA<BackupState>().having((s) => s.progress, 'progress', 0.3),
          isA<BackupState>()
              .having((s) => s.isBackingUp, 'backing up', isFalse)
              .having((s) => s.progress, 'progress', 1.0),
        ],
      );

      test('that fails resets the progress and stops backing up', () async {
        service.snapshotError = const FileSystemException('disk full');
        final bloc = buildBloc();
        addTearDown(bloc.close);

        bloc.add(const BackupRequested(name: 'nightly'));
        await bloc.stream.firstWhere((s) => s.error != null);

        expect(bloc.state.error, ro.desktopBackupFailed);
        expect(bloc.state.isBackingUp, isFalse);
        expect(bloc.state.progress, 0.0);
        expect(tcp.sentOf('backup_start'), isEmpty);
      });
    });

    group('the phone asking for a backup', () {
      test('is told the desktop is backing up, then gets the backup', () async {
        final dir = await Directory.systemTemp.createTemp('backup_bloc_cov');
        addTearDown(() => dir.delete(recursive: true));
        service.dir = dir;
        final bloc = buildBloc();
        addTearDown(bloc.close);
        bloc.add(const BackupHistoryLoaded());
        await bloc.stream.firstWhere((s) => s.hasUserSelectedPath);
        tcp.sent.clear();

        tcp.deliver('backup.request', {});
        await bloc.stream.firstWhere((s) => s.progress == 1.0);
        await pumpEventQueue();

        expect(tcp.sent.first.type, 'backup.status');
        expect(tcp.sent.first.payload, {
          'ready': true,
          'backing_up': true,
          'count': 0,
        });
        expect(
          service.snapshotNames.single,
          startsWith(ro.desktopRemoteBackupName('')),
        );
        expect(tcp.sentOf('backup.status').last, containsPair('count', 1));
      });

      test('while a backup runs is ignored', () async {
        service.snapshotGate = Completer<void>();
        final bloc = buildBloc();
        addTearDown(bloc.close);
        bloc.add(const BackupHistoryLoaded());
        await bloc.stream.firstWhere((s) => s.hasUserSelectedPath);
        bloc.add(const BackupRequested(name: 'nightly'));
        await bloc.stream.firstWhere((s) => s.isBackingUp);
        tcp.sent.clear();

        tcp.deliver('backup.request', {});
        await pumpEventQueue();

        expect(tcp.sent, isEmpty);
        service.snapshotGate!.complete();
        await bloc.stream.firstWhere((s) => !s.isBackingUp);
        expect(service.snapshotNames, ['nightly']);
      });

      test('another message type, or a message of another frame type, does '
          'nothing', () async {
        final bloc = buildBloc();
        addTearDown(bloc.close);

        tcp.deliver('backup.status', {'ready': true, 'backing_up': true});
        tcp.deliver('backup.complete', {'count': 4});
        tcp.deliverRaw(
          TcpMessage.fromString(
            type: MessageType.ping,
            data: jsonEncode({'type': 'backup.request', 'payload': {}}),
          ),
        );
        await pumpEventQueue();

        expect(bloc.state, BackupState.initial());
        expect(tcp.sent, isEmpty);
      });
    });

    group('a restore', () {
      late BackupEntry target;
      setUp(() => target = service.add('b1'));

      test('while a backup runs is ignored', () async {
        service.snapshotGate = Completer<void>();
        final bloc = buildBloc();
        addTearDown(bloc.close);
        bloc.add(const BackupRequested(name: 'nightly'));
        await bloc.stream.firstWhere((s) => s.isBackingUp);

        bloc.add(RestoreRequested(backupId: target.id));
        await pumpEventQueue();
        expect(bloc.state.isRestoring, isFalse);

        service.snapshotGate!.complete();
        await bloc.stream.firstWhere((s) => !s.isBackingUp);
        expect(service.calls, isNot(contains('restore')));
      });

      test('a backup the desktop asked for while it runs is not started and '
          'not reported to the phone', () async {
        final bloc = buildBloc();
        addTearDown(bloc.close);
        // The backup event arrives from the same restoring state.
        bloc.emit(const BackupState(isRestoring: true));

        bloc.add(const BackupRequested(name: 'nightly'));
        await pumpEventQueue();

        expect(service.snapshotNames, isEmpty);
        expect(tcp.sentOf('backup.error'), isEmpty);
      });

      test('a backup the phone asked for while it runs tells the phone a '
          'restore is running', () async {
        final bloc = buildBloc();
        addTearDown(bloc.close);
        bloc.emit(const BackupState(isRestoring: true));

        bloc.add(const BackupRequested(name: 'phone', fromPhone: true));
        await pumpEventQueue();

        expect(service.snapshotNames, isEmpty);
        expect(
          tcp.sentOf('backup.error').single['code'],
          BackupBloc.restoreInProgressCode,
        );
      });

      test('whose backup list cannot be read fails before the safety '
          'copy', () async {
        service.listError = const FileSystemException('denied');
        final bloc = buildBloc();
        addTearDown(bloc.close);

        bloc.add(RestoreRequested(backupId: target.id));
        await bloc.stream.firstWhere((s) => s.error != null);

        expect(bloc.state.error, ro.desktopBackupActionFailed);
        expect(bloc.state.isRestoring, isFalse);
        expect(service.calls, isNot(contains('safetyCopy')));
      });

      test('that committed but cannot list the backups afterwards keeps the '
          'list it had', () async {
        service.onRestore = () =>
            service.listError = const FileSystemException('gone');
        final bloc = buildBloc();
        addTearDown(bloc.close);
        bloc.emit(BackupState(backupHistory: [target]));

        bloc.add(RestoreRequested(backupId: target.id));
        await bloc.stream.firstWhere((s) => s.progress == 1.0);

        expect(bloc.state.isRestoring, isFalse);
        expect(bloc.state.error, isNull);
        expect(bloc.state.backupHistory, [target]);
      });

      test('reloads the records and sends the restored rows to the '
          'phone', () async {
        final home = _FakeHomeBloc();
        getIt.registerSingleton<HomeBloc>(home);
        final bloc = buildBloc();
        addTearDown(bloc.close);

        bloc.add(RestoreRequested(backupId: target.id));
        await bloc.stream.firstWhere((s) => s.progress == 1.0);

        expect(home.events.single, isA<HomeInitialised>());
        expect(sync.added.single, isA<LwwLocalChanged>());
      });

      test('still finishes when sync and the records cannot be told', () async {
        sync.addThrows = true;
        final bloc = buildBloc();
        addTearDown(bloc.close);

        bloc.add(RestoreRequested(backupId: target.id));
        await bloc.stream.firstWhere((s) => s.progress == 1.0);

        expect(bloc.state.isRestoring, isFalse);
        expect(bloc.state.error, isNull);
        expect(bloc.state.restoreNotice, isNull);
      });

      test('that left files behind, with the phone online, says only '
          'that', () async {
        service.restoreResult = const RestoreResult(
          hadFiles: true,
          filesNotRestored: 1,
        );
        final bloc = buildBloc();
        addTearDown(bloc.close);

        bloc.add(RestoreRequested(backupId: target.id));
        await bloc.stream.firstWhere((s) => s.progress == 1.0);

        expect(bloc.state.restoreNotice, ro.backupFilesNotRestored(1));
      });
    });

    test('sendBackupStatus sends nothing on the phone', () async {
      await getIt.unregister<AppPlatform>();
      getIt.registerSingleton<AppPlatform>(AppPlatform.mobile);
      final bloc = buildBloc();
      addTearDown(bloc.close);

      bloc.sendBackupStatus();
      await pumpEventQueue();

      expect(tcp.sent, isEmpty);
    });

    test('once closed, messages from the phone are not handled', () async {
      final bloc = buildBloc();
      await bloc.close();

      tcp.deliver('backup.request', {});
      await pumpEventQueue();

      expect(tcp.sent, isEmpty);
      expect(service.calls, isEmpty);
    });
  });

  group('on the phone', () {
    setUp(() => getIt.registerSingleton<AppPlatform>(AppPlatform.mobile));

    blocTest<BackupBloc, BackupState>(
      'loading the history does not clean up the desktop\'s folder',
      build: buildBloc,
      act: (bloc) => bloc.add(const BackupHistoryLoaded()),
      verify: (_) {
        expect(service.calls, ['list']);
        // The phone never reports a backup status of its own.
        expect(tcp.sent, isEmpty);
      },
    );

    blocTest<BackupBloc, BackupState>(
      'a desktop backing up shows a backup running from the start',
      build: buildBloc,
      act: (_) => tcp.deliver('backup.status', {
        'ready': true,
        'backing_up': true,
        'count': 3,
      }),
      wait: Duration.zero,
      expect: () => [
        isA<BackupState>()
            .having((s) => s.isBackingUp, 'backing up', isTrue)
            .having((s) => s.progress, 'progress', 0.0)
            .having((s) => s.error, 'error', isNull),
      ],
    );

    blocTest<BackupBloc, BackupState>(
      'a status shows the desktop\'s folder, count and last backup',
      build: buildBloc,
      seed: () => const BackupState(isBackingUp: true),
      act: (_) => tcp.deliver('backup.status', {
        'ready': true,
        'count': 4,
        'last_backup': '2026-10-01T08:30:00.000Z',
      }),
      wait: Duration.zero,
      expect: () => [
        isA<BackupState>()
            .having((s) => s.isBackingUp, 'backing up', isFalse)
            .having((s) => s.desktopBackupReady, 'ready', isTrue)
            .having((s) => s.desktopBackupCount, 'count', 4)
            .having(
              (s) => s.desktopLastBackupTime,
              'last',
              DateTime.utc(2026, 10, 1, 8, 30),
            ),
      ],
    );

    blocTest<BackupBloc, BackupState>(
      'a status without fields is a desktop without a folder or backups',
      build: buildBloc,
      act: (_) => tcp.deliver('backup.status', {}),
      wait: Duration.zero,
      expect: () => [
        isA<BackupState>()
            .having((s) => s.desktopBackupReady, 'ready', isFalse)
            .having((s) => s.desktopBackupCount, 'count', 0)
            .having((s) => s.desktopLastBackupTime, 'last', isNull),
      ],
    );

    blocTest<BackupBloc, BackupState>(
      'a message without a payload is read as an empty one',
      build: buildBloc,
      act: (_) => tcp.deliverRaw(
        TcpMessage.fromString(
          type: MessageType.data,
          data: jsonEncode({'type': 'backup.status'}),
        ),
      ),
      wait: Duration.zero,
      expect: () => [
        isA<BackupState>().having((s) => s.desktopBackupReady, 'ready', false),
      ],
    );

    blocTest<BackupBloc, BackupState>(
      'a finished backup ends the running one and shows the new count and '
      'time',
      build: buildBloc,
      seed: () => const BackupState(isBackingUp: true),
      act: (_) => tcp.deliver('backup.complete', {
        'count': 5,
        'last_backup': '2026-11-03T10:00:00.000Z',
      }),
      wait: Duration.zero,
      expect: () => [
        isA<BackupState>()
            .having((s) => s.isBackingUp, 'backing up', isFalse)
            .having((s) => s.desktopBackupReady, 'ready', isTrue)
            .having((s) => s.desktopBackupCount, 'count', 5)
            .having(
              (s) => s.desktopLastBackupTime,
              'last',
              DateTime.utc(2026, 11, 3, 10),
            ),
      ],
    );

    blocTest<BackupBloc, BackupState>(
      'a finished backup without fields counts none and has no time',
      build: buildBloc,
      act: (_) => tcp.deliver('backup.complete', {}),
      wait: Duration.zero,
      expect: () => [
        isA<BackupState>()
            .having((s) => s.desktopBackupReady, 'ready', isTrue)
            .having((s) => s.desktopBackupCount, 'count', 0)
            .having((s) => s.desktopLastBackupTime, 'last', isNull),
      ],
    );

    blocTest<BackupBloc, BackupState>(
      'an error ends the running backup with the progress full',
      build: buildBloc,
      seed: () => const BackupState(isBackingUp: true, progress: 0.4),
      act: (_) => tcp.deliver('backup.error', {
        'code': BackupBloc.backupFailedCode,
      }),
      wait: Duration.zero,
      expect: () => [
        isA<BackupState>()
            .having((s) => s.isBackingUp, 'backing up', isFalse)
            .having((s) => s.progress, 'progress', 1.0)
            .having((s) => s.error, 'error', ro.desktopBackupFailed),
      ],
    );

    blocTest<BackupBloc, BackupState>(
      'a restore running on the desktop is shown as a backup failure',
      build: buildBloc,
      act: (_) => tcp.deliver('backup.error', {
        'code': BackupBloc.restoreInProgressCode,
      }),
      wait: Duration.zero,
      expect: () => [
        isA<BackupState>().having(
          (s) => s.error,
          'error',
          ro.desktopBackupFailed,
        ),
      ],
    );

    blocTest<BackupBloc, BackupState>(
      'a backup request from the desktop is ignored',
      build: buildBloc,
      act: (_) => tcp.deliver('backup.request', {}),
      wait: Duration.zero,
      expect: () => <BackupState>[],
      verify: (_) => expect(tcp.sent, isEmpty),
    );

    blocTest<BackupBloc, BackupState>(
      'a link that connects is not a lost link',
      build: buildBloc,
      act: (_) => tcp.emitState(ConnectionState.connected),
      wait: Duration.zero,
      expect: () => <BackupState>[],
    );

    group('asking the desktop for a backup', () {
      blocTest<BackupBloc, BackupState>(
        'waits until this phone\'s changes were sent, then asks and shows '
        'it running',
        build: buildBloc,
        seed: () => const BackupState(error: 'old', progress: 1.0),
        act: (bloc) => bloc.add(const PhoneBackupRequested()),
        expect: () => [
          isA<BackupState>()
              .having((s) => s.isBackingUp, 'backing up', isTrue)
              .having((s) => s.progress, 'progress', 0.0)
              .having((s) => s.error, 'error', isNull),
        ],
        verify: (_) {
          expect(sync.drainWaits, 1);
          expect(tcp.sentOf('backup.request'), [<String, dynamic>{}]);
        },
      );

      blocTest<BackupBloc, BackupState>(
        'still asks when not every change was sent in time',
        setUp: () => sync.drained = false,
        build: buildBloc,
        act: (bloc) => bloc.add(const PhoneBackupRequested()),
        expect: () => [
          isA<BackupState>().having((s) => s.isBackingUp, 'backing up', true),
        ],
        verify: (_) => expect(tcp.sentOf('backup.request'), hasLength(1)),
      );

      blocTest<BackupBloc, BackupState>(
        'without a link says the desktop is not connected',
        setUp: () => tcp.state = ConnectionState.disconnected,
        build: buildBloc,
        act: (bloc) => bloc.add(const PhoneBackupRequested()),
        expect: () => [
          isA<BackupState>().having((s) => s.isBackingUp, 'backing up', true),
          isA<BackupState>()
              .having((s) => s.isBackingUp, 'backing up', isFalse)
              .having((s) => s.error, 'error', ro.backupStatusNotConnected),
        ],
        verify: (_) => expect(tcp.sent, isEmpty),
      );
    });

    test('once closed, the link dropping changes nothing', () async {
      final bloc = buildBloc();
      await bloc.close();

      tcp.emitState(ConnectionState.disconnected);
      tcp.deliver('backup.status', {'ready': true});
      await pumpEventQueue();

      expect(bloc.state, BackupState.initial());
    });
  });
}
