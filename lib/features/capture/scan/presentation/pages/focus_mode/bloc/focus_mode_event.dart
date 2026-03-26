part of 'focus_mode_bloc.dart';

@freezed
class FocusModeEvent with _$FocusModeEvent {
  const factory FocusModeEvent.started() = FocusModeStarted;
  const factory FocusModeEvent.countdownTicked({
    required int remainingSeconds,
  }) = FocusModeCountdownTicked;
  const factory FocusModeEvent.screenRestored() = FocusModeScreenRestored;
  const factory FocusModeEvent.batteryStateChanged({
    required BatteryState batteryState,
  }) = FocusModeBatteryStateChanged;
  const factory FocusModeEvent.processingCompleted() =
      FocusModeProcessingCompleted;
  const factory FocusModeEvent.notificationDisplayed() =
      FocusModeNotificationDisplayed;
  const factory FocusModeEvent.disposed() = FocusModeDisposed;
}
