part of 'communication_bloc.dart';

@freezed
sealed class CommunicationEvent with _$CommunicationEvent {
  const factory CommunicationEvent.initialised() = CommunicationInitialised;

  /// Desktop: a new pairing (new key and identity), shown as a QR code. The
  /// paired phone has to pair again.
  const factory CommunicationEvent.pairingRequested() =
      CommunicationPairingRequested;

  /// Phone: a desktop's QR code was scanned.
  const factory CommunicationEvent.pairingCompleted({
    required DevicePairing pairing,
  }) = CommunicationPairingCompleted;
  const factory CommunicationEvent.connectionRequested() =
      CommunicationConnectionRequested;
  const factory CommunicationEvent.linkStateChanged({
    required ConnectionState state,
  }) = CommunicationLinkStateChanged;
  const factory CommunicationEvent.manualDisconnect() =
      CommunicationManualDisconnect;

  /// Desktop: a phone holding the key asks to replace the paired one.
  const factory CommunicationEvent.approvalRequested({
    required PendingApproval? request,
  }) = CommunicationApprovalRequested;
  const factory CommunicationEvent.approvalAnswered({required bool accepted}) =
      CommunicationApprovalAnswered;

  /// Desktop: a phone became the paired one.
  const factory CommunicationEvent.peerApproved({required PeerInfo peer}) =
      CommunicationPeerApproved;

  /// A `pairing.*` message from the other side.
  const factory CommunicationEvent.pairingMessage({
    required String type,
    required Map<String, dynamic> payload,
  }) = CommunicationPairingMessage;
  const factory CommunicationEvent.serverFailure({
    required LinkFailure failure,
  }) = CommunicationServerFailure;

  /// Desktop: the MPC session ended; advertise again.
  const factory CommunicationEvent.mpcEnded() = CommunicationMpcEnded;

  /// Desktop: check whether this computer's address changed.
  const factory CommunicationEvent.networkChecked() =
      CommunicationNetworkChecked;
}
