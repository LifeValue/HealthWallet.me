import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/utils/pdf_pages.dart';
import 'package:pdfx/pdfx.dart' as pdfx;

/// A document as pdfx opens it, with [pagesCount] pages.
class _FakeDocument extends Fake implements pdfx.PdfDocument {
  _FakeDocument(this.pagesCount);

  @override
  final int pagesCount;

  var closed = false;

  @override
  Future<void> close() async => closed = true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => PdfPages.usePdfx = !Platform.isLinux);

  test('pdfx draws the pages everywhere but on Linux', () {
    expect(PdfPages.usePdfx, !Platform.isLinux);
  });

  // Neither plugin runs in tests, so every file fails to open: with pdfx
  // (macOS, Windows, mobile) and with printing's rasteriser (Linux).
  for (final usePdfx in [true, false]) {
    group(usePdfx ? 'with pdfx' : 'with printing', () {
      setUp(() => PdfPages.usePdfx = usePdfx);

      test('a PDF that cannot be opened has no preview, and nothing is '
          'thrown', () async {
        expect(await PdfPages.renderFirst('/nowhere/report.pdf'), isNull);
      });

      test('a PDF that cannot be opened has no pages', () async {
        expect(await PdfPages.hasPages('/nowhere/report.pdf'), isFalse);
      });

      test('drawing a PDF that cannot be opened fails with an error the '
          'caller can handle', () async {
        await expectLater(
          PdfPages.renderAll('/nowhere/report.pdf'),
          throwsA(anything),
        );
      });
    });
  }

  group('hasPages with pdfx', () {
    setUp(() => PdfPages.usePdfx = true);

    test('a document with pages has them, and is closed again', () async {
      final document = _FakeDocument(2);

      expect(
        await PdfPages.hasPages(
          '/docs/report.pdf',
          open: (_) async => document,
        ),
        isTrue,
      );
      expect(document.closed, isTrue);
    });

    test('a file pdfx cannot open has none, and nothing is thrown', () async {
      expect(
        await PdfPages.hasPages(
          '/docs/broken.pdf',
          open: (_) async => throw const FormatException('not a PDF'),
        ),
        isFalse,
      );
    });

    test('a document without pages has none', () async {
      expect(
        await PdfPages.hasPages(
          '/docs/empty.pdf',
          open: (_) async => _FakeDocument(0),
        ),
        isFalse,
      );
    });
  });
}
