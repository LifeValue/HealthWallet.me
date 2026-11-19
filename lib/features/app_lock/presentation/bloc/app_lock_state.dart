part of 'app_lock_bloc.dart';

enum AppLockStatus {
  /// Start-up: whether the lock applies isn't known yet, so the app stays
  /// covered.
  checking,

  /// Covered until the user authenticates.
  locked,

  /// Nothing covers the app.
  unlocked,
}

@freezed
abstract class AppLockState with _$AppLockState {
  const AppLockState._();

  const factory AppLockState({
    @Default(AppLockStatus.checking) AppLockStatus status,

    /// The OS authentication prompt is open.
    @Default(false) bool isAuthenticating,
  }) = _AppLockState;

  bool get coversApp => status != AppLockStatus.unlocked;
}
