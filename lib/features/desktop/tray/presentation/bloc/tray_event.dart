part of 'tray_bloc.dart';

@freezed
class TrayEvent with _$TrayEvent {
  const factory TrayEvent.initialised() = TrayInitialised;
  const factory TrayEvent.minimizeToTrayToggled({
    required bool enabled,
  }) = TrayMinimizeToTrayToggled;
  const factory TrayEvent.windowVisibilityChanged({
    required bool isVisible,
  }) = TrayWindowVisibilityChanged;
  const factory TrayEvent.connectionStatusChanged({
    required ConnectionStatus connectionStatus,
    String? deviceName,
  }) = TrayConnectionStatusChanged;
  const factory TrayEvent.syncStatusChanged({
    required LwwSyncStatus syncStatus,
  }) = TraySyncStatusChanged;
  const factory TrayEvent.quitRequested() = TrayQuitRequested;
}
