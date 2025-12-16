part of 'local_qr_share_bloc.dart';

@freezed
class LocalQRShareEvent with _$LocalQRShareEvent {
  const factory LocalQRShareEvent.initialized() = LocalQRShareInitialized;
  const factory LocalQRShareEvent.loadResources() = LocalQRShareLoadResources;
  const factory LocalQRShareEvent.resourcesSelected(
    List<String> resourceIds,
  ) = LocalQRShareResourcesSelected;
  const factory LocalQRShareEvent.configChanged(
    LocalQRShareConfig config,
  ) = LocalQRShareConfigChanged;
  const factory LocalQRShareEvent.generateQrCode({
    required List<String> resourceIds,
    String? sourceId,
  }) = LocalQRShareGenerateQrCode;
  const factory LocalQRShareEvent.timerTick(int remainingSeconds) =
      LocalQRShareTimerTick;
  const factory LocalQRShareEvent.proximityChanged(bool isConnected) =
      LocalQRShareProximityChanged;
  const factory LocalQRShareEvent.bleTransferProgress(double progress) =
      LocalQRShareBleTransferProgress;
  const factory LocalQRShareEvent.expired() = LocalQRShareExpired;
  const factory LocalQRShareEvent.stop() = LocalQRShareStop;
  const factory LocalQRShareEvent.reset() = LocalQRShareReset;
}
