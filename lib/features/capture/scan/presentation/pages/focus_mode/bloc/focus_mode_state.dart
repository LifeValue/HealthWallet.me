part of 'focus_mode_bloc.dart';

@freezed
abstract class FocusModeState with _$FocusModeState {
  const factory FocusModeState({
    @Default(10) int remainingSeconds,
    @Default(false) bool isScreenDarkened,
    @Default(false) bool shouldExit,
    @Default(false) bool waitingForNotification,
    @Default(BatteryState.unknown) BatteryState batteryState,
  }) = _FocusModeState;
}

extension FocusModeStateExtension on FocusModeState {
  bool get isCharging {
    return batteryState == BatteryState.charging ||
        batteryState == BatteryState.full;
  }
}
