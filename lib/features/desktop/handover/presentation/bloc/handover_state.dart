part of 'handover_bloc.dart';

@freezed
abstract class HandoverState with _$HandoverState {
  const factory HandoverState({
    /// Documents the phone is sending now, by session id.
    @Default({}) Map<String, HandoverSession> transfers,
  }) = _HandoverState;

  factory HandoverState.initial() => const HandoverState();
}
