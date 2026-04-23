part of 'tray_bloc.dart';

@freezed
class TrayState with _$TrayState {
  const factory TrayState({
    @Default(true) bool isWindowVisible,
    @Default(true) bool isMinimizeToTrayEnabled,
    @Default(ConnectionStatus.disconnected)
    ConnectionStatus connectionStatus,
    String? connectedDeviceName,
    @Default(LwwSyncStatus.idle) LwwSyncStatus syncStatus,
  }) = _TrayState;

  factory TrayState.initial() => const TrayState();
}
