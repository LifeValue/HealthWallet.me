import 'package:flutter/material.dart';
import 'package:health_wallet/core/l10n/l10n.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/logger.dart';
import 'package:pdfx/pdfx.dart' as pdfx;

/// Opens [filePath] as a PDF before [builder] shows it. The full-screen PDF
/// viewer draws a blank page for a file it cannot read and does not report
/// it, so a file that does not open shows a "failed to load" message instead.
/// Meant for the viewers' black full-screen background.
class CheckedPdfView extends StatefulWidget {
  const CheckedPdfView({
    required this.filePath,
    required this.builder,
    this.canOpen = canOpenPdf,
    super.key,
  });

  final String filePath;
  final WidgetBuilder builder;

  /// Whether the file at a path opens as a PDF with at least one page.
  final Future<bool> Function(String filePath) canOpen;

  static Future<bool> canOpenPdf(String filePath) async {
    try {
      final document = await pdfx.PdfDocument.openFile(filePath);
      final readable = document.pagesCount > 0;
      await document.close();
      return readable;
    } catch (e, s) {
      logger.w('Could not open the PDF $filePath', e, s);
      return false;
    }
  }

  @override
  State<CheckedPdfView> createState() => _CheckedPdfViewState();
}

class _CheckedPdfViewState extends State<CheckedPdfView> {
  late final Future<bool> _opens = widget.canOpen(widget.filePath);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _opens,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.data ?? false) return widget.builder(context);
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(Insets.medium),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.picture_as_pdf_outlined,
                  color: Colors.white54,
                  size: Insets.huge,
                ),
                const SizedBox(height: Insets.normal),
                Text(
                  context.l10n.failedToLoadPdf,
                  textAlign: TextAlign.center,
                  style: AppTextStyle.bodyMedium.copyWith(
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
