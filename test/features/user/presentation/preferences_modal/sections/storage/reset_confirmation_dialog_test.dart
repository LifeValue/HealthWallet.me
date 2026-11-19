import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/features/user/presentation/preferences_modal/sections/storage/storage_section.dart';

Widget _dialog(Locale locale) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: const Scaffold(body: ResetConfirmationDialog()),
);

bool _deleteEnabled(WidgetTester tester) =>
    tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed !=
    null;

void main() {
  for (final code in ['en', 'es', 'de', 'ro']) {
    final l10n = lookupAppLocalizations(Locale(code));

    testWidgets('$code: asks for the word it accepts', (tester) async {
      await tester.pumpWidget(_dialog(Locale(code)));

      expect(
        find.text(l10n.resetTypeToConfirm(resetConfirmationWord)),
        findsOne,
      );
      expect(find.text(l10n.resetDataWarning), findsOne);
      expect(find.text(l10n.delete), findsOne);
      expect(find.text(l10n.cancel), findsOne);
      expect(_deleteEnabled(tester), isFalse);

      await tester.enterText(find.byType(TextField), 'reset');
      await tester.pump();
      expect(_deleteEnabled(tester), isFalse);

      await tester.enterText(
        find.byType(TextField),
        ' $resetConfirmationWord ',
      );
      await tester.pump();
      expect(_deleteEnabled(tester), isTrue);
    });
  }

  testWidgets('Delete runs the reset once and disables itself', (
    tester,
  ) async {
    var resets = 0;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ResetConfirmationDialog(onReset: () async => resets++),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), resetConfirmationWord);
    await tester.pump();
    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();

    expect(resets, 1);
    expect(_deleteEnabled(tester), isFalse);
  });

  group('close button', () {
    Future<void> openDialog(
      WidgetTester tester, {
      Future<void> Function()? onReset,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => ResetConfirmationDialog(onReset: onReset),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('shows the title and an X that closes without resetting', (
      tester,
    ) async {
      var resets = 0;
      await openDialog(tester, onReset: () async => resets++);
      final l10n = lookupAppLocalizations(const Locale('en'));

      expect(find.text(l10n.settingsReset), findsOne);
      expect(find.byTooltip(l10n.close), findsOne);

      await tester.tap(find.byKey(const Key('reset_dialog_close')));
      await tester.pumpAndSettle();

      expect(find.byType(ResetConfirmationDialog), findsNothing);
      expect(resets, 0);
    });

    testWidgets('the X is disabled while the reset runs', (tester) async {
      final reset = Completer<void>();
      await openDialog(tester, onReset: () => reset.future);

      await tester.enterText(find.byType(TextField), resetConfirmationWord);
      await tester.pump();
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      final close = tester.widget<IconButton>(
        find.byKey(const Key('reset_dialog_close')),
      );
      expect(close.onPressed, isNull);

      reset.complete();
      await tester.pumpAndSettle();
    });
  });
}
