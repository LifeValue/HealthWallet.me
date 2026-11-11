import 'dart:async';

import 'package:bloc_test/bloc_test.dart' show MockBloc, whenListen;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/app/app.dart';
import 'package:health_wallet/core/config/app_platform.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/services/bluetooth_state_service.dart';
import 'package:health_wallet/features/desktop/communication/data/models/device_pairing.dart';
import 'package:health_wallet/features/desktop/communication/presentation/bloc/communication_bloc.dart';
import 'package:health_wallet/features/desktop/tray/presentation/bloc/tray_bloc.dart';
import 'package:health_wallet/features/home/presentation/bloc/home_bloc.dart';
import 'package:health_wallet/features/processing/presentation/bloc/processing_bloc.dart';
import 'package:health_wallet/features/records/presentation/bloc/records_bloc.dart';
import 'package:health_wallet/features/share_records/domain/services/receive_mode_service.dart';
import 'package:health_wallet/features/sync/presentation/bloc/sync_bloc.dart';
import 'package:health_wallet/features/user/domain/entity/user.dart';
import 'package:health_wallet/features/user/domain/repository/user_repository.dart';
import 'package:health_wallet/features/user/presentation/bloc/user_bloc.dart';
import 'package:health_wallet/features/user/presentation/preferences_modal/sections/patient/bloc/patient_bloc.dart';

import '../../helpers/app_test_dependencies.dart';
import '../../helpers/log_capture.dart';

// The blocs below keep the events the App sends them.

class _EventsHomeBloc extends MockHomeBloc {
  final events = <HomeEvent>[];

  @override
  void add(HomeEvent event) => events.add(event);
}

class _EventsRecordsBloc extends MockRecordsBloc {
  final events = <RecordsEvent>[];

  @override
  void add(RecordsEvent event) => events.add(event);
}

class _EventsPatientBloc extends MockBloc<PatientEvent, PatientState>
    implements PatientBloc {
  final events = <PatientEvent>[];

  @override
  void add(PatientEvent event) => events.add(event);
}

class _EventsUserBloc extends MockBloc<UserEvent, UserState>
    implements UserBloc {
  final events = <UserEvent>[];

  @override
  void add(UserEvent event) => events.add(event);
}

class _EventsCommunicationBloc
    extends MockBloc<CommunicationEvent, DesktopSyncState>
    implements CommunicationBloc {
  final events = <CommunicationEvent>[];

  @override
  void add(CommunicationEvent event) => events.add(event);
}

class _MockTrayBloc extends MockBloc<TrayEvent, TrayState>
    implements TrayBloc {}

/// The signed-in user, or [error] before onboarding made one.
class _ReceiveModeUserRepository extends FakeUserRepository {
  _ReceiveModeUserRepository({this.receiveMode = true, this.error});

  final bool receiveMode;
  final Exception? error;
  final updates = <User>[];
  int reads = 0;

  @override
  Future<User> getCurrentUser() async {
    reads++;
    if (error case final error?) throw error;
    return User(isReceiveModeEnabled: receiveMode);
  }

  @override
  Future<void> updateUser(User user) async => updates.add(user);
}

class _BluetoothStateService extends FakeBluetoothStateService {
  _BluetoothStateService({required this.on});

  final bool on;
  int listens = 0;

  @override
  void startListening() => listens++;

  @override
  Future<bool> isEnabled() async => on;
}

class _CountingReceiveModeService extends Fake implements ReceiveModeService {
  _CountingReceiveModeService({
    this.isListening = false,
    this.isPaused = false,
  });

  @override
  bool isListening;

  @override
  bool isPaused;

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

/// Puts [instance] in getIt in place of what is registered as [T].
Future<void> _replace<T extends Object>(T instance) async {
  if (getIt.isRegistered<T>()) await getIt.unregister<T>();
  getIt.registerSingleton<T>(instance);
}

/// Unmounts the app before the splash's 1 s timer opens a route whose pages
/// need dependencies these tests don't register.
Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 1));
}

void _lifecycle(WidgetTester tester, AppLifecycleState state) =>
    tester.binding.handleAppLifecycleStateChanged(state);

/// Sends the app to the background and back.
Future<void> _pauseAndResume(WidgetTester tester) async {
  _lifecycle(tester, AppLifecycleState.paused);
  await tester.pump();
  _lifecycle(tester, AppLifecycleState.resumed);
  await tester.pump();
}

void main() {
  group('receive mode', () {
    final logs = captureLogs();

    Future<_CountingReceiveModeService> pumpApp(
      WidgetTester tester, {
      required UserRepository users,
      bool bluetoothOn = true,
      bool listening = false,
      bool paused = false,
    }) async {
      await registerAppDependencies();
      final receiveMode = _CountingReceiveModeService(
        isListening: listening,
        isPaused: paused,
      );
      await _replace<UserRepository>(users);
      await _replace<BluetoothStateService>(
        _BluetoothStateService(on: bluetoothOn),
      );
      await _replace<ReceiveModeService>(receiveMode);
      await tester.pumpWidget(const App());
      await tester.pump();
      return receiveMode;
    }

    testWidgets('the Bluetooth state is followed from the start', (
      tester,
    ) async {
      await pumpApp(tester, users: _ReceiveModeUserRepository());

      final bluetooth =
          getIt<BluetoothStateService>() as _BluetoothStateService;
      expect(bluetooth.listens, 1);
      await _unmount(tester);
    });

    testWidgets('is not started before onboarding made a user', (
      tester,
    ) async {
      final users = _ReceiveModeUserRepository(error: Exception('no user'));
      final receiveMode = await pumpApp(tester, users: users);

      expect(users.reads, 1);
      expect(receiveMode.starts, 0);
      expect(logs, loggedWarning('Receive mode not started'));
      await _unmount(tester);
    });

    testWidgets('is not started when the user turned it off', (tester) async {
      final users = _ReceiveModeUserRepository(receiveMode: false);
      final receiveMode = await pumpApp(tester, users: users);

      expect(users.reads, 1);
      expect(receiveMode.starts, 0);
      expect(users.updates, isEmpty);
      await _unmount(tester);
    });

    testWidgets('is turned off when Bluetooth is off', (tester) async {
      final users = _ReceiveModeUserRepository();
      final receiveMode = await pumpApp(
        tester,
        users: users,
        bluetoothOn: false,
      );

      expect(receiveMode.starts, 0);
      expect(users.updates.single.isReceiveModeEnabled, isFalse);
      await _unmount(tester);
    });

    testWidgets('starts at launch, stops in the background and starts again '
        'on resume', (tester) async {
      final users = _ReceiveModeUserRepository();
      final receiveMode = await pumpApp(tester, users: users);
      expect(receiveMode.starts, 1);

      _lifecycle(tester, AppLifecycleState.paused);
      await tester.pump();
      expect(receiveMode.stops, 1);

      _lifecycle(tester, AppLifecycleState.resumed);
      await tester.pump();
      expect(receiveMode.starts, 2);
      expect(users.updates, isEmpty);

      // Closing the app stops it too.
      await _unmount(tester);
      expect(receiveMode.stops, 2);
    });

    testWidgets('is not started twice while it listens', (tester) async {
      final receiveMode = await pumpApp(
        tester,
        users: _ReceiveModeUserRepository(),
        listening: true,
      );

      expect(receiveMode.starts, 0);
      await _unmount(tester);
    });

    testWidgets('keeps listening in the background while a share screen '
        'holds it paused', (tester) async {
      final receiveMode = await pumpApp(
        tester,
        users: _ReceiveModeUserRepository(receiveMode: false),
        listening: true,
        paused: true,
      );

      _lifecycle(tester, AppLifecycleState.paused);
      await tester.pump();
      expect(receiveMode.stops, 0);

      // Other lifecycle states neither start nor stop it.
      _lifecycle(tester, AppLifecycleState.inactive);
      await tester.pump();
      _lifecycle(tester, AppLifecycleState.resumed);
      await tester.pump();
      await _unmount(tester);
      expect(receiveMode.stops, 0);
      expect(receiveMode.starts, 0);
    });
  });

  group('the paired desktop on resume', () {
    final logs = captureLogs();

    final pairing = DevicePairing(
      deviceId: 'mac',
      deviceName: 'Mac',
      pairingKey: 'key',
      lastIp: '192.168.1.2',
      lastPort: 4040,
      pairedAt: DateTime(2026),
    );

    Future<_EventsCommunicationBloc> pumpApp(
      WidgetTester tester,
      DesktopSyncState state,
    ) async {
      await registerAppDependencies();
      final communication = _EventsCommunicationBloc();
      whenListen(
        communication,
        const Stream<DesktopSyncState>.empty(),
        initialState: state,
      );
      await _replace<CommunicationBloc>(communication);
      await tester.pumpWidget(const App());
      await tester.pump();
      return communication;
    }

    testWidgets('is reconnected when the link dropped', (tester) async {
      final communication = await pumpApp(
        tester,
        DesktopSyncState(pairedDevice: pairing),
      );

      await _pauseAndResume(tester);

      expect(communication.events, [isA<CommunicationConnectionRequested>()]);
      await _unmount(tester);
    });

    testWidgets('is left alone while connected', (tester) async {
      final communication = await pumpApp(
        tester,
        DesktopSyncState(
          pairedDevice: pairing,
          connectionStatus: ConnectionStatus.connected,
        ),
      );

      await _pauseAndResume(tester);

      expect(communication.events, isEmpty);
      await _unmount(tester);
    });

    testWidgets('is not looked for when none was paired', (tester) async {
      final communication = await pumpApp(tester, const DesktopSyncState());

      await _pauseAndResume(tester);

      expect(communication.events, isEmpty);
      await _unmount(tester);
    });

    testWidgets('logs when the desktop link is not available', (tester) async {
      await registerAppDependencies();
      await tester.pumpWidget(const App());
      await tester.pump();

      await _pauseAndResume(tester);

      expect(logs, loggedWarning('Could not reconnect to the paired desktop'));
      await _unmount(tester);
    });
  });

  testWidgets('on desktop, provides the tray and leaves receive mode and '
      'the phone link alone', (tester) async {
    await registerAppDependencies();
    final users = _ReceiveModeUserRepository();
    final receiveMode = _CountingReceiveModeService(isListening: true);
    final tray = _MockTrayBloc();
    whenListen(
      tray,
      const Stream<TrayState>.empty(),
      initialState: const TrayState(),
    );
    final communication = _EventsCommunicationBloc();
    whenListen(
      communication,
      const Stream<DesktopSyncState>.empty(),
      initialState: const DesktopSyncState(),
    );
    await _replace<AppPlatform>(AppPlatform.desktop);
    await _replace<UserRepository>(users);
    await _replace<ReceiveModeService>(receiveMode);
    await _replace<TrayBloc>(tray);
    await _replace<CommunicationBloc>(communication);

    await tester.pumpWidget(const App());
    await tester.pump();

    expect(
      BlocProvider.of<TrayBloc>(tester.element(find.byType(MaterialApp))),
      same(tray),
    );

    await _pauseAndResume(tester);
    await _unmount(tester);

    expect(users.reads, 0);
    expect(receiveMode.starts, 0);
    expect(receiveMode.stops, 0);
    expect(communication.events, isEmpty);
  });

  testWidgets('on mobile, provides no tray', (tester) async {
    await registerAppDependencies();

    await tester.pumpWidget(const App());
    await tester.pump();

    expect(
      () => BlocProvider.of<TrayBloc>(
        tester.element(find.byType(MaterialApp)),
      ),
      throwsFlutterError,
    );
    await _unmount(tester);
  });

  group('app-level listeners', () {
    late StreamController<SyncState> sync;
    late StreamController<ProcessingState> processing;
    late StreamController<RecordsState> records;
    late _EventsHomeBloc home;
    late _EventsRecordsBloc recordsBloc;
    late _EventsPatientBloc patients;
    late _EventsUserBloc user;

    /// Pumps the app with blocs that keep their events.
    Future<void> pumpApp(WidgetTester tester) async {
      await registerAppDependencies();
      // Broadcast, so closing one that nothing listened to doesn't wait.
      sync = StreamController<SyncState>.broadcast();
      processing = StreamController<ProcessingState>.broadcast();
      records = StreamController<RecordsState>.broadcast();
      addTearDown(sync.close);
      addTearDown(processing.close);
      addTearDown(records.close);
      final mockSync = MockSyncBloc();
      whenListen(mockSync, sync.stream, initialState: const SyncState());
      final processingBloc = MockProcessingBloc();
      whenListen(
        processingBloc,
        processing.stream,
        initialState: const ProcessingState(),
      );
      recordsBloc = _EventsRecordsBloc();
      whenListen(
        recordsBloc,
        records.stream,
        initialState: const RecordsState(),
      );
      home = _EventsHomeBloc();
      whenListen(
        home,
        const Stream<HomeState>.empty(),
        initialState: const HomeState(),
      );
      patients = _EventsPatientBloc();
      whenListen(
        patients,
        const Stream<PatientState>.empty(),
        initialState: const PatientState(),
      );
      user = _EventsUserBloc();
      whenListen(
        user,
        const Stream<UserState>.empty(),
        initialState: const UserState(),
      );
      await _replace<SyncBloc>(mockSync);
      await _replace<ProcessingBloc>(processingBloc);
      await _replace<RecordsBloc>(recordsBloc);
      await _replace<HomeBloc>(home);
      await _replace<PatientBloc>(patients);
      await _replace<UserBloc>(user);

      await tester.pumpWidget(const App());
    }

    /// Forgets the events the blocs got at start-up, leaving only what the
    /// listeners send.
    void clearEvents() {
      home.events.clear();
      recordsBloc.events.clear();
      patients.events.clear();
      user.events.clear();
    }

    testWidgets('the app starts the blocs it provides', (tester) async {
      await pumpApp(tester);

      expect(user.events, [isA<UserInitialised>()]);
      expect(home.events, [isA<HomeInitialised>()]);
      expect(patients.events, [isA<PatientInitialised>()]);
      expect(recordsBloc.events, isEmpty);
      await _unmount(tester);
    });

    testWidgets('a finished scan reloads the people, Home and the records', (
      tester,
    ) async {
      await pumpApp(tester);
      clearEvents();

      processing.add(
        const ProcessingState(status: PipelineStatus.success(sessionId: 's')),
      );
      await tester.pump();
      await tester.pump();

      expect(patients.events, [isA<PatientPatientsLoaded>()]);
      expect(home.events, [isA<HomeScanCompleted>()]);
      expect(recordsBloc.events, [isA<RecordsInitialised>()]);
      await _unmount(tester);
    });

    testWidgets('a scan that has not finished reloads nothing', (
      tester,
    ) async {
      await pumpApp(tester);
      clearEvents();

      processing.add(
        const ProcessingState(status: PipelineStatus.savingResources()),
      );
      await tester.pump();
      await tester.pump();

      expect(patients.events, isEmpty);
      expect(home.events, isEmpty);
      expect(recordsBloc.events, isEmpty);
      await _unmount(tester);
    });

    testWidgets('what arrives as the app closes reloads nothing', (
      tester,
    ) async {
      await pumpApp(tester);
      clearEvents();

      processing.add(
        const ProcessingState(status: PipelineStatus.success(sessionId: 's')),
      );
      records.add(const RecordsState(status: RecordsStatus.deleted()));
      sync.add(
        const SyncState(
          syncStatus: SyncStatus.synced,
          shouldShowTutorial: true,
        ),
      );
      // The listeners run before the frame that unmounts the app, and their
      // work after it.
      await _unmount(tester);

      expect(patients.events, isEmpty);
      expect(home.events, isEmpty);
      expect(recordsBloc.events, isEmpty);
      expect(user.events, isEmpty);
    });

    testWidgets('a deleted record reloads the people', (tester) async {
      await pumpApp(tester);
      clearEvents();

      records.add(const RecordsState(status: RecordsStatus.deleted()));
      await tester.pump();
      await tester.pump();

      expect(patients.events, [isA<PatientPatientsLoaded>()]);
      expect(home.events, isEmpty);
      await _unmount(tester);
    });

    testWidgets('the tutorial refreshes Home, keeping its order', (
      tester,
    ) async {
      await pumpApp(tester);
      clearEvents();

      sync.add(const SyncState(shouldShowTutorial: true));
      await tester.pump();
      await tester.pump();

      expect(home.events, [isA<HomeRefreshPreservingOrder>()]);
      expect(recordsBloc.events, isEmpty);
      expect(user.events, isEmpty);
      expect(patients.events, isEmpty);
      await _unmount(tester);
    });

    testWidgets('a sync state that changes neither the status nor the '
        'tutorial reloads nothing', (tester) async {
      await pumpApp(tester);
      clearEvents();

      sync.add(const SyncState(isLoading: true));
      await tester.pump();
      await tester.pump();

      expect(home.events, isEmpty);
      expect(recordsBloc.events, isEmpty);
      expect(user.events, isEmpty);
      expect(patients.events, isEmpty);
      await _unmount(tester);
    });
  });
}
