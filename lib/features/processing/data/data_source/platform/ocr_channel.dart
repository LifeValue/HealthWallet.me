import 'package:flutter/services.dart';

/// On-device OCR implemented by each runner: Apple Vision on iOS and macOS,
/// ML Kit on Android, Windows.Media.Ocr on Windows.
class OcrChannel {
  static const _channel = MethodChannel('dev.lifevalue.healthwallet/ocr');

  Future<String> recognizeText(String imagePath) async {
    try {
      final result = await _channel.invokeMethod<String>(
        'recognizeText',
        {'imagePath': imagePath},
      );
      return result ?? '';
    } catch (_) {
      return '';
    }
  }
}
