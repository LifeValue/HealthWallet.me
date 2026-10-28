part of 'processing_bloc.dart';

/// What kind of failure a [Failure] is. The UI branches on it and shows
/// [localizedMessage]; [Failure.error] keeps English text for the logs and
/// for the handover error a desktop sends to the phone.
enum PipelineFailureReason {
  /// The AI model is not downloaded.
  modelNotFound,

  /// The AI model file is damaged.
  modelCorrupted,

  /// Not enough free memory to load the AI model.
  notEnoughMemory,

  /// A camera scan could not be turned into a session.
  scanFailed,

  /// Picked or shared files could not be turned into a session.
  importFailed,

  /// None of the files to import exist.
  noValidFiles,

  /// The document's pages produced no images to read.
  noImagesGenerated,

  other;

  /// The reason for [error], or [fallback] when the error has no reason of
  /// its own.
  static PipelineFailureReason of(
    Object error, {
    PipelineFailureReason fallback = other,
  }) {
    if (error is ModelNotFoundException) return modelNotFound;
    // The AI engine (ai_inference_data_source.dart) throws plain Exceptions
    // with fixed English text for these two.
    final text = error.toString();
    if (text.contains('Not enough memory')) return notEnoughMemory;
    if (text.contains('corrupted')) return modelCorrupted;
    return fallback;
  }

  /// Text shown to the user; never the exception text.
  String localizedMessage(AppLocalizations l10n) => switch (this) {
    modelNotFound => l10n.modelNotFoundError,
    modelCorrupted => l10n.modelCorruptedError,
    notEnoughMemory => l10n.processingFailedCapacity,
    scanFailed => l10n.scanFailed,
    importFailed => l10n.importDocumentFailed,
    noValidFiles => l10n.noValidFilesFound,
    noImagesGenerated => l10n.processingNoImagesGenerated,
    other => l10n.processingFailedGeneric,
  };
}

@freezed
sealed class PipelineStatus with _$PipelineStatus {
  const factory PipelineStatus.initial() = Initial;
  const factory PipelineStatus.loading() = Loading;
  const factory PipelineStatus.sessionCreated({
    required ProcessingSession session,
  }) = SessionCreated;

  /// [error] is English diagnostic text for logs and the handover message;
  /// the UI shows [reason]'s localized message.
  const factory PipelineStatus.failure({
    required String error,
    @Default(PipelineFailureReason.other) PipelineFailureReason reason,
  }) = Failure;
  const factory PipelineStatus.capacityFailure({required String sessionId}) =
      CapacityFailure;
  const factory PipelineStatus.convertingPdfs() = ConvertingPdfs;
  const factory PipelineStatus.savingResources() = SavingResources;
  const factory PipelineStatus.success() = Success;
}

@freezed
abstract class ProcessingState with _$ProcessingState {
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
