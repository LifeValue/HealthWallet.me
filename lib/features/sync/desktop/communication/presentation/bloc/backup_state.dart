part of 'backup_bloc.dart';

enum BackupConnectionStatus { disconnected, discovering, connected }

enum ConnectionTransport { tcp, multipeerConnectivity, unknown }

@freezed
class BackupState with _$BackupState {
  const factory BackupState({
    @Default(BackupConnectionStatus.disconnected)
    BackupConnectionStatus connectionStatus,
    @Default(ConnectionTransport.unknown)
    ConnectionTransport connectionTransport,
    DevicePairing? pairedDevice,
    String? connectedIp,
    int? connectedPort,
    String? error,
  }) = _BackupState;

  factory BackupState.initial() => const BackupState();
}
