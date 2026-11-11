import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/features/user/data/data_source/local/user_local_data_source.dart';
import 'package:health_wallet/features/user/data/repository/user_repository_impl.dart';
import 'package:health_wallet/features/user/domain/entity/user.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeUserLocalDataSource implements UserLocalDataSource {
  User? stored;
  int clears = 0;

  @override
  Future<User?> getUser() async => stored;

  @override
  Future<void> saveUser(User user) async => stored = user;

  @override
  Future<void> clearUser() async {
    clears++;
    stored = null;
  }
}

void main() {
  late _FakeUserLocalDataSource local;
  late SharedPreferences prefs;
  late UserRepositoryImpl repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    local = _FakeUserLocalDataSource();
    repository = UserRepositoryImpl(local, prefs);
  });

  group('updateUser', () {
    test('saves the user locally without waiting', () {
      fakeAsync((async) {
        var done = false;
        repository
            .updateUser(const User(name: 'Maria', isDarkMode: true))
            .then((_) => done = true);

        async.flushMicrotasks();

        expect(done, isTrue);
        expect(async.elapsed, Duration.zero);
        expect(local.stored, const User(name: 'Maria', isDarkMode: true));
      });
    });
  });

  group('getCurrentUser', () {
    test('returns the stored user', () async {
      local.stored = const User(name: 'Ana');

      expect(await repository.getCurrentUser(), const User(name: 'Ana'));
    });

    test('throws when no user is stored', () {
      expect(repository.getCurrentUser(), throwsException);
    });
  });

  test('clearUser removes the stored user', () async {
    local.stored = const User(name: 'Ana');

    await repository.clearUser();

    expect(local.stored, isNull);
    expect(local.clears, 1);
  });

  group('biometric lock', () {
    test('is off when nothing is saved', () async {
      expect(await repository.isBiometricAuthEnabled(), isFalse);
    });

    test('saveBiometricAuth stores the setting', () async {
      await repository.saveBiometricAuth(true);

      expect(await repository.isBiometricAuthEnabled(), isTrue);
      expect(prefs.getBool('isBiometricAuthEnabled'), isTrue);

      await repository.saveBiometricAuth(false);

      expect(await repository.isBiometricAuthEnabled(), isFalse);
    });
  });
}
