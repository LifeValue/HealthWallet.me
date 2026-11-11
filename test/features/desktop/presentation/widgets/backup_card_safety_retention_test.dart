import 'package:bloc_test/bloc_test.dart' show MockBloc, whenListen;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/features/desktop/backup/presentation/bloc/backup_bloc.dart';
import 'package:health_wallet/features/desktop/communication/presentation/bloc/communication_bloc.dart';
import 'package:health_wallet/features/desktop/presentation/widgets/backup_card.dart';
import 'package:health_wallet/features/desktop/presentation/widgets/safety_copy_retention_row.dart';

/// Records the events the card sends instead of handling them.
class _RecordingBackupBloc extends MockBloc<BackupEvent, BackupState>
    implements BackupBloc {
  final events = <BackupEvent>[];

  @override
  void add(BackupEvent event) => events.add(event);
}

void main() {
  late _RecordingBackupBloc bloc;

  Future<void> pumpCard(
    WidgetTester tester, {
    Locale locale = const Locale('en'),
    int days = 30,
    bool isBackingUp = false,
  }) async {
    final state = BackupState(
      hasUserSelectedPath: true,
      backupPath: '/backups',
      safetyCopyRetentionDays: days,
      isBackingUp: isBackingUp,
    );
    bloc = _RecordingBackupBloc();
    whenListen(bloc, const Stream<BackupState>.empty(), initialState: state);
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            // About the width of the backup dialog.
            child: SizedBox(
              width: 500,
              height: 600,
              child: BlocProvider<BackupBloc>.value(
                value: bloc,
                child: BackupCard(
                  syncState: const DesktopSyncState(),
                  backupState: state,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  final en = lookupAppLocalizations(const Locale('en'));
  final field = find.descendant(
    of: find.byKey(SafetyCopyRetentionRow.fieldKey),
    matching: find.byType(TextField),
  );

  Future<void> openEditor(WidgetTester tester) async {
    await tester.tap(find.byKey(SafetyCopyRetentionRow.changeKey));
    await tester.pump();
  }

  Future<void> typeAndSave(WidgetTester tester, String text) async {
    await tester.enterText(field, text);
    await tester.pump();
    await tester.tap(find.byKey(SafetyCopyRetentionRow.saveKey));
    await tester.pump();
  }

  testWidgets('shows the retention under the backup folder', (tester) async {
    await pumpCard(tester);

    final row = find.text('Keep the copy made before a restore: 30 days');
    expect(row, findsOneWidget);
    expect(
      tester.getTopLeft(row).dy,
      greaterThan(tester.getTopLeft(find.text('/backups')).dy),
    );
    expect(
      tester.getTopLeft(row).dy,
      lessThan(tester.getTopLeft(find.text(en.desktopBackupHistory)).dy),
    );
    expect(find.byKey(SafetyCopyRetentionRow.changeKey), findsOneWidget);
  });

  testWidgets('says 1 day for one day', (tester) async {
    await pumpCard(tester, days: 1);

    expect(
      find.text('Keep the copy made before a restore: 1 day'),
      findsOneWidget,
    );
  });

  testWidgets('edits the value and sends it to the bloc', (tester) async {
    await pumpCard(tester, days: 30);

    await openEditor(tester);
    expect(find.text(en.backupSafetyRetentionEditLabel), findsOneWidget);
    expect(find.text(en.backupSafetyRetentionHint), findsOneWidget);
    expect(tester.widget<TextField>(field).controller!.text, '30');

    await typeAndSave(tester, '45');

    expect(bloc.events, [const SafetyCopyRetentionChanged(45)]);
    expect(field, findsNothing);
  });

  testWidgets('takes the limits 1 and 365', (tester) async {
    await pumpCard(tester);

    await openEditor(tester);
    await typeAndSave(tester, '1');
    await openEditor(tester);
    await typeAndSave(tester, ' 365 ');

    expect(bloc.events, [
      const SafetyCopyRetentionChanged(1),
      const SafetyCopyRetentionChanged(365),
    ]);
  });

  for (final input in ['0', '366', 'abc', '7.5', '-3', '']) {
    testWidgets('rejects "$input" with a message and sends nothing', (
      tester,
    ) async {
      await pumpCard(tester);

      await openEditor(tester);
      await typeAndSave(tester, input);

      expect(bloc.events, isEmpty);
      expect(field, findsOneWidget);
      expect(
        find.text('Enter a whole number of days from 1 to 365.'),
        findsOneWidget,
      );
      expect(find.text(en.backupSafetyRetentionHint), findsNothing);
    });
  }

  testWidgets('typing again clears the message; a valid value then saves', (
    tester,
  ) async {
    await pumpCard(tester);
    await openEditor(tester);
    await typeAndSave(tester, '0');
    expect(find.byKey(SafetyCopyRetentionRow.errorKey), findsOneWidget);

    await tester.enterText(field, '12');
    await tester.pump();
    expect(find.byKey(SafetyCopyRetentionRow.errorKey), findsNothing);

    await tester.tap(find.byKey(SafetyCopyRetentionRow.saveKey));
    await tester.pump();
    expect(bloc.events, [const SafetyCopyRetentionChanged(12)]);
  });

  testWidgets('Cancel closes the editor without sending anything', (
    tester,
  ) async {
    await pumpCard(tester);
    await openEditor(tester);
    await tester.enterText(field, '5');

    await tester.tap(find.byKey(SafetyCopyRetentionRow.cancelKey));
    await tester.pump();

    expect(bloc.events, isEmpty);
    expect(field, findsNothing);
    expect(
      find.text('Keep the copy made before a restore: 30 days'),
      findsOneWidget,
    );
  });

  testWidgets('cannot be changed while a backup runs', (tester) async {
    await pumpCard(tester, isBackingUp: true);

    final button = tester.widget<TextButton>(
      find.descendant(
        of: find.byKey(SafetyCopyRetentionRow.changeKey),
        matching: find.byType(TextButton),
      ),
    );
    expect(button.onPressed, isNull);
  });

  for (final code in ['en', 'de', 'es', 'ro']) {
    final locale = Locale(code);
    final l10n = lookupAppLocalizations(locale);

    testWidgets('in $code the row and the editor fit the card', (
      tester,
    ) async {
      await pumpCard(tester, locale: locale, days: 120);

      expect(find.text(l10n.backupSafetyRetention(120)), findsOneWidget);
      expect(tester.takeException(), isNull);

      await openEditor(tester);
      await typeAndSave(tester, '400');

      expect(
        find.text(l10n.backupSafetyRetentionInvalid(1, 365)),
        findsOneWidget,
      );
      expect(find.text(l10n.save), findsOneWidget);
      expect(find.text(l10n.cancel), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  test('Romanian uses its few form below 20 days', () {
    final ro = lookupAppLocalizations(const Locale('ro'));

    expect(ro.backupSafetyRetention(1), endsWith(': 1 zi'));
    expect(ro.backupSafetyRetention(2), endsWith(': 2 zile'));
    expect(ro.backupSafetyRetention(19), endsWith(': 19 zile'));
    expect(ro.backupSafetyRetention(20), endsWith(': 20 de zile'));
    expect(ro.backupSafetyRetention(101), endsWith(': 101 zile'));
  });
}
