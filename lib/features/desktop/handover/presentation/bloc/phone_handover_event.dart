part of 'phone_handover_bloc.dart';

@freezed
sealed class PhoneHandoverEvent with _$PhoneHandoverEvent {
  const factory PhoneHandoverEvent.initialised() = PhoneHandoverInitialised;

  /// Send processing session [sessionId] to the desktop.
  const factory PhoneHandoverEvent.sendRequested({required String sessionId}) =
      PhoneHandoverSendRequested;

  /// Stop a transfer in progress.
  const factory PhoneHandoverEvent.cancelRequested({
    required String sessionId,
  }) = PhoneHandoverCancelRequested;

  /// Process a handed-over session on this phone after all.
  const factory PhoneHandoverEvent.takeBackRequested({
    required String sessionId,
  }) = PhoneHandoverTakeBackRequested;

  const factory PhoneHandoverEvent.transferUpdated({
    required HandoverSession transfer,
  }) = PhoneHandoverTransferUpdated;

  const factory PhoneHandoverEvent.desktopEventReceived({
    required DesktopHandoverEvent event,
  }) = PhoneHandoverDesktopEventReceived;

  const factory PhoneHandoverEvent.processingChanged({
    required ProcessingState processing,
  }) = PhoneHandoverProcessingChanged;
}
