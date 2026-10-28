import 'package:flutter/services.dart';
import 'package:health_wallet/core/utils/logger.dart';

class ScreenSecurityService {
  static const _channel = MethodChannel('app.screen_security');

  static Future<void> enable() async {
    try {
      await _channel.invokeMethod('enable');
    } catch (e) {
      logger.w('Could not turn on screen capture protection', e);
    }
  }

  static Future<void> disable() async {
    try {
      await _channel.invokeMethod('disable');
    } catch (e) {
      logger.w('Could not turn off screen capture protection', e);
    }
  }
}
