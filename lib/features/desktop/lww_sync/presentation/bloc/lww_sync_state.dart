part of 'lww_sync_bloc.dart';

enum LwwSyncStatus { idle, syncing, error }

@freezed
abstract class LwwSyncState with _$LwwSyncState {
  const LwwSyncState._();

  const factory LwwSyncState({
    @Default(LwwSyncStatus.idle) LwwSyncStatus syncStatus,

    /// When rows last reached the peer or came from it.
    DateTime? lastSyncTime,

    /// The device [lastSyncTime] refers to.
    String? lastSyncPeerName,

    /// Rows changed here that the peer hasn't acknowledged yet.
    @Default(0) int pendingChangeCount,
    String? error,
    @Default(false) bool connected,

    /// Both sides' tables matched at the last comparison.
    @Default(false) bool tablesMatch,
    @Default(false) bool sending,
    @Default(false) bool receiving,
    @Default(0) int sentRows,
    @Default(0) int receivedRows,

    /// Goes up once after rows from the peer were saved and no more arrived
    /// for a moment, so lists reload once per sync rather than per batch.
    @Default(0) int recordsVersion,
  }) = _LwwSyncState;

  factory LwwSyncState.initial() => const LwwSyncState();

  /// Connected, nothing waiting to go either way, and both sides agree.
  bool get isSynced =>
      connected &&
      !sending &&
      !receiving &&
      pendingChangeCount == 0 &&
      tablesMatch;
}
