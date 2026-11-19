import 'dart:io';

import 'package:health_wallet/core/config/constants/shared_prefs_constants.dart';
import 'package:health_wallet/core/utils/logger.dart';
import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

@lazySingleton
class WindowLifecycleService with WindowListener {
  Function(bool isVisible)? onWindowVisibilityChanged;

  /// Runs before the app exits, e.g. to let a sync batch finish and tell the
  /// phone. Bounded, so a stuck step can't keep the app from quitting.
  Future<void> Function()? beforeQuit;

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

  Future<void> runBeforeQuit() async {
    final hook = beforeQuit;
    if (hook == null) return;
    try {
      await hook().timeout(const Duration(seconds: 5));
    } catch (e) {
      logger.w('[Window] quitting without finishing the shutdown steps', e);
    }
  }

  Future<void> quitApp() async {
    await runBeforeQuit();
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
