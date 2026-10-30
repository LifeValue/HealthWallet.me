import 'dart:async';

import 'package:bloc_test/bloc_test.dart' show MockBloc, whenListen;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/core/widgets/app_message_card.dart';
import 'package:health_wallet/features/desktop/backup/domain/entity/backup_entry.dart';
import 'package:health_wallet/features/desktop/backup/presentation/bloc/backup_bloc.dart';
import 'package:health_wallet/features/desktop/communication/presentation/bloc/communication_bloc.dart';
import 'package:health_wallet/features/desktop/lww_sync/presentation/bloc/lww_sync_bloc.dart';
import 'package:health_wallet/features/desktop/presentation/widgets/backup_card.dart';

/// Records the events the card sends instead of running them.
class _MockBackupBloc extends MockBloc<BackupEvent, BackupState>
    implements BackupBloc {
  final events = <BackupEvent>[];

  @override
  void add(BackupEvent event) => events.add(event);
}

/// Records the syncs the card starts before a backup.
class _MockLwwSyncBloc extends MockBloc<LwwSyncEvent, LwwSyncState>
    implements LwwSyncBloc {
  final events = <LwwSyncEvent>[];

  @override
  void add(LwwSyncEvent event) => events.add(event);
}

final _l10n = lookupAppLocalizations(const Locale('en'));

final _backup = BackupEntry(
  id: 'b1',
  name: 'backup-28-10-2026',
  timestamp: DateTime(2026, 10, 28, 14, 5),
  sizeBytes: 1024,
  recordCount: 27,
  checksum: 'abc',
  filePath: '/tmp/backup-28-10-2026.db',
);

void main() {
  late _MockBackupBloc bloc;
  late _MockLwwSyncBloc lwwBloc;
  late StreamController<BackupState> states;

  BackupState cardState({
    bool isRestoring = false,
    bool isBackingUp = false,
    String? error,
    List<BackupEntry>? history,
  }) => BackupState(
    hasUserSelectedPath: true,
    backupPath: '/tmp',
    backupHistory: history ?? [_backup],
    selectedBackup: _backup,
    isRestoring: isRestoring,
    isBackingUp: isBackingUp,
    error: error,
  );

  setUp(() {
    bloc = _MockBackupBloc();
    states = StreamController<BackupState>();
    whenListen(bloc, states.stream, initialState: cardState());
    lwwBloc = _MockLwwSyncBloc();
    whenListen(
      lwwBloc,
      const Stream<LwwSyncState>.empty(),
      initialState: LwwSyncState.initial(),
    );
  });

  tearDown(() => states.close());

  Widget card(
    BackupState state, {
    DesktopSyncState syncState = const DesktopSyncState(),
  }) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: MultiBlocProvider(
        providers: [
          BlocProvider<BackupBloc>.value(value: bloc),
          BlocProvider<LwwSyncBloc>.value(value: lwwBloc),
        ],
        child: BackupCard(syncState: syncState, backupState: state),
      ),
    ),
  );

  Future<void> pumpCard(
    WidgetTester tester, [
    BackupState? state,
    DesktopSyncState syncState = const DesktopSyncState(),
  ]) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(card(state ?? cardState(), syncState: syncState));
    await tester.pumpAndSettle();
  }

  /// Sends [sequence] through the bloc, as its handlers emit them, and
  /// rebuilds the card once with the last, as BlocBuilder would after a
  /// frame.
  Future<void> emit(WidgetTester tester, List<BackupState> sequence) async {
    sequence.forEach(states.add);
    await tester.pump();
    await tester.pumpWidget(card(sequence.last));
    await tester.pumpAndSettle();
  }

  Finder dialogButton(String text) => find.ancestor(
    of: find.descendant(of: find.byType(Dialog), matching: find.text(text)),
    matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
  );

  group('restore confirmation', () {
    Future<void> open(WidgetTester tester) async {
      await pumpCard(tester);
      await tester.tap(find.text(_l10n.desktopRestoreThisBackup));
      await tester.pumpAndSettle();
    }

    testWidgets('has a title with an X and two buttons side by side', (
      tester,
    ) async {
      await open(tester);

      expect(find.text(_l10n.desktopRestoreBackupTitle), findsOne);
      expect(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.byIcon(Icons.close),
        ),
        findsOne,
      );
      final cancel = dialogButton(_l10n.cancel);
      final restore = dialogButton(_l10n.desktopRestore);
      expect(cancel, findsOne);
      expect(restore, findsOne);
      // Cancel is a real button with a border, not plain text.
      final cancelButton = tester.widget<OutlinedButton>(cancel);
      final side = cancelButton.style?.side?.resolve({});
      expect(side, isNotNull);
      expect(side!.style, BorderStyle.solid);
      expect(side.width, greaterThan(0));
      // Same row, same width: two columns.
      expect(tester.getCenter(cancel).dy, tester.getCenter(restore).dy);
      expect(tester.getSize(cancel).width, tester.getSize(restore).width);
      expect(
        tester.getCenter(cancel).dx,
        lessThan(tester.getCenter(restore).dx),
      );
    });

    testWidgets('Restore restores the backup', (tester) async {
      await open(tester);

      await tester.tap(dialogButton(_l10n.desktopRestore));
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsNothing);
      expect(bloc.events, [const RestoreRequested(backupId: 'b1')]);
    });

    testWidgets('the X and Cancel close it without restoring', (
      tester,
    ) async {
      await open(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.byIcon(Icons.close),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);

      await tester.tap(find.text(_l10n.desktopRestoreThisBackup));
      await tester.pumpAndSettle();
      await tester.tap(dialogButton(_l10n.cancel));
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsNothing);
      expect(bloc.events, isEmpty);
    });
  });

  group('delete confirmation', () {
    testWidgets('has an X and two buttons, and Delete deletes', (
      tester,
    ) async {
      await pumpCard(tester);
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      expect(find.text(_l10n.desktopDeleteBackupTitle), findsOne);
      expect(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.byIcon(Icons.close),
        ),
        findsOne,
      );
      expect(dialogButton(_l10n.cancel), findsOne);

      await tester.tap(dialogButton(_l10n.desktopDelete));
      await tester.pumpAndSettle();

      expect(bloc.events, [const BackupDeleted(backupId: 'b1')]);
    });
  });

  group('after a restore', () {
    Future<void> confirmRestore(WidgetTester tester) async {
      await pumpCard(tester);
      await tester.tap(find.text(_l10n.desktopRestoreThisBackup));
      await tester.pumpAndSettle();
      await tester.tap(dialogButton(_l10n.desktopRestore));
      await tester.pumpAndSettle();
    }

    testWidgets('a successful restore is announced', (tester) async {
      await confirmRestore(tester);
      await emit(tester, [cardState(isRestoring: true), cardState()]);

      expect(find.text(_l10n.desktopRestoreSucceededTitle), findsOne);
      expect(
        find.text(
          _l10n.desktopRestoreSucceededMessage('backup-28-10-2026', 27),
        ),
        findsOne,
      );

      await tester.tap(find.text(_l10n.ok));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
    });

    testWidgets('a restore that starts and finishes within one frame is '
        'still announced', (tester) async {
      await confirmRestore(tester);
      // No rebuild between the two states: only the listener sees both.
      states
        ..add(cardState(isRestoring: true))
        ..add(cardState());
      await tester.pumpAndSettle();

      expect(find.text(_l10n.desktopRestoreSucceededTitle), findsOne);
    });

    testWidgets('a failed restore shows no success message', (tester) async {
      await confirmRestore(tester);
      await emit(tester, [
        cardState(isRestoring: true),
        cardState(error: 'Restore failed'),
      ]);

      expect(find.text(_l10n.desktopRestoreSucceededTitle), findsNothing);
      expect(find.text('Restore failed'), findsOne);
    });

    testWidgets('a restore the user did not start here is not announced', (
      tester,
    ) async {
      await pumpCard(tester);
      await emit(tester, [cardState(isRestoring: true), cardState()]);

      expect(find.text(_l10n.desktopRestoreSucceededTitle), findsNothing);
    });
  });

  group('after a backup', () {
    final created = BackupEntry(
      id: 'b2',
      name: 'nightly',
      timestamp: DateTime(2026, 10, 30, 11, 27),
      sizeBytes: 2048,
      recordCount: 31,
      checksum: 'def',
      filePath: '/tmp/nightly.db',
    );

    Finder successCard() => find.ancestor(
      of: find.text(_l10n.desktopBackupSucceededMessage('nightly', 31)),
      matching: find.byKey(AppMessageCard.cardKey),
    );

    testWidgets('a successful backup shows a success card with its name and '
        'record count', (tester) async {
      await pumpCard(tester);
      await emit(tester, [
        cardState(isBackingUp: true),
        cardState(history: [created, _backup]),
      ]);

      expect(successCard(), findsOne);
    });

    testWidgets('the success card hides itself after a while', (
      tester,
    ) async {
      await pumpCard(tester);
      await emit(tester, [
        cardState(isBackingUp: true),
        cardState(history: [created, _backup]),
      ]);

      await tester.pump(BackupCard.messageDuration);
      await tester.pump();
      expect(successCard(), findsNothing);
    });

    testWidgets('closing the success card hides it', (tester) async {
      await pumpCard(tester);
      await emit(tester, [
        cardState(isBackingUp: true),
        cardState(history: [created, _backup]),
      ]);

      await tester.tap(
        find.descendant(
          of: successCard(),
          matching: find.byKey(AppMessageCard.closeKey),
        ),
      );
      await tester.pumpAndSettle();

      expect(successCard(), findsNothing);
    });

    testWidgets('the next backup or restore clears the success card', (
      tester,
    ) async {
      await pumpCard(tester);
      await emit(tester, [
        cardState(isBackingUp: true),
        cardState(history: [created, _backup]),
      ]);

      // The progress bar never settles while restoring, so pump frames.
      states.add(cardState(isRestoring: true));
      await tester.pump();
      await tester.pumpWidget(card(cardState(isRestoring: true)));
      await tester.pump();

      expect(successCard(), findsNothing);
    });

    testWidgets('a failed backup shows its error, not a success card', (
      tester,
    ) async {
      await pumpCard(tester);
      await emit(tester, [
        cardState(isBackingUp: true),
        cardState(error: 'Backup failed'),
      ]);

      expect(find.text('Backup failed'), findsOne);
      expect(
        find.text(_l10n.desktopBackupSucceededMessage('nightly', 31)),
        findsNothing,
      );
    });
  });

  group('an error', () {
    Finder errorCard(String message) => find.ancestor(
      of: find.text(message),
      matching: find.byKey(AppMessageCard.cardKey),
    );

    testWidgets('shows in the app message card with a close button', (
      tester,
    ) async {
      await pumpCard(tester, cardState(error: 'Restore failed'));

      expect(errorCard('Restore failed'), findsOne);
      expect(
        find.descendant(
          of: errorCard('Restore failed'),
          matching: find.byKey(AppMessageCard.closeKey),
        ),
        findsOne,
      );
    });

    testWidgets('closing it hides it', (tester) async {
      await pumpCard(tester, cardState(error: 'Restore failed'));

      await tester.tap(find.byKey(AppMessageCard.closeKey));
      await tester.pumpAndSettle();

      expect(find.text('Restore failed'), findsNothing);
    });

    testWidgets('a retry that fails with the same message shows it again, '
        'even within one frame', (tester) async {
      await pumpCard(tester, cardState(error: 'Restore failed'));
      await tester.tap(find.byKey(AppMessageCard.closeKey));
      await tester.pumpAndSettle();

      await emit(tester, [
        cardState(isRestoring: true),
        cardState(error: 'Restore failed'),
      ]);

      expect(errorCard('Restore failed'), findsOne);
    });

    testWidgets('hides itself after a while', (tester) async {
      await pumpCard(tester, cardState(error: 'Restore failed'));

      await tester.pump(const Duration(seconds: 1));
      expect(errorCard('Restore failed'), findsOne);

      await tester.pump(BackupCard.messageDuration);
      await tester.pump();
      expect(find.text('Restore failed'), findsNothing);
    });

    testWidgets('a new error after a retry starts its own timer', (
      tester,
    ) async {
      await pumpCard(tester);
      await emit(tester, [
        cardState(isRestoring: true),
        cardState(error: 'Restore failed'),
      ]);

      await tester.pump(BackupCard.messageDuration);
      await tester.pump();
      expect(find.text('Restore failed'), findsNothing);
    });

    testWidgets('no error, no card', (tester) async {
      await pumpCard(tester);

      expect(find.byKey(AppMessageCard.cardKey), findsNothing);
    });
  });

  group('a backup\'s details', () {
    testWidgets('the way back to the list is the first row, above the '
        'location', (tester) async {
      await pumpCard(tester);

      final back = tester.getRect(find.text(_l10n.desktopAllBackups));
      final location = tester.getRect(find.text(_l10n.desktopBackupLocation));
      final name = tester.getRect(find.text('backup-28-10-2026'));
      expect(back.bottom, lessThan(location.top));
      expect(back.bottom, lessThan(name.top));
    });

    testWidgets('tapping it goes back to the list', (tester) async {
      await pumpCard(tester);

      await tester.tap(find.text(_l10n.desktopAllBackups));

      expect(bloc.events, contains(const BackupSelected(null)));
    });

    testWidgets('the list has no way back', (tester) async {
      await pumpCard(
        tester,
        BackupState(
          hasUserSelectedPath: true,
          backupPath: '/tmp',
          backupHistory: [_backup],
        ),
      );

      expect(find.text(_l10n.desktopAllBackups), findsNothing);
    });
  });

  group('while a backup runs', () {
    final running = BackupState(
      hasUserSelectedPath: true,
      backupPath: '/tmp',
      backupHistory: [_backup],
      isBackingUp: true,
      progress: 0.4,
    );

    testWidgets('the progress bar shows how far it got', (tester) async {
      await pumpCard(tester, running);

      final bar = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(bar.value, 0.4);
    });

    testWidgets('the progress bar runs without a value before the first '
        'step', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      // An indeterminate bar never settles, so pump a single frame.
      await tester.pumpWidget(card(running.copyWith(progress: 0)));

      final bar = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(bar.value, isNull);
    });

    testWidgets('the create button says it is backing up and is disabled', (
      tester,
    ) async {
      await pumpCard(tester, running);

      expect(find.text(_l10n.desktopCreateBackup), findsNothing);
      final button = find.ancestor(
        of: find.text(_l10n.desktopBackingUp),
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
      );
      expect(tester.widget<ButtonStyleButton>(button).onPressed, isNull);
    });
  });

  group('the create form', () {
    final list = BackupState(
      hasUserSelectedPath: true,
      backupPath: '/tmp',
      backupHistory: [_backup],
    );
    const connected = DesktopSyncState(
      connectionStatus: ConnectionStatus.connected,
    );

    Future<void> openForm(
      WidgetTester tester, {
      DesktopSyncState syncState = const DesktopSyncState(),
    }) async {
      await pumpCard(tester, list, syncState);
      await tester.tap(find.text(_l10n.desktopCreateBackup));
      await tester.pumpAndSettle();
    }

    Checkbox syncFirstBox(WidgetTester tester) =>
        tester.widget<Checkbox>(find.byType(Checkbox));

    testWidgets('submitting the name from the keyboard starts the backup', (
      tester,
    ) async {
      await openForm(tester);

      await tester.enterText(find.byType(TextField), '  nightly  ');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(bloc.events, [const BackupRequested(name: 'nightly')]);
      expect(find.byType(TextField), findsNothing);
      expect(find.text(_l10n.desktopCreateBackup), findsOne);
    });

    testWidgets('with a phone connected, syncing first is on and both the '
        'label and the box toggle it', (tester) async {
      await openForm(tester, syncState: connected);
      expect(syncFirstBox(tester).value, isTrue);
      expect(find.textContaining(_l10n.desktopNotConnected), findsNothing);

      await tester.tap(find.textContaining(_l10n.desktopSyncWithPhoneFirst));
      await tester.pump();
      expect(syncFirstBox(tester).value, isFalse);

      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      expect(syncFirstBox(tester).value, isTrue);

      await tester.tap(find.text(_l10n.desktopStartBackup));
      await tester.pumpAndSettle();

      expect(lwwBloc.events, [const SyncTriggered()]);
      expect(bloc.events.single, isA<BackupRequested>());
    });

    testWidgets('with syncing first turned off, the backup starts without a '
        'sync', (tester) async {
      await openForm(tester, syncState: connected);

      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await tester.tap(find.text(_l10n.desktopStartBackup));
      await tester.pumpAndSettle();

      expect(lwwBloc.events, isEmpty);
      expect(bloc.events.single, isA<BackupRequested>());
    });

    testWidgets('without a phone, syncing first is off and cannot be turned '
        'on', (tester) async {
      await openForm(tester);
      expect(syncFirstBox(tester).value, isFalse);
      expect(syncFirstBox(tester).onChanged, isNull);
      expect(find.textContaining(_l10n.desktopNotConnected), findsOne);

      await tester.tap(find.textContaining(_l10n.desktopSyncWithPhoneFirst));
      await tester.pump();
      expect(syncFirstBox(tester).value, isFalse);

      await tester.tap(find.text(_l10n.desktopStartBackup));
      await tester.pumpAndSettle();
      expect(lwwBloc.events, isEmpty);
    });

    testWidgets('Cancel closes the form, clears the name and starts nothing', (
      tester,
    ) async {
      await openForm(tester);
      await tester.enterText(find.byType(TextField), 'nightly');

      await tester.tap(find.text(_l10n.cancel));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsNothing);
      expect(bloc.events, isEmpty);

      await tester.tap(find.text(_l10n.desktopCreateBackup));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
    });
  });
}
