import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:health_wallet/core/utils/logger.dart';
import 'package:health_wallet/core/utils/pdf_open.dart';
import 'package:pdfx/pdfx.dart' as pdfx;
import 'package:printing/printing.dart';

/// A PDF page drawn as a PNG on white, [width] by [height] pixels.
class PdfPageImage {
  const PdfPageImage({
    required this.bytes,
    required this.width,
    required this.height,
  });

  final Uint8List bytes;
  final int width;
  final int height;
}

/// Draws PDF pages for the previews and viewers.
///
/// pdfx draws them where it runs. It has no Linux implementation, so there
/// printing's pdfium rasteriser draws them, the one OCR already uses on every
/// platform.
abstract final class PdfPages {
  /// Whether pdfx draws the pages here. Tests set it, so the path they cover
  /// does not depend on the host (CI runs on Linux).
  static bool usePdfx = !Platform.isLinux;

  static const _pointsPerInch = 72.0;

  /// Every page of [filePath], each [scale] times its size in points. Throws
  /// when the file does not open.
  static Future<List<PdfPageImage>> renderAll(
    String filePath, {
    double scale = 1,
  }) async {
    if (!usePdfx) {
      return _raster(filePath, dpi: _pointsPerInch * scale);
    }
    final document = await openPdfDocument(filePath);
    try {
      final images = <PdfPageImage>[];
      for (var number = 1; number <= document.pagesCount; number++) {
        final page = await document.getPage(number);
        try {
          final image = await page.render(
            width: page.width * scale,
            height: page.height * scale,
            backgroundColor: '#FFFFFF',
          );
          if (image != null) {
            images.add(
              PdfPageImage(
                bytes: image.bytes,
                width: image.width ?? 0,
                height: image.height ?? 0,
              ),
            );
          }
        } finally {
          await page.close();
        }
      }
      return images;
    } finally {
      await document.close();
    }
  }

  /// The first page of [filePath] fitted into a [targetSize] square, or null
  /// when the file does not open.
  static Future<Uint8List?> renderFirst(
    String filePath, {
    double targetSize = 200,
  }) async {
    try {
      if (!usePdfx) {
        // A small draw first gives the page's proportions.
        const probeDpi = 18.0;
        final probe = await _raster(filePath, dpi: probeDpi, pages: [0]);
        if (probe.isEmpty) return null;
        final longestSideInInches =
            math.max(probe.first.width, probe.first.height) / probeDpi;
        final pages = await _raster(
          filePath,
          dpi: targetSize / longestSideInInches,
          pages: [0],
        );
        return pages.isEmpty ? null : pages.first.bytes;
      }

      final document = await openPdfDocument(filePath);
      try {
        final page = await document.getPage(1);
        try {
          final aspect = page.width / page.height;
          final image = await page.render(
            width: aspect >= 1 ? targetSize : targetSize * aspect,
            height: aspect >= 1 ? targetSize / aspect : targetSize,
            backgroundColor: '#FFFFFF',
          );
          return image?.bytes;
        } finally {
          await page.close();
        }
      } finally {
        await document.close();
      }
    } catch (e) {
      logger.w('No preview of the PDF', e);
      return null;
    }
  }

  /// Whether [filePath] opens as a PDF with at least one page.
  static Future<bool> hasPages(
    String filePath, {
    @visibleForTesting
    Future<pdfx.PdfDocument> Function(String filePath) open = openPdfDocument,
  }) async {
    try {
      if (!usePdfx) {
        final pages = await _raster(filePath, dpi: 1, pages: [0]);
        return pages.isNotEmpty;
      }
      final document = await open(filePath);
      final readable = document.pagesCount > 0;
      await document.close();
      return readable;
    } catch (e, s) {
      logger.w('Could not open the PDF $filePath', e, s);
      return false;
    }
  }

  static Future<List<PdfPageImage>> _raster(
    String filePath, {
    required double dpi,
    List<int>? pages,
  }) async {
    // Without the plugin (tests) printing's raster stream never ends and its
    // error escapes, so the support check comes first, as pdfx's does.
    if (!(await Printing.info()).canRaster) {
      throw UnsupportedError('printing cannot draw PDF pages here');
    }
    final bytes = await File(filePath).readAsBytes();
    final images = <PdfPageImage>[];
    await for (final raster in Printing.raster(bytes, pages: pages, dpi: dpi)) {
      images.add(
        PdfPageImage(
          bytes: await _onWhite(raster),
          width: raster.width,
          height: raster.height,
        ),
      );
    }
    return images;
  }

  /// pdfium leaves the page transparent; the viewers' background is black.
  static Future<Uint8List> _onWhite(PdfRaster raster) async {
    final page = await raster.toImage();
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder)
      ..drawColor(const ui.Color(0xFFFFFFFF), ui.BlendMode.src)
      ..drawImage(page, ui.Offset.zero, ui.Paint());
    final flattened = await recorder.endRecording().toImage(
      raster.width,
      raster.height,
    );
    try {
      final png = await flattened.toByteData(format: ui.ImageByteFormat.png);
      return png!.buffer.asUint8List();
    } finally {
      page.dispose();
      flattened.dispose();
    }
  }
}
