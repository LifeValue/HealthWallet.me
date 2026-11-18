import 'package:health_wallet/features/user/domain/entity/user.dart';

abstract class UserRepository {
  Future<User> getCurrentUser();
  Future<void> updateUser(User user);
  Future<void> clearUser();
  Future<void> saveBiometricAuth(bool isEnabled);
  Future<bool> isBiometricAuthEnabled();
}
