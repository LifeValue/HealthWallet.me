import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/core/widgets/app_button.dart';
import 'package:health_wallet/features/processing/presentation/widgets/import_actions.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  Future<void> pump(WidgetTester tester, ImportActions actions) =>
      tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: actions),
        ),
      );

  testWidgets('offers the three actions, in order, and each runs its own '
      'callback', (tester) async {
    final tapped = <String>[];
    await pump(
      tester,
      ImportActions(
        onImportDocument: () => tapped.add('import'),
        onPickImage: () => tapped.add('gallery'),
        onScanDocument: () => tapped.add('scan'),
      ),
    );

    final labels = tester
        .widgetList<AppButton>(find.byType(AppButton))
        .map((b) => b.label);
    expect(labels, [
      l10n.importDocument,
      l10n.pickImageFromGallery,
      l10n.scanDocument,
    ]);

    await tester.tap(find.text(l10n.importDocument));
    await tester.tap(find.text(l10n.pickImageFromGallery));
    await tester.tap(find.text(l10n.scanDocument));
    expect(tapped, ['import', 'gallery', 'scan']);
  });

  testWidgets('an action without a callback is not offered', (tester) async {
    // The desktop has no scanner.
    await pump(
      tester,
      ImportActions(onImportDocument: () {}, onPickImage: () {}),
    );

    expect(find.byType(AppButton), findsNWidgets(2));
    expect(find.text(l10n.scanDocument), findsNothing);
  });

  testWidgets('the gaps sit only between the offered actions', (tester) async {
    await pump(tester, ImportActions(onImportDocument: () {}));

    final column = tester.widget<Column>(
      find
          .descendant(
            of: find.byType(ImportActions),
            matching: find.byType(Column),
          )
          .first,
    );
    expect(column.children, hasLength(1));
    expect(column.children.single, isA<AppButton>());
  });

  testWidgets('with no actions, shows nothing', (tester) async {
    await pump(tester, const ImportActions());

    expect(find.byType(AppButton), findsNothing);
  });
}
