import 'dart:io';

import 'package:flutter/services.dart';
import 'package:injectable/injectable.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:health_wallet/features/desktop/communication/presentation/bloc/communication_bloc.dart';

@lazySingleton
class TrayService with TrayListener {
  Function()? onShowWindowRequested;
  Function()? onHideWindowRequested;
  Function()? onQuitRequested;

  bool _isWindowVisible = true;
  bool _initialized = false;

  static const _menuKeyToggleWindow = 'toggle_window';
  static const _menuKeyQuit = 'quit';

  Future<void> init() async {
    if (_initialized) {
      await trayManager.destroy();
    }

    final iconPath = Platform.isMacOS
        ? 'assets/icons/tray_icon.png'
        : 'assets/icons/tray_icon.png';

    await trayManager.setIcon(iconPath);
    await trayManager.setToolTip('HealthWallet.me');
    trayManager.addListener(this);
    _initialized = true;

    await _rebuildMenu();
  }

  Future<void> updateMenu({
    ConnectionStatus connectionStatus = ConnectionStatus.disconnected,
    String? deviceName,
    String syncLabel = 'Idle',
  }) async {
    if (!_initialized) return;
    await _rebuildMenu(
      connectionStatus: connectionStatus,
      deviceName: deviceName,
      syncLabel: syncLabel,
    );
  }

  Future<void> _rebuildMenu({
    ConnectionStatus connectionStatus = ConnectionStatus.disconnected,
    String? deviceName,
    String syncLabel = 'Idle',
  }) async {
    final toggleLabel =
        _isWindowVisible ? 'Hide Window' : 'Show Window';

    final connectionLabel = switch (connectionStatus) {
      ConnectionStatus.connected =>
        'Connected to "${deviceName ?? "Device"}"',
      ConnectionStatus.discovering => 'Discovering...',
      ConnectionStatus.disconnected => 'No device connected',
    };

    final menu = Menu(
      items: [
        MenuItem(label: 'HealthWallet.me', disabled: true),
        MenuItem.separator(),
        MenuItem(label: toggleLabel, key: _menuKeyToggleWindow),
        MenuItem.separator(),
        MenuItem(label: connectionLabel, disabled: true),
        MenuItem(label: 'Sync: $syncLabel', disabled: true),
        MenuItem.separator(),
        MenuItem(label: 'Quit HealthWallet.me', key: _menuKeyQuit),
      ],
    );

    await trayManager.setContextMenu(menu);
  }

  void setWindowVisible(bool visible) {
    _isWindowVisible = visible;
  }

  @override
  void onTrayIconMouseDown() {
    if (_isWindowVisible) {
      onHideWindowRequested?.call();
    } else {
      onShowWindowRequested?.call();
    }
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case _menuKeyToggleWindow:
        if (_isWindowVisible) {
          onHideWindowRequested?.call();
        } else {
          onShowWindowRequested?.call();
        }
      case _menuKeyQuit:
        onQuitRequested?.call();
    }
  }

  Future<void> dispose() async {
    trayManager.removeListener(this);
    await trayManager.destroy();
    _initialized = false;
  }
}
