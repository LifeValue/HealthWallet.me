part of 'lww_sync_bloc.dart';

@freezed
sealed class LwwSyncEvent with _$LwwSyncEvent {
  const factory LwwSyncEvent.initialised() = LwwSyncInitialised;

  /// Send what is waiting now (Sync Now, a saved scan, a handover result).
  const factory LwwSyncEvent.syncTriggered() = SyncTriggered;

  /// A synced table was written locally.
  const factory LwwSyncEvent.localChanged() = LwwLocalChanged;
  const factory LwwSyncEvent.connectionChanged({required bool isConnected}) =
      ConnectionChanged;

  /// A `sync.*` message from the peer.
  const factory LwwSyncEvent.messageReceived({
    required String type,
    required Map<String, dynamic> payload,
  }) = LwwMessageReceived;
  const factory LwwSyncEvent.ackTimedOut({required int batchId}) =
      LwwAckTimedOut;

  /// The peer did not answer this side's digest.
  const factory LwwSyncEvent.digestTimedOut() = LwwDigestTimedOut;

  /// Compare both sides' tables afresh: forget the last comparison and send
  /// a digest (see [LwwSyncBloc.syncAndConfirmMatch]).
  const factory LwwSyncEvent.matchCheckRequested() = LwwMatchCheckRequested;

  /// Received rows stopped arriving for a moment; screens reload once.
  const factory LwwSyncEvent.recordsSettled() = LwwRecordsSettled;
}
