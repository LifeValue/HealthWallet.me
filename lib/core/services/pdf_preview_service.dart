import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:pdfx/pdfx.dart' as pdfx;
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/core/services/path_resolver.dart';
import 'package:injectable/injectable.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

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
      Map<String, dynamic> rawResource) async {
    final contentList = rawResource['content'] as List?;
    if (contentList == null || contentList.isEmpty) return null;
    final attachment = (contentList[0] as Map?)?['attachment'] as Map?;
    final url = attachment?['url'] as String?;
    if (url == null) return null;
    final rawPath = url.startsWith('file://') ? url.substring(7) : url;
    final resolved = await _pathResolver.toAbsolute(rawPath);
    return resolved;
  }

  Future<String?> _extractMediaPath(
      Map<String, dynamic> rawResource, String displayTitle) async {
    final content = rawResource['content'];
    if (content == null) return null;

    if (content['url'] != null) return content['url'] as String;

    if (content['data'] != null) {
      return _saveBase64ToTempFile(content['data'] as String, displayTitle);
    }

    return null;
  }

  Future<void> previewPdfFromFile(
    BuildContext context,
    String filePath,
  ) async {
    try {
      final result = await OpenFile.open(filePath);

      if (result.type != ResultType.done) {
        _showWarningSnackBar(context, 'Could not open PDF: ${result.message}');
      }
    } catch (e) {
      _showErrorSnackBar(context, 'Error opening PDF: $e');
    }
  }

  Future<String> _saveBase64ToTempFile(
      String base64Data, String fileName) async {
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
      _showErrorSnackBar(context, 'This resource is not a viewable file');
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

      if (filePath == null) {
        _showErrorSnackBar(context, 'No file path found');
        return;
      }

      if (!await File(filePath).exists()) {
        _showErrorSnackBar(context, 'File not available on this device');
        return;
      }

      if (!context.mounted) return;

      final extension = path.extension(filePath).toLowerCase();
      final isImage = {'.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp'}
          .contains(extension);

      if (isImage) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => _InAppImageViewer(filePath: filePath!),
          ),
        );
      } else {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => _InAppPdfViewer(filePath: filePath!),
          ),
        );
      }
    } catch (e) {
      _showErrorSnackBar(context, 'Error opening file: $e');
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
            errorBuilder: (context, error, stackTrace) => const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.broken_image, color: Colors.white54, size: 64),
                SizedBox(height: 16),
                Text(
                  'Failed to load image',
                  style: TextStyle(color: Colors.white54),
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
                    SnackBar(content: Text('Error loading PDF: $error')),
                  );
                }
              },
              onPageError: (page, error) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error on page $page: $error')),
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
