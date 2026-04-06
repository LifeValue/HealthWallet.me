part of 'communication_bloc.dart';

@freezed
class CommunicationEvent with _$CommunicationEvent {
  const factory CommunicationEvent.initialised() = CommunicationInitialised;
  const factory CommunicationEvent.pairingRequested() = CommunicationPairingRequested;
  const factory CommunicationEvent.pairingCompleted({
    required DevicePairing pairing,
  }) = CommunicationPairingCompleted;
  const factory CommunicationEvent.connectionRequested() = CommunicationConnectionRequested;
  const factory CommunicationEvent.connected({
    required String ip,
    required int port,
  }) = CommunicationConnected;
  const factory CommunicationEvent.disconnected() = CommunicationDisconnected;
  const factory CommunicationEvent.manualDisconnect() = CommunicationManualDisconnect;
  const factory CommunicationEvent.connectionFailed({required String error}) =
      CommunicationConnectionFailed;
  const factory CommunicationEvent.remoteDeviceNameReceived({
    required String name,
  }) = CommunicationRemoteDeviceNameReceived;
}
