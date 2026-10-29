import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/core/widgets/checked_pdf_view.dart';

final _l10n = lookupAppLocalizations(const Locale('en'));

Widget _app(Future<bool> Function(String) canOpen) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: CheckedPdfView(
      filePath: '/docs/report.pdf',
      canOpen: canOpen,
      builder: (_) => const Text('pdf pages'),
    ),
  ),
);

void main() {
  testWidgets('shows the PDF when the file opens', (tester) async {
    await tester.pumpWidget(_app((_) async => true));
    await tester.pumpAndSettle();

    expect(find.text('pdf pages'), findsOne);
    expect(find.text(_l10n.failedToLoadPdf), findsNothing);
  });

  testWidgets('shows a message instead of a blank page for a broken PDF', (
    tester,
  ) async {
    await tester.pumpWidget(_app((_) async => false));
    await tester.pumpAndSettle();

    expect(find.text('pdf pages'), findsNothing);
    expect(find.text(_l10n.failedToLoadPdf), findsOne);
    expect(find.byIcon(Icons.picture_as_pdf_outlined), findsOne);
  });

  testWidgets('shows progress while the file is opened', (tester) async {
    final opened = Completer<bool>();
    await tester.pumpWidget(_app((_) => opened.future));

    expect(find.byType(CircularProgressIndicator), findsOne);
    expect(find.text('pdf pages'), findsNothing);

    opened.complete(true);
    await tester.pumpAndSettle();
    expect(find.text('pdf pages'), findsOne);
  });

  testWidgets('checks the file it was given', (tester) async {
    final checked = <String>[];
    await tester.pumpWidget(
      _app((path) async {
        checked.add(path);
        return true;
      }),
    );
    await tester.pumpAndSettle();

    expect(checked, ['/docs/report.pdf']);
  });
}
