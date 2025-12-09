import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:injectable/injectable.dart';
import 'package:health_wallet/core/utils/logger.dart';
import 'package:path/path.dart' as path;

@Injectable()
class PdfStorageService {
  /// Save a PDF file to permanent storage and return the new path
  Future<String?> savePdfToStorage({
    required String sourcePdfPath,
    String? customFileName,
  }) async {
    try {
      final hasPermission = await _requestStoragePermission();
      if (!hasPermission) {
        throw Exception('Storage permission denied');
      }

      final sourceFile = File(sourcePdfPath);
      if (!await sourceFile.exists()) {
        throw Exception('Source PDF file not found');
      }

      final fileName = customFileName ??
          'health_document_${DateTime.now().millisecondsSinceEpoch}.pdf';

      final directory = await getApplicationDocumentsDirectory();
      final newPath = '${directory.path}/$fileName';

      await sourceFile.copy(newPath);

      return newPath;
    } catch (e) {
      logger.e('Error saving PDF: $e');
      return null;
    }
  }

  /// Get all saved PDFs
  Future<List<String>> getSavedPdfs() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final allPdfs = <String>[];

      final files = directory.listSync();
      allPdfs.addAll(
        files
            .where((file) => file.path.toLowerCase().endsWith('.pdf'))
            .map((file) => file.path)
            .toList(),
      );

      final sharedDir = Directory(path.join(directory.path, 'shared_files'));
      if (await sharedDir.exists()) {
        final sharedFiles = sharedDir.listSync();
        allPdfs.addAll(
          sharedFiles
              .where((file) => file.path.toLowerCase().endsWith('.pdf'))
              .map((file) => file.path)
              .toList(),
        );
      }

      return allPdfs;
    } catch (e) {
      logger.e('Error getting saved PDFs: $e');
      return [];
    }
  }

  /// Delete a saved PDF
  Future<bool> deletePdf(String pdfPath) async {
    try {
      final file = File(pdfPath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      logger.e('Error deleting PDF: $e');
      return false;
    }
  }

  /// Get PDF file info
  Future<Map<String, dynamic>> getPdfInfo(String pdfPath) async {
    try {
      final file = File(pdfPath);
      if (await file.exists()) {
        final stats = await file.stat();
        return {
          'name': file.path.split('/').last,
          'size': _formatFileSize(stats.size),
          'created': stats.modified,
          'path': pdfPath,
        };
      }
      return {};
    } catch (e) {
      return {};
    }
  }

  /// Check and request storage permission
  Future<bool> _requestStoragePermission() async {
    if (Platform.isAndroid) {
      final status = await Permission.storage.status;
      if (status.isGranted) {
        return true;
      }

      final result = await Permission.storage.request();
      return result.isGranted;
    }

    return true;
  }

  /// Format file size in human-readable format
  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
