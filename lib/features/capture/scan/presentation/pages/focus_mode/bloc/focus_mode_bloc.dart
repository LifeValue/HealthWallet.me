import 'dart:async';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'focus_mode_event.dart';
part 'focus_mode_state.dart';
part 'focus_mode_bloc.freezed.dart';

@injectable
class FocusModeBloc extends Bloc<FocusModeEvent, FocusModeState> {
  Timer? _countdownTimer;
  StreamSubscription<BatteryState>? _batterySubscription;
  final Battery _battery = Battery();
  static const int _initialCountdownSeconds = 10;

  FocusModeBloc() : super(const FocusModeState()) {
    on<FocusModeStarted>(_onFocusModeStarted);
    on<FocusModeCountdownTicked>(_onFocusModeCountdownTicked);
    on<FocusModeScreenRestored>(_onFocusModeScreenRestored);
    on<FocusModeBatteryStateChanged>(_onFocusModeBatteryStateChanged);
    on<FocusModeProcessingCompleted>(_onFocusModeProcessingCompleted);
    on<FocusModeNotificationDisplayed>(_onFocusModeNotificationDisplayed);
    on<FocusModeDisposed>(_onFocusModeDisposed);
  }

  void _onFocusModeStarted(
    FocusModeStarted event,
    Emitter<FocusModeState> emit,
  ) async {
    _startCountdown(emit);
    await _initBatteryState(emit);
  }

  Future<void> _initBatteryState(Emitter<FocusModeState> emit) async {
    try {
      final batteryState = await _battery.batteryState;
      emit(state.copyWith(batteryState: batteryState));

      _batterySubscription?.cancel();
      _batterySubscription = _battery.onBatteryStateChanged.listen((state) {
        add(FocusModeBatteryStateChanged(batteryState: state));
      });
    } catch (e) {
      emit(state.copyWith(batteryState: BatteryState.unknown));
    }
  }

  void _onFocusModeBatteryStateChanged(
    FocusModeBatteryStateChanged event,
    Emitter<FocusModeState> emit,
  ) {
    emit(state.copyWith(batteryState: event.batteryState));
  }

  void _onFocusModeCountdownTicked(
    FocusModeCountdownTicked event,
    Emitter<FocusModeState> emit,
  ) {
    if (event.remainingSeconds > 0) {
      emit(state.copyWith(
        remainingSeconds: event.remainingSeconds,
        isScreenDarkened: false,
      ));
    } else {
      emit(state.copyWith(
        remainingSeconds: 0,
        isScreenDarkened: true,
      ));
      _countdownTimer?.cancel();
    }
  }

  void _onFocusModeScreenRestored(
    FocusModeScreenRestored event,
    Emitter<FocusModeState> emit,
  ) {
    _countdownTimer?.cancel();
    emit(state.copyWith(isScreenDarkened: false));
    _startCountdown(emit);
  }

  void _onFocusModeProcessingCompleted(
    FocusModeProcessingCompleted event,
    Emitter<FocusModeState> emit,
  ) {
    emit(state.copyWith(waitingForNotification: true));
  }

  void _onFocusModeNotificationDisplayed(
    FocusModeNotificationDisplayed event,
    Emitter<FocusModeState> emit,
  ) {
    emit(state.copyWith(
      waitingForNotification: false,
      shouldExit: true,
    ));
  }

  void _onFocusModeDisposed(
    FocusModeDisposed event,
    Emitter<FocusModeState> emit,
  ) {
    _countdownTimer?.cancel();
  }

  void _startCountdown(Emitter<FocusModeState> emit) {
    emit(state.copyWith(remainingSeconds: _initialCountdownSeconds));

    _countdownTimer?.cancel();
    int currentSeconds = _initialCountdownSeconds;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      currentSeconds--;
      if (currentSeconds > 0) {
        add(FocusModeCountdownTicked(remainingSeconds: currentSeconds));
      } else {
        add(const FocusModeCountdownTicked(remainingSeconds: 0));
        timer.cancel();
      }
    });
  }

  @override
  Future<void> close() {
    _countdownTimer?.cancel();
    _batterySubscription?.cancel();
    return super.close();
  }
}
