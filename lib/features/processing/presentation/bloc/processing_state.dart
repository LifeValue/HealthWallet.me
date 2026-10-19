part of 'processing_bloc.dart';

@freezed
class PipelineStatus with _$PipelineStatus {
  const factory PipelineStatus.initial() = Initial;
  const factory PipelineStatus.loading() = Loading;
  const factory PipelineStatus.sessionCreated(
      {required ProcessingSession session}) = SessionCreated;
  const factory PipelineStatus.failure({required String error}) = Failure;
  const factory PipelineStatus.capacityFailure({required String sessionId}) =
      CapacityFailure;
  const factory PipelineStatus.convertingPdfs() = ConvertingPdfs;
  const factory PipelineStatus.savingResources() = SavingResources;
  const factory PipelineStatus.success() = Success;
}

@freezed
class ProcessingState with _$ProcessingState {
  const ProcessingState._();

  const factory ProcessingState({
    @Default(PipelineStatus.initial()) PipelineStatus status,
    @Default([]) List<ProcessingSession> sessions,
    String? displayedSessionId,
    String? deletingSessionId,
    @Default([]) List<String> allImagePathsForOCR,
    @Default({}) Map<String, List<String>> sessionImagePaths,
    Notification? notification,
    @Default(false) bool useVision,
  }) = _ProcessingState;

  bool canRetrySession(String sessionId) {
    final session = sessions.firstWhereOrNull((s) => s.id == sessionId);
    return session != null &&
        (session.status == ProcessingStatus.draft ||
            session.status == ProcessingStatus.patientExtracted ||
            session.status == ProcessingStatus.cancelled ||
            status is Failure ||
            status is CapacityFailure);
  }

  bool canRetryStep2(String sessionId) {
    final session = sessions.firstWhereOrNull((s) => s.id == sessionId);
    return session != null &&
        (session.status == ProcessingStatus.draft ||
            (session.status == ProcessingStatus.patientExtracted &&
                status is Failure));
  }
}
