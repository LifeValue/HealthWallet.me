part of 'app_lock_bloc.dart';

abstract class AppLockEvent {
  const AppLockEvent();
}

/// The app has started: lock and prompt if the lock applies.
@freezed
abstract class AppLockStarted extends AppLockEvent with _$AppLockStarted {
  const AppLockStarted._();

  const factory AppLockStarted() = _AppLockStarted;
}

/// The app moved between foreground and background.
@freezed
abstract class AppLockLifecycleChanged extends AppLockEvent
    with _$AppLockLifecycleChanged {
  const AppLockLifecycleChanged._();

  const factory AppLockLifecycleChanged(AppLifecycleState lifecycleState) =
      _AppLockLifecycleChanged;
}

/// The user asked to unlock (the lock screen's Unlock button).
@freezed
abstract class AppLockUnlockRequested extends AppLockEvent
    with _$AppLockUnlockRequested {
  const AppLockUnlockRequested._();

  const factory AppLockUnlockRequested() = _AppLockUnlockRequested;
}
