import 'dart:async';

import 'package:bloc_test/bloc_test.dart' show MockBloc, whenListen;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/config/app_platform.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/core/services/bluetooth_state_service.dart';
import 'package:health_wallet/core/widgets/app_snack_bar.dart';
import 'package:health_wallet/features/desktop/backup/presentation/bloc/backup_bloc.dart';
import 'package:health_wallet/features/desktop/communication/presentation/bloc/communication_bloc.dart';
import 'package:health_wallet/features/desktop/lww_sync/presentation/bloc/lww_sync_bloc.dart';
import 'package:health_wallet/features/processing/presentation/pages/load_model/bloc/load_model_bloc.dart';
import 'package:health_wallet/features/share_records/domain/services/receive_mode_service.dart';
import 'package:health_wallet/features/sync/presentation/bloc/sync_bloc.dart';
import 'package:health_wallet/features/user/domain/entity/user.dart';
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
  late StreamController<UserState> userStates;

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
    userStates = StreamController<UserState>();
    whenListen(
      userBloc,
      userStates.stream,
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

  tearDown(() async {
    await userStates.close();
    await getIt.reset();
  });

  /// Pumps a page that opens the modal from its 'open' button.
  Future<void> pumpPage(WidgetTester tester, {Size? size}) async {
    tester.view.physicalSize = size ?? const Size(800, 1400);
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
  }

  Future<void> openModal(WidgetTester tester) async {
    await tester.tap(find.text('open'));
    // The AI model section shows a spinner that never settles: pump past
    // the dialog transition instead.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  /// Lets the snackbar time out so no timer is left pending.
  Future<void> letSnackBarTimeOut(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(seconds: 1));
  }

  final inModal = find.descendant(
    of: find.byKey(PreferenceModal.scaffoldKey),
    matching: find.byKey(AppSnackBar.cardKey),
  );

  testWidgets('opening it checks the VPN again for the Sync section', (
    tester,
  ) async {
    await pumpPage(tester);
    expect(commBloc.events, isEmpty);

    await openModal(tester);

    expect(commBloc.events, [const CommunicationVpnChecked()]);
    expect(find.byType(PreferenceModal), findsOne);
    expect(find.text(_en.preferences), findsOne);
  });

  const failures = {
    UserSetting.theme: 'Theme',
    UserSetting.receiveMode: 'Share Proximity',
    UserSetting.biometric: 'Biometric Authentication',
  };
  for (final MapEntry(key: setting, value: label) in failures.entries) {
    testWidgets('a ${setting.name} failure names the setting inside the '
        'modal', (tester) async {
      await pumpPage(tester);
      await openModal(tester);

      userStates.add(
        UserState(status: UserStatus.failure('disk full', setting)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(inModal, findsOne);
      expect(
        find.descendant(
          of: inModal,
          matching: find.text("Couldn't save “$label”. Try again."),
        ),
        findsOne,
      );
      expect(find.textContaining('disk full'), findsNothing);

      await letSnackBarTimeOut(tester);
    });
  }

  testWidgets('a theme failure shows inside the modal on a wide desktop '
      'screen', (tester) async {
    await pumpPage(tester, size: const Size(1400, 1000));
    await openModal(tester);

    userStates.add(
      const UserState(
        status: UserStatus.failure('disk full', UserSetting.theme),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(
      find.descendant(
        of: inModal,
        matching: find.text(_en.failedToSaveSetting(_en.theme)),
      ),
      findsOne,
    );

    await letSnackBarTimeOut(tester);
  });

  testWidgets('a name failure shows the display-name message once, inside '
      'the modal', (tester) async {
    await pumpPage(tester);
    await openModal(tester);

    userStates.add(
      const UserState(
        user: User(name: 'Ana'),
        status: UserStatus.failure('disk full', UserSetting.name),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(
      find.descendant(
        of: inModal,
        matching: find.text(_en.failedToUpdateDisplayName),
      ),
      findsOne,
    );
    expect(find.byKey(AppSnackBar.cardKey), findsOne);

    await letSnackBarTimeOut(tester);
  });

  testWidgets('a setting saved or saving shows no message', (tester) async {
    await pumpPage(tester);
    await openModal(tester);

    userStates.add(const UserState(status: UserStatus.loading()));
    await tester.pump();
    userStates.add(const UserState(status: UserStatus.success()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byKey(AppSnackBar.cardKey), findsNothing);
  });

  testWidgets('shows the app version and build', (tester) async {
    await pumpPage(tester);
    await openModal(tester);

    expect(find.text('${_en.version}: v1.2.1 (42)'), findsOne);
  });

  testWidgets('the close button closes it', (tester) async {
    await pumpPage(tester);
    await openModal(tester);

    await tester.tap(
      find
          .descendant(
            of: find.byType(PreferenceModal),
            matching: find.byType(IconButton),
          )
          .first,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(PreferenceModal), findsNothing);
  });

  testWidgets('a tap outside the dialog still closes it, a tap inside does '
      'not', (tester) async {
    await pumpPage(tester);
    await openModal(tester);

    await tester.tap(find.text(_en.preferences));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(PreferenceModal), findsOne);

    await tester.tapAt(const Offset(4, 4));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(PreferenceModal), findsNothing);
  });

  testWidgets('screen readers get one Dismiss outside the dialog, and it '
      'closes it', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpPage(tester);
    await openModal(tester);

    final dismiss = find.semantics.byLabel(
      const DefaultMaterialLocalizations().modalBarrierDismissLabel,
    );
    expect(dismiss, findsOne);
    expect(
      dismiss.evaluate().single,
      isSemantics(hasTapAction: true, hasDismissAction: true),
    );

    tester.semantics.tap(dismiss);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(PreferenceModal), findsNothing);
    semantics.dispose();
  });
}
