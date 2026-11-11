part of 'backup_bloc.dart';

@freezed
abstract class BackupState with _$BackupState {
  const factory BackupState({
    @Default([]) List<BackupEntry> backupHistory,
    @Default(false) bool isBackingUp,
    @Default(false) bool isRestoring,
    @Default(0.0) double progress,
    BackupEntry? selectedBackup,
    String? backupPath,
    @Default(false) bool hasUserSelectedPath,

    /// Phone: whether the desktop has a backup folder, as it last reported;
    /// null until it reports on this connection.
    bool? desktopBackupReady,
    @Default(0) int desktopBackupCount,
    DateTime? desktopLastBackupTime,
    String? error,

    /// Desktop: what the user should know about the restore that just
    /// finished, such as files that couldn't be restored; null when there
    /// is nothing to add.
    String? restoreNotice,

    /// Desktop: the scans on this computer not saved yet (every processing
    /// session: a saved one is deleted), which a restore removes. Counted
    /// when a backup is selected and after a restore.
    @Default(0) int unsavedScanCount,

    /// Desktop: how many whole days "Before restore" copies are kept, as set
    /// on this computer. Read with the history.
    @Default(SafetyCopyRetention.defaultDays) int safetyCopyRetentionDays,
  }) = _BackupState;

  factory BackupState.initial() => const BackupState();
}
