part of 'scan_bloc.dart';

@freezed
class ScanStatus with _$ScanStatus {
  const factory ScanStatus.initial() = Initial;
  const factory ScanStatus.loading() = Loading;
  const factory ScanStatus.sessionCreated(
      {required ProcessingSession session}) = SessionCreated;
  const factory ScanStatus.failure({required String error}) = Failure;
  const factory ScanStatus.capacityFailure({required String sessionId}) =
      CapacityFailure;
  const factory ScanStatus.convertingPdfs() = ConvertingPdfs;
  const factory ScanStatus.savingResources() = SavingResources;
  const factory ScanStatus.success() = Success;
}

@freezed
class ScanState with _$ScanState {
  const factory ScanState({
    @Default(ScanStatus.initial()) ScanStatus status,
    @Default([]) List<ProcessingSession> sessions,
    String? displayedSessionId,
    String? deletingSessionId,
    @Default([]) List<String> allImagePathsForOCR,
    @Default({}) Map<String, List<String>> sessionImagePaths,
    Notification? notification,
  }) = _ScanState;
}
