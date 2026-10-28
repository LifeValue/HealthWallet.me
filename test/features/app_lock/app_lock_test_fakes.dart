import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/services/biometric_auth_service.dart';
import 'package:health_wallet/features/app_lock/domain/services/app_lock_clock.dart';
import 'package:health_wallet/features/user/domain/entity/user.dart';
import 'package:health_wallet/features/user/domain/repository/user_repository.dart';

/// OS authentication: answers from [results] in order (false when empty), or
/// waits on [pending] while it is set.
class FakeLockAuthService extends Fake implements BiometricAuthService {
  FakeLockAuthService({
    this.deviceSecure = true,
    this.biometricAvailable = true,
    List<bool>? results,
  }) : results = results ?? [];

  bool deviceSecure;
  bool biometricAvailable;
  final List<bool> results;
  Completer<bool>? pending;
  Exception? authenticateError;
  int authenticateCalls = 0;

  @override
  Future<bool> isDeviceSecure() async => deviceSecure;

  @override
  Future<bool> isBiometricAvailable() async => biometricAvailable;

  @override
  Future<bool> canAuthenticate() async => deviceSecure;

  @override
  Future<bool> authenticate() async {
    authenticateCalls++;
    final error = authenticateError;
    if (error != null) throw error;
    final waiting = pending;
    if (waiting != null) return waiting.future;
    return results.isEmpty ? false : results.removeAt(0);
  }
}

/// User repository holding the lock setting in memory.
class FakeLockUserRepository extends Fake implements UserRepository {
  FakeLockUserRepository({this.lockEnabled = true});

  bool lockEnabled;
  Exception? readError;
  final List<bool> savedLockValues = [];

  @override
  Future<bool> isBiometricAuthEnabled() async {
    final error = readError;
    if (error != null) throw error;
    return lockEnabled;
  }

  @override
  Future<void> saveBiometricAuth(bool isEnabled) async {
    savedLockValues.add(isEnabled);
    lockEnabled = isEnabled;
  }

  @override
  Future<User> getCurrentUser({bool fetchFromNetwork = false}) async =>
      const User();

  @override
  Future<void> updateUser(User user) async {}
}

/// A clock that only moves when the test moves it.
class FakeAppLockClock extends AppLockClock {
  FakeAppLockClock([DateTime? start])
    : current = start ?? DateTime(2026, 10, 28, 9);

  DateTime current;

  void advance(Duration duration) => current = current.add(duration);

  @override
  DateTime now() => current;
}
