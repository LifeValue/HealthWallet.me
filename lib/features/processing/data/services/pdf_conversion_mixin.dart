import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:health_wallet/core/services/temp_file_sweeper.dart';
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

          final whiteBg = img.Image(
            width: decoded.width,
            height: decoded.height,
          );
          img.fill(whiteBg, color: img.ColorRgba8(255, 255, 255, 255));
          img.compositeImage(whiteBg, decoded);
          final pngOut = img.encodePng(whiteBg, level: 6);

          final tempFile = File(
            '${tempDir.path}/${TempFileSweeper.ocrPagePrefix}${DateTime.now().millisecondsSinceEpoch}_$index.png',
          );
          await tempFile.writeAsBytes(pngOut);
          imagePaths.add(tempFile.path);
        } catch (e) {
          logger.w('Could not convert PDF page $index; skipping it', e);
        }
        index++;
      }
      return imagePaths;
    } catch (_) {
      return [];
    }
  }

  Future<Directory> getCacheDirectory() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final pdfCacheDir = Directory(path.join(docsDir.path, 'pdf_preview_cache'));
    if (!await pdfCacheDir.exists()) {
      await pdfCacheDir.create(recursive: true);
    }
    return pdfCacheDir;
  }

  String generateCacheKey(
    String pdfPath,
    int fileSize,
    DateTime modified,
    double dpi,
  ) => TempFileSweeper.pdfPageCacheKey(pdfPath, fileSize, modified, dpi);

  Future<List<String>?> getCachedImages(String cacheKey) async {
    try {
      final cacheDir = await getCacheDirectory();
      final cacheMetadataFile = File(
        path.join(cacheDir.path, '$cacheKey.json'),
      );

      if (!await cacheMetadataFile.exists()) {
        return null;
      }

      final metadataJson = await cacheMetadataFile.readAsString();
      final metadata = jsonDecode(metadataJson) as Map<String, dynamic>;
      final cachedImagePaths = (metadata['imagePaths'] as List)
          .map((p) => p as String)
          .toList();

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
          } catch (_) {
            // Best-effort cleanup; a leftover cached page is harmless.
          }
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
      final cacheMetadataFile = File(
        path.join(cacheDir.path, '$cacheKey.json'),
      );

      final metadata = {
        'imagePaths': imagePaths,
        'cachedAt': DateTime.now().toIso8601String(),
      };

      await cacheMetadataFile.writeAsString(jsonEncode(metadata));
    } catch (_) {
      // The cache only saves time; without it the PDF is converted again.
    }
  }

  /// The pages of [pdfPath] as JPEGs in the page cache, rendered at [dpi]:
  /// 72 for the preview, `OcrProcessingHelper.ocrDpi` for OCR and the AI.
  /// Rendering stays on this isolate (it goes through the platform), the
  /// decode, white background and JPEG encode run in another one.
  @override
  Future<List<String>> convertPdfToImagesForPreview(
    String pdfPath, {
    double dpi = 72,
  }) async {
    try {
      final file = File(pdfPath);
      if (!await file.exists()) return [];

      final fileStat = await file.stat();
      final cacheKey = generateCacheKey(
        pdfPath,
        fileStat.size,
        fileStat.modified,
        dpi,
      );

      final cachedImages = await getCachedImages(cacheKey);
      if (cachedImages != null) return cachedImages;

      final List<String> imagePaths = [];
      final cacheDir = await getCacheDirectory();
      final bytes = await file.readAsBytes();
      // Small print needs a sharper JPEG once the page is big enough to read.
      final quality = dpi > 72 ? 85 : 75;

      int index = 1;
      await for (final page in Printing.raster(bytes, dpi: dpi)) {
        try {
          final pngBytes = await page.toPng();
          final jpegBytes = await _jpegOnWhiteInIsolate(pngBytes, quality);
          if (jpegBytes == null) {
            index++;
            continue;
          }

          final cachedImageFile = File(
            path.join(cacheDir.path, '${cacheKey}_page_$index.jpg'),
          );
          await cachedImageFile.writeAsBytes(jpegBytes);
          imagePaths.add(cachedImageFile.path);
        } catch (e, stackTrace) {
          logger.e(
            'convertPdfToImagesForPreview - Error processing page $index: $e',
            e,
            stackTrace,
          );
        }
        index++;
      }

      if (imagePaths.isNotEmpty) {
        await saveToCache(cacheKey, imagePaths);
      }

      return imagePaths;
    } catch (e, stackTrace) {
      logger.e(
        'convertPdfToImagesForPreview - Conversion failed: $e',
        e,
        stackTrace,
      );
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
      '.tiff',
    ];
    final lowerPath = filePath.toLowerCase();
    return imageExtensions.any(lowerPath.endsWith);
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

/// [png] on a white background as a JPEG, encoded in another isolate: at
/// 200 dpi a page is about 15 MB of pixels, too much for the UI isolate.
/// Null when [png] can't be decoded.
Future<Uint8List?> _jpegOnWhiteInIsolate(Uint8List png, int quality) =>
    Isolate.run(() => jpegOnWhite(png, quality));

/// [png] on a white background, encoded as a JPEG of [quality]; null when
/// [png] can't be decoded.
Uint8List? jpegOnWhite(Uint8List png, int quality) {
  final decoded = img.decodePng(png);
  if (decoded == null) return null;
  final whiteBg = img.Image(width: decoded.width, height: decoded.height);
  img.fill(whiteBg, color: img.ColorRgba8(255, 255, 255, 255));
  img.compositeImage(whiteBg, decoded);
  return img.encodeJpg(whiteBg, quality: quality);
}
