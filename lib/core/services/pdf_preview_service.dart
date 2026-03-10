import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
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
    if (!_previewableTypes.contains(resource.fhirType)) {
      _showErrorSnackBar(context, 'This resource is not a PDF file');
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

      final result = await OpenFile.open(filePath);

      if (result.type != ResultType.done) {
        _showWarningSnackBar(context, 'Could not open PDF: ${result.message}');
      }
    } catch (e) {
      _showErrorSnackBar(context, 'Error opening PDF: $e');
    }
  }

  Future<String?> _extractDocumentReferencePath(
      Map<String, dynamic> rawResource) async {
    final contentList = rawResource['content'] as List?;
    if (contentList == null || contentList.isEmpty) return null;
    final attachment = (contentList[0] as Map?)?['attachment'] as Map?;
    final url = attachment?['url'] as String?;
    if (url == null) return null;
    final rawPath = url.startsWith('file://') ? url.substring(7) : url;
    return _pathResolver.toAbsolute(rawPath);
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

  void _showWarningSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.orange,
      ),
    );
  }
}
