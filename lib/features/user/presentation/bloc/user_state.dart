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

@freezed
sealed class UserStatus with _$UserStatus {
  const factory UserStatus.initial() = _Initial;
  const factory UserStatus.loading() = _Loading;
  const factory UserStatus.success() = _Success;
  const factory UserStatus.failure(Object exception) = _Failure;
}
