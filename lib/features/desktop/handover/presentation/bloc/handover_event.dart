part of 'handover_bloc.dart';

@freezed
sealed class HandoverEvent with _$HandoverEvent {
  const factory HandoverEvent.initialised() = HandoverInitialised;
  const factory HandoverEvent.transferUpdated({
    required HandoverSession transfer,
  }) = HandoverTransferUpdated;
  const factory HandoverEvent.phoneEventReceived({
    required IncomingHandoverEvent event,
  }) = HandoverPhoneEventReceived;
  const factory HandoverEvent.processingChanged({
    required ProcessingState processing,
  }) = HandoverProcessingChanged;
}
