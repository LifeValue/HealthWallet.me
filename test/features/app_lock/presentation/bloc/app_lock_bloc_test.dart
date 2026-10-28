import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/features/app_lock/presentation/bloc/app_lock_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app_lock_test_fakes.dart';

const _checking = AppLockState();
const _locked = AppLockState(status: AppLockStatus.locked);
const _prompting = AppLockState(
  status: AppLockStatus.locked,
  isAuthenticating: true,
);
const _unlocked = AppLockState(status: AppLockStatus.unlocked);

/// What the bloc emits when it locks on resume and prompts.
const _lockAndPrompt = [_locked, _prompting];

void main() {
  late FakeLockAuthService auth;
  late FakeLockUserRepository users;
  late FakeAppLockClock clock;
  late SharedPreferences prefs;

  Future<void> givenOnboarding({required bool done}) async {
    SharedPreferences.setMockInitialValues({'hasSeenOnboarding': done});
    prefs = await SharedPreferences.getInstance();
  }

  setUp(() async {
    auth = FakeLockAuthService();
    users = FakeLockUserRepository();
    clock = FakeAppLockClock();
    await givenOnboarding(done: true);
  });

  AppLockBloc buildBloc() => AppLockBloc(auth, users, prefs, clock);

  /// Starts unlocked: the lock is on and the first prompt succeeds.
  Future<void> startUnlocked(AppLockBloc bloc) async {
    auth.results.add(true);
    bloc.add(const AppLockStarted());
    await bloc.stream.firstWhere((s) => s == _unlocked);
  }

  Future<void> lifecycle(AppLockBloc bloc, AppLifecycleState state) async {
    bloc.add(AppLockLifecycleChanged(state));
    await pumpEventQueue();
  }

  test('starts covered while it checks whether the lock applies', () {
    expect(buildBloc().state, _checking);
    expect(_checking.coversApp, isTrue);
    expect(_locked.coversApp, isTrue);
    expect(_unlocked.coversApp, isFalse);
  });

  group('start', () {
    blocTest<AppLockBloc, AppLockState>(
      'unlocks without a prompt before onboarding is done',
      setUp: () => givenOnboarding(done: false),
      build: buildBloc,
      act: (bloc) => bloc.add(const AppLockStarted()),
      expect: () => [_unlocked],
      verify: (_) => expect(auth.authenticateCalls, 0),
    );

    blocTest<AppLockBloc, AppLockState>(
      'unlocks without a prompt when the onboarding flag was never written',
      setUp: () async {
        SharedPreferences.setMockInitialValues({});
        prefs = await SharedPreferences.getInstance();
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const AppLockStarted()),
      expect: () => [_unlocked],
      verify: (_) => expect(auth.authenticateCalls, 0),
    );

    blocTest<AppLockBloc, AppLockState>(
      'unlocks without a prompt when the lock is off',
      setUp: () => users.lockEnabled = false,
      build: buildBloc,
      act: (bloc) => bloc.add(const AppLockStarted()),
      expect: () => [_unlocked],
      verify: (_) => expect(auth.authenticateCalls, 0),
    );

    blocTest<AppLockBloc, AppLockState>(
      'Device no longer secure: no lock when the OS cannot authenticate',
      setUp: () => auth.deviceSecure = false,
      build: buildBloc,
      act: (bloc) => bloc.add(const AppLockStarted()),
      expect: () => [_unlocked],
      verify: (_) => expect(auth.authenticateCalls, 0),
    );

    blocTest<AppLockBloc, AppLockState>(
      'locks, prompts and unlocks when authentication succeeds',
      setUp: () => auth.results.add(true),
      build: buildBloc,
      act: (bloc) => bloc.add(const AppLockStarted()),
      expect: () => [_locked, _prompting, _unlocked],
      verify: (_) => expect(auth.authenticateCalls, 1),
    );

    blocTest<AppLockBloc, AppLockState>(
      'Lock fails: a cancelled prompt leaves the lock screen up',
      setUp: () => auth.results.add(false),
      build: buildBloc,
      act: (bloc) => bloc.add(const AppLockStarted()),
      expect: () => [_locked, _prompting, _locked],
    );

    blocTest<AppLockBloc, AppLockState>(
      'stays locked when the prompt throws',
      setUp: () => auth.authenticateError = Exception('NotAvailable'),
      build: buildBloc,
      act: (bloc) => bloc.add(const AppLockStarted()),
      expect: () => [_locked, _prompting, _locked],
    );

    blocTest<AppLockBloc, AppLockState>(
      'Passcode-only device: locks and the passcode unlocks it',
      setUp: () {
        auth
          ..biometricAvailable = false
          ..deviceSecure = true
          ..results.add(true);
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const AppLockStarted()),
      expect: () => [_locked, _prompting, _unlocked],
      verify: (_) => expect(auth.authenticateCalls, 1),
    );

    blocTest<AppLockBloc, AppLockState>(
      'fails closed when the lock setting cannot be read',
      setUp: () => users.readError = Exception('prefs'),
      build: buildBloc,
      act: (bloc) => bloc.add(const AppLockStarted()),
      expect: () => [_locked, _prompting, _locked],
      verify: (_) => expect(auth.authenticateCalls, 1),
    );
  });

  group('Retry', () {
    blocTest<AppLockBloc, AppLockState>(
      'prompts again after a cancelled prompt and unlocks',
      setUp: () => auth.results.addAll([false, true]),
      build: buildBloc,
      act: (bloc) async {
        bloc.add(const AppLockStarted());
        await pumpEventQueue();
        bloc.add(const AppLockUnlockRequested());
      },
      expect: () => [
        _locked,
        _prompting,
        _locked,
        _prompting,
        _unlocked,
      ],
      verify: (_) => expect(auth.authenticateCalls, 2),
    );

    blocTest<AppLockBloc, AppLockState>(
      'stays locked when the retry is cancelled too',
      setUp: () => auth.results.addAll([false, false]),
      build: buildBloc,
      act: (bloc) async {
        bloc.add(const AppLockStarted());
        await pumpEventQueue();
        bloc.add(const AppLockUnlockRequested());
      },
      expect: () => [_locked, _prompting, _locked, _prompting, _locked],
    );

    blocTest<AppLockBloc, AppLockState>(
      'is ignored while a prompt is open',
      build: buildBloc,
      act: (bloc) async {
        auth.pending = Completer<bool>();
        bloc.add(const AppLockStarted());
        await pumpEventQueue();
        bloc.add(const AppLockUnlockRequested());
        await pumpEventQueue();
        auth.pending!.complete(true);
      },
      expect: () => [_locked, _prompting, _unlocked],
      verify: (_) => expect(auth.authenticateCalls, 1),
    );

    blocTest<AppLockBloc, AppLockState>(
      'does nothing when the app is unlocked',
      setUp: () => users.lockEnabled = false,
      build: buildBloc,
      act: (bloc) async {
        bloc.add(const AppLockStarted());
        await pumpEventQueue();
        bloc.add(const AppLockUnlockRequested());
      },
      expect: () => [_unlocked],
      verify: (_) => expect(auth.authenticateCalls, 0),
    );

    blocTest<AppLockBloc, AppLockState>(
      'unlocks without a prompt once the device has no passcode any more',
      setUp: () => auth.results.add(false),
      build: buildBloc,
      act: (bloc) async {
        bloc.add(const AppLockStarted());
        await pumpEventQueue();
        auth.deviceSecure = false;
        bloc.add(const AppLockUnlockRequested());
      },
      expect: () => [_locked, _prompting, _locked, _unlocked],
      verify: (_) => expect(auth.authenticateCalls, 1),
    );
  });

  group('Resume', () {
    blocTest<AppLockBloc, AppLockState>(
      'locks and prompts after 31 s in the background',
      build: buildBloc,
      act: (bloc) async {
        await startUnlocked(bloc);
        await lifecycle(bloc, AppLifecycleState.paused);
        clock.advance(const Duration(seconds: 31));
        await lifecycle(bloc, AppLifecycleState.resumed);
      },
      skip: 3,
      expect: () => [..._lockAndPrompt, _locked],
      verify: (_) => expect(auth.authenticateCalls, 2),
    );

    blocTest<AppLockBloc, AppLockState>(
      'unlocks again when the prompt on resume succeeds',
      build: buildBloc,
      act: (bloc) async {
        await startUnlocked(bloc);
        await lifecycle(bloc, AppLifecycleState.paused);
        clock.advance(const Duration(seconds: 31));
        auth.results.add(true);
        await lifecycle(bloc, AppLifecycleState.resumed);
      },
      skip: 3,
      expect: () => [..._lockAndPrompt, _unlocked],
    );

    blocTest<AppLockBloc, AppLockState>(
      'stays unlocked after 10 s in the background',
      build: buildBloc,
      act: (bloc) async {
        await startUnlocked(bloc);
        await lifecycle(bloc, AppLifecycleState.paused);
        clock.advance(const Duration(seconds: 10));
        await lifecycle(bloc, AppLifecycleState.resumed);
      },
      skip: 3,
      expect: () => <AppLockState>[],
      verify: (_) => expect(auth.authenticateCalls, 1),
    );

    blocTest<AppLockBloc, AppLockState>(
      'stays unlocked after exactly 30 s (it locks after more than 30 s)',
      build: buildBloc,
      act: (bloc) async {
        await startUnlocked(bloc);
        await lifecycle(bloc, AppLifecycleState.paused);
        clock.advance(AppLockBloc.lockTimeout);
        await lifecycle(bloc, AppLifecycleState.resumed);
      },
      skip: 3,
      expect: () => <AppLockState>[],
    );

    blocTest<AppLockBloc, AppLockState>(
      'locks when the clock was set back while in the background',
      build: buildBloc,
      act: (bloc) async {
        await startUnlocked(bloc);
        await lifecycle(bloc, AppLifecycleState.paused);
        clock.advance(const Duration(hours: -1));
        await lifecycle(bloc, AppLifecycleState.resumed);
      },
      skip: 3,
      expect: () => [..._lockAndPrompt, _locked],
      verify: (_) => expect(auth.authenticateCalls, 2),
    );

    blocTest<AppLockBloc, AppLockState>(
      'times the background from the first hidden, not the later paused',
      build: buildBloc,
      act: (bloc) async {
        await startUnlocked(bloc);
        await lifecycle(bloc, AppLifecycleState.inactive);
        await lifecycle(bloc, AppLifecycleState.hidden);
        clock.advance(const Duration(seconds: 20));
        await lifecycle(bloc, AppLifecycleState.paused);
        clock.advance(const Duration(seconds: 11));
        await lifecycle(bloc, AppLifecycleState.hidden);
        await lifecycle(bloc, AppLifecycleState.inactive);
        await lifecycle(bloc, AppLifecycleState.resumed);
      },
      skip: 3,
      expect: () => [..._lockAndPrompt, _locked],
    );

    blocTest<AppLockBloc, AppLockState>(
      'measures each background stay on its own',
      build: buildBloc,
      act: (bloc) async {
        await startUnlocked(bloc);
        await lifecycle(bloc, AppLifecycleState.paused);
        clock.advance(const Duration(seconds: 20));
        await lifecycle(bloc, AppLifecycleState.resumed);
        clock.advance(const Duration(minutes: 5));
        await lifecycle(bloc, AppLifecycleState.paused);
        clock.advance(const Duration(seconds: 20));
        await lifecycle(bloc, AppLifecycleState.resumed);
      },
      skip: 3,
      expect: () => <AppLockState>[],
    );

    blocTest<AppLockBloc, AppLockState>(
      'ignores inactive and detached (focus loss, notification shade)',
      build: buildBloc,
      act: (bloc) async {
        await startUnlocked(bloc);
        await lifecycle(bloc, AppLifecycleState.inactive);
        await lifecycle(bloc, AppLifecycleState.detached);
        clock.advance(const Duration(minutes: 5));
        await lifecycle(bloc, AppLifecycleState.resumed);
      },
      skip: 3,
      expect: () => <AppLockState>[],
    );

    blocTest<AppLockBloc, AppLockState>(
      'a resume without a background stay does nothing',
      build: buildBloc,
      act: (bloc) async {
        await startUnlocked(bloc);
        clock.advance(const Duration(minutes: 5));
        await lifecycle(bloc, AppLifecycleState.resumed);
      },
      skip: 3,
      expect: () => <AppLockState>[],
    );

    blocTest<AppLockBloc, AppLockState>(
      'stays unlocked after 31 s when the lock was turned off meanwhile',
      build: buildBloc,
      act: (bloc) async {
        await startUnlocked(bloc);
        users.lockEnabled = false;
        await lifecycle(bloc, AppLifecycleState.paused);
        clock.advance(const Duration(seconds: 31));
        await lifecycle(bloc, AppLifecycleState.resumed);
      },
      skip: 3,
      expect: () => <AppLockState>[],
    );

    blocTest<AppLockBloc, AppLockState>(
      'does not prompt by itself when the app comes back still locked',
      setUp: () => auth.results.add(false),
      build: buildBloc,
      act: (bloc) async {
        bloc.add(const AppLockStarted());
        await pumpEventQueue();
        await lifecycle(bloc, AppLifecycleState.paused);
        clock.advance(const Duration(minutes: 5));
        await lifecycle(bloc, AppLifecycleState.resumed);
      },
      expect: () => [_locked, _prompting, _locked],
      verify: (_) => expect(auth.authenticateCalls, 1),
    );

    blocTest<AppLockBloc, AppLockState>(
      'ignores lifecycle changes caused by the open prompt',
      build: buildBloc,
      act: (bloc) async {
        auth.pending = Completer<bool>();
        bloc.add(const AppLockStarted());
        await pumpEventQueue();
        // The passcode screen sends the app to the background and back.
        await lifecycle(bloc, AppLifecycleState.inactive);
        await lifecycle(bloc, AppLifecycleState.paused);
        clock.advance(const Duration(minutes: 2));
        auth.pending!.complete(true);
        await pumpEventQueue();
        await lifecycle(bloc, AppLifecycleState.resumed);
      },
      expect: () => [_locked, _prompting, _unlocked],
      verify: (_) => expect(auth.authenticateCalls, 1),
    );

    blocTest<AppLockBloc, AppLockState>(
      'ignores lifecycle changes while the resume prompt is open',
      build: buildBloc,
      act: (bloc) async {
        await startUnlocked(bloc);
        await lifecycle(bloc, AppLifecycleState.paused);
        clock.advance(const Duration(seconds: 31));
        auth.pending = Completer<bool>();
        await lifecycle(bloc, AppLifecycleState.resumed);
        await lifecycle(bloc, AppLifecycleState.paused);
        clock.advance(const Duration(minutes: 2));
        await lifecycle(bloc, AppLifecycleState.resumed);
        auth.pending!.complete(true);
      },
      skip: 3,
      expect: () => [..._lockAndPrompt, _unlocked],
      verify: (_) => expect(auth.authenticateCalls, 2),
    );
  });
}
