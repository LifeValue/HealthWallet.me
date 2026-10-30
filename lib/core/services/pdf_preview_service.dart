import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:health_wallet/core/config/app_platform.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/l10n/l10n.dart';
import 'package:health_wallet/core/services/path_resolver.dart';
import 'package:health_wallet/core/utils/logger.dart';
import 'package:health_wallet/core/utils/pdf_open.dart';
import 'package:health_wallet/core/widgets/app_snack_bar.dart';
import 'package:health_wallet/core/widgets/checked_pdf_view.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:injectable/injectable.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart' as pdfx;

@injectable
class PdfPreviewService {
  final PathResolver _pathResolver;

  PdfPreviewService(this._pathResolver);

  static const _previewableTypes = {FhirType.Media, FhirType.DocumentReference};

  Future<void> previewPdfFromResource(
    BuildContext context,
    IFhirResource resource,
  ) async {
    return previewInApp(context, resource);
  }

  Future<String?> _extractDocumentReferencePath(
    Map<String, dynamic> rawResource,
  ) async {
    final contentList = rawResource['content'] as List?;
    if (contentList == null || contentList.isEmpty) return null;
    final attachment = (contentList[0] as Map?)?['attachment'] as Map?;
    final url = attachment?['url'] as String?;
    if (url == null) return null;
    final rawPath = Uri.decodeComponent(
      url.startsWith('file://') ? url.substring(7) : url,
    );
    final resolved = await _pathResolver.toAbsolute(rawPath);
    return resolved;
  }

  Future<String?> _extractMediaPath(
    Map<String, dynamic> rawResource,
    String displayTitle,
  ) async {
    final content = rawResource['content'];
    if (content == null) return null;

    if (content['url'] != null) return content['url'] as String;

    if (content['data'] != null) {
      return _saveBase64ToTempFile(content['data'] as String, displayTitle);
    }

    return null;
  }

  Future<String> _saveBase64ToTempFile(
    String base64Data,
    String fileName,
  ) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final cleanFileName = fileName.replaceAll(RegExp(r'[^\w\s-.]'), '_');
      final tempFileName = '${cleanFileName}_$timestamp.pdf';
      final tempFilePath = path.join(tempDir.path, tempFileName);

      final bytes = base64Decode(base64Data);
      final file = File(tempFilePath);
      await file.writeAsBytes(bytes);

      return tempFilePath;
    } catch (e) {
      throw Exception('Failed to save base64 data to temp file: $e');
    }
  }

  void _showErrorSnackBar(BuildContext context, String message) {
    AppSnackBar.show(context, message: message, type: AppSnackBarType.error);
  }

  /// The name the user knows the file by: the attachment's title, then the
  /// record's title (never empty: it falls back to the record type). Files
  /// are stored under a unique name (`report_1a2b3c4d.pdf`), so the file
  /// name is never shown.
  static String _viewerTitle(IFhirResource resource) {
    final content = resource.rawResource['content'];
    final first = content is List && content.isNotEmpty ? content.first : null;
    final attachment = first is Map ? first['attachment'] : null;
    final attachmentTitle = attachment is Map ? attachment['title'] : null;
    if (attachmentTitle is String && attachmentTitle.trim().isNotEmpty) {
      return attachmentTitle;
    }
    return resource.displayTitle;
  }

  Future<void> previewInApp(
    BuildContext context,
    IFhirResource resource,
  ) async {
    if (!_previewableTypes.contains(resource.fhirType)) {
      _showErrorSnackBar(context, context.l10n.resourceNotViewable);
      return;
    }

    try {
      final rawResource = resource.rawResource;
      String? filePath;

      if (resource.fhirType == FhirType.DocumentReference) {
        filePath = await _extractDocumentReferencePath(rawResource);
      } else {
        filePath = await _extractMediaPath(rawResource, resource.displayTitle);
      }

      if (!context.mounted) return;
      if (filePath == null) {
        _showErrorSnackBar(context, context.l10n.noFilePathFound);
        return;
      }

      final exists = await File(filePath).exists();
      if (!context.mounted) return;
      if (!exists) {
        _showErrorSnackBar(context, context.l10n.fileNotAvailable);
        return;
      }

      final title = _viewerTitle(resource);
      final extension = path.extension(filePath).toLowerCase();
      final isImage = {
        '.jpg',
        '.jpeg',
        '.png',
        '.gif',
        '.bmp',
        '.webp',
      }.contains(extension);

      if (isImage) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                _InAppImageViewer(filePath: filePath!, title: title),
          ),
        );
      } else {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => _InAppPdfViewer(filePath: filePath!, title: title),
          ),
        );
      }
    } catch (e, s) {
      logger.w('Could not open the attachment preview', e, s);
      if (!context.mounted) return;
      _showErrorSnackBar(context, context.l10n.fileOpenFailed);
    }
  }
}

class _InAppImageViewer extends StatelessWidget {
  final String filePath;

  final String title;

  const _InAppImageViewer({required this.filePath, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(title),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Image.file(
            File(filePath),
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.broken_image, color: Colors.white54, size: 64),
                const SizedBox(height: 16),
                Text(
                  context.l10n.failedToLoadImage,
                  style: const TextStyle(color: Colors.white54),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InAppPdfViewer extends StatelessWidget {
  final String filePath;

  final String title;

  const _InAppPdfViewer({required this.filePath, required this.title});

  static bool get _isDesktop => getIt<AppPlatform>().isDesktop;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(title),
      ),
      body: CheckedPdfView(
        filePath: filePath,
        builder: (context) => _isDesktop
            ? _DesktopPdfBody(filePath: filePath)
            : PDFView(
                filePath: filePath,
                enableSwipe: true,
                swipeHorizontal: true,
                autoSpacing: true,
                pageFling: true,
                onError: (error) =>
                    CheckedPdfView.reportViewerError(context, error),
                onPageError: (page, error) => CheckedPdfView.reportViewerError(
                  context,
                  'page $page: $error',
                ),
              ),
      ),
    );
  }
}

class _DesktopPdfBody extends StatefulWidget {
  final String filePath;
  const _DesktopPdfBody({required this.filePath});

  @override
  State<_DesktopPdfBody> createState() => _DesktopPdfBodyState();
}

class _DesktopPdfBodyState extends State<_DesktopPdfBody> {
  late final pdfx.PdfController _controller;

  @override
  void initState() {
    super.initState();
    _controller = pdfx.PdfController(
      document: openPdfDocument(widget.filePath),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return pdfx.PdfView(controller: _controller);
  }
}
