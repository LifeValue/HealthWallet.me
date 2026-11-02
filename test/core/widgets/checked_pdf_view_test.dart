import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/core/widgets/app_snack_bar.dart';
import 'package:health_wallet/core/widgets/checked_pdf_view.dart';
import 'package:pdfx/pdfx.dart' as pdfx;

final _l10n = lookupAppLocalizations(const Locale('en'));

/// A document as pdfx opens it, with [pagesCount] pages.
class _FakeDocument extends Fake implements pdfx.PdfDocument {
  _FakeDocument(this.pagesCount);

  @override
  final int pagesCount;

  var closed = false;

  @override
  Future<void> close() async => closed = true;
}

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

  group('canOpenPdf', () {
    test('a document with pages can be opened, and is closed again', () async {
      final document = _FakeDocument(3);

      final opens = await CheckedPdfView.canOpenPdf(
        '/docs/report.pdf',
        open: (_) async => document,
      );

      expect(opens, isTrue);
      expect(document.closed, isTrue);
    });

    test('a document without pages cannot', () async {
      expect(
        await CheckedPdfView.canOpenPdf(
          '/docs/empty.pdf',
          open: (_) async => _FakeDocument(0),
        ),
        isFalse,
      );
    });

    test('a file pdfx cannot open cannot, and nothing is thrown', () async {
      expect(
        await CheckedPdfView.canOpenPdf(
          '/docs/broken.pdf',
          open: (_) async => throw const FormatException('not a PDF'),
        ),
        isFalse,
      );
    });
  });

  testWidgets('without its own check it uses the default one', (tester) async {
    final previous = CheckedPdfView.defaultCanOpen;
    addTearDown(() => CheckedPdfView.defaultCanOpen = previous);
    final checked = <String>[];
    CheckedPdfView.defaultCanOpen = (path) async {
      checked.add(path);
      return false;
    };

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: CheckedPdfView(
            filePath: '/docs/report.pdf',
            builder: (_) => const Text('pdf pages'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(checked, ['/docs/report.pdf']);
    expect(find.text(_l10n.failedToLoadPdf), findsOne);
  });

  testWidgets('a PDF view error shows the translated message, not its own '
      'text', (tester) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (c) {
              context = c;
              return const SizedBox();
            },
          ),
        ),
      ),
    );

    CheckedPdfView.reportViewerError(context, 'PdfiumException: page 3');
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(AppSnackBar.cardKey),
        matching: find.text(_l10n.failedToLoadPdf),
      ),
      findsOne,
    );
    expect(find.textContaining('Pdfium'), findsNothing);
  });
}
