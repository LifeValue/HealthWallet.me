import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:health_wallet/core/l10n/l10n.dart';
import 'package:health_wallet/core/services/path_resolver.dart';
import 'package:health_wallet/core/services/temp_file_sweeper.dart';
import 'package:health_wallet/core/utils/logger.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:injectable/injectable.dart';
import 'package:open_file/open_file.dart';
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

  Future<String?> _extractMediaPath(Map<String, dynamic> rawResource) async {
    final content = rawResource['content'];
    if (content == null) return null;

    if (content['url'] != null) return content['url'] as String;

    if (content['data'] != null) {
      return _saveBase64ToTempFile(
        content['data'] as String,
        content['contentType'] as String?,
      );
    }

    return null;
  }

  Future<void> previewPdfFromFile(
    BuildContext context,
    String filePath,
  ) async {
    try {
      final result = await OpenFile.open(filePath);
      if (!context.mounted) return;

      if (result.type != ResultType.done) {
        _showWarningSnackBar(
          context,
          context.l10n.couldNotOpenPdf(result.message),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      _showErrorSnackBar(context, context.l10n.errorOpeningPdf(e.toString()));
    }
  }

  /// Writes inline attachment data to a temp file named for the startup
  /// sweep, with the extension of its [contentType].
  Future<String> _saveBase64ToTempFile(
    String base64Data,
    String? contentType,
  ) async {
    try {
      final extension = switch (contentType?.toLowerCase()) {
        'image/png' => 'png',
        'image/jpeg' || 'image/jpg' => 'jpg',
        'image/gif' => 'gif',
        'image/webp' => 'webp',
        'image/bmp' => 'bmp',
        _ => 'pdf',
      };
      final tempDir = await getTemporaryDirectory();
      final file = File(
        path.join(tempDir.path, TempFileSweeper.recordPreviewName(extension)),
      );
      await file.writeAsBytes(base64Decode(base64Data));
      return file.path;
    } catch (e) {
      throw Exception('Failed to save base64 data to temp file: $e');
    }
  }

  Future<void> _deleteTemp(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) await file.delete();
    } catch (e, s) {
      // The startup sweep deletes it next time.
      logger.w('Deleting a record preview failed', e, s);
    }
  }

  void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
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
        filePath = await _extractMediaPath(rawResource);
      }
      // Decoded health data: it goes when the viewer closes.
      final isTemp =
          filePath != null &&
          path
              .basename(filePath)
              .startsWith(TempFileSweeper.recordPreviewPrefix);

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

      final extension = path.extension(filePath).toLowerCase();
      final isImage = {
        '.jpg',
        '.jpeg',
        '.png',
        '.gif',
        '.bmp',
        '.webp',
      }.contains(extension);

      final viewerPath = filePath;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => isImage
              ? _InAppImageViewer(filePath: viewerPath)
              : _InAppPdfViewer(filePath: viewerPath),
        ),
      );
      if (isTemp) await _deleteTemp(viewerPath);
    } catch (e) {
      if (!context.mounted) return;
      _showErrorSnackBar(context, context.l10n.errorOpeningFile(e.toString()));
    }
  }

  void _showWarningSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.orange,
      ),
    );
  }
}

class _InAppImageViewer extends StatelessWidget {
  final String filePath;

  const _InAppImageViewer({required this.filePath});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(path.basename(filePath)),
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

  const _InAppPdfViewer({required this.filePath});

  static bool get _isDesktop =>
      Platform.isMacOS || Platform.isWindows || Platform.isLinux;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(path.basename(filePath)),
      ),
      body: _isDesktop
          ? _DesktopPdfBody(filePath: filePath)
          : PDFView(
              filePath: filePath,
              enableSwipe: true,
              swipeHorizontal: true,
              autoSpacing: true,
              pageFling: true,
              onError: (error) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        context.l10n.errorLoadingPdf(error.toString()),
                      ),
                    ),
                  );
                }
              },
              onPageError: (page, error) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        context.l10n.errorOnPage(
                          page.toString(),
                          error.toString(),
                        ),
                      ),
                    ),
                  );
                }
              },
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
      document: pdfx.PdfDocument.openFile(widget.filePath),
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
