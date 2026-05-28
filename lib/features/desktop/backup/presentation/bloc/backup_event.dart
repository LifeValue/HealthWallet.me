part of 'backup_bloc.dart';

@freezed
class BackupEvent with _$BackupEvent {
  const factory BackupEvent.backupRequested({String? name}) = BackupRequested;
  const factory BackupEvent.restoreRequested({required String backupId}) =
      RestoreRequested;
  const factory BackupEvent.historyLoaded() = BackupHistoryLoaded;
  const factory BackupEvent.backupSelected(BackupEntry? backup) =
      BackupSelected;
  const factory BackupEvent.backupDeleted({required String backupId}) =
      BackupDeleted;
  const factory BackupEvent.backupLocationChanged(String path) =
      BackupLocationChanged;
  const factory BackupEvent.backupLocationReset() = BackupLocationReset;
  const factory BackupEvent.remoteBackupRequested() = RemoteBackupRequested;
  const factory BackupEvent.remoteBackupStatusChanged({
    required bool isBackingUp,
    String? error,
  }) = RemoteBackupStatusChanged;
  const factory BackupEvent.remoteBackupStatusReceived({
    required bool ready,
    required int count,
    DateTime? lastBackupTime,
  }) = RemoteBackupStatusReceived;
}
