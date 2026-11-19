import 'package:freezed_annotation/freezed_annotation.dart';

part 'handover_session.freezed.dart';

/// Where a document's transfer between the phone and the desktop stands.
/// What happens after the transfer is the processing session's status.
enum HandoverStatus {
  /// The phone is sending the files.
  sending,

  /// Every file reached the desktop.
  sent,

  /// The desktop is receiving the files.
  receiving,

  /// The transfer ended without the files arriving; see
  /// [HandoverSession.failure].
  error,
}

/// Why a handover failed, so both ends show localized text.
enum HandoverFailure {
  /// The desktop did not answer the offer in time (an older desktop app
  /// never answers).
  notAccepted(null),

  /// A document to send is no longer on the phone.
  fileNotFound(null),

  /// The link dropped while the files were being sent.
  connectionLost(null),

  /// The user cancelled the handover on either device.
  cancelled('cancelled'),

  /// The desktop has no AI model downloaded.
  modelNotFound('model_not_found'),

  /// The documents are larger than the desktop accepts in one handover.
  tooLarge('too_large'),

  /// The desktop app speaks another handover version.
  desktopOutdated('version'),

  /// The phone stopped sending before every file arrived.
  timeout('timeout'),

  /// Processing failed for another reason.
  failed('failed');

  const HandoverFailure(this.wire);

  /// The `reason` sent over the link, or null for a failure only the phone
  /// sees.
  final String? wire;

  static HandoverFailure fromWire(String? reason) =>
      values.firstWhere((f) => f.wire == reason, orElse: () => failed);
}

@freezed
abstract class HandoverSession with _$HandoverSession {
  const factory HandoverSession({
    required String sessionId,
    @Default(HandoverStatus.sending) HandoverStatus status,
    @Default(0) int fileCount,

    /// Files that arrived completely.
    @Default(0) int receivedCount,

    /// Share of the bytes transferred, 0 to 1.
    @Default(0.0) double progress,
    HandoverFailure? failure,
  }) = _HandoverSession;
}
