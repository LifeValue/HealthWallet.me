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

import '../../../app_lock/app_lock_test_fakes.dart';

class _FakeUserRepository extends Fake implements UserRepository {
  User? storedUser;
  bool lockEnabled = false;
  Exception? getUserError;
  Exception? updateUserError;
  Exception? saveLockError;
  final List<User> updatedUsers = [];
  final List<bool> savedLockValues = [];

  @override
  Future<User> getCurrentUser() async {
    final error = getUserError;
    if (error != null) throw error;
    return storedUser ?? const User();
  }

  @override
  Future<void> updateUser(User user) async {
    final error = updateUserError;
    if (error != null) throw error;
    updatedUsers.add(user);
    storedUser = user;
  }

  @override
  Future<bool> isBiometricAuthEnabled() async => lockEnabled;

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

  @override
  Future<void> startListening() async {
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

final _isFailure = isA<UserState>().having(
  (s) => s.status.maybeWhen(failure: (_) => true, orElse: () => false),
  'is failure',
  isTrue,
);

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  final dispatcher = binding.platformDispatcher;

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
      'reports a failure when the theme cannot be saved',
      setUp: () => users.updateUserError = Exception('disk full'),
      build: buildBloc,
      act: (bloc) => bloc.add(const UserThemeToggled()),
      expect: () => [_state(status: const UserStatus.loading()), _isFailure],
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
      'leaves the lock off when the check throws',
      setUp: () => auth.authenticateError = Exception('NotAvailable'),
      build: buildBloc,
      act: (bloc) => bloc.add(const UserBiometricAuthToggled(true)),
      expect: () => [
        _state(status: const UserStatus.loading()),
        _state(status: const UserStatus.success(), lockEnabled: false),
      ],
      verify: (_) => expect(users.savedLockValues, isEmpty),
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
        _isFailure.having((s) => s.isBiometricAuthEnabled, 'lock', isTrue),
      ],
    );
  });

  group('UserNameUpdated', () {
    blocTest<UserBloc, UserState>(
      'shows and saves the new name',
      build: buildBloc,
      act: (bloc) => bloc.add(const UserNameUpdated('Maria')),
      expect: () => [
        isA<UserState>().having((s) => s.user.name, 'name', 'Maria'),
      ],
      verify: (_) => expect(users.updatedUsers.single.name, 'Maria'),
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
        expect(states.last, _isFailure);
        await sub.cancel();
        await bloc.close();
      },
      skip:
          'BUG: the name is shown before it is saved and never rolled back, '
          'and the save error escapes the handler instead of a failure state',
    );
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
      'reports a failure when the setting cannot be saved',
      setUp: () => users.updateUserError = Exception('disk full'),
      build: buildBloc,
      act: (bloc) => bloc.add(const UserReceiveModeToggled(true)),
      expect: () => [_state(status: const UserStatus.loading()), _isFailure],
      verify: (_) => expect(receiveMode.starts, 0),
    );
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
