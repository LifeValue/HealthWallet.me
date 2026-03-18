import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:health_wallet/core/config/constants/region_preset.dart';
import 'package:health_wallet/core/config/constants/shared_prefs_constants.dart';
import 'package:health_wallet/core/services/biometric_auth_service.dart';
import 'package:health_wallet/features/user/domain/entity/user.dart';
import 'package:health_wallet/features/user/domain/repository/user_repository.dart';
import 'package:health_wallet/features/share_records/domain/services/receive_mode_service.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:injectable/injectable.dart';
import 'package:local_auth/local_auth.dart';
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
    on<UserThemeToggled>(_onThemeToggled);
    on<UserBiometricAuthToggled>(_onBiometricAuthToggled);
    on<UserBiometricsSetupShown>(_onBiometricsSetupShown);
    on<UserDataUpdatedFromSync>(_onUserDataUpdatedFromSync);
    on<UserNameUpdated>(_onUserNameUpdated);
    on<UserReceiveModeToggled>(_onReceiveModeToggled);
    on<UserRegionPresetChanged>(_onRegionPresetChanged);
    on<UserLocaleChanged>(_onLocaleChanged);
  }

  Future<void> _onInitialised(
    UserInitialised event,
    Emitter<UserState> emit,
  ) async {
    await _getCurrentUser(false, emit);
  }

  Future<void> _getCurrentUser(
    bool fetchFromNetwork,
    Emitter<UserState> emit,
  ) async {
    emit(state.copyWith(status: const UserStatus.loading()));

    final isBiometricAuthEnabled =
        await _userRepository.isBiometricAuthEnabled();

    final prefs = await SharedPreferences.getInstance();
    final savedRegionString = prefs.getString(SharedPrefsConstants.regionPreset);
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

    final savedLocaleCode = prefs.getString(SharedPrefsConstants.appLocale);
    final Locale? savedLocale =
        savedLocaleCode != null ? Locale(savedLocaleCode) : null;

    try {
      User user;
      try {
        user = await _userRepository.getCurrentUser(
            fetchFromNetwork: fetchFromNetwork);
      } catch (e) {
        final systemTheme =
            WidgetsBinding.instance.platformDispatcher.platformBrightness;
        final isSystemDarkMode = systemTheme == Brightness.dark;

        user = User(
          isDarkMode: isSystemDarkMode,
        );

        await _userRepository.updateUser(user);
      }

      emit(state.copyWith(
        status: const UserStatus.success(),
        user: user,
        isBiometricAuthEnabled: isBiometricAuthEnabled,
        regionPreset: savedRegion,
        appLocale: savedLocale,
      ));
    } catch (e) {
      final systemTheme =
          WidgetsBinding.instance.platformDispatcher.platformBrightness;
      final isSystemDarkMode = systemTheme == Brightness.dark;

      final defaultUser = User(
        isDarkMode: isSystemDarkMode,
      );

      emit(state.copyWith(
        status: const UserStatus.success(),
        user: defaultUser,
        isBiometricAuthEnabled: isBiometricAuthEnabled,
        regionPreset: savedRegion,
        appLocale: savedLocale,
      ));
    }
  }

  Future<void> _onThemeToggled(
    UserThemeToggled event,
    Emitter<UserState> emit,
  ) async {
    emit(state.copyWith(status: const UserStatus.loading()));
    try {
      final updatedUser = state.user.copyWith(
        isDarkMode: !state.user.isDarkMode,
      );
      await _userRepository.updateUser(updatedUser);
      emit(
        state.copyWith(status: const UserStatus.success(), user: updatedUser),
      );
    } catch (e) {
      emit(state.copyWith(status: UserStatus.failure(e)));
    }
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
          try {
            final didAuthenticate = await _biometricAuthService.authenticate();
            if (didAuthenticate) {
              await _userRepository.saveBiometricAuth(true);

              emit(
                state.copyWith(
                  status: const UserStatus.success(),
                  isBiometricAuthEnabled: true,
                ),
              );
            } else {
              emit(
                state.copyWith(
                  status: const UserStatus.success(),
                  isBiometricAuthEnabled: false,
                ),
              );
            }
          } catch (e) {
            emit(
              state.copyWith(
                status: const UserStatus.success(),
                isBiometricAuthEnabled: false,
              ),
            );
          }
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
        await _userRepository.saveBiometricAuth(false);

        emit(
          state.copyWith(
            status: const UserStatus.success(),
            isBiometricAuthEnabled: false,
          ),
        );
      }
    } catch (e) {
      emit(state.copyWith(status: UserStatus.failure(e)));
    }
  }

  Future<void> _onUserNameUpdated(
    UserNameUpdated event,
    Emitter<UserState> emit,
  ) async {
    final updatedUser = state.user.copyWith(
      name: event.name,
    );

    emit(state.copyWith(user: updatedUser));
    await _userRepository.updateUser(updatedUser);
  }

  Future<void> _onUserDataUpdatedFromSync(
    UserDataUpdatedFromSync event,
    Emitter<UserState> emit,
  ) async {
    await _getCurrentUser(false, emit);
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
  ) async {
    emit(state.copyWith(status: const UserStatus.loading()));
    try {
      final updatedUser = state.user.copyWith(
        isReceiveModeEnabled: event.isEnabled,
      );
      await _userRepository.updateUser(updatedUser);

      final manager = getIt<ReceiveModeService>();
      if (event.isEnabled) {
        if (!manager.isListening) {
          await manager.startListening();
        }
      } else {
        if (manager.isListening) {
          await manager.stopListening();
        }
      }

      emit(state.copyWith(
        status: const UserStatus.success(),
        user: updatedUser,
      ));
    } catch (e) {
      emit(state.copyWith(status: UserStatus.failure(e)));
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
        'DE', 'FR', 'ES', 'IT', 'NL', 'BE', 'AT', 'CH', 'PT', 'SE',
        'NO', 'DK', 'FI', 'PL', 'CZ', 'SK', 'HU', 'RO', 'BG', 'HR',
        'SI', 'EE', 'LV', 'LT', 'IE', 'GR', 'LU', 'MT', 'CY',
      };
      if (europeanCountries.contains(country)) return RegionPreset.europe;
    }

    final lang = locale.languageCode.toLowerCase();
    if (lang == 'en') return RegionPreset.us;
    if (lang == 'de' || lang == 'fr' || lang == 'es' || lang == 'it' ||
        lang == 'nl' || lang == 'pt' || lang == 'pl' || lang == 'sv' ||
        lang == 'da' || lang == 'fi' || lang == 'no') {
      return RegionPreset.europe;
    }

    return RegionPreset.europe;
  }
}
