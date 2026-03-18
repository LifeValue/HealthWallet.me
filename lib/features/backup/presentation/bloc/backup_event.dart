part of 'backup_bloc.dart';

@freezed
class BackupEvent with _$BackupEvent {
  const factory BackupEvent.initialised() = BackupInitialised;
  const factory BackupEvent.pairingRequested() = BackupPairingRequested;
  const factory BackupEvent.pairingCompleted({
    required DevicePairing pairing,
  }) = BackupPairingCompleted;
  const factory BackupEvent.connectionRequested() = BackupConnectionRequested;
  const factory BackupEvent.connected({
    required String ip,
    required int port,
  }) = BackupConnected;
  const factory BackupEvent.disconnected() = BackupDisconnected;
  const factory BackupEvent.connectionFailed({required String error}) =
      BackupConnectionFailed;
}
