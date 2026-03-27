import 'package:freezed_annotation/freezed_annotation.dart';

part 'handover_session.freezed.dart';
part 'handover_session.g.dart';

enum HandoverStatus {
  receiving,
  processing,
  sendingResults,
  complete,
  error;
}

@freezed
class HandoverSession with _$HandoverSession {
  const factory HandoverSession({
    required String sessionId,
    @Default(HandoverStatus.receiving) HandoverStatus status,
    @Default(0) int fileCount,
    @Default(0) int receivedCount,
    @Default(0.0) double progress,
    String? error,
  }) = _HandoverSession;

  factory HandoverSession.fromJson(Map<String, dynamic> json) =>
      _$HandoverSessionFromJson(json);
}
