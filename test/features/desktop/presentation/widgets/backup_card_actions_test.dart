import 'dart:async';
import 'dart:io';

import 'package:bloc_test/bloc_test.dart' show MockBloc, whenListen;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/core/widgets/app_message_card.dart';
import 'package:health_wallet/features/desktop/backup/domain/entity/backup_entry.dart';
import 'package:health_wallet/features/desktop/backup/presentation/bloc/backup_bloc.dart';
import 'package:health_wallet/features/desktop/communication/presentation/bloc/communication_bloc.dart';
import 'package:health_wallet/features/desktop/presentation/widgets/backup_card.dart';
import 'package:intl/intl.dart';

import '../../../../helpers/log_capture.dart';

/// Records the events the card sends; with [closed] it refuses them as a
/// closed bloc does.
class _MockBackupBloc extends MockBloc<BackupEvent, BackupState>
    implements BackupBloc {
  final events = <BackupEvent>[];
  bool closed = false;

  @override
  void add(BackupEvent event) {
    if (closed) throw StateError('Cannot add new events after calling close');
    events.add(event);
  }
}

/// A directory that exists or not as the test says, without touching disk.
class _FakeDirectory extends Fake implements Directory {
  _FakeDirectory(this.path, {required this.present});

  @override
  final String path;
  final bool present;

  @override
  Future<bool> exists() async => present;
}

final _l10n = lookupAppLocalizations(const Locale('en'));

const _fsChannel = MethodChannel('dev.lifevalue.healthwallet/fs');

BackupEntry _entry({
  String name = 'nightly',
  int sizeBytes = 1024,
  String checksum = 'abc',
}) => BackupEntry(
  id: 'b-$name-$sizeBytes',
  name: name,
  timestamp: DateTime(2026, 10, 28, 14, 5),
  sizeBytes: sizeBytes,
  recordCount: 4,
  checksum: checksum,
  filePath: '/tmp/b.db',
);

void main() {
  final logs = captureLogs();
  late _MockBackupBloc bloc;
  late StreamController<BackupState> states;

  /// The arguments of each folder picker opened, answered with [picked].
  late List<Map<Object?, Object?>> pickerCalls;
  String? picked;

  setUp(() {
    bloc = _MockBackupBloc();
    // Broadcast, so closing it never waits for a listener.
    states = StreamController<BackupState>.broadcast();
    whenListen(bloc, states.stream, initialState: const BackupState());
    pickerCalls = [];
    picked = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_fsChannel, (call) async {
          if (call.method != 'pickDirectory') return null;
          pickerCalls.add(call.arguments as Map<Object?, Object?>);
          return picked;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_fsChannel, null);
    return states.close();
  });

  Widget card(
    BackupState state, {
    DesktopSyncState syncState = const DesktopSyncState(),
  }) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: BlocProvider<BackupBloc>.value(
        value: bloc,
        child: BackupCard(syncState: syncState, backupState: state),
      ),
    ),
  );

  Future<void> pumpCard(
    WidgetTester tester,
    BackupState state, {
    DesktopSyncState syncState = const DesktopSyncState(),
  }) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(card(state, syncState: syncState));
    await tester.pumpAndSettle();
  }

  BackupState listState({
    List<BackupEntry>? history,
    BackupEntry? selected,
    String backupPath = '/tmp/backups',
    bool isBackingUp = false,
  }) => BackupState(
    hasUserSelectedPath: true,
    backupPath: backupPath,
    backupHistory: history ?? [_entry()],
    selectedBackup: selected,
    isBackingUp: isBackingUp,
  );

  group('choosing the folder', () {
    testWidgets('Choose location opens the folder picker and saves the folder '
        'chosen', (tester) async {
      picked = '/Users/ana/Backups';
      await pumpCard(tester, const BackupState());

      await tester.tap(find.text(_l10n.desktopChooseLocation));
      await tester.pumpAndSettle();

      expect(pickerCalls, [
        {'title': _l10n.desktopChooseBackupLocation},
      ]);
      expect(bloc.events, [const BackupLocationChanged('/Users/ana/Backups')]);
    });

    testWidgets('closing the picker without a folder changes nothing', (
      tester,
    ) async {
      await pumpCard(tester, const BackupState());

      await tester.tap(find.text(_l10n.desktopChooseLocation));
      await tester.pumpAndSettle();

      expect(pickerCalls, hasLength(1));
      expect(bloc.events, isEmpty);
    });

    Future<void> tapChange(WidgetTester tester, {required bool present}) =>
        IOOverrides.runZoned(
          () async {
            await tester.tap(find.text(_l10n.desktopChange));
            await tester.pumpAndSettle();
          },
          createDirectory: (path) => _FakeDirectory(path, present: present),
        );

    testWidgets('Change opens the picker in the current folder', (
      tester,
    ) async {
      picked = '/Volumes/USB/Backups';
      await pumpCard(tester, listState());

      await tapChange(tester, present: true);

      expect(pickerCalls, [
        {
          'initialDirectory': '/tmp/backups',
          'title': _l10n.desktopChooseBackupLocation,
        },
      ]);
      expect(bloc.events, [
        const BackupLocationChanged('/Volumes/USB/Backups'),
      ]);
    });

    testWidgets('Change opens the picker anywhere when the current folder is '
        'gone', (tester) async {
      await pumpCard(tester, listState());

      await tapChange(tester, present: false);

      expect(pickerCalls, [
        {'title': _l10n.desktopChooseBackupLocation},
      ]);
      expect(bloc.events, isEmpty);
    });

    testWidgets('Change does nothing while a backup runs', (tester) async {
      // The progress bar keeps animating, so frames are pumped one by one.
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(card(listState(isBackingUp: true)));

      await IOOverrides.runZoned(() async {
        await tester.tap(find.text(_l10n.desktopChange));
        await tester.pump();
      }, createDirectory: (path) => _FakeDirectory(path, present: true));

      expect(pickerCalls, isEmpty);
    });

    testWidgets('a long folder path shows its end, the whole path on '
        'hover', (tester) async {
      const path =
          '/Users/ana/Library/Mobile Documents/com~apple~CloudDocs/'
          'HealthWallet/Backups';
      await pumpCard(tester, listState(backupPath: path));

      final shown = '…${path.substring(path.length - 40)}';
      expect(find.text(shown), findsOne);
      expect(find.byTooltip(path), findsOne);
    });
  });

  group('the list and details', () {
    testWidgets('tapping a backup opens its details', (tester) async {
      final backup = _entry();
      await pumpCard(tester, listState(history: [backup]));

      await tester.tap(find.text('nightly'));
      await tester.pump();

      expect(bloc.events, [BackupSelected(backup)]);
    });

    testWidgets('a backup without a name is listed and shown by its date', (
      tester,
    ) async {
      final unnamed = _entry(name: '');
      await pumpCard(tester, listState(history: [unnamed]));
      expect(
        find.text(DateFormat.yMMMd().add_Hm().format(unnamed.timestamp)),
        findsOne,
      );

      await pumpCard(tester, listState(history: [unnamed], selected: unnamed));
      expect(
        find.text(
          '${_l10n.desktopBackupFrom} '
          '${DateFormat.yMMMd().format(unnamed.timestamp)}',
        ),
        findsOne,
      );
    });

    testWidgets('a long checksum is shortened', (tester) async {
      final backup = _entry(checksum: '0123456789abcdef0123456789abcdef');
      await pumpCard(tester, listState(history: [backup], selected: backup));

      expect(find.text('0123456789abcdef…'), findsOne);
    });

    testWidgets('sizes are shown in MB and GB', (tester) async {
      final mb = _entry(sizeBytes: 5 * 1024 * 1024);
      await pumpCard(tester, listState(history: [mb], selected: mb));
      expect(find.text('5.0 MB'), findsWidgets);

      final gb = _entry(sizeBytes: 3 * 1024 * 1024 * 1024);
      await pumpCard(tester, listState(history: [gb], selected: gb));
      expect(find.text('3.0 GB'), findsWidgets);
    });

    testWidgets('a finished backup without a name is announced by its '
        'date', (tester) async {
      final unnamed = _entry(name: '');
      await pumpCard(tester, listState(history: const []));

      final sequence = [
        listState(history: const [], isBackingUp: true),
        listState(history: [unnamed]),
      ];
      sequence.forEach(states.add);
      await tester.pump();
      await tester.pumpWidget(card(sequence.last));
      await tester.pumpAndSettle();

      final name =
          '${_l10n.desktopBackupFrom} '
          '${DateFormat.yMMMd().format(unnamed.timestamp)}';
      expect(
        find.descendant(
          of: find.byKey(AppMessageCard.cardKey),
          matching: find.text(_l10n.desktopBackupSucceededMessage(name, 4)),
        ),
        findsOne,
      );
    });
  });

  group('starting a backup', () {
    Future<void> start(
      WidgetTester tester, {
      DesktopSyncState syncState = const DesktopSyncState(),
    }) async {
      await pumpCard(tester, listState(), syncState: syncState);
      await tester.tap(find.text(_l10n.desktopCreateBackup));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'nightly');
      await tester.tap(find.text(_l10n.desktopStartBackup));
      await tester.pumpAndSettle();
    }

    testWidgets('without the sync to run first, the backup still starts', (
      tester,
    ) async {
      // No LwwSyncBloc above the card.
      await start(
        tester,
        syncState: const DesktopSyncState(
          connectionStatus: ConnectionStatus.connected,
        ),
      );

      expect(logs, loggedWarning('could not sync before the backup'));
      expect(bloc.events, [const BackupRequested(name: 'nightly')]);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('a backup that cannot be started is logged and the form '
        'closes', (tester) async {
      bloc.closed = true;

      await start(tester);

      expect(logs, loggedWarning('could not start the backup'));
      expect(bloc.events, isEmpty);
      expect(find.byType(TextField), findsNothing);
    });
  });
}
