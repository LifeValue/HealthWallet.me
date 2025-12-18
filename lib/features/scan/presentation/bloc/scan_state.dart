part of 'scan_bloc.dart';

@freezed
class ScanStatus with _$ScanStatus {
  // Statuses used for scan and import pages
  const factory ScanStatus.initial() = Initial;
  const factory ScanStatus.loading() = Loading;
  const factory ScanStatus.sessionCreated(
      {required ProcessingSession session}) = SessionCreated;
  // General error status
  const factory ScanStatus.failure({required String error}) = Failure;
  // Statuses used for processing page
  const factory ScanStatus.convertingPdfs() = ConvertingPdfs;
  const factory ScanStatus.savingResources() = SavingResources;
  const factory ScanStatus.success() = Success;
}

@freezed
class ScanState with _$ScanState {
  const factory ScanState({
    @Default(ScanStatus.initial()) ScanStatus status,
    @Default([]) List<ProcessingSession> sessions,

    /// This is the id of the session that is currently being displayed on the
    /// processing page, not the id of the sesssion that is currently being processed
    ///
    /// To get the id of the session that is currently being processed search through
    /// sessions for the session with .processing state
    String? displayedSessionId,
    String? deletingSessionId,
    @Default([]) List<String> allImagePathsForOCR,
    @Default({}) Map<String, List<String>> sessionImagePaths,
    Notification? notification,
  }) = _ScanState;
}
