import 'package:freezed_annotation/freezed_annotation.dart';

part 'handover_session.freezed.dart';
part 'handover_session.g.dart';

enum HandoverStatus {
  receiving,
  processing,
  sendingResults,
  complete,
  error,
  sending,
  waitingForResults,
}

/// Why a handover ended in [HandoverStatus.error], so the UI shows localized
/// text instead of [HandoverSession.error], which is technical detail.
enum HandoverFailure {
  /// The desktop did not answer the handover request in time.
  notAccepted,

  /// A document to send is no longer on the phone.
  fileNotFound,

  /// The user cancelled the handover.
  cancelled,

  /// The desktop has no AI model downloaded.
  modelNotFound,

  /// Processing or sending results failed for another reason.
  failed;

  /// `reason` value of a `handover.progress` error for [modelNotFound].
  static const modelNotFoundReason = 'model_not_found';
}

@freezed
abstract class HandoverSession with _$HandoverSession {
  const factory HandoverSession({
    required String sessionId,
    @Default(HandoverStatus.receiving) HandoverStatus status,
    @Default(0) int fileCount,
    @Default(0) int receivedCount,
    @Default(0.0) double progress,
    String? error,
    HandoverFailure? failure,
  }) = _HandoverSession;

  factory HandoverSession.fromJson(Map<String, dynamic> json) =>
      _$HandoverSessionFromJson(json);
}
