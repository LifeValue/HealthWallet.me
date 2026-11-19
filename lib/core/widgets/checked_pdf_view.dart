import 'package:flutter/material.dart';
import 'package:health_wallet/core/l10n/l10n.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/logger.dart';
import 'package:health_wallet/core/utils/pdf_pages.dart';
import 'package:health_wallet/core/widgets/app_snack_bar.dart';

/// Opens [filePath] as a PDF before [builder] shows it. The full-screen PDF
/// viewer draws a blank page for a file it cannot read and does not report
/// it, so a file that does not open shows a "failed to load" message instead.
/// Meant for the viewers' black full-screen background.
class CheckedPdfView extends StatefulWidget {
  const CheckedPdfView({
    required this.filePath,
    required this.builder,
    this.canOpen,
    super.key,
  });

  final String filePath;
  final WidgetBuilder builder;

  /// Whether the file at a path opens as a PDF with at least one page;
  /// [defaultCanOpen] when null.
  final Future<bool> Function(String filePath)? canOpen;

  /// The check the viewers use. Neither PDF plugin runs in tests, so they
  /// replace it.
  @visibleForTesting
  static Future<bool> Function(String filePath) defaultCanOpen =
      PdfPages.hasPages;

  /// For the PDF view's own `onError` and `onPageError`: their text is
  /// technical English, so it is only logged and the user reads the
  /// translated "failed to load" message.
  static void reportViewerError(BuildContext context, Object error) {
    logger.w('The PDF view failed: $error');
    if (!context.mounted) return;
    AppSnackBar.show(
      context,
      message: context.l10n.failedToLoadPdf,
      type: AppSnackBarType.error,
    );
  }

  @override
  State<CheckedPdfView> createState() => _CheckedPdfViewState();
}

class _CheckedPdfViewState extends State<CheckedPdfView> {
  late final Future<bool> _opens =
      (widget.canOpen ?? CheckedPdfView.defaultCanOpen)(
        widget.filePath,
      );

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
