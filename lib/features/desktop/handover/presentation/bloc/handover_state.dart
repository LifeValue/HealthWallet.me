part of 'handover_bloc.dart';

@freezed
class HandoverState with _$HandoverState {
  const factory HandoverState({
    @Default({}) Map<String, HandoverSession> activeSessions,
    String? error,
  }) = _HandoverState;

  factory HandoverState.initial() => const HandoverState();
}
