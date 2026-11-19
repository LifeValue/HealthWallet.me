import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/core/widgets/app_snack_bar.dart';
import 'package:health_wallet/features/home/presentation/widgets/source/source_label_edit_dialog.dart';
import 'package:health_wallet/features/sync/domain/entities/source.dart';

final _l10n = lookupAppLocalizations(const Locale('en'));

void main() {
  const source = Source(id: 'clinic', labelSource: 'Clinic');

  Future<void> open(WidgetTester tester, void Function(String) onSaved) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () =>
                  SourceLabelEditDialog.show(context, source, onSaved),
              child: const Text('edit'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('edit'));
    await tester.pumpAndSettle();
  }

  Future<void> save(WidgetTester tester, String label) async {
    await tester.enterText(find.byType(TextField), label);
    await tester.tap(find.byType(ElevatedButton).last);
    await tester.pumpAndSettle();
  }

  testWidgets('starts with the current label', (tester) async {
    await open(tester, (_) {});

    expect(find.widgetWithText(TextField, 'Clinic'), findsOne);
  });

  testWidgets('saving passes the new label on and closes the dialog', (
    tester,
  ) async {
    final saved = <String>[];
    await open(tester, saved.add);

    await save(tester, '  City clinic  ');

    expect(saved, ['City clinic']);
    expect(find.byType(SourceLabelEditDialog), findsNothing);
  });

  testWidgets('a failed save shows the translated message, not the exception, '
      'and keeps the dialog open', (tester) async {
    await open(tester, (_) => throw StateError('database is locked'));

    await save(tester, 'City clinic');

    expect(
      find.descendant(
        of: find.byKey(AppSnackBar.cardKey),
        matching: find.text(_l10n.errorUpdatingSourceLabel),
      ),
      findsOne,
    );
    expect(find.textContaining('database is locked'), findsNothing);
    expect(find.byType(SourceLabelEditDialog), findsOne);
  });
}
