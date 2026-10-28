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
}
