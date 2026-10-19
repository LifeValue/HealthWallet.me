import 'dart:io';

import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';
import 'package:health_wallet/core/config/constants/shared_prefs_constants.dart';

@lazySingleton
class WindowLifecycleService with WindowListener {
  Function(bool isVisible)? onWindowVisibilityChanged;

  bool _minimizeToTrayEnabled = true;
  bool _isVisible = true;

  bool get isMinimizeToTrayEnabled => _minimizeToTrayEnabled;
  bool get isVisible => _isVisible;

  Future<void> init() async {
    await windowManager.ensureInitialized();
    await windowManager.setPreventClose(true);
    windowManager.addListener(this);

    final prefs = await SharedPreferences.getInstance();
    _minimizeToTrayEnabled =
        prefs.getBool(SharedPrefsConstants.minimizeToTray) ?? true;
  }

  Future<void> setMinimizeToTray(bool enabled) async {
    _minimizeToTrayEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(SharedPrefsConstants.minimizeToTray, enabled);
  }

  Future<void> showWindow() async {
    await windowManager.show();
    await windowManager.focus();
    _isVisible = true;
    onWindowVisibilityChanged?.call(true);
  }

  Future<void> hideWindow() async {
    await windowManager.hide();
    _isVisible = false;
    onWindowVisibilityChanged?.call(false);
  }

  Future<void> quitApp() async {
    await windowManager.setPreventClose(false);
    await windowManager.close();
    exit(0);
  }

  @override
  void onWindowClose() {
    if (_minimizeToTrayEnabled) {
      hideWindow();
    } else {
      quitApp();
    }
  }

  @override
  void onWindowFocus() {
    if (!_isVisible) {
      _isVisible = true;
      onWindowVisibilityChanged?.call(true);
    }
  }

  void dispose() {
    windowManager.removeListener(this);
  }
}
