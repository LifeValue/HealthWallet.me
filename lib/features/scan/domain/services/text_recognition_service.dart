import 'dart:io';
import 'dart:convert';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:injectable/injectable.dart';
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:image/image.dart' as img;
import 'package:health_wallet/core/utils/logger.dart';
import 'package:crypto/crypto.dart';

@injectable
class TextRecognitionService {
  final TextRecognizer _textRecognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );

  Future<String> recognizeTextFromImage(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final RecognizedText recognizedText = await _textRecognizer.processImage(
        inputImage,
      );
      return recognizedText.text;
    } catch (e) {
      return 'Error recognizing text: ${e.toString()}';
    }
  }

  Future<String> recognizeTextFromXFile(XFile image) async {
    try {
      final inputImage = InputImage.fromFilePath(image.path);
      final RecognizedText recognizedText = await _textRecognizer.processImage(
        inputImage,
      );
      return recognizedText.text;
    } catch (e) {
      return 'Error recognizing text: ${e.toString()}';
    }
  }

  Future<List<String>> convertPdfToImages(String pdfPath) async {
    try {
      final List<String> imagePaths = [];
      final tempDir = await getTemporaryDirectory();
      final bytes = await File(pdfPath).readAsBytes();
      int index = 1;
      const double dpi = 200; // higher DPI for better OCR fidelity
      await for (final page in Printing.raster(bytes, dpi: dpi)) {
        try {
          final pngBytes = await page.toPng();
          final decoded = img.decodePng(pngBytes);
          if (decoded == null) {
            throw Exception('Failed to decode PNG for page $index');
          }

          // Flatten any transparency onto a white background and save as PNG
          var whiteBg = img.Image(width: decoded.width, height: decoded.height);
          img.fill(whiteBg, color: img.ColorRgba8(255, 255, 255, 255));
          img.compositeImage(whiteBg, decoded);
          final pngOut = img.encodePng(whiteBg, level: 6);

          final tempFile = File(
            '${tempDir.path}/pdf_page_${DateTime.now().millisecondsSinceEpoch}_$index.png',
          );
          await tempFile.writeAsBytes(pngOut);
          imagePaths.add(tempFile.path);
        } catch (e) {
          // ignore per-page rasterization errors
        }
        index++;
      }
      return imagePaths;
    } catch (e) {
      return [];
    }
  }

  Future<Directory> _getCacheDirectory() async {
    final cacheDir = await getTemporaryDirectory();
    final pdfCacheDir = Directory(path.join(cacheDir.path, 'pdf_preview_cache'));
    if (!await pdfCacheDir.exists()) {
      await pdfCacheDir.create(recursive: true);
    }
    return pdfCacheDir;
  }

  String _generateCacheKey(String pdfPath, int fileSize, DateTime modified, double dpi) {
    final keyString = '$pdfPath|$fileSize|${modified.millisecondsSinceEpoch}|$dpi';
    final bytes = utf8.encode(keyString);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<List<String>?> _getCachedImages(String cacheKey) async {
    try {
      final cacheDir = await _getCacheDirectory();
      final cacheMetadataFile = File(path.join(cacheDir.path, '$cacheKey.json'));
      
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
        final imageFile = File(imagePath);
        if (!await imageFile.exists()) {
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
          } catch (e) {
            // ignore
          }
        }
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  Future<void> _saveToCache(String cacheKey, List<String> imagePaths) async {
    try {
      final cacheDir = await _getCacheDirectory();
      final cacheMetadataFile = File(path.join(cacheDir.path, '$cacheKey.json'));
      
      final metadata = {
        'imagePaths': imagePaths,
        'cachedAt': DateTime.now().toIso8601String(),
      };
      
      await cacheMetadataFile.writeAsString(jsonEncode(metadata));
    } catch (e) {
      // ignore
    }
  }

  Future<List<String>> convertPdfToImagesForPreview(
    String pdfPath, {
    double dpi = 72,
  }) async {
    logger.d('convertPdfToImagesForPreview - START: $pdfPath (dpi=$dpi)');
    try {
      final file = File(pdfPath);
      final exists = await file.exists();
      logger.d('convertPdfToImagesForPreview - File exists: $exists');
      
      if (!exists) {
        logger.d('convertPdfToImagesForPreview - File not found, returning empty');
        return [];
      }

      logger.d('convertPdfToImagesForPreview - Getting file stats...');
      final fileStat = await file.stat();
      final fileSize = fileStat.size;
      final modified = fileStat.modified;
      logger.d('convertPdfToImagesForPreview - File size: $fileSize bytes, modified: $modified');
      
      final cacheKey = _generateCacheKey(pdfPath, fileSize, modified, dpi);
      logger.d('convertPdfToImagesForPreview - Cache key: $cacheKey');
      
      logger.d('convertPdfToImagesForPreview - Checking cache...');
      final cachedImages = await _getCachedImages(cacheKey);
      if (cachedImages != null) {
        logger.d('convertPdfToImagesForPreview - Cache hit! ${cachedImages.length} images');
        return cachedImages;
      }
      logger.d('convertPdfToImagesForPreview - Cache miss, converting PDF...');
      
      final List<String> imagePaths = [];
      final cacheDir = await _getCacheDirectory();
      logger.d('convertPdfToImagesForPreview - Cache dir: ${cacheDir.path}');
      
      logger.d('convertPdfToImagesForPreview - Reading PDF bytes...');
      final bytes = await file.readAsBytes();
      logger.d('convertPdfToImagesForPreview - PDF bytes read: ${bytes.length}');
      
      int index = 1;
      int totalPages = 0;
      
      logger.d('convertPdfToImagesForPreview - Starting rasterization...');
      await for (final page in Printing.raster(bytes, dpi: dpi)) {
        totalPages++;
        logger.d('convertPdfToImagesForPreview - Processing page $index...');
        try {
          logger.d('convertPdfToImagesForPreview - Converting page $index to PNG...');
          final pngBytes = await page.toPng();
          logger.d('convertPdfToImagesForPreview - Page $index PNG: ${pngBytes.length} bytes');
          
          logger.d('convertPdfToImagesForPreview - Decoding PNG for page $index...');
          final decoded = img.decodePng(pngBytes);
          
          if (decoded == null) {
            logger.d('convertPdfToImagesForPreview - Failed to decode page $index');
            index++;
            continue;
          }
          logger.d('convertPdfToImagesForPreview - Page $index decoded: ${decoded.width}x${decoded.height}');
          
          logger.d('convertPdfToImagesForPreview - Creating white background for page $index...');
          final whiteBg = img.Image(width: decoded.width, height: decoded.height);
          img.fill(whiteBg, color: img.ColorRgba8(255, 255, 255, 255));
          img.compositeImage(whiteBg, decoded);
          
          logger.d('convertPdfToImagesForPreview - Encoding JPEG for page $index...');
          final jpegBytes = img.encodeJpg(whiteBg, quality: 75);
          logger.d('convertPdfToImagesForPreview - Page $index JPEG: ${jpegBytes.length} bytes');
          
          final cachedImageFile = File(
            path.join(cacheDir.path, '${cacheKey}_page_$index.jpg'),
          );
          logger.d('convertPdfToImagesForPreview - Saving page $index to: ${cachedImageFile.path}');
          await cachedImageFile.writeAsBytes(jpegBytes);
          
          imagePaths.add(cachedImageFile.path);
          logger.d('convertPdfToImagesForPreview - Page $index saved successfully');
        } catch (e, stackTrace) {
          logger.e('convertPdfToImagesForPreview - Error processing page $index: $e', e, stackTrace);
        }
        index++;
      }
      
      logger.d('convertPdfToImagesForPreview - Total pages processed: $totalPages, images created: ${imagePaths.length}');
      
      if (imagePaths.isNotEmpty) {
        logger.d('convertPdfToImagesForPreview - Saving to cache...');
        await _saveToCache(cacheKey, imagePaths);
        logger.d('convertPdfToImagesForPreview - Cache saved');
      }
      
      logger.d('convertPdfToImagesForPreview - COMPLETE: ${imagePaths.length} images');
      return imagePaths;
    } catch (e, stackTrace) {
      logger.e('convertPdfToImagesForPreview - Conversion failed: $e', e, stackTrace);
      return [];
    }
  }

  Future<String> extractTextFromPDF(String pdfPath) async {
    try {
      String allText = '';
      final textRecognizer = TextRecognizer();
      final tempDir = await getTemporaryDirectory();
      int index = 1;
      final bytes = await File(pdfPath).readAsBytes();
      await for (final page in Printing.raster(bytes, dpi: 144)) {
        File? tempFile;
        try {
          final png = await page.toPng();
          tempFile = File('${tempDir.path}/pdf_page_$index.png');
          await tempFile.writeAsBytes(png);
          final inputImage = InputImage.fromFilePath(tempFile.path);
          final recognizedText = await textRecognizer.processImage(inputImage);
          if (recognizedText.text.isNotEmpty) {
            allText += '--- Page $index ---\n';
            allText += recognizedText.text;
            allText += '\n\n';
          }
        } catch (e) {
          allText += '--- Page $index (Error) ---\n';
          allText += 'Error processing this page: $e\n\n';
        } finally {
          if (tempFile != null && await tempFile.exists()) {
            await tempFile.delete();
          }
        }
        index++;
      }
      await textRecognizer.close();

      if (allText.isNotEmpty) {
        return allText;
      } else {
        return 'No readable text found.';
      }
    } catch (e) {
      return 'Error processing PDF: ${e.toString()}';
    }
  }

  Future<List<String>> extractTextFromPDFPages(String pdfPath) async {
    try {
      final List<String> pageTexts = [];
      final textRecognizer = TextRecognizer();
      final tempDir = await getTemporaryDirectory();
      int index = 1;
      final bytes = await File(pdfPath).readAsBytes();
      await for (final page in Printing.raster(bytes, dpi: 144)) {
        File? tempFile;
        try {
          final png = await page.toPng();
          tempFile = File('${tempDir.path}/pdf_page_$index.png');
          await tempFile.writeAsBytes(png);
          final inputImage = InputImage.fromFilePath(tempFile.path);
          final recognizedText = await textRecognizer.processImage(inputImage);
          pageTexts.add(
            recognizedText.text.isNotEmpty
                ? recognizedText.text
                : 'No text found on this page',
          );
        } catch (e) {
          pageTexts.add('Error processing this page: $e');
        } finally {
          if (tempFile != null && await tempFile.exists()) {
            await tempFile.delete();
          }
        }
        index++;
      }
      await textRecognizer.close();
      return pageTexts;
    } catch (e) {
      return ['Error processing PDF: ${e.toString()}'];
    }
  }

  bool isPDF(String filePath) {
    return filePath.toLowerCase().endsWith('.pdf');
  }

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

  Future<String> extractTextFromFile(String filePath) async {
    if (isPDF(filePath)) {
      return await extractTextFromPDF(filePath);
    } else if (isImage(filePath)) {
      return await recognizeTextFromImage(filePath);
    } else {
      return 'Unsupported file type. Please select a PDF or image file.';
    }
  }

  void dispose() {
    _textRecognizer.close();
  }
}
