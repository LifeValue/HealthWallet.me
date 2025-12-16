part of 'receive_bloc.dart';

@freezed
class ReceiveEvent with _$ReceiveEvent {
  const factory ReceiveEvent.initialized() = ReceiveInitialized;
  const factory ReceiveEvent.startScanning() = ReceiveStartScanning;
  const factory ReceiveEvent.qrCodeScanned(String qrData) =
      ReceiveQrCodeScanned;
  const factory ReceiveEvent.reset() = ReceiveReset;
  // LocalQR expiration timer events
  const factory ReceiveEvent.timerTick(int remainingSeconds) = ReceiveTimerTick;
  const factory ReceiveEvent.resourcesExpired() = ReceiveResourcesExpired;
}
