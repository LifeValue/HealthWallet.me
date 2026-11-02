import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:health_wallet/core/l10n/app_strings_provider.dart';
import 'package:health_wallet/features/desktop/communication/presentation/bloc/communication_bloc.dart';
import 'package:health_wallet/features/desktop/lww_sync/presentation/bloc/lww_sync_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:tray_manager/tray_manager.dart';

@lazySingleton
class TrayService with TrayListener {
  TrayService(this._strings);

  final AppStringsProvider _strings;

  Function()? onShowWindowRequested;
  Function()? onHideWindowRequested;
  Function()? onQuitRequested;

  bool _isWindowVisible = true;
  bool _initialized = false;
  Timer? _menuDebounce;

  static const _menuKeyToggleWindow = 'toggle_window';
  static const _menuKeyQuit = 'quit';
  static const _appName = 'HealthWallet.me';

  ConnectionStatus _connectionStatus = ConnectionStatus.disconnected;
  String? _deviceName;
  LwwSyncStatus _syncStatus = LwwSyncStatus.idle;

  Future<void> init() async {
    if (_initialized) {
      await trayManager.destroy();
    }

    // Windows loads tray icons with LoadImage(IMAGE_ICON), which needs an
    // .ico; a .png leaves the tray empty.
    final iconPath = Platform.isWindows
        ? 'assets/icons/tray_icon.ico'
        : 'assets/icons/tray_icon.png';

    await trayManager.setIcon(iconPath);
    await trayManager.setToolTip(_appName);
    trayManager.addListener(this);
    // init() runs again to recreate the tray; keep a single listener.
    _strings
      ..removeListener(_onLanguageChanged)
      ..addListener(_onLanguageChanged);
    _initialized = true;

    await _rebuildMenu();
  }

  Future<void> updateMenu({
    ConnectionStatus connectionStatus = ConnectionStatus.disconnected,
    String? deviceName,
    LwwSyncStatus syncStatus = LwwSyncStatus.idle,
  }) async {
    _connectionStatus = connectionStatus;
    _deviceName = deviceName;
    _syncStatus = syncStatus;
    _scheduleRebuild();
  }

  void _onLanguageChanged() => _scheduleRebuild();

  void _scheduleRebuild() {
    if (!_initialized) return;
    _menuDebounce?.cancel();
    _menuDebounce = Timer(const Duration(milliseconds: 100), _rebuildMenu);
  }

  Future<void> _rebuildMenu() async {
    await trayManager.setContextMenu(Menu(items: buildMenuItems()));
  }

  /// The tray menu for the current window, connection and sync state, in the
  /// app language.
  @visibleForTesting
  List<MenuItem> buildMenuItems() {
    final l10n = _strings.l10n;
    final toggleLabel = _isWindowVisible
        ? l10n.trayHideWindow
        : l10n.trayShowWindow;

    final connectionLabel = switch (_connectionStatus) {
      ConnectionStatus.connected => l10n.desktopConnectedTo(
        _deviceName ?? l10n.desktopDevice,
      ),
      ConnectionStatus.discovering ||
      ConnectionStatus.awaitingApproval => l10n.desktopDiscovering,
      ConnectionStatus.disconnected => l10n.trayNoDeviceConnected,
    };

    final syncLabel = switch (_syncStatus) {
      LwwSyncStatus.idle => l10n.trayUpToDate,
      LwwSyncStatus.syncing => l10n.desktopSyncing,
      LwwSyncStatus.error => l10n.desktopSyncError,
    };

    return [
      MenuItem(label: _appName, disabled: true),
      MenuItem.separator(),
      MenuItem(label: toggleLabel, key: _menuKeyToggleWindow),
      MenuItem.separator(),
      MenuItem(label: connectionLabel, disabled: true),
      MenuItem(label: l10n.traySyncStatus(syncLabel), disabled: true),
      MenuItem.separator(),
      MenuItem(label: l10n.trayQuit(_appName), key: _menuKeyQuit),
    ];
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
    _menuDebounce?.cancel();
    _strings.removeListener(_onLanguageChanged);
    trayManager.removeListener(this);
    await trayManager.destroy();
    _initialized = false;
  }
}
