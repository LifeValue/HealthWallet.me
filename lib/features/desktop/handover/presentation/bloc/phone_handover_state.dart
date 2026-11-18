part of 'phone_handover_bloc.dart';

@freezed
abstract class PhoneHandoverState with _$PhoneHandoverState {
  const factory PhoneHandoverState({
    /// Transfers by session id: in progress, sent, or failed.
    @Default({}) Map<String, HandoverSession> transfers,

    /// How far the desktop is with each handed-over session, 0 to 1.
    @Default({}) Map<String, double> desktopProgress,

    /// Sessions the desktop also holds, until one of the two saves or
    /// deletes them.
    @Default({}) Set<String> handedOver,
  }) = _PhoneHandoverState;
}
