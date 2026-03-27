part of 'backup_bloc.dart';

@freezed
class BackupState with _$BackupState {
  const factory BackupState({
    @Default([]) List<BackupEntry> backupHistory,
    @Default(false) bool isBackingUp,
    @Default(false) bool isRestoring,
    @Default(0.0) double progress,
    BackupEntry? selectedBackup,
    String? backupPath,
    String? error,
  }) = _BackupState;

  factory BackupState.initial() => const BackupState();
}
