part of 'lww_sync_bloc.dart';

@freezed
class LwwSyncEvent with _$LwwSyncEvent {
  const factory LwwSyncEvent.initialised() = LwwSyncInitialised;
  const factory LwwSyncEvent.syncTriggered() = SyncTriggered;
  const factory LwwSyncEvent.deltaReceived({
    required SyncDelta delta,
  }) = DeltaReceived;
  const factory LwwSyncEvent.connectionChanged({
    required bool isConnected,
  }) = ConnectionChanged;
  const factory LwwSyncEvent.tableStatusReceived({
    required Map<String, int> remoteCounts,
  }) = TableStatusReceived;
  const factory LwwSyncEvent.syncVerifyReceived({
    required Map<String, int> remoteCounts,
  }) = SyncVerifyReceived;
}
