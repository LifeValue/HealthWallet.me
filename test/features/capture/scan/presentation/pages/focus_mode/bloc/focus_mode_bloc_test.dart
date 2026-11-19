import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/features/capture/scan/presentation/pages/focus_mode/bloc/focus_mode_bloc.dart';

import '../../../../../../../helpers/log_capture.dart';

class _FakeBattery extends Fake implements Battery {
  _FakeBattery({this.error});

  final Error? error;

  /// Closed by the test once the bloc is closed.
  // ignore: close_sinks
  final changes = StreamController<BatteryState>.broadcast();

  @override
  Future<BatteryState> get batteryState async {
    if (error != null) throw error!;
    return BatteryState.discharging;
  }

  @override
  Stream<BatteryState> get onBatteryStateChanged => changes.stream;
}

void main() {
  final logs = captureLogs();

  /// Runs [body] on fake time with a started bloc.
  void started(
    void Function(FakeAsync time, FocusModeBloc bloc, _FakeBattery battery)
    body, {
    _FakeBattery? battery,
  }) => fakeAsync((time) {
    final fake = battery ?? _FakeBattery();
    final bloc = FocusModeBloc(battery: fake)
      ..add(const FocusModeEvent.started());
    time.flushMicrotasks();
    body(time, bloc, fake);
    bloc.close();
    fake.changes.close();
    time.flushMicrotasks();
  });

  test('starts a 10 s countdown and reads the battery', () {
    started((time, bloc, _) {
      expect(bloc.state.remainingSeconds, 10);
      expect(bloc.state.batteryState, BatteryState.discharging);
      expect(bloc.state.isScreenDarkened, isFalse);
    });
  });

  test('the screen darkens when the countdown ends', () {
    started((time, bloc, _) {
      time.elapse(const Duration(seconds: 4));
      expect(bloc.state.remainingSeconds, 6);

      time.elapse(const Duration(seconds: 6));
      expect(bloc.state.remainingSeconds, 0);
      expect(bloc.state.isScreenDarkened, isTrue);
    });
  });

  test('a touch restores the screen and starts the countdown again', () {
    started((time, bloc, _) {
      time.elapse(const Duration(seconds: 10));

      bloc.add(const FocusModeEvent.screenRestored());
      time.flushMicrotasks();
      expect(bloc.state.isScreenDarkened, isFalse);
      expect(bloc.state.remainingSeconds, 10);

      time.elapse(const Duration(seconds: 3));
      expect(bloc.state.remainingSeconds, 7);
    });
  });

  test('battery changes are followed', () {
    started((time, bloc, battery) {
      battery.changes.add(BatteryState.charging);
      time.flushMicrotasks();

      expect(bloc.state.batteryState, BatteryState.charging);
    });
  });

  test('an unreadable battery is logged and shown as unknown', () {
    started(
      battery: _FakeBattery(error: StateError('no battery')),
      (time, bloc, _) {
        expect(bloc.state.batteryState, BatteryState.unknown);
        expect(logs, loggedWarning('Reading the battery state failed'));
      },
    );
  });

  test('the end of processing waits for its notification, then exits', () {
    started((time, bloc, _) {
      bloc.add(const FocusModeEvent.processingCompleted());
      time.flushMicrotasks();
      expect(bloc.state.waitingForNotification, isTrue);

      bloc.add(const FocusModeEvent.notificationDisplayed());
      time.flushMicrotasks();
      expect(bloc.state.waitingForNotification, isFalse);
      expect(bloc.state.shouldExit, isTrue);
    });
  });

  test('leaving stops the countdown', () {
    started((time, bloc, _) {
      bloc.add(const FocusModeEvent.disposed());
      time.flushMicrotasks();

      time.elapse(const Duration(seconds: 20));
      expect(bloc.state.remainingSeconds, 10);
      expect(bloc.state.isScreenDarkened, isFalse);
    });
  });
}
