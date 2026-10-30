import 'package:bloc_test/bloc_test.dart' show MockBloc, whenListen;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/config/app_platform.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/core/services/bluetooth_state_service.dart';
import 'package:health_wallet/features/desktop/backup/presentation/bloc/backup_bloc.dart';
import 'package:health_wallet/features/desktop/communication/presentation/bloc/communication_bloc.dart';
import 'package:health_wallet/features/desktop/lww_sync/presentation/bloc/lww_sync_bloc.dart';
import 'package:health_wallet/features/processing/presentation/pages/load_model/bloc/load_model_bloc.dart';
import 'package:health_wallet/features/share_records/domain/services/receive_mode_service.dart';
import 'package:health_wallet/features/sync/presentation/bloc/sync_bloc.dart';
import 'package:health_wallet/features/user/presentation/bloc/user_bloc.dart';
import 'package:health_wallet/features/user/presentation/preferences_modal/preference_modal.dart';
import 'package:health_wallet/features/user/presentation/preferences_modal/sections/patient/bloc/patient_bloc.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Records the events sent to it instead of running them.
class _MockCommunicationBloc
    extends MockBloc<CommunicationEvent, DesktopSyncState>
    implements CommunicationBloc {
  final events = <CommunicationEvent>[];

  @override
  void add(CommunicationEvent event) => events.add(event);
}

class _MockLwwSyncBloc extends MockBloc<LwwSyncEvent, LwwSyncState>
    implements LwwSyncBloc {}

class _MockBackupBloc extends MockBloc<BackupEvent, BackupState>
    implements BackupBloc {}

class _MockLoadModelBloc extends MockBloc<LoadModelEvent, LoadModelState>
    implements LoadModelBloc {}

class _MockSyncBloc extends MockBloc<SyncEvent, SyncState>
    implements SyncBloc {}

class _MockUserBloc extends MockBloc<UserEvent, UserState>
    implements UserBloc {}

class _MockPatientBloc extends MockBloc<PatientEvent, PatientState>
    implements PatientBloc {}

class _FakeBluetoothStateService extends Fake implements BluetoothStateService {
  @override
  Stream<bool> get onStateChanged => const Stream.empty();
}

class _FakeReceiveModeService extends Fake implements ReceiveModeService {
  @override
  bool get isListening => false;
}

final _en = lookupAppLocalizations(const Locale('en'));

void main() {
  late _MockCommunicationBloc commBloc;
  late _MockUserBloc userBloc;
  late _MockPatientBloc patientBloc;
  late _MockSyncBloc syncBloc;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'HealthWallet',
      packageName: 'me.healthwallet',
      version: '1.2.1',
      buildNumber: '42',
      buildSignature: '',
    );

    commBloc = _MockCommunicationBloc();
    final lwwBloc = _MockLwwSyncBloc();
    final backupBloc = _MockBackupBloc();
    final loadModelBloc = _MockLoadModelBloc();
    userBloc = _MockUserBloc();
    patientBloc = _MockPatientBloc();
    syncBloc = _MockSyncBloc();

    whenListen(
      commBloc,
      const Stream<DesktopSyncState>.empty(),
      initialState: const DesktopSyncState(),
    );
    whenListen(
      lwwBloc,
      const Stream<LwwSyncState>.empty(),
      initialState: LwwSyncState.initial(),
    );
    whenListen(
      backupBloc,
      const Stream<BackupState>.empty(),
      initialState: BackupState.initial(),
    );
    whenListen(
      loadModelBloc,
      const Stream<LoadModelState>.empty(),
      initialState: const LoadModelState(),
    );
    whenListen(
      userBloc,
      const Stream<UserState>.empty(),
      initialState: const UserState(),
    );
    whenListen(
      patientBloc,
      const Stream<PatientState>.empty(),
      initialState: const PatientState(),
    );
    whenListen(
      syncBloc,
      const Stream<SyncState>.empty(),
      initialState: const SyncState(),
    );

    getIt
      ..registerSingleton<AppPlatform>(AppPlatform.mobile)
      ..registerSingleton<CommunicationBloc>(commBloc)
      ..registerSingleton<LwwSyncBloc>(lwwBloc)
      ..registerSingleton<BackupBloc>(backupBloc)
      ..registerSingleton<LoadModelBloc>(loadModelBloc)
      ..registerSingleton<BluetoothStateService>(_FakeBluetoothStateService())
      ..registerSingleton<ReceiveModeService>(_FakeReceiveModeService());
  });

  tearDown(getIt.reset);

  testWidgets('opening it checks the VPN again for the Sync section', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<UserBloc>.value(value: userBloc),
          BlocProvider<PatientBloc>.value(value: patientBloc),
          BlocProvider<SyncBloc>.value(value: syncBloc),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => PreferenceModal.show(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    expect(commBloc.events, isEmpty);

    await tester.tap(find.text('open'));
    // The AI model section shows a spinner that never settles: pump past
    // the dialog transition instead.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(commBloc.events, [const CommunicationVpnChecked()]);
    expect(find.byType(PreferenceModal), findsOne);
    expect(find.text(_en.preferences), findsOne);
  });
}
