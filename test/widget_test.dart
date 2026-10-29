import 'dart:async';

import 'dart:typed_data';

import 'package:bloc_test/bloc_test.dart' show MockBloc, whenListen;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/app/app.dart';
import 'package:health_wallet/core/config/app_platform.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/l10n/app_strings_provider.dart';
import 'package:health_wallet/core/navigation/app_router.dart';
import 'package:health_wallet/core/navigation/observers/order_route_observer.dart';
import 'package:health_wallet/core/services/biometric_auth_service.dart';
import 'package:health_wallet/core/services/bluetooth_state_service.dart';
import 'package:health_wallet/features/app_lock/presentation/bloc/app_lock_bloc.dart';
import 'package:health_wallet/features/app_lock/presentation/widgets/app_lock_overlay.dart';
import 'package:health_wallet/features/home/data/services/specialty_classifier_impl.dart';
import 'package:health_wallet/features/home/presentation/bloc/home_bloc.dart';
import 'package:health_wallet/features/notifications/bloc/notification_bloc.dart';
import 'package:health_wallet/features/processing/presentation/bloc/processing_bloc.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/records/domain/entity/record_note/record_note.dart';
import 'package:health_wallet/features/records/domain/repository/records_repository.dart';
import 'package:health_wallet/features/records/presentation/bloc/records_bloc.dart';
import 'package:health_wallet/features/share_records/domain/services/receive_mode_service.dart';
import 'package:health_wallet/features/sync/data/data_source/local/sync_local_data_source.dart';
import 'package:health_wallet/features/sync/domain/entities/source.dart';
import 'package:health_wallet/features/sync/domain/repository/sync_repository.dart';
import 'package:health_wallet/features/sync/domain/services/wallet_patient_service.dart';
import 'package:health_wallet/features/sync/domain/use_case/get_sources_use_case.dart';
import 'package:health_wallet/features/sync/ehrs/fasten/domain/entities/sync_qr_data.dart';
import 'package:health_wallet/features/sync/presentation/bloc/sync_bloc.dart';
import 'package:health_wallet/features/user/domain/entity/user.dart';
import 'package:health_wallet/features/user/domain/repository/user_repository.dart';
import 'package:health_wallet/features/user/domain/services/default_patient_service.dart';
import 'package:health_wallet/features/user/domain/services/patient_deduplication_service.dart';
import 'package:health_wallet/features/user/domain/services/patient_edit_service.dart';
import 'package:health_wallet/features/user/domain/services/patient_selection_service.dart';
import 'package:health_wallet/features/user/presentation/bloc/user_bloc.dart';
import 'package:health_wallet/features/user/presentation/preferences_modal/sections/patient/bloc/patient_bloc.dart';
import 'package:health_wallet/features/wallet_pass/domain/entity/emergency_card_data.dart';
import 'package:health_wallet/features/wallet_pass/presentation/bloc/wallet_pass_bloc.dart';
import 'package:intl/intl.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'features/app_lock/app_lock_test_fakes.dart';

// ---------------------------------------------------------------------------
// Fake implementations for abstract repositories / services
// ---------------------------------------------------------------------------

class FakeUserRepository extends Fake implements UserRepository {
  @override
  Future<User> getCurrentUser({bool fetchFromNetwork = false}) async =>
      const User();

  @override
  Future<void> updateUser(User user) async {}

  @override
  Future<bool> isBiometricAuthEnabled() async => false;

  @override
  Future<void> saveBiometricAuth(bool isEnabled) async {}
}

class FakeBiometricAuthService extends Fake implements BiometricAuthService {
  @override
  Future<bool> canAuthenticate() async => false;

  @override
  Future<bool> isBiometricAvailable() async => false;

  @override
  Future<bool> isDeviceSecure() async => false;

  @override
  Future<bool> authenticate() async => false;
}

class FakeRecordsRepository extends Fake implements RecordsRepository {
  @override
  Future<List<IFhirResource>> getResources({
    List<FhirType> resourceTypes = const [],
    String? sourceId,
    List<String>? sourceIds,
    int limit = 20,
    int offset = 0,
    DateFilter? dateFilter,
  }) async => [];

  @override
  Future<List<IFhirResource>> getRelatedResourcesForEncounter({
    required String encounterId,
    String? sourceId,
  }) async => [];

  @override
  Future<List<IFhirResource>> getRelatedResources({
    required IFhirResource resource,
  }) async => [];

  @override
  Future<IFhirResource?> resolveReference(String reference) async => null;

  @override
  Future<int> addRecordNote({
    required String resourceId,
    String? sourceId,
    required String content,
  }) async => 0;

  @override
  Future<List<RecordNote>> getRecordNotes(String resourceId) async => [];

  @override
  Future<int> editRecordNote(RecordNote note) async => 0;

  @override
  Future<int> deleteRecordNote(RecordNote note) async => 0;

  @override
  Future<void> loadDemoData() async {}

  @override
  Future<void> clearDemoData() async {}

  @override
  Future<bool> hasDemoData() async => false;

  @override
  Future<List<IFhirResource>> getBloodTypeObservations({
    required String patientId,
    String? sourceId,
  }) async => [];

  @override
  Future<String> saveObservation(IFhirResource observation) async => '';

  @override
  Future<void> updatePatient(IFhirResource patient) async {}

  @override
  Future<List<IFhirResource>> searchResources({
    required String query,
    List<FhirType> resourceTypes = const [],
    String? sourceId,
    List<String>? sourceIds,
    int limit = 50,
  }) async => [];

  @override
  Future<({Uint8List bytes, String patientName})> buildIpsExport({
    String? sourceId,
    String? patientId,
  }) async => (bytes: Uint8List(0), patientName: 'Unknown');
}

class FakeSyncRepository extends Fake implements SyncRepository {
  @override
  Future<List<Source>> getSources() async => [];

  @override
  Future<void> syncResources({required String endpoint}) async {}

  @override
  Future<String?> getLastSyncTimestamp() async => null;

  @override
  void setBaseUrl(String baseUrl) {}

  @override
  void setBearerToken(String token) {}

  @override
  Future<void> saveSyncQrData(SyncQrData qrData) async {}

  @override
  Future<SyncQrData?> getCurrentSyncQrData() async => null;

  @override
  Future<void> updateSourceLabel(String sourceId, String newLabel) async {}

  @override
  Future<void> createWalletSource() async {}

  @override
  Future<void> createDemoDataSource() async {}

  @override
  Future<void> deleteSource(String sourceId) async {}

  @override
  Future<void> cacheSources(List<Source> sources) async {}

  @override
  Future saveResources(List<IFhirResource> resources) async {}
}

class FakeSyncLocalDataSource extends Fake implements SyncLocalDataSource {}

class FakeBluetoothStateService extends Fake implements BluetoothStateService {
  @override
  void startListening() {}

  @override
  Future<bool> isEnabled() async => false;
}

class FakeReceiveModeService extends Fake implements ReceiveModeService {
  @override
  bool get isListening => false;
}

// ---------------------------------------------------------------------------
// Mock classes for concrete types that cannot be easily constructed in tests
// (e.g. they depend on native plugins or database connections)
// ---------------------------------------------------------------------------

class MockPatientEditService extends Mock implements PatientEditService {}

class MockProcessingBloc extends MockBloc<ProcessingEvent, ProcessingState>
    implements ProcessingBloc {}

class MockHomeBloc extends MockBloc<HomeEvent, HomeState> implements HomeBloc {}

class MockWalletPassBloc extends MockBloc<WalletPassEvent, WalletPassState>
    implements WalletPassBloc {}

// ---------------------------------------------------------------------------
// Test
// ---------------------------------------------------------------------------

/// Resets getIt and registers the fakes and blocs the App widget resolves.
///
/// The app lock gets its own fakes: [lockAuth] and [lockClock] when given,
/// with [initialPrefs] deciding whether onboarding is done. Call it from the test
/// body, so the lock bloc runs in the test's fake async zone.
Future<void> _registerAppDependencies({
  Map<String, Object> initialPrefs = const {},
  bool lockEnabled = false,
  FakeLockAuthService? lockAuth,
  FakeAppLockClock? lockClock,
}) async {
  // Provide fake SharedPreferences values before any code touches it
  SharedPreferences.setMockInitialValues(initialPrefs);

  // Reset the service locator to a clean state
  await getIt.reset();

  // --- Fake repositories & services ---
  final fakeUserRepo = FakeUserRepository();
  final fakeBiometricAuth = FakeBiometricAuthService();
  final fakeRecordsRepo = FakeRecordsRepository();
  final fakeSyncRepo = FakeSyncRepository();

  final deduplicationService = PatientDeduplicationService(
    fakeRecordsRepo,
    fakeSyncRepo,
  );
  final selectionService = PatientSelectionService(deduplicationService);
  final getSourcesUseCase = GetSourcesUseCase(fakeSyncRepo);
  final walletPatientService = WalletPatientService(fakeSyncRepo);

  // --- Blocs (constructed with fake dependencies) ---
  final userBloc = UserBloc(fakeUserRepo, fakeBiometricAuth);
  final syncBloc = SyncBloc(
    fakeSyncRepo,
    fakeRecordsRepo,
    DefaultPatientService(
      fakeRecordsRepo,
      FakeSyncLocalDataSource(),
      walletPatientService,
    ),
    AppStringsProvider(),
  );
  final recordsBloc = RecordsBloc(fakeRecordsRepo, SpecialtyClassifierImpl());
  final prefs = await SharedPreferences.getInstance();
  final notificationBloc = NotificationBloc(prefs);
  final patientBloc = PatientBloc(
    fakeRecordsRepo,
    deduplicationService,
    MockPatientEditService(),
  );

  // Blocs with heavy dependency graphs (AI models, native plugins) are
  // mocked; the smoke test only needs their initial state.
  final processingBloc = MockProcessingBloc();
  whenListen(
    processingBloc,
    const Stream<ProcessingState>.empty(),
    initialState: const ProcessingState(),
  );
  final homeBloc = MockHomeBloc();
  whenListen(
    homeBloc,
    const Stream<HomeState>.empty(),
    initialState: const HomeState(),
  );
  final walletPassBloc = MockWalletPassBloc();
  whenListen(
    walletPassBloc,
    const Stream<WalletPassState>.empty(),
    initialState: const WalletPassState(),
  );

  final appLockBloc = AppLockBloc(
    lockAuth ?? FakeLockAuthService(),
    FakeLockUserRepository(lockEnabled: lockEnabled),
    prefs,
    lockClock ?? FakeAppLockClock(),
  );

  // --- Register everything the App widget resolves from getIt ---
  getIt.registerSingleton<AppLockBloc>(appLockBloc);
  getIt.registerSingleton<AppPlatform>(AppPlatform.mobile);
  getIt.registerSingleton<AppStringsProvider>(AppStringsProvider());
  getIt.registerSingleton<AppRouter>(AppRouter());
  getIt.registerFactory<AppRouteObserver>(AppRouteObserver.new);
  getIt.registerSingleton<BluetoothStateService>(FakeBluetoothStateService());
  getIt.registerSingleton<ReceiveModeService>(FakeReceiveModeService());
  getIt.registerFactory<UserRepository>(() => fakeUserRepo);
  getIt.registerFactory<BiometricAuthService>(() => fakeBiometricAuth);
  getIt.registerFactory<UserBloc>(() => userBloc);
  getIt.registerFactory<SyncBloc>(() => syncBloc);
  getIt.registerFactory<RecordsBloc>(() => recordsBloc);
  getIt.registerSingleton<ProcessingBloc>(processingBloc);
  getIt.registerSingleton<HomeBloc>(homeBloc);
  getIt.registerFactory<WalletPassBloc>(() => walletPassBloc);
  getIt.registerFactory<GetSourcesUseCase>(() => getSourcesUseCase);
  getIt.registerFactory<RecordsRepository>(() => fakeRecordsRepo);
  getIt.registerFactory<SyncRepository>(() => fakeSyncRepo);
  getIt.registerFactory<PatientDeduplicationService>(
    () => deduplicationService,
  );
  getIt.registerFactory<PatientSelectionService>(() => selectionService);
  getIt.registerFactory<PatientBloc>(() => patientBloc);
  getIt.registerSingleton<NotificationBloc>(notificationBloc);
}

const _lockOverlay = Key('app_lock_overlay');

void main() {
  testWidgets('App starts', (WidgetTester tester) async {
    await _registerAppDependencies();

    // Build the App widget and pump a single frame.
    // Using pump() (not pumpAndSettle) because the route pages may have
    // their own getIt dependencies that are not registered in this test.
    // A single frame is enough to verify that MaterialApp is in the tree.
    await tester.pumpWidget(const App());
    await tester.pump();

    expect(find.byType(MaterialApp), findsOneWidget);
    // Onboarding isn't done, so nothing covers the app.
    expect(find.byKey(_lockOverlay), findsNothing);

    // Cleanup: unmounting lets BlocProvider close the blocs it created.
    // Awaiting bloc.close() directly would hang, because close() waits for
    // in-flight handlers that never finish under the test's fake async zone.
    // The extra pump lets the splash page's 1s minimum-display timer fire.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('follows the device language for code without a context', (
    WidgetTester tester,
  ) async {
    tester.platformDispatcher.localesTestValue = const [Locale('ro')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    addTearDown(() => Intl.defaultLocale = null);
    await _registerAppDependencies();

    await tester.pumpWidget(const App());
    await tester.pump();

    expect(getIt<AppStringsProvider>().l10n.localeName, 'ro');
    expect(Intl.defaultLocale, 'ro');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  group('app lock', () {
    const lockedPrefs = {'hasSeenOnboarding': true};

    /// Unmounts the app before the splash's 1 s timer opens a route whose
    /// pages need dependencies this test doesn't register.
    Future<void> unmount(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets('Lock fails: covers every route when the start check is '
        'cancelled', (tester) async {
      final auth = FakeLockAuthService(results: [false]);
      await _registerAppDependencies(
        initialPrefs: lockedPrefs,
        lockEnabled: true,
        lockAuth: auth,
      );

      await tester.pumpWidget(const App());
      await tester.pump();
      await tester.pump();

      expect(auth.authenticateCalls, 1);
      expect(find.text('HealthWallet is locked'), findsOneWidget);
      expect(getIt<AppLockBloc>().state.status, AppLockStatus.locked);

      await unmount(tester);
    });

    testWidgets('forwards lifecycle changes: locks after 31 s in the '
        'background, not after 10 s', (tester) async {
      final auth = FakeLockAuthService(results: [true]);
      final clock = FakeAppLockClock();
      await _registerAppDependencies(
        initialPrefs: lockedPrefs,
        lockEnabled: true,
        lockAuth: auth,
        lockClock: clock,
      );
      await tester.pumpWidget(const App());
      await tester.pump();
      await tester.pump();
      expect(find.byKey(_lockOverlay), findsNothing);

      Future<void> background(Duration stay) async {
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await tester.pump();
        clock.advance(stay);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();
        await tester.pump();
      }

      await background(const Duration(seconds: 10));
      expect(find.byKey(_lockOverlay), findsNothing);
      expect(auth.authenticateCalls, 1);

      await background(const Duration(seconds: 31));
      expect(find.text('HealthWallet is locked'), findsOneWidget);
      expect(auth.authenticateCalls, 2);

      await unmount(tester);
    });

    testWidgets('swallows the back button while locked', (tester) async {
      await _registerAppDependencies(
        initialPrefs: lockedPrefs,
        lockEnabled: true,
      );
      await tester.pumpWidget(const App());
      await tester.pump();
      await tester.pump();

      expect(await tester.binding.handlePopRoute(), isTrue);

      await unmount(tester);
    });

    testWidgets('leaves the back button to the router when unlocked', (
      tester,
    ) async {
      await _registerAppDependencies();
      await tester.pumpWidget(const App());
      await tester.pump();

      final overlay =
          tester.state(find.byType(AppLockOverlay)) as WidgetsBindingObserver;
      expect(await overlay.didPopRoute(), isFalse);

      await unmount(tester);
    });
  });

  group('emergency card back', () {
    const card = EmergencyCardData(patientName: 'Test Patient');

    Future<AppRouter> pumpApp(WidgetTester tester) async {
      await _registerAppDependencies(initialPrefs: {'hasSeenOnboarding': true});
      await tester.pumpWidget(const App());
      await tester.pump();
      return getIt<AppRouter>();
    }

    /// Unmounts the app before the splash's 1 s timer opens a route whose
    /// pages need dependencies this test doesn't register.
    Future<void> unmount(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets('opens the app when a link at start made the card the only '
        'page', (tester) async {
      final router = await pumpApp(tester);
      // What DeepLinkService does before the app is drawn.
      unawaited(router.replaceAll([EmergencyCardRoute(cardData: card)]));
      await tester.pump();
      await tester.pump();
      expect(find.text('Test Patient'), findsOneWidget);
      expect(router.canPop(), isFalse);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pump();
      await tester.pump();

      expect(router.current.name, SplashRoute.name);
      // Let the page transition finish (well before the splash's 1 s timer).
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Test Patient'), findsNothing);
      await unmount(tester);
    });

    testWidgets('the system back button also opens the app', (tester) async {
      final router = await pumpApp(tester);
      unawaited(router.replaceAll([EmergencyCardRoute(cardData: card)]));
      await tester.pump();
      await tester.pump();

      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump();

      expect(router.current.name, SplashRoute.name);
      // Let the page transition finish (well before the splash's 1 s timer).
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Test Patient'), findsNothing);
      await unmount(tester);
    });

    testWidgets('returns to the page below when the app opened the card', (
      tester,
    ) async {
      final router = await pumpApp(tester);
      unawaited(router.push(EmergencyCardRoute(cardData: card)));
      await tester.pump();
      await tester.pump();
      expect(router.stack, hasLength(2));

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pump();
      await tester.pump();

      expect(router.stack, hasLength(1));
      expect(router.current.name, SplashRoute.name);
      await unmount(tester);
    });
  });

  group('emergency card', () {
    Future<void> openCard(WidgetTester tester, EmergencyCardData card) async {
      await _registerAppDependencies(initialPrefs: {'hasSeenOnboarding': true});
      await tester.pumpWidget(const App());
      await tester.pump();
      unawaited(
        getIt<AppRouter>().replaceAll([EmergencyCardRoute(cardData: card)]),
      );
      await tester.pump();
      await tester.pump();
    }

    Future<void> unmount(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets('shows every field of a full card', (tester) async {
      await openCard(
        tester,
        EmergencyCardData(
          patientName: 'Test Patient',
          bloodType: 'A+',
          dateOfBirth: DateTime(1985, 5, 14),
          gender: 'female',
          patientPhone: '+40700000001',
          emergencyContactName: 'Maria Pop',
          emergencyContactPhone: '+40700000000',
          allergies: const ['Penicillin', 'Peanuts'],
          conditions: const ['Asthma'],
          medications: const ['Salbutamol'],
        ),
      );

      for (final text in [
        'Test Patient',
        'A+',
        'May 14, 1985',
        '+40700000001',
        'Maria Pop',
        '+40700000000',
        'Penicillin',
        'Peanuts',
        'Asthma',
        'Salbutamol',
      ]) {
        expect(find.text(text), findsOne, reason: text);
      }
      await unmount(tester);
    });

    testWidgets('shows only the name when nothing else is known', (
      tester,
    ) async {
      await openCard(tester, const EmergencyCardData(patientName: 'Only Name'));

      expect(find.text('Only Name'), findsOne);
      expect(find.byIcon(Icons.phone), findsNothing);
      expect(find.byIcon(Icons.contact_phone_outlined), findsNothing);
      expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
      expect(find.byIcon(Icons.medication_outlined), findsNothing);
      await unmount(tester);
    });
  });
}
