import 'package:flutter/services.dart';

class MacOsOcrChannel {
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
