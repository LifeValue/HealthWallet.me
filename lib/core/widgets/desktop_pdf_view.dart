import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:health_wallet/core/utils/pdf_open.dart';
import 'package:health_wallet/core/utils/pdf_pages.dart';
import 'package:health_wallet/core/widgets/checked_pdf_view.dart';
import 'package:pdfx/pdfx.dart' as pdfx;

/// A PDF in the desktop's full-screen viewers, one page at a time: pdfx's
/// page view where pdfx runs, and on Linux the pages [PdfPages] draws.
/// Shown inside a [CheckedPdfView], which has already opened the file.
class DesktopPdfView extends StatefulWidget {
  const DesktopPdfView({required this.filePath, super.key});

  final String filePath;

  @override
  State<DesktopPdfView> createState() => _DesktopPdfViewState();
}

class _DesktopPdfViewState extends State<DesktopPdfView> {
  pdfx.PdfController? _controller;
  Future<List<PdfPageImage>>? _pages;

  /// Drawn at twice their size in points, so text stays sharp on high-density
  /// screens and when zoomed.
  static const _scale = 2.0;

  @override
  void initState() {
    super.initState();
    if (PdfPages.usePdfx) {
      _controller = pdfx.PdfController(
        document: openPdfDocument(widget.filePath),
      );
    } else {
      _pages = PdfPages.renderAll(widget.filePath, scale: _scale).catchError((
        Object error,
      ) {
        if (mounted) CheckedPdfView.reportViewerError(context, error);
        return <PdfPageImage>[];
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller != null) return pdfx.PdfView(controller: controller);

    return FutureBuilder<List<PdfPageImage>>(
      future: _pages,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final pages = snapshot.data ?? const <PdfPageImage>[];
        return ScrollConfiguration(
          // Pages turn with a mouse drag too, as in pdfx's view.
          behavior: ScrollConfiguration.of(context).copyWith(
            dragDevices: PointerDeviceKind.values.toSet(),
          ),
          child: PageView.builder(
            itemCount: pages.length,
            itemBuilder: (context, index) => InteractiveViewer(
              maxScale: 4,
              child: Center(
                child: Image.memory(pages[index].bytes, fit: BoxFit.contain),
              ),
            ),
          ),
        );
      },
    );
  }
}
