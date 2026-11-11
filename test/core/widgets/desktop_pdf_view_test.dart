import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/core/utils/pdf_pages.dart';
import 'package:health_wallet/core/widgets/app_snack_bar.dart';
import 'package:health_wallet/core/widgets/desktop_pdf_view.dart';
import 'package:pdfx/pdfx.dart' as pdfx;

final _l10n = lookupAppLocalizations(const Locale('en'));

Widget _app() => const MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: DesktopPdfView(filePath: '/docs/report.pdf')),
);

void main() {
  tearDown(() => PdfPages.usePdfx = !Platform.isLinux);

  testWidgets('shows the PDF in pdfx where pdfx runs', (tester) async {
    PdfPages.usePdfx = true;

    await tester.pumpWidget(_app());

    expect(find.byType(pdfx.PdfView), findsOne);
  });

  testWidgets('on Linux shows the drawn pages, and says so when they could '
      'not be drawn', (tester) async {
    PdfPages.usePdfx = false;

    await tester.pumpWidget(_app());
    expect(find.byType(CircularProgressIndicator), findsOne);

    // printing's rasteriser does not run in tests, so the file fails to draw.
    // Its plugin answers on real I/O: wait for that, however long the host
    // takes, instead of a fixed time.
    for (var i = 0; i < 150; i++) {
      if (find.byType(CircularProgressIndicator).evaluate().isEmpty) break;
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();

    expect(find.byType(pdfx.PdfView), findsNothing);
    expect(find.byType(PageView), findsOne);
    expect(find.byType(Image), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(AppSnackBar.cardKey),
        matching: find.text(_l10n.failedToLoadPdf),
      ),
      findsOne,
    );
  });
}
