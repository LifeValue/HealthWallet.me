import 'package:flutter/services.dart';

class ScreenSecurityService {
  static const _channel = MethodChannel('app.screen_security');

  static Future<void> enable() async {
    try {
      await _channel.invokeMethod('enable');
    } catch (_) {}
  }

  static Future<void> disable() async {
    try {
      await _channel.invokeMethod('disable');
    } catch (_) {}
  }
}
