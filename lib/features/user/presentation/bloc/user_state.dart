part of 'user_bloc.dart';

@freezed
class UserState with _$UserState {
  const factory UserState({
    @Default(UserStatus.initial()) UserStatus status,
    @Default(User()) User user,
    @Default(false) bool isBiometricAuthEnabled,
    @Default(false) bool shouldShowBiometricsSetup,
    @Default(RegionPreset.europe) RegionPreset regionPreset,
  }) = _UserState;
}

@freezed
class UserStatus with _$UserStatus {
  const factory UserStatus.initial() = _Initial;
  const factory UserStatus.loading() = _Loading;
  const factory UserStatus.success() = _Success;
  const factory UserStatus.failure(Object exception) = _Failure;
}
