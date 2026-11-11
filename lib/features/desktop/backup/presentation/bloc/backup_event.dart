part of 'backup_bloc.dart';

@freezed
sealed class BackupEvent with _$BackupEvent {
  /// [fromPhone]: the paired phone asked for it, so it is told when the
  /// backup fails.
  const factory BackupEvent.backupRequested({
    String? name,
    @Default(false) bool fromPhone,
  }) = BackupRequested;
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

  /// Desktop: the user set how many whole days "Before restore" copies are
  /// kept. Saving it makes `SafetyCopyExpiryScheduler` delete the copies
  /// older than that at once.
  const factory BackupEvent.safetyCopyRetentionChanged(int days) =
      SafetyCopyRetentionChanged;

  /// Desktop: `SafetyCopyExpiryScheduler` deleted expired safety copies, so
  /// the list is read again.
  const factory BackupEvent.safetyCopiesExpired() = SafetyCopiesExpired;
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

  /// Phone: the link to the desktop dropped.
  const factory BackupEvent.remoteLinkLost() = RemoteLinkLost;
}
