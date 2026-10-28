part of 'sync_bloc.dart';

enum SyncStatus {
  initial,
  syncing,
  synced,
}

/// Why a Fasten sync failed, read from the exception type and HTTP status
/// rather than from the error text.
enum SyncFailureReason {
  connection,
  endpointNotFound,
  authentication,
  invalidFormat,
  unknown;

  static SyncFailureReason of(Object error) => switch (error) {
    DioException(
      type: DioExceptionType.connectionTimeout ||
          DioExceptionType.sendTimeout ||
          DioExceptionType.receiveTimeout ||
          DioExceptionType.connectionError ||
          DioExceptionType.badCertificate,
    ) =>
      connection,
    DioException(type: DioExceptionType.badResponse, :final response) =>
      switch (response?.statusCode) {
        404 => endpointNotFound,
        401 || 403 => authentication,
        _ => unknown,
      },
    DioException(type: DioExceptionType.unknown, error: final Object cause) =>
      of(cause),
    SocketException() || TlsException() || TimeoutException() => connection,
    FormatException() => invalidFormat,
    _ => unknown,
  };
}

/// [SyncState.errorMessage] is translated text for the user; the cause is
/// logged, never shown.
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
