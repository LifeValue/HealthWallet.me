import 'dart:io';

import 'package:health_wallet/core/utils/logger.dart';

import 'package:health_wallet/features/processing/domain/services/text_recognition_service.dart';
import 'package:injectable/injectable.dart';

@injectable
class OcrProcessingHelper {
  final TextRecognitionService _textRecognitionService;

  OcrProcessingHelper(this._textRecognitionService);

  /// The resolution PDF pages are rendered at for OCR. At the 72 dpi of the
  /// previews, small print loses characters (a "D" read as "0", digits
  /// dropped from dates).
  static const pdfDpi = 200.0;

  Future<String> processOcrForImages(List<String> imagePaths) async {
    final pageTexts = <String>[];

    for (int i = 0; i < imagePaths.length; i++) {
      final imagePath = imagePaths[i];
      final imageFile = File(imagePath);
      if (!await imageFile.exists()) {
        continue;
      }

      final text = await _textRecognitionService.recognizeTextFromImage(
        imagePath,
      );

      if (text.isNotEmpty) {
        pageTexts.add(text);
      }
    }

    return pageTexts.join('\n');
  }

  Future<List<String>> prepareAllImages({
    required List<String> filePaths,
  }) async {
    final allImages = <String>[];

    for (int i = 0; i < filePaths.length; i++) {
      final path = filePaths[i];

      if (_textRecognitionService.isImage(path)) {
        allImages.add(path);
      } else {
        try {
          final convertedImages = await _textRecognitionService
              .convertPdfToImagesForPreview(path, dpi: pdfDpi);
          allImages.addAll(convertedImages);
        } catch (e, stackTrace) {
          logger.e(
            'prepareAllImages - Error converting PDF: $e',
            e,
            stackTrace,
          );
        }
      }
    }

    return allImages;
  }
}
