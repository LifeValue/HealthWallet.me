import 'package:health_wallet/core/utils/logger.dart';
import 'package:health_wallet/features/scan/domain/services/text_recognition_service.dart';
import 'package:injectable/injectable.dart';

@injectable
class OcrProcessingHelper {
  final TextRecognitionService _textRecognitionService;

  OcrProcessingHelper(this._textRecognitionService);

  Future<String> processOcrForImages(List<String> imagePaths) async {
    logger.d('processOcrForImages - START: ${imagePaths.length} images');
    final pageTexts = <String>[];

    for (int i = 0; i < imagePaths.length; i++) {
      final imagePath = imagePaths[i];
      logger.d(
          'processOcrForImages - Processing image ${i + 1}/${imagePaths.length}: $imagePath');

      final text =
          await _textRecognitionService.recognizeTextFromImage(imagePath);

      if (text.isNotEmpty && !text.startsWith('Error recognizing text:')) {
        pageTexts.add(text);
        logger.d('processOcrForImages - Text extracted: ${text.length} chars');
      } else {
        logger.d('processOcrForImages - No text or error for image $i');
      }
    }

    logger.d(
        'processOcrForImages - COMPLETE: ${pageTexts.length} pages with text');
    return pageTexts.join('\n');
  }

  Future<List<String>> prepareAllImages({
    required List<String> filePaths,
  }) async {
    logger.d('prepareAllImages - START: ${filePaths.length} files');
    final allImages = <String>[];

    for (int i = 0; i < filePaths.length; i++) {
      final path = filePaths[i];
      logger.d(
          'prepareAllImages - Processing file ${i + 1}/${filePaths.length}: $path');

      if (_textRecognitionService.isImage(path)) {
        logger.d('prepareAllImages - File is image, adding directly');
        allImages.add(path);
      } else {
        logger.d('prepareAllImages - File is PDF, converting to images...');
        try {
          final convertedImages =
              await _textRecognitionService.convertPdfToImagesForPreview(path);
          logger.d(
              'prepareAllImages - PDF converted: ${convertedImages.length} images');
          allImages.addAll(convertedImages);
        } catch (e, stackTrace) {
          logger.e(
              'prepareAllImages - Error converting PDF: $e', e, stackTrace);
        }
      }
    }

    logger.d('prepareAllImages - COMPLETE: ${allImages.length} total images');
    return allImages;
  }
}
