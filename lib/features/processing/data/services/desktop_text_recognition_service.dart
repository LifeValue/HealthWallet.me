import 'dart:io';

import 'package:health_wallet/features/processing/data/data_source/platform/macos_ocr_channel.dart';
import 'package:health_wallet/features/processing/data/services/pdf_conversion_mixin.dart';
import 'package:health_wallet/features/processing/domain/services/text_recognition_service.dart';
import 'package:path_provider/path_provider.dart';

class DesktopTextRecognitionService
    with PdfConversionMixin
    implements TextRecognitionService {
  final MacOsOcrChannel? _macOsOcr =
      Platform.isMacOS ? MacOsOcrChannel() : null;

  @override
  Future<String> recognizeTextFromImage(String imagePath) async {
    if (_macOsOcr != null) {
      return _macOsOcr.recognizeText(imagePath);
    }
    return '';
  }

  @override
  Future<String> extractTextFromPDF(String pdfPath) async {
    try {
      final imagePaths = await convertPdfToImages(pdfPath);
      final pageTexts = <String>[];
      int index = 1;

      for (final imagePath in imagePaths) {
        final text = await recognizeTextFromImage(imagePath);
        if (text.isNotEmpty) {
          pageTexts.add('--- Page $index ---\n$text\n');
        }
        index++;
      }

      return pageTexts.isNotEmpty ? pageTexts.join('\n') : 'No readable text found.';
    } catch (e) {
      return 'Error processing PDF: ${e.toString()}';
    }
  }

  @override
  Future<List<String>> extractTextFromPDFPages(String pdfPath) async {
    try {
      final imagePaths = await convertPdfToImages(pdfPath);
      final pageTexts = <String>[];

      for (final imagePath in imagePaths) {
        final text = await recognizeTextFromImage(imagePath);
        pageTexts.add(text.isNotEmpty ? text : 'No text found on this page');
      }

      return pageTexts;
    } catch (e) {
      return ['Error processing PDF: ${e.toString()}'];
    }
  }

  @override
  void dispose() {}
}
