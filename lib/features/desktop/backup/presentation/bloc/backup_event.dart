part of 'backup_bloc.dart';

@freezed
sealed class BackupEvent with _$BackupEvent {
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

  /// Phone: ask the desktop for a backup, once this phone's changes reached
  /// it.
  const factory BackupEvent.phoneBackupRequested() = PhoneBackupRequested;
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
