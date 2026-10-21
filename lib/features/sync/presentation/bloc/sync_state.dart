part of 'sync_bloc.dart';

enum SyncStatus {
  initial,
  syncing,
  synced,
}

@freezed
abstract class SyncState with _$SyncState {
  const factory SyncState({
    SyncQrData? syncQrData,
    @Default(false) bool isLoading,
    @Default(SyncStatus.initial) SyncStatus syncStatus,
    String? errorMessage,
    @Default(false) bool isQRScanning,
    String? lastSyncTime,
    String? successMessage,
    @Default(false) bool hasDemoData,
    // Tutorial state
    @Default(false) bool shouldShowTutorial,
    @Default(false) bool hasSyncedData,
    @Default(false) bool syncDialogShown,
    @Default(false) bool demoDataConfirmed,
  }) = _SyncState;
}
