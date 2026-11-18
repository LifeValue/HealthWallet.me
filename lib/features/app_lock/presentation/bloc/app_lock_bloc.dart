import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:health_wallet/core/config/constants/shared_prefs_constants.dart';
import 'package:health_wallet/core/services/biometric_auth_service.dart';
import 'package:health_wallet/core/utils/logger.dart';
import 'package:health_wallet/features/app_lock/domain/services/app_lock_clock.dart';
import 'package:health_wallet/features/user/domain/repository/user_repository.dart';
import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'app_lock_bloc.freezed.dart';
part 'app_lock_event.dart';
part 'app_lock_state.dart';

/// The app-wide lock: one gate in front of every route, on mobile and
/// desktop.
///
/// The lock applies when onboarding is done, the user turned the lock on and
/// the OS can authenticate (biometrics or the device passcode). It locks on
/// start and again when the app comes back after more than [lockTimeout] in
/// the background.
@lazySingleton
class AppLockBloc extends Bloc<AppLockEvent, AppLockState> {
  AppLockBloc(
    this._authService,
    this._userRepository,
    this._prefs,
    this._clock,
  ) : super(const AppLockState()) {
    on<AppLockStarted>(_onStarted, transformer: droppable());
    on<AppLockLifecycleChanged>(
      _onLifecycleChanged,
      transformer: sequential(),
    );
    on<AppLockUnlockRequested>(_onUnlockRequested, transformer: droppable());
  }

  /// Background time after which the app locks again.
  static const lockTimeout = Duration(seconds: 30);

  final BiometricAuthService _authService;
  final UserRepository _userRepository;
  final SharedPreferences _prefs;
  final AppLockClock _clock;

  /// When the app went to the background while unlocked, or null.
  DateTime? _backgroundedAt;

  Future<void> _onStarted(
    AppLockStarted event,
    Emitter<AppLockState> emit,
  ) async {
    if (!await _lockApplies()) {
      emit(state.copyWith(status: AppLockStatus.unlocked));
      return;
    }
    emit(state.copyWith(status: AppLockStatus.locked));
    await _prompt(emit);
  }

  Future<void> _onUnlockRequested(
    AppLockUnlockRequested event,
    Emitter<AppLockState> emit,
  ) async {
    if (state.isAuthenticating || state.status == AppLockStatus.unlocked) {
      return;
    }
    if (!await _lockApplies()) {
      // The passcode was removed while locked: the OS can't authenticate any
      // more, so there is nothing to check against.
      emit(state.copyWith(status: AppLockStatus.unlocked));
      return;
    }
    await _prompt(emit);
  }

  Future<void> _onLifecycleChanged(
    AppLockLifecycleChanged event,
    Emitter<AppLockState> emit,
  ) async {
    // The OS prompt itself moves the app to inactive or paused and back.
    if (state.isAuthenticating) return;

    switch (event.lifecycleState) {
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        if (state.status == AppLockStatus.unlocked) {
          _backgroundedAt ??= _clock.now();
        }
      case AppLifecycleState.resumed:
        final backgroundedAt = _backgroundedAt;
        _backgroundedAt = null;
        if (backgroundedAt == null || state.status != AppLockStatus.unlocked) {
          return;
        }
        final elapsed = _clock.now().difference(backgroundedAt);
        // A clock set back while in the background counts as expired.
        if (!elapsed.isNegative && elapsed <= lockTimeout) return;
        if (!await _lockApplies()) return;
        emit(state.copyWith(status: AppLockStatus.locked));
        // Prompt from its own handler so lifecycle changes caused by the
        // prompt are seen (and ignored) while it is open.
        add(const AppLockUnlockRequested());
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  Future<bool> _lockApplies() async {
    try {
      final hasSeenOnboarding =
          _prefs.getBool(
            SharedPrefsConstants.hasSeenOnboarding,
          ) ??
          false;
      if (!hasSeenOnboarding) return false;
      if (!await _userRepository.isBiometricAuthEnabled()) return false;
      return await _authService.isDeviceSecure();
    } catch (e) {
      // Fail closed: an unreadable setting keeps the records covered.
      logger.e('App lock: could not read the lock settings: $e');
      return true;
    }
  }

  Future<void> _prompt(Emitter<AppLockState> emit) async {
    emit(state.copyWith(isAuthenticating: true));
    var didAuthenticate = false;
    try {
      didAuthenticate = await _authService.authenticate();
    } catch (e) {
      logger.w('App lock: authentication failed: $e');
    }
    _backgroundedAt = null;
    emit(
      state.copyWith(
        status: didAuthenticate ? AppLockStatus.unlocked : AppLockStatus.locked,
        isAuthenticating: false,
      ),
    );
  }
}
