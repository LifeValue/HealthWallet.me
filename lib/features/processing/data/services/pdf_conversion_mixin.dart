import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:health_wallet/core/utils/logger.dart';
import 'package:health_wallet/features/processing/domain/services/text_recognition_service.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';

mixin PdfConversionMixin implements TextRecognitionService {
  @override
  Future<List<String>> convertPdfToImages(String pdfPath) async {
    try {
      final List<String> imagePaths = [];
      final tempDir = await getTemporaryDirectory();
      final bytes = await File(pdfPath).readAsBytes();
      int index = 1;
      const double dpi = 200;
      await for (final page in Printing.raster(bytes, dpi: dpi)) {
        try {
          final pngBytes = await page.toPng();
          final decoded = img.decodePng(pngBytes);
          if (decoded == null) {
            throw Exception('Failed to decode PNG for page $index');
          }

          var whiteBg = img.Image(width: decoded.width, height: decoded.height);
          img.fill(whiteBg, color: img.ColorRgba8(255, 255, 255, 255));
          img.compositeImage(whiteBg, decoded);
          final pngOut = img.encodePng(whiteBg, level: 6);

          final tempFile = File(
            '${tempDir.path}/pdf_page_${DateTime.now().millisecondsSinceEpoch}_$index.png',
          );
          await tempFile.writeAsBytes(pngOut);
          imagePaths.add(tempFile.path);
        } catch (_) {}
        index++;
      }
      return imagePaths;
    } catch (_) {
      return [];
    }
  }

  Future<Directory> getCacheDirectory() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final pdfCacheDir =
        Directory(path.join(docsDir.path, 'pdf_preview_cache'));
    if (!await pdfCacheDir.exists()) {
      await pdfCacheDir.create(recursive: true);
    }
    return pdfCacheDir;
  }

  String generateCacheKey(
      String pdfPath, int fileSize, DateTime modified, double dpi) {
    final keyString =
        '$pdfPath|$fileSize|${modified.millisecondsSinceEpoch}|$dpi';
    final bytes = utf8.encode(keyString);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<List<String>?> getCachedImages(String cacheKey) async {
    try {
      final cacheDir = await getCacheDirectory();
      final cacheMetadataFile =
          File(path.join(cacheDir.path, '$cacheKey.json'));

      if (!await cacheMetadataFile.exists()) {
        return null;
      }

      final metadataJson = await cacheMetadataFile.readAsString();
      final metadata = jsonDecode(metadataJson) as Map<String, dynamic>;
      final cachedImagePaths =
          (metadata['imagePaths'] as List).map((p) => p as String).toList();

      bool allExist = true;
      for (final imagePath in cachedImagePaths) {
        if (!await File(imagePath).exists()) {
          allExist = false;
          break;
        }
      }

      if (allExist && cachedImagePaths.isNotEmpty) {
        return cachedImagePaths;
      } else {
        await cacheMetadataFile.delete();
        for (final imagePath in cachedImagePaths) {
          try {
            await File(imagePath).delete();
          } catch (_) {}
        }
        return null;
      }
    } catch (_) {
      return null;
    }
  }

  Future<void> saveToCache(String cacheKey, List<String> imagePaths) async {
    try {
      final cacheDir = await getCacheDirectory();
      final cacheMetadataFile =
          File(path.join(cacheDir.path, '$cacheKey.json'));

      final metadata = {
        'imagePaths': imagePaths,
        'cachedAt': DateTime.now().toIso8601String(),
      };

      await cacheMetadataFile.writeAsString(jsonEncode(metadata));
    } catch (_) {}
  }

  @override
  Future<List<String>> convertPdfToImagesForPreview(
    String pdfPath, {
    double dpi = 72,
  }) async {
    try {
      final file = File(pdfPath);
      if (!await file.exists()) return [];

      final fileStat = await file.stat();
      final cacheKey =
          generateCacheKey(pdfPath, fileStat.size, fileStat.modified, dpi);

      final cachedImages = await getCachedImages(cacheKey);
      if (cachedImages != null) return cachedImages;

      final List<String> imagePaths = [];
      final cacheDir = await getCacheDirectory();
      final bytes = await file.readAsBytes();

      int index = 1;
      await for (final page in Printing.raster(bytes, dpi: dpi)) {
        try {
          final pngBytes = await page.toPng();
          final decoded = img.decodePng(pngBytes);
          if (decoded == null) {
            index++;
            continue;
          }

          final whiteBg =
              img.Image(width: decoded.width, height: decoded.height);
          img.fill(whiteBg, color: img.ColorRgba8(255, 255, 255, 255));
          img.compositeImage(whiteBg, decoded);
          final jpegBytes = img.encodeJpg(whiteBg, quality: 75);

          final cachedImageFile = File(
            path.join(cacheDir.path, '${cacheKey}_page_$index.jpg'),
          );
          await cachedImageFile.writeAsBytes(jpegBytes);
          imagePaths.add(cachedImageFile.path);
        } catch (e, stackTrace) {
          logger.e(
              'convertPdfToImagesForPreview - Error processing page $index: $e',
              e,
              stackTrace);
        }
        index++;
      }

      if (imagePaths.isNotEmpty) {
        await saveToCache(cacheKey, imagePaths);
      }

      return imagePaths;
    } catch (e, stackTrace) {
      logger.e('convertPdfToImagesForPreview - Conversion failed: $e', e,
          stackTrace);
      return [];
    }
  }

  @override
  bool isPDF(String filePath) {
    return filePath.toLowerCase().endsWith('.pdf');
  }

  @override
  bool isImage(String filePath) {
    final imageExtensions = [
      '.jpg',
      '.jpeg',
      '.png',
      '.gif',
      '.bmp',
      '.webp',
      '.tiff'
    ];
    final lowerPath = filePath.toLowerCase();
    return imageExtensions.any((ext) => lowerPath.endsWith(ext));
  }

  @override
  Future<String> extractTextFromFile(String filePath) async {
    if (isPDF(filePath)) {
      return await extractTextFromPDF(filePath);
    } else if (isImage(filePath)) {
      return await recognizeTextFromImage(filePath);
    } else {
      return 'Unsupported file type. Please select a PDF or image file.';
    }
  }
}
