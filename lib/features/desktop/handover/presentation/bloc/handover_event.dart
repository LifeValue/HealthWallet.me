part of 'handover_bloc.dart';

@freezed
class HandoverEvent with _$HandoverEvent {
  const factory HandoverEvent.initialised() = HandoverInitialised;
  const factory HandoverEvent.offerReceived({
    required HandoverSession session,
  }) = HandoverOfferReceived;
  const factory HandoverEvent.fileReceived({
    required String sessionId,
  }) = HandoverFileReceived;
  const factory HandoverEvent.processingComplete({
    required String sessionId,
  }) = HandoverProcessingComplete;
}
