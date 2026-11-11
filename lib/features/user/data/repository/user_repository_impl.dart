import 'package:health_wallet/features/user/data/data_source/local/user_local_data_source.dart';
import 'package:health_wallet/features/user/domain/entity/user.dart';
import 'package:health_wallet/features/user/domain/repository/user_repository.dart';
import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

@Injectable(as: UserRepository)
class UserRepositoryImpl implements UserRepository {
  final UserLocalDataSource _localDataSource;
  final SharedPreferences _sharedPreferences;

  UserRepositoryImpl(this._localDataSource, this._sharedPreferences);

  static const _biometricAuthKey = 'isBiometricAuthEnabled';

  @override
  Future<User> getCurrentUser() async {
    final localUser = await _localDataSource.getUser();
    if (localUser == null) {
      throw Exception('User not found in local storage');
    }
    return localUser;
  }

  @override
  Future<void> updateUser(User user) => _localDataSource.saveUser(user);

  @override
  Future<void> clearUser() => _localDataSource.clearUser();

  @override
  Future<bool> isBiometricAuthEnabled() async {
    return _sharedPreferences.getBool(_biometricAuthKey) ?? false;
  }

  @override
  Future<void> saveBiometricAuth(bool isEnabled) async {
    await _sharedPreferences.setBool(_biometricAuthKey, isEnabled);
  }
}
