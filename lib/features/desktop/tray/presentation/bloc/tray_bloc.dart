import 'dart:async';
import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:health_wallet/features/desktop/communication/presentation/bloc/communication_bloc.dart';
import 'package:health_wallet/features/desktop/lww_sync/presentation/bloc/lww_sync_bloc.dart';
import 'package:health_wallet/features/desktop/tray/data/services/tray_service.dart';
import 'package:health_wallet/features/desktop/tray/data/services/window_lifecycle_service.dart';

part 'tray_event.dart';
part 'tray_state.dart';
part 'tray_bloc.freezed.dart';

class TrayBloc extends Bloc<TrayEvent, TrayState> {
  final TrayService _trayService;
  final WindowLifecycleService _windowLifecycleService;

  TrayBloc(
    this._trayService,
    this._windowLifecycleService,
  ) : super(TrayState.initial()) {
    on<TrayInitialised>(_onInitialised);
    on<TrayMinimizeToTrayToggled>(_onMinimizeToTrayToggled);
    on<TrayWindowVisibilityChanged>(_onWindowVisibilityChanged);
    on<TrayConnectionStatusChanged>(_onConnectionStatusChanged);
    on<TraySyncStatusChanged>(_onSyncStatusChanged);
    on<TrayQuitRequested>(_onQuitRequested);
  }

  Future<void> _onInitialised(
    TrayInitialised event,
    Emitter<TrayState> emit,
  ) async {
    _trayService.onShowWindowRequested = () {
      add(const TrayWindowVisibilityChanged(isVisible: true));
    };
    _trayService.onHideWindowRequested = () {
      add(const TrayWindowVisibilityChanged(isVisible: false));
    };
    _trayService.onQuitRequested = () {
      add(const TrayQuitRequested());
    };

    _windowLifecycleService.onWindowVisibilityChanged = (isVisible) {
      add(TrayWindowVisibilityChanged(isVisible: isVisible));
    };

    await _windowLifecycleService.init();
    await _trayService.init();

    emit(state.copyWith(
      isMinimizeToTrayEnabled:
          _windowLifecycleService.isMinimizeToTrayEnabled,
    ));
  }

  Future<void> _onMinimizeToTrayToggled(
    TrayMinimizeToTrayToggled event,
    Emitter<TrayState> emit,
  ) async {
    await _windowLifecycleService.setMinimizeToTray(event.enabled);
    emit(state.copyWith(isMinimizeToTrayEnabled: event.enabled));

    if (!event.enabled && !state.isWindowVisible) {
      await _windowLifecycleService.showWindow();
    }
  }

  Future<void> _onWindowVisibilityChanged(
    TrayWindowVisibilityChanged event,
    Emitter<TrayState> emit,
  ) async {
    if (event.isVisible) {
      await _windowLifecycleService.showWindow();
    } else {
      await _windowLifecycleService.hideWindow();
    }

    _trayService.setWindowVisible(event.isVisible);
    emit(state.copyWith(isWindowVisible: event.isVisible));

    await _trayService.updateMenu(
      connectionStatus: state.connectionStatus,
      deviceName: state.connectedDeviceName,
      syncLabel: _syncLabel(state.syncStatus),
    );
  }

  Future<void> _onConnectionStatusChanged(
    TrayConnectionStatusChanged event,
    Emitter<TrayState> emit,
  ) async {
    emit(state.copyWith(
      connectionStatus: event.connectionStatus,
      connectedDeviceName: event.deviceName,
    ));

    await _trayService.updateMenu(
      connectionStatus: event.connectionStatus,
      deviceName: event.deviceName,
      syncLabel: _syncLabel(state.syncStatus),
    );
  }

  Future<void> _onSyncStatusChanged(
    TraySyncStatusChanged event,
    Emitter<TrayState> emit,
  ) async {
    emit(state.copyWith(syncStatus: event.syncStatus));

    await _trayService.updateMenu(
      connectionStatus: state.connectionStatus,
      deviceName: state.connectedDeviceName,
      syncLabel: _syncLabel(event.syncStatus),
    );
  }

  Future<void> _onQuitRequested(
    TrayQuitRequested event,
    Emitter<TrayState> emit,
  ) async {
    await _trayService.dispose();
    _windowLifecycleService.dispose();
    exit(0);
  }

  String _syncLabel(LwwSyncStatus status) {
    return switch (status) {
      LwwSyncStatus.idle => 'Up to date',
      LwwSyncStatus.syncing => 'Syncing...',
      LwwSyncStatus.error => 'Error',
    };
  }
}
