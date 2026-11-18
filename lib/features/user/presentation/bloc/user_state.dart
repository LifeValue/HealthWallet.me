part of 'user_bloc.dart';

@freezed
abstract class UserState with _$UserState {
  const factory UserState({
    @Default(UserStatus.initial()) UserStatus status,
    @Default(User()) User user,
    @Default(false) bool isBiometricAuthEnabled,
    @Default(false) bool shouldShowBiometricsSetup,
    @Default(RegionPreset.europe) RegionPreset regionPreset,
    String? countryCode,
    Locale? appLocale,
  }) = _UserState;
}

/// The profile setting a save belongs to, so the screen can say which one
/// failed.
enum UserSetting { name, theme, receiveMode, biometric }

@freezed
sealed class UserStatus with _$UserStatus {
  const factory UserStatus.initial() = _Initial;
  const factory UserStatus.loading() = _Loading;

  /// [setting] is set only by the name save, whose field closes on success.
  const factory UserStatus.success({UserSetting? setting}) = _Success;
  const factory UserStatus.failure(Object exception, UserSetting setting) =
      _Failure;
}
