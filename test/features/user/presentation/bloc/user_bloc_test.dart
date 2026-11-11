import 'dart:async';
import 'dart:ui';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/config/constants/region_preset.dart';
import 'package:health_wallet/core/config/constants/shared_prefs_constants.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/features/share_records/domain/services/receive_mode_service.dart';
import 'package:health_wallet/features/user/domain/entity/user.dart';
import 'package:health_wallet/features/user/domain/repository/user_repository.dart';
import 'package:health_wallet/features/user/presentation/bloc/user_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/log_capture.dart';
import '../../../app_lock/app_lock_test_fakes.dart';

class _FakeUserRepository extends Fake implements UserRepository {
  User? storedUser;
  bool lockEnabled = false;
  Exception? getUserError;
  Exception? updateUserError;
  Exception? saveLockError;
  Exception? readLockError;
  final List<User> updatedUsers = [];
  final List<bool> savedLockValues = [];

  /// While set, a save is stored right away but returns only once it
  /// completes, like a preferences write still flushing to disk.
  Completer<void>? pendingUpdate;

  /// Stores a save only once [pendingUpdate] completes, like a write that
  /// lands on disk after a read already ran.
  bool storeWhenDone = false;

  /// While set, a read returns what was stored when it started, once this
  /// completes.
  Completer<void>? pendingGet;

  @override
  Future<User> getCurrentUser() async {
    final error = getUserError;
    if (error != null) throw error;
    final user = storedUser ?? const User();
    await pendingGet?.future;
    return user;
  }

  @override
  Future<void> updateUser(User user) async {
    final error = updateUserError;
    if (error != null) throw error;
    updatedUsers.add(user);
    if (!storeWhenDone) storedUser = user;
    await pendingUpdate?.future;
    storedUser = user;
  }

  @override
  Future<bool> isBiometricAuthEnabled() async {
    final error = readLockError;
    if (error != null) throw error;
    return lockEnabled;
  }

  @override
  Future<void> saveBiometricAuth(bool isEnabled) async {
    final error = saveLockError;
    if (error != null) throw error;
    savedLockValues.add(isEnabled);
    lockEnabled = isEnabled;
  }
}

class _FakeReceiveModeService extends Fake implements ReceiveModeService {
  @override
  bool isListening = false;
  int starts = 0;
  int stops = 0;
  Exception? startError;

  @override
  Future<void> startListening() async {
    final error = startError;
    if (error != null) throw error;
    starts++;
    isListening = true;
  }

  @override
  Future<void> stopListening() async {
    stops++;
    isListening = false;
  }
}

TypeMatcher<UserState> _state({
  UserStatus? status,
  bool? lockEnabled,
  bool? showSetup,
}) {
  var m = isA<UserState>();
  if (status != null) m = m.having((s) => s.status, 'status', status);
  if (lockEnabled != null) {
    m = m.having((s) => s.isBiometricAuthEnabled, 'lock', lockEnabled);
  }
  if (showSetup != null) {
    m = m.having((s) => s.shouldShowBiometricsSetup, 'setup', showSetup);
  }
  return m;
}

TypeMatcher<UserState> _failure(UserSetting setting) => isA<UserState>().having(
  (s) => s.status.maybeWhen(
    failure: (_, setting) => setting,
    orElse: () => null,
  ),
  'failed setting',
  setting,
);

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  final dispatcher = binding.platformDispatcher;
  final logs = captureLogs();

  late _FakeUserRepository users;
  late FakeLockAuthService auth;
  late _FakeReceiveModeService receiveMode;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    users = _FakeUserRepository();
    auth = FakeLockAuthService();
    receiveMode = _FakeReceiveModeService();
    await getIt.reset();
    getIt.registerSingleton<ReceiveModeService>(receiveMode);
    dispatcher.localeTestValue = const Locale('en', 'US');
    dispatcher.platformBrightnessTestValue = Brightness.light;
  });

  tearDown(() async {
    dispatcher.clearLocaleTestValue();
    dispatcher.clearPlatformBrightnessTestValue();
    await getIt.reset();
  });

  UserBloc buildBloc() => UserBloc(users, auth);

  Future<SharedPreferences> prefs() => SharedPreferences.getInstance();

  group('UserInitialised', () {
    blocTest<UserBloc, UserState>(
      'loads the stored user and the lock setting',
      setUp: () {
        users
          ..storedUser = const User(name: 'Ana', isDarkMode: true)
          ..lockEnabled = true;
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const UserInitialised()),
      expect: () => [
        _state(status: const UserStatus.loading()),
        isA<UserState>()
            .having((s) => s.status, 'status', const UserStatus.success())
            .having((s) => s.user.name, 'name', 'Ana')
            .having((s) => s.user.isDarkMode, 'dark', isTrue)
            .having((s) => s.isBiometricAuthEnabled, 'lock', isTrue),
      ],
    );

    blocTest<UserBloc, UserState>(
      'restores the saved region, country and language',
      setUp: () => SharedPreferences.setMockInitialValues({
        SharedPrefsConstants.regionPreset: RegionPreset.uk.name,
        SharedPrefsConstants.countryCode: 'GB',
        SharedPrefsConstants.appLocale: 'ro',
      }),
      build: buildBloc,
      act: (bloc) => bloc.add(const UserInitialised()),
      skip: 1,
      expect: () => [
        isA<UserState>()
            .having((s) => s.regionPreset, 'region', RegionPreset.uk)
            .having((s) => s.countryCode, 'country', 'GB')
            .having((s) => s.appLocale, 'locale', const Locale('ro')),
      ],
    );

    blocTest<UserBloc, UserState>(
      'saves the region and country detected from the device on first run',
      setUp: () => dispatcher.localeTestValue = const Locale('de', 'de'),
      build: buildBloc,
      act: (bloc) => bloc.add(const UserInitialised()),
      skip: 1,
      expect: () => [
        isA<UserState>()
            .having((s) => s.regionPreset, 'region', RegionPreset.europe)
            .having((s) => s.countryCode, 'country', 'DE')
            .having((s) => s.appLocale, 'locale', isNull),
      ],
      verify: (_) async {
        final saved = await prefs();
        expect(
          saved.getString(SharedPrefsConstants.regionPreset),
          RegionPreset.europe.name,
        );
        expect(saved.getString(SharedPrefsConstants.countryCode), 'DE');
      },
    );

    blocTest<UserBloc, UserState>(
      'saves no country when the device locale has none',
      setUp: () => dispatcher.localeTestValue = const Locale('en'),
      build: buildBloc,
      act: (bloc) => bloc.add(const UserInitialised()),
      skip: 1,
      expect: () => [
        isA<UserState>()
            .having((s) => s.regionPreset, 'region', RegionPreset.us)
            .having((s) => s.countryCode, 'country', isNull),
      ],
      verify: (_) async {
        expect(
          (await prefs()).getString(SharedPrefsConstants.countryCode),
          isNull,
        );
      },
    );

    const detected = <String, (Locale, RegionPreset)>{
      'US': (Locale('en', 'US'), RegionPreset.us),
      'GB': (Locale('en', 'GB'), RegionPreset.uk),
      'an EU country': (Locale('ro', 'RO'), RegionPreset.europe),
      'another country, English': (Locale('en', 'AU'), RegionPreset.us),
      'another country, a European language': (
        Locale('fr', 'CA'),
        RegionPreset.europe,
      ),
      'no country, Spanish': (Locale('es'), RegionPreset.europe),
      'another country, another language': (
        Locale('ja', 'JP'),
        RegionPreset.europe,
      ),
    };
    for (final MapEntry(key: name, value: (locale, region))
        in detected.entries) {
      blocTest<UserBloc, UserState>(
        'detects the region for $name',
        setUp: () => dispatcher.localeTestValue = locale,
        build: buildBloc,
        act: (bloc) => bloc.add(const UserInitialised()),
        skip: 1,
        expect: () => [
          isA<UserState>().having((s) => s.regionPreset, 'region', region),
        ],
      );
    }

    blocTest<UserBloc, UserState>(
      'creates a user in the system theme when none is stored',
      setUp: () {
        users.getUserError = Exception('no user');
        dispatcher.platformBrightnessTestValue = Brightness.dark;
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const UserInitialised()),
      skip: 1,
      expect: () => [
        isA<UserState>()
            .having((s) => s.status, 'status', const UserStatus.success())
            .having((s) => s.user, 'user', const User(isDarkMode: true)),
      ],
      verify: (_) => expect(users.updatedUsers, [const User(isDarkMode: true)]),
    );

    blocTest<UserBloc, UserState>(
      'falls back to a default user when it cannot be created either',
      setUp: () {
        users
          ..getUserError = Exception('no user')
          ..updateUserError = Exception('disk full')
          ..lockEnabled = true;
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const UserInitialised()),
      skip: 1,
      expect: () => [
        isA<UserState>()
            .having((s) => s.status, 'status', const UserStatus.success())
            .having((s) => s.user, 'user', const User())
            .having((s) => s.isBiometricAuthEnabled, 'lock', isTrue),
      ],
    );

    blocTest<UserBloc, UserState>(
      'shows the user with the lock on when the lock setting cannot be read',
      setUp: () {
        users
          ..storedUser = const User(name: 'Ana')
          ..readLockError = Exception('keychain locked');
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const UserInitialised()),
      expect: () => [
        _state(status: const UserStatus.loading()),
        isA<UserState>()
            .having((s) => s.status, 'status', const UserStatus.success())
            .having((s) => s.user.name, 'name', 'Ana')
            // The app lock fails closed on the same read, so the switch
            // shows it on rather than off.
            .having((s) => s.isBiometricAuthEnabled, 'lock', isTrue),
      ],
      verify: (_) =>
          expect(logs, loggedWarning('Failed to read the biometric lock')),
    );

    blocTest<UserBloc, UserState>(
      'shows the user with the device region when the saved preferences '
      'cannot be read',
      setUp: () {
        // A value of the wrong type, as a corrupt preferences file leaves.
        SharedPreferences.setMockInitialValues({
          SharedPrefsConstants.regionPreset: 1,
          SharedPrefsConstants.countryCode: 2,
          SharedPrefsConstants.appLocale: 3,
        });
        users.storedUser = const User(name: 'Ana');
        dispatcher.localeTestValue = const Locale('en', 'GB');
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const UserInitialised()),
      expect: () => [
        _state(status: const UserStatus.loading()),
        isA<UserState>()
            .having((s) => s.status, 'status', const UserStatus.success())
            .having((s) => s.user.name, 'name', 'Ana')
            .having((s) => s.regionPreset, 'region', RegionPreset.uk)
            .having((s) => s.countryCode, 'country', 'GB')
            .having((s) => s.appLocale, 'locale', isNull),
      ],
      verify: (_) =>
          expect(logs, loggedWarning('Failed to read the saved preferences')),
    );

    blocTest<UserBloc, UserState>(
      'UserDataUpdatedFromSync reloads the user',
      build: buildBloc,
      act: (bloc) async {
        bloc.add(const UserInitialised());
        await pumpEventQueue();
        users.storedUser = const User(name: 'Synced');
        bloc.add(const UserDataUpdatedFromSync());
      },
      skip: 3,
      expect: () => [
        isA<UserState>().having((s) => s.user.name, 'name', 'Synced'),
      ],
    );
  });

  group('UserThemeToggled', () {
    blocTest<UserBloc, UserState>(
      'switches the theme and saves it',
      build: buildBloc,
      act: (bloc) => bloc.add(const UserThemeToggled()),
      expect: () => [
        _state(status: const UserStatus.loading()),
        isA<UserState>()
            .having((s) => s.status, 'status', const UserStatus.success())
            .having((s) => s.user.isDarkMode, 'dark', isTrue),
      ],
      verify: (_) => expect(users.updatedUsers.single.isDarkMode, isTrue),
    );

    blocTest<UserBloc, UserState>(
      'reports a theme failure and keeps the old theme when it cannot be '
      'saved',
      setUp: () => users.updateUserError = Exception('disk full'),
      build: buildBloc,
      act: (bloc) => bloc.add(const UserThemeToggled()),
      expect: () => [
        _state(status: const UserStatus.loading()),
        _failure(
          UserSetting.theme,
        ).having((s) => s.user.isDarkMode, 'dark', isFalse),
      ],
    );

    blocTest<UserBloc, UserState>(
      'a second toggle waits for the first and switches back',
      build: buildBloc,
      act: (bloc) => bloc
        ..add(const UserThemeToggled())
        ..add(const UserThemeToggled()),
      skip: 2,
      expect: () => [
        _state(status: const UserStatus.loading()),
        isA<UserState>()
            .having((s) => s.status, 'status', const UserStatus.success())
            .having((s) => s.user.isDarkMode, 'dark', isFalse),
      ],
      verify: (_) => expect(
        users.updatedUsers.map((u) => u.isDarkMode),
        [true, false],
      ),
    );
  });

  group('UserBiometricAuthToggled on', () {
    blocTest<UserBloc, UserState>(
      'turns the lock on after a successful check',
      setUp: () => auth.results.add(true),
      build: buildBloc,
      act: (bloc) => bloc.add(const UserBiometricAuthToggled(true)),
      expect: () => [
        _state(status: const UserStatus.loading()),
        _state(status: const UserStatus.success(), lockEnabled: true),
      ],
      verify: (_) => expect(users.savedLockValues, [true]),
    );

    blocTest<UserBloc, UserState>(
      'leaves the lock off when the check fails',
      setUp: () => auth.results.add(false),
      build: buildBloc,
      act: (bloc) => bloc.add(const UserBiometricAuthToggled(true)),
      expect: () => [
        _state(status: const UserStatus.loading()),
        _state(status: const UserStatus.success(), lockEnabled: false),
      ],
      verify: (_) => expect(users.savedLockValues, isEmpty),
    );

    blocTest<UserBloc, UserState>(
      'reports a biometric failure and leaves the lock off when the check '
      'throws',
      setUp: () => auth.authenticateError = Exception('NotAvailable'),
      build: buildBloc,
      act: (bloc) => bloc.add(const UserBiometricAuthToggled(true)),
      expect: () => [
        _state(status: const UserStatus.loading()),
        _failure(
          UserSetting.biometric,
        ).having((s) => s.isBiometricAuthEnabled, 'lock', isFalse),
      ],
      verify: (_) => expect(users.savedLockValues, isEmpty),
    );

    blocTest<UserBloc, UserState>(
      'reports a biometric failure and leaves the lock off when it cannot be '
      'saved',
      setUp: () {
        users.saveLockError = Exception('disk full');
        auth.results.add(true);
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const UserBiometricAuthToggled(true)),
      expect: () => [
        _state(status: const UserStatus.loading()),
        _failure(
          UserSetting.biometric,
        ).having((s) => s.isBiometricAuthEnabled, 'lock', isFalse),
      ],
    );

    blocTest<UserBloc, UserState>(
      'asks to set up a passcode when the device has none',
      setUp: () => auth.deviceSecure = false,
      build: buildBloc,
      act: (bloc) => bloc.add(const UserBiometricAuthToggled(true)),
      expect: () => [
        _state(status: const UserStatus.loading()),
        _state(
          status: const UserStatus.success(),
          lockEnabled: false,
          showSetup: true,
        ),
      ],
      verify: (_) {
        expect(auth.authenticateCalls, 0);
        expect(users.savedLockValues, isEmpty);
      },
    );

    blocTest<UserBloc, UserState>(
      'UserBiometricsSetupShown clears the setup request',
      setUp: () => auth.deviceSecure = false,
      build: buildBloc,
      act: (bloc) async {
        bloc.add(const UserBiometricAuthToggled(true));
        await pumpEventQueue();
        bloc.add(const UserBiometricsSetupShown());
      },
      skip: 2,
      expect: () => [_state(showSetup: false)],
    );

    blocTest<UserBloc, UserState>(
      'drops a second toggle while the first prompt is open',
      build: buildBloc,
      act: (bloc) async {
        auth.pending = Completer<bool>();
        bloc
          ..add(const UserBiometricAuthToggled(true))
          ..add(const UserBiometricAuthToggled(true));
        await pumpEventQueue();
        auth.pending!.complete(true);
      },
      expect: () => [
        _state(status: const UserStatus.loading()),
        _state(status: const UserStatus.success(), lockEnabled: true),
      ],
      verify: (_) => expect(auth.authenticateCalls, 1),
    );
  });

  group('UserBiometricAuthToggled off (Disable lock)', () {
    const lockOn = UserState(
      status: UserStatus.success(),
      isBiometricAuthEnabled: true,
    );

    blocTest<UserBloc, UserState>(
      'turns the lock off after a successful check',
      setUp: () {
        users.lockEnabled = true;
        auth.results.add(true);
      },
      build: buildBloc,
      seed: () => lockOn,
      act: (bloc) => bloc.add(const UserBiometricAuthToggled(false)),
      expect: () => [
        _state(status: const UserStatus.loading(), lockEnabled: true),
        _state(status: const UserStatus.success(), lockEnabled: false),
      ],
      verify: (_) {
        expect(auth.authenticateCalls, 1);
        expect(users.savedLockValues, [false]);
        expect(users.lockEnabled, isFalse);
      },
    );

    blocTest<UserBloc, UserState>(
      'keeps the lock on when the check fails',
      setUp: () {
        users.lockEnabled = true;
        auth.results.add(false);
      },
      build: buildBloc,
      seed: () => lockOn,
      act: (bloc) => bloc.add(const UserBiometricAuthToggled(false)),
      expect: () => [
        _state(status: const UserStatus.loading(), lockEnabled: true),
        _state(status: const UserStatus.success(), lockEnabled: true),
      ],
      verify: (_) {
        expect(users.savedLockValues, isEmpty);
        expect(users.lockEnabled, isTrue);
      },
    );

    blocTest<UserBloc, UserState>(
      'turns the lock off without a prompt when the device has no passcode '
      'any more',
      setUp: () {
        users.lockEnabled = true;
        auth.deviceSecure = false;
      },
      build: buildBloc,
      seed: () => lockOn,
      act: (bloc) => bloc.add(const UserBiometricAuthToggled(false)),
      expect: () => [
        _state(status: const UserStatus.loading()),
        _state(status: const UserStatus.success(), lockEnabled: false),
      ],
      verify: (_) {
        expect(auth.authenticateCalls, 0);
        expect(users.savedLockValues, [false]);
      },
    );

    blocTest<UserBloc, UserState>(
      'reports a failure and keeps the lock on when it cannot be saved',
      setUp: () {
        users
          ..lockEnabled = true
          ..saveLockError = Exception('disk full');
        auth.results.add(true);
      },
      build: buildBloc,
      seed: () => lockOn,
      act: (bloc) => bloc.add(const UserBiometricAuthToggled(false)),
      expect: () => [
        _state(status: const UserStatus.loading()),
        _failure(
          UserSetting.biometric,
        ).having((s) => s.isBiometricAuthEnabled, 'lock', isTrue),
      ],
    );

    blocTest<UserBloc, UserState>(
      'a declined prompt keeps the lock on without a failure',
      setUp: () {
        users.lockEnabled = true;
        auth.results.add(false);
      },
      build: buildBloc,
      seed: () => lockOn,
      act: (bloc) => bloc.add(const UserBiometricAuthToggled(false)),
      expect: () => [
        _state(status: const UserStatus.loading(), lockEnabled: true),
        _state(status: const UserStatus.success(), lockEnabled: true),
      ],
    );
  });

  group('UserNameUpdated', () {
    blocTest<UserBloc, UserState>(
      'saves the new name, then shows it with a name success',
      build: buildBloc,
      act: (bloc) => bloc.add(const UserNameUpdated('Maria')),
      expect: () => [
        _state(
          status: const UserStatus.loading(),
        ).having((s) => s.user.name, 'name', ''),
        isA<UserState>()
            .having(
              (s) => s.status,
              'status',
              const UserStatus.success(setting: UserSetting.name),
            )
            .having((s) => s.user.name, 'name', 'Maria'),
      ],
      verify: (_) => expect(users.updatedUsers.single.name, 'Maria'),
    );

    blocTest<UserBloc, UserState>(
      'keeps the other fields of the user',
      build: buildBloc,
      seed: () => const UserState(
        user: User(name: 'Ana', isDarkMode: true, isReceiveModeEnabled: true),
      ),
      act: (bloc) => bloc.add(const UserNameUpdated('Maria')),
      skip: 1,
      expect: () => [
        isA<UserState>().having(
          (s) => s.user,
          'user',
          const User(
            name: 'Maria',
            isDarkMode: true,
            isReceiveModeEnabled: true,
          ),
        ),
      ],
      verify: (_) => expect(
        users.storedUser,
        const User(name: 'Maria', isDarkMode: true, isReceiveModeEnabled: true),
      ),
    );

    test(
      'reports a failure and keeps the saved name when the save fails',
      () async {
        users.updateUserError = Exception('disk full');
        final bloc = buildBloc();
        final states = <UserState>[];
        final sub = bloc.stream.listen(states.add);

        bloc.add(const UserNameUpdated('Maria'));
        await pumpEventQueue();

        expect(states.last.user.name, '');
        expect(states.last, _failure(UserSetting.name));
        await sub.cancel();
        await bloc.close();
      },
    );
  });

  group('concurrent saves', () {
    test('a theme toggled while the name saves keeps both', () async {
      final bloc = buildBloc();
      final saving = users.pendingUpdate = Completer<void>();

      bloc.add(const UserNameUpdated('Maria'));
      await pumpEventQueue();
      bloc.add(const UserThemeToggled());
      await pumpEventQueue();
      users.pendingUpdate = null;
      saving.complete();
      await pumpEventQueue();

      const both = User(name: 'Maria', isDarkMode: true);
      expect(bloc.state.user, both);
      expect(users.storedUser, both);
      await bloc.close();
    });

    test('a name saved while the theme saves keeps both', () async {
      final bloc = buildBloc();
      final saving = users.pendingUpdate = Completer<void>();

      bloc.add(const UserThemeToggled());
      await pumpEventQueue();
      bloc.add(const UserNameUpdated('Maria'));
      await pumpEventQueue();
      users.pendingUpdate = null;
      saving.complete();
      await pumpEventQueue();

      const both = User(name: 'Maria', isDarkMode: true);
      expect(bloc.state.user, both);
      expect(users.storedUser, both);
      await bloc.close();
    });

    test('receive mode switched while the name saves keeps both', () async {
      final bloc = buildBloc();
      final saving = users.pendingUpdate = Completer<void>();

      bloc.add(const UserNameUpdated('Maria'));
      await pumpEventQueue();
      bloc.add(const UserReceiveModeToggled(true));
      await pumpEventQueue();
      users.pendingUpdate = null;
      saving.complete();
      await pumpEventQueue();

      const both = User(name: 'Maria', isReceiveModeEnabled: true);
      expect(bloc.state.user, both);
      expect(users.storedUser, both);
      await bloc.close();
    });
  });

  test('a sync reload during a name save ends with the new name', () async {
    final bloc = buildBloc();
    final saving = users.pendingUpdate = Completer<void>();
    users
      ..storedUser = const User(name: 'Ana')
      ..storeWhenDone = true;

    bloc.add(const UserNameUpdated('Maria'));
    await pumpEventQueue();
    final reading = users.pendingGet = Completer<void>();
    bloc.add(const UserDataUpdatedFromSync());
    await pumpEventQueue();
    users.pendingUpdate = null;
    saving.complete();
    await pumpEventQueue();
    users.pendingGet = null;
    reading.complete();
    await pumpEventQueue();

    expect(bloc.state.user.name, 'Maria');
    expect(users.storedUser?.name, 'Maria');
    await bloc.close();
  });

  group('UserReceiveModeToggled (Share Proximity)', () {
    blocTest<UserBloc, UserState>(
      'turns receive mode on and starts listening',
      build: buildBloc,
      act: (bloc) => bloc.add(const UserReceiveModeToggled(true)),
      expect: () => [
        _state(status: const UserStatus.loading()),
        isA<UserState>()
            .having((s) => s.status, 'status', const UserStatus.success())
            .having((s) => s.user.isReceiveModeEnabled, 'on', isTrue),
      ],
      verify: (_) {
        expect(receiveMode.starts, 1);
        expect(users.updatedUsers.single.isReceiveModeEnabled, isTrue);
      },
    );

    blocTest<UserBloc, UserState>(
      'does not start listening twice',
      setUp: () => receiveMode.isListening = true,
      build: buildBloc,
      act: (bloc) => bloc.add(const UserReceiveModeToggled(true)),
      skip: 1,
      expect: () => [
        isA<UserState>().having((s) => s.user.isReceiveModeEnabled, 'on', true),
      ],
      verify: (_) => expect(receiveMode.starts, 0),
    );

    blocTest<UserBloc, UserState>(
      'turns receive mode off and stops listening',
      setUp: () => receiveMode.isListening = true,
      build: buildBloc,
      seed: () => const UserState(user: User(isReceiveModeEnabled: true)),
      act: (bloc) => bloc.add(const UserReceiveModeToggled(false)),
      skip: 1,
      expect: () => [
        isA<UserState>().having(
          (s) => s.user.isReceiveModeEnabled,
          'on',
          isFalse,
        ),
      ],
      verify: (_) => expect(receiveMode.stops, 1),
    );

    blocTest<UserBloc, UserState>(
      'does not stop when it is not listening',
      build: buildBloc,
      act: (bloc) => bloc.add(const UserReceiveModeToggled(false)),
      skip: 1,
      expect: () => [
        _state(status: const UserStatus.success()),
      ],
      verify: (_) => expect(receiveMode.stops, 0),
    );

    blocTest<UserBloc, UserState>(
      'reports a receive-mode failure, keeps it off and stops listening when '
      'the setting cannot be saved',
      setUp: () => users.updateUserError = Exception('disk full'),
      build: buildBloc,
      act: (bloc) => bloc.add(const UserReceiveModeToggled(true)),
      expect: () => [
        _state(status: const UserStatus.loading()),
        _failure(
          UserSetting.receiveMode,
        ).having((s) => s.user.isReceiveModeEnabled, 'on', isFalse),
      ],
      verify: (_) => expect(receiveMode.isListening, isFalse),
    );

    blocTest<UserBloc, UserState>(
      'reports a receive-mode failure and saves nothing when listening cannot '
      'start',
      setUp: () => receiveMode.startError = Exception('Bluetooth off'),
      build: buildBloc,
      act: (bloc) => bloc.add(const UserReceiveModeToggled(true)),
      expect: () => [
        _state(status: const UserStatus.loading()),
        _failure(
          UserSetting.receiveMode,
        ).having((s) => s.user.isReceiveModeEnabled, 'on', isFalse),
      ],
      verify: (_) => expect(users.updatedUsers, isEmpty),
    );

    blocTest<UserBloc, UserState>(
      'reports a receive-mode failure and saves nothing when the service '
      'cannot be found',
      setUp: () => getIt.unregister<ReceiveModeService>(),
      build: buildBloc,
      act: (bloc) => bloc.add(const UserReceiveModeToggled(true)),
      expect: () => [
        _state(status: const UserStatus.loading()),
        _failure(
          UserSetting.receiveMode,
        ).having((s) => s.user.isReceiveModeEnabled, 'on', isFalse),
      ],
      verify: (_) => expect(users.updatedUsers, isEmpty),
    );
  });

  blocTest<UserBloc, UserState>(
    'puts listening back on when turning it off cannot be saved, and still '
    'reports the failure when it cannot start again',
    setUp: () {
      receiveMode.isListening = true;
      users.updateUserError = Exception('disk full');
    },
    build: buildBloc,
    seed: () => const UserState(user: User(isReceiveModeEnabled: true)),
    act: (bloc) {
      // Stopping works; starting again, to undo it, fails.
      receiveMode.startError = Exception('Bluetooth off');
      bloc.add(const UserReceiveModeToggled(false));
    },
    expect: () => [
      _state(status: const UserStatus.loading()),
      _failure(
        UserSetting.receiveMode,
      ).having((s) => s.user.isReceiveModeEnabled, 'on', isTrue),
    ],
    verify: (_) {
      expect(receiveMode.stops, 1);
      expect(receiveMode.isListening, isFalse);
    },
  );

  test('a sync reload that cannot read the lock setting shows the user and '
      'does not hold up the saves queued after it', () async {
    users
      ..lockEnabled = true
      ..storedUser = const User(name: 'Synced');
    final errors = <Object>[];
    late UserBloc bloc;

    // The bloc rethrows a handler's error into the zone it was built in.
    await runZonedGuarded(() async {
      bloc = buildBloc()..add(const UserInitialised());
      await pumpEventQueue();
      users.readLockError = Exception('keychain locked');
      bloc
        ..add(const UserDataUpdatedFromSync())
        ..add(const UserThemeToggled());
      await pumpEventQueue();
    }, (error, _) => errors.add(error));

    expect(errors, isEmpty);
    expect(bloc.state.user.name, 'Synced');
    expect(bloc.state.isBiometricAuthEnabled, isTrue);
    expect(users.storedUser?.isDarkMode, isTrue);
    expect(bloc.state.user.isDarkMode, isTrue);
    expect(bloc.state.status, const UserStatus.success());
    expect(logs, loggedWarning('Failed to read the biometric lock'));
    await bloc.close();
  });

  group('preferences', () {
    blocTest<UserBloc, UserState>(
      'UserRegionPresetChanged saves and shows the region',
      build: buildBloc,
      act: (bloc) => bloc.add(const UserRegionPresetChanged(RegionPreset.uk)),
      expect: () => [
        isA<UserState>().having(
          (s) => s.regionPreset,
          'region',
          RegionPreset.uk,
        ),
      ],
      verify: (_) async => expect(
        (await prefs()).getString(SharedPrefsConstants.regionPreset),
        RegionPreset.uk.name,
      ),
    );

    blocTest<UserBloc, UserState>(
      'UserLocaleChanged saves and shows the language',
      build: buildBloc,
      act: (bloc) => bloc.add(const UserLocaleChanged(Locale('de'))),
      expect: () => [
        isA<UserState>().having(
          (s) => s.appLocale,
          'locale',
          const Locale('de'),
        ),
      ],
      verify: (_) async => expect(
        (await prefs()).getString(SharedPrefsConstants.appLocale),
        'de',
      ),
    );

    blocTest<UserBloc, UserState>(
      'UserLocaleChanged(null) goes back to the device language',
      setUp: () => SharedPreferences.setMockInitialValues({
        SharedPrefsConstants.appLocale: 'de',
      }),
      build: buildBloc,
      seed: () => const UserState(appLocale: Locale('de')),
      act: (bloc) => bloc.add(const UserLocaleChanged(null)),
      expect: () => [
        isA<UserState>().having((s) => s.appLocale, 'locale', isNull),
      ],
      verify: (_) async => expect(
        (await prefs()).getString(SharedPrefsConstants.appLocale),
        isNull,
      ),
    );
  });
}
