import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:health_wallet/features/processing/data/services/pdf_conversion_mixin.dart';
import 'package:health_wallet/features/processing/domain/services/text_recognition_service.dart';
import 'package:path_provider/path_provider.dart';

class MobileTextRecognitionService
    with PdfConversionMixin
    implements TextRecognitionService {
  final TextRecognizer _textRecognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );

  @override
  Future<String> recognizeTextFromImage(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final RecognizedText recognizedText =
          await _textRecognizer.processImage(inputImage);
      return recognizedText.text;
    } catch (e) {
      return 'Error recognizing text: ${e.toString()}';
    }
  }

  @override
  Future<String> extractTextFromPDF(String pdfPath) async {
    try {
      String allText = '';
      final textRecognizer = TextRecognizer();
      final tempDir = await getTemporaryDirectory();
      int index = 1;
      final imagePaths = await convertPdfToImages(pdfPath);
      for (final imagePath in imagePaths) {
        try {
          final inputImage = InputImage.fromFilePath(imagePath);
          final recognizedText =
              await textRecognizer.processImage(inputImage);
          if (recognizedText.text.isNotEmpty) {
            allText += '--- Page $index ---\n';
            allText += recognizedText.text;
            allText += '\n\n';
          }
        } catch (e) {
          allText += '--- Page $index (Error) ---\n';
          allText += 'Error processing this page: $e\n\n';
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

  @override
  Future<List<String>> extractTextFromPDFPages(String pdfPath) async {
    try {
      final List<String> pageTexts = [];
      final textRecognizer = TextRecognizer();
      final imagePaths = await convertPdfToImages(pdfPath);
      for (final imagePath in imagePaths) {
        try {
          final inputImage = InputImage.fromFilePath(imagePath);
          final recognizedText =
              await textRecognizer.processImage(inputImage);
          pageTexts.add(
            recognizedText.text.isNotEmpty
                ? recognizedText.text
                : 'No text found on this page',
          );
        } catch (e) {
          pageTexts.add('Error processing this page: $e');
        }
      }
      await textRecognizer.close();
      return pageTexts;
    } catch (e) {
      return ['Error processing PDF: ${e.toString()}'];
    }
  }

  @override
  void dispose() {
    _textRecognizer.close();
  }
}
