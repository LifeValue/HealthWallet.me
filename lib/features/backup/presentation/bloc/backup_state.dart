part of 'backup_bloc.dart';

enum BackupConnectionStatus { disconnected, discovering, connected }

@freezed
class BackupState with _$BackupState {
  const factory BackupState({
    @Default(BackupConnectionStatus.disconnected)
    BackupConnectionStatus connectionStatus,
    DevicePairing? pairedDevice,
    String? connectedIp,
    int? connectedPort,
    String? error,
  }) = _BackupState;

  factory BackupState.initial() => const BackupState();
}
