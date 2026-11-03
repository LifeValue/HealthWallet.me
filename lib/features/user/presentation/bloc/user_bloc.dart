import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:health_wallet/core/config/constants/region_preset.dart';
import 'package:health_wallet/core/config/constants/shared_prefs_constants.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/services/biometric_auth_service.dart';
import 'package:health_wallet/core/utils/logger.dart';
import 'package:health_wallet/features/share_records/domain/services/receive_mode_service.dart';
import 'package:health_wallet/features/user/domain/entity/user.dart';
import 'package:health_wallet/features/user/domain/repository/user_repository.dart';
import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'user_bloc.freezed.dart';
part 'user_event.dart';
part 'user_state.dart';

@injectable
class UserBloc extends Bloc<UserEvent, UserState> {
  final UserRepository _userRepository;
  final BiometricAuthService _biometricAuthService;

  UserBloc(
    this._userRepository,
    this._biometricAuthService,
  ) : super(const UserState()) {
    on<UserInitialised>(_onInitialised);
    on<UserThemeToggled>(_onThemeToggled, transformer: sequential());
    on<UserBiometricAuthToggled>(
      _onBiometricAuthToggled,
      transformer: droppable(),
    );
    on<UserBiometricsSetupShown>(_onBiometricsSetupShown);
    on<UserDataUpdatedFromSync>(_onUserDataUpdatedFromSync);
    on<UserNameUpdated>(_onUserNameUpdated, transformer: sequential());
    on<UserReceiveModeToggled>(
      _onReceiveModeToggled,
      transformer: sequential(),
    );
    on<UserRegionPresetChanged>(_onRegionPresetChanged);
    on<UserLocaleChanged>(_onLocaleChanged);
  }

  /// The theme, name and receive-mode saves queued so far. Each one writes
  /// the whole user, so they run one after another and each applies its
  /// field to the user the previous one left in state; run side by side, the
  /// later write would drop the earlier field from storage.
  Future<void> _userSaves = Future<void>.value();

  Future<void> _queueUserSave(Future<void> Function() save) {
    final next = _userSaves.then((_) => save());
    // The saves report their own failures; this only keeps the queue going
    // if one ever throws past them.
    _userSaves = next.then(
      (_) {},
      onError: (Object e, StackTrace s) =>
          logger.e('A user save threw past its handler', e, s),
    );
    return next;
  }

  Future<void> _onInitialised(
    UserInitialised event,
    Emitter<UserState> emit,
  ) async {
    await _getCurrentUser(emit);
  }

  Future<void> _getCurrentUser(Emitter<UserState> emit) async {
    emit(state.copyWith(status: const UserStatus.loading()));

    final isBiometricAuthEnabled = await _userRepository
        .isBiometricAuthEnabled();

    final prefs = await SharedPreferences.getInstance();
    final savedRegionString = prefs.getString(
      SharedPrefsConstants.regionPreset,
    );
    final RegionPreset savedRegion;
    if (savedRegionString == null) {
      savedRegion = _detectRegionFromLocale();
      await prefs.setString(
        SharedPrefsConstants.regionPreset,
        savedRegion.name,
      );
    } else {
      savedRegion = RegionPreset.fromString(savedRegionString);
    }

    var savedCountryCode = prefs.getString(SharedPrefsConstants.countryCode);
    if (savedCountryCode == null) {
      savedCountryCode = WidgetsBinding
          .instance
          .platformDispatcher
          .locale
          .countryCode
          ?.toUpperCase();
      if (savedCountryCode != null) {
        await prefs.setString(
          SharedPrefsConstants.countryCode,
          savedCountryCode,
        );
      }
    }

    final savedLocaleCode = prefs.getString(SharedPrefsConstants.appLocale);
    final Locale? savedLocale = savedLocaleCode != null
        ? Locale(savedLocaleCode)
        : null;

    try {
      User user;
      try {
        user = await _userRepository.getCurrentUser();
      } catch (e) {
        final systemTheme =
            WidgetsBinding.instance.platformDispatcher.platformBrightness;
        final isSystemDarkMode = systemTheme == Brightness.dark;

        user = User(
          isDarkMode: isSystemDarkMode,
        );

        await _userRepository.updateUser(user);
      }

      emit(
        state.copyWith(
          status: const UserStatus.success(),
          user: user,
          isBiometricAuthEnabled: isBiometricAuthEnabled,
          regionPreset: savedRegion,
          countryCode: savedCountryCode,
          appLocale: savedLocale,
        ),
      );
    } catch (e, s) {
      logger.e('Failed to save the new user', e, s);
      final systemTheme =
          WidgetsBinding.instance.platformDispatcher.platformBrightness;
      final isSystemDarkMode = systemTheme == Brightness.dark;

      final defaultUser = User(
        isDarkMode: isSystemDarkMode,
      );

      emit(
        state.copyWith(
          status: const UserStatus.success(),
          user: defaultUser,
          isBiometricAuthEnabled: isBiometricAuthEnabled,
          regionPreset: savedRegion,
          countryCode: savedCountryCode,
          appLocale: savedLocale,
        ),
      );
    }
  }

  Future<void> _onThemeToggled(
    UserThemeToggled event,
    Emitter<UserState> emit,
  ) {
    emit(state.copyWith(status: const UserStatus.loading()));
    return _queueUserSave(() async {
      final isDarkMode = !state.user.isDarkMode;
      try {
        await _userRepository.updateUser(
          state.user.copyWith(isDarkMode: isDarkMode),
        );
        emit(
          state.copyWith(
            status: const UserStatus.success(),
            user: state.user.copyWith(isDarkMode: isDarkMode),
          ),
        );
      } catch (e, s) {
        logger.e('Failed to save the theme', e, s);
        emit(
          state.copyWith(status: UserStatus.failure(e, UserSetting.theme)),
        );
      }
    });
  }

  Future<void> _onBiometricAuthToggled(
    UserBiometricAuthToggled event,
    Emitter<UserState> emit,
  ) async {
    emit(state.copyWith(status: const UserStatus.loading()));
    try {
      if (event.isEnabled) {
        final isDeviceSecure = await _biometricAuthService.isDeviceSecure();

        if (isDeviceSecure) {
          // A declined or cancelled prompt answers false and leaves the lock
          // off without a message; only a throw is a failure.
          final didAuthenticate = await _biometricAuthService.authenticate();
          if (didAuthenticate) {
            await _userRepository.saveBiometricAuth(true);
          }
          emit(
            state.copyWith(
              status: const UserStatus.success(),
              isBiometricAuthEnabled: didAuthenticate,
            ),
          );
        } else {
          emit(
            state.copyWith(
              status: const UserStatus.success(),
              isBiometricAuthEnabled: false,
              shouldShowBiometricsSetup: true,
            ),
          );
        }
      } else {
        // Turning the lock off needs the same check as unlocking, or anyone
        // holding the unlocked phone could switch it off for good. Without a
        // passcode the OS can't check and the lock doesn't apply, so it just
        // turns off.
        final didAuthenticate =
            !await _biometricAuthService.isDeviceSecure() ||
            await _biometricAuthService.authenticate();
        if (didAuthenticate) {
          await _userRepository.saveBiometricAuth(false);
        }

        emit(
          state.copyWith(
            status: const UserStatus.success(),
            isBiometricAuthEnabled: !didAuthenticate,
          ),
        );
      }
    } catch (e, s) {
      logger.e('Failed to change the biometric lock', e, s);
      emit(
        state.copyWith(status: UserStatus.failure(e, UserSetting.biometric)),
      );
    }
  }

  Future<void> _onUserNameUpdated(
    UserNameUpdated event,
    Emitter<UserState> emit,
  ) {
    emit(state.copyWith(status: const UserStatus.loading()));
    return _queueUserSave(() async {
      try {
        await _userRepository.updateUser(state.user.copyWith(name: event.name));
        emit(
          state.copyWith(
            status: const UserStatus.success(setting: UserSetting.name),
            user: state.user.copyWith(name: event.name),
          ),
        );
      } catch (e, s) {
        logger.e('Failed to save the display name', e, s);
        emit(state.copyWith(status: UserStatus.failure(e, UserSetting.name)));
      }
    });
  }

  Future<void> _onUserDataUpdatedFromSync(
    UserDataUpdatedFromSync event,
    Emitter<UserState> emit,
  ) {
    // Waits for queued saves, or it could read storage before one writes and
    // then show the user without that save's change.
    return _queueUserSave(() => _getCurrentUser(emit));
  }

  Future<void> _onBiometricsSetupShown(
    UserBiometricsSetupShown event,
    Emitter<UserState> emit,
  ) async {
    emit(state.copyWith(shouldShowBiometricsSetup: false));
  }

  Future<void> _onReceiveModeToggled(
    UserReceiveModeToggled event,
    Emitter<UserState> emit,
  ) {
    emit(state.copyWith(status: const UserStatus.loading()));
    return _queueUserSave(() async {
      ReceiveModeService? manager;
      bool? wasListening;
      try {
        manager = getIt<ReceiveModeService>();
        wasListening = manager.isListening;
        // Listen first: if it can't start, nothing is saved and the switch
        // stays as it was.
        await _setListening(manager, event.isEnabled);
        await _userRepository.updateUser(
          state.user.copyWith(isReceiveModeEnabled: event.isEnabled),
        );
        emit(
          state.copyWith(
            status: const UserStatus.success(),
            user: state.user.copyWith(isReceiveModeEnabled: event.isEnabled),
          ),
        );
      } catch (e, s) {
        logger.e('Failed to save Share Proximity', e, s);
        if (manager != null && wasListening != null) {
          await _restoreListening(manager, wasListening);
        }
        emit(
          state.copyWith(
            status: UserStatus.failure(e, UserSetting.receiveMode),
          ),
        );
      }
    });
  }

  static Future<void> _setListening(
    ReceiveModeService manager,
    bool listen,
  ) async {
    if (listen && !manager.isListening) {
      await manager.startListening();
    } else if (!listen && manager.isListening) {
      await manager.stopListening();
    }
  }

  /// Puts listening back as it was after the setting could not be saved, so
  /// the service matches the switch.
  static Future<void> _restoreListening(
    ReceiveModeService manager,
    bool wasListening,
  ) async {
    try {
      await _setListening(manager, wasListening);
    } catch (e, s) {
      logger.e('Failed to put Share Proximity listening back', e, s);
    }
  }

  Future<void> _onRegionPresetChanged(
    UserRegionPresetChanged event,
    Emitter<UserState> emit,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      SharedPrefsConstants.regionPreset,
      event.preset.name,
    );
    emit(state.copyWith(regionPreset: event.preset));
  }

  Future<void> _onLocaleChanged(
    UserLocaleChanged event,
    Emitter<UserState> emit,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    if (event.locale == null) {
      await prefs.remove(SharedPrefsConstants.appLocale);
    } else {
      await prefs.setString(
        SharedPrefsConstants.appLocale,
        event.locale!.languageCode,
      );
    }
    emit(state.copyWith(appLocale: event.locale));
  }

  static RegionPreset _detectRegionFromLocale() {
    final locale = WidgetsBinding.instance.platformDispatcher.locale;
    final country = locale.countryCode?.toUpperCase();

    if (country != null) {
      if (country == 'US') return RegionPreset.us;
      if (country == 'GB') return RegionPreset.uk;

      const europeanCountries = {
        'DE',
        'FR',
        'ES',
        'IT',
        'NL',
        'BE',
        'AT',
        'CH',
        'PT',
        'SE',
        'NO',
        'DK',
        'FI',
        'PL',
        'CZ',
        'SK',
        'HU',
        'RO',
        'BG',
        'HR',
        'SI',
        'EE',
        'LV',
        'LT',
        'IE',
        'GR',
        'LU',
        'MT',
        'CY',
      };
      if (europeanCountries.contains(country)) return RegionPreset.europe;
    }

    final lang = locale.languageCode.toLowerCase();
    if (lang == 'en') return RegionPreset.us;
    if (lang == 'de' ||
        lang == 'fr' ||
        lang == 'es' ||
        lang == 'it' ||
        lang == 'nl' ||
        lang == 'pt' ||
        lang == 'pl' ||
        lang == 'sv' ||
        lang == 'da' ||
        lang == 'fi' ||
        lang == 'no') {
      return RegionPreset.europe;
    }

    return RegionPreset.europe;
  }
}
