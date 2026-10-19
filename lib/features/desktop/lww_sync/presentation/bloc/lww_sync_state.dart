part of 'lww_sync_bloc.dart';

enum LwwSyncStatus { idle, syncing, error }

@freezed
class LwwSyncState with _$LwwSyncState {
  const factory LwwSyncState({
    @Default(LwwSyncStatus.idle) LwwSyncStatus syncStatus,
    DateTime? lastSyncTime,
    @Default(0) int pendingChangeCount,
    String? error,
    @Default(false) bool isSynced,
    String? currentTable,
    @Default(0) int totalTables,
    @Default(0) int completedTables,
    @Default(0) int sentRows,
    @Default(0) int receivedRows,
  }) = _LwwSyncState;

  factory LwwSyncState.initial() => const LwwSyncState();
}
