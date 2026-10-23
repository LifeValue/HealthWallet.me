import 'dart:convert';

import 'package:health_wallet/features/user/domain/entity/user.dart';
import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract class UserLocalDataSource {
  Future<User?> getUser();
  Future<void> saveUser(User user);
  Future<void> clearUser();
}

@Injectable(as: UserLocalDataSource)
class UserLocalDataSourceImpl implements UserLocalDataSource {
  final SharedPreferences _sharedPreferences;
  static const String _userKey = 'user_data';

  UserLocalDataSourceImpl(this._sharedPreferences);

  @override
  Future<User?> getUser() async {
    final userJson = _sharedPreferences.getString(_userKey);
    if (userJson != null) {
      try {
        final userMap = jsonDecode(userJson) as Map<String, dynamic>;
        return User.fromJson(userMap);
      } catch (e) {
        // If JSON parsing fails, return null
        return null;
      }
    }
    return null;
  }

  @override
  Future<void> saveUser(User user) async {
    final userJson = jsonEncode(user.toJson());
    await _sharedPreferences.setString(_userKey, userJson);
  }

  @override
  Future<void> clearUser() async {
    await _sharedPreferences.remove(_userKey);
  }
}

class MockUserLocalDataSource implements UserLocalDataSource {
  User? _user;

  @override
  Future<User?> getUser() async {
    await Future.delayed(const Duration(milliseconds: 100));
    return _user;
  }

  @override
  Future<void> saveUser(User user) async {
    await Future.delayed(const Duration(milliseconds: 100));
    _user = user;
  }

  @override
  Future<void> clearUser() async {
    await Future.delayed(const Duration(milliseconds: 100));
    _user = null;
  }
}
