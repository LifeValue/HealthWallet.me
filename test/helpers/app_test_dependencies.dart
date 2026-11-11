/// The fakes and blocs the App widget resolves from getIt, for the tests
/// that pump the whole app.
library;

import 'dart:typed_data';

import 'package:bloc_test/bloc_test.dart' show MockBloc, whenListen;
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/config/app_platform.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/l10n/app_strings_provider.dart';
import 'package:health_wallet/core/navigation/app_router.dart';
import 'package:health_wallet/core/navigation/observers/order_route_observer.dart';
import 'package:health_wallet/core/services/biometric_auth_service.dart';
import 'package:health_wallet/core/services/bluetooth_state_service.dart';
import 'package:health_wallet/features/app_lock/presentation/bloc/app_lock_bloc.dart';
import 'package:health_wallet/features/holders/domain/repository/holder_repository.dart';
import 'package:health_wallet/features/holders/domain/services/holder_linking_service.dart';
import 'package:health_wallet/features/holders/domain/services/holder_selection.dart';
import 'package:health_wallet/features/holders/domain/services/holder_service.dart';
import 'package:health_wallet/features/home/data/services/specialty_classifier_impl.dart';
import 'package:health_wallet/features/home/presentation/bloc/home_bloc.dart';
import 'package:health_wallet/features/notifications/bloc/notification_bloc.dart';
import 'package:health_wallet/features/processing/domain/services/ai_model_selection_guard.dart';
import 'package:health_wallet/features/processing/presentation/bloc/processing_bloc.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/records/domain/entity/record_note/record_note.dart';
import 'package:health_wallet/features/records/domain/repository/records_repository.dart';
import 'package:health_wallet/features/records/presentation/bloc/records_bloc.dart';
import 'package:health_wallet/features/share_records/domain/services/receive_mode_service.dart';
import 'package:health_wallet/features/sync/data/data_source/local/sync_local_data_source.dart';
import 'package:health_wallet/features/sync/domain/entities/source.dart';
import 'package:health_wallet/features/sync/domain/repository/sync_repository.dart';
import 'package:health_wallet/features/sync/domain/use_case/get_sources_use_case.dart';
import 'package:health_wallet/features/sync/ehrs/fasten/domain/entities/sync_qr_data.dart';
import 'package:health_wallet/features/sync/presentation/bloc/sync_bloc.dart';
import 'package:health_wallet/features/user/domain/entity/user.dart';
import 'package:health_wallet/features/user/domain/repository/user_repository.dart';
import 'package:health_wallet/features/user/domain/services/default_patient_service.dart';
import 'package:health_wallet/features/user/domain/services/patient_edit_service.dart';
import 'package:health_wallet/features/user/presentation/bloc/user_bloc.dart';
import 'package:health_wallet/features/user/presentation/preferences_modal/sections/patient/bloc/patient_bloc.dart';
import 'package:health_wallet/features/wallet_pass/presentation/bloc/wallet_pass_bloc.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/app_lock/app_lock_test_fakes.dart';
import 'fake_device_capability_service.dart';

// ---------------------------------------------------------------------------
// Fake implementations for abstract repositories / services
// ---------------------------------------------------------------------------

class FakeUserRepository extends Fake implements UserRepository {
  @override
  Future<User> getCurrentUser() async => const User();

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
  }) async => [];

  @override
  Future<ResourcePage> getResourcePage({
    List<FhirType> resourceTypes = const [],
    String? sourceId,
    List<String>? sourceIds,
    DateFilter? dateFilter,
    bool Function(IFhirResource resource)? where,
    int? limit = 20,
    int offset = 0,
  }) async => (resources: <IFhirResource>[], nextOffset: 0, hasMore: false);

  @override
  Future<List<IFhirResource>> getResourcesByIds(Iterable<String> ids) async =>
      [];

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
  Future<List<IFhirResource>> getAttachedDocuments(
    IFhirResource resource,
  ) async => [];

  @override
  Future<List<IFhirResource>> searchResources({
    required String query,
    List<FhirType> resourceTypes = const [],
    String? sourceId,
    List<String>? sourceIds,
    DateFilter? dateFilter,
    bool Function(IFhirResource resource)? where,
    int limit = 50,
  }) async => [];

  @override
  Future<({Uint8List bytes, String patientName})> buildIpsExport({
    String? sourceId,
    List<String>? sourceIds,
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
  Future<void> createDemoDataSource() async {}

  @override
  Future<void> deleteSource(String sourceId) async {}

  @override
  Future<void> cacheSources(List<Source> sources) async {}

  @override
  Future saveResources(List<IFhirResource> resources) async {}
}

class FakeSyncLocalDataSource extends Fake implements SyncLocalDataSource {}

class FakeHolderRepository extends Fake implements HolderRepository {
  @override
  Future<bool> hasUnassigned() async => false;

  @override
  Future<Map<String, String>> holderBySource() async => {};
}

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

class MockRecordsBloc extends MockBloc<RecordsEvent, RecordsState>
    implements RecordsBloc {}

class MockSyncBloc extends MockBloc<SyncEvent, SyncState> implements SyncBloc {}

// ---------------------------------------------------------------------------
// Registration
// ---------------------------------------------------------------------------

/// Resets getIt and registers the fakes and blocs the App widget resolves.
///
/// The app lock gets its own fakes: [lockAuth] and [lockClock] when given,
/// with [initialPrefs] deciding whether onboarding is done. Call it from the test
/// body, so the lock bloc runs in the test's fake async zone.
Future<void> registerAppDependencies({
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

  final holderRepo = FakeHolderRepository();
  final holderService = HolderService(
    HolderLinkingService(holderRepo),
    holderRepo,
    fakeRecordsRepo,
    fakeSyncRepo,
  );
  final selection = HolderSelection(
    holderService,
    await SharedPreferences.getInstance(),
  );
  final getSourcesUseCase = GetSourcesUseCase(fakeSyncRepo);

  // --- Blocs (constructed with fake dependencies) ---
  final userBloc = UserBloc(fakeUserRepo, fakeBiometricAuth);
  final syncBloc = SyncBloc(
    fakeSyncRepo,
    fakeRecordsRepo,
    DefaultPatientService(
      fakeRecordsRepo,
      FakeSyncLocalDataSource(),
      holderService,
    ),
    AppStringsProvider(),
  );
  final recordsBloc = RecordsBloc(fakeRecordsRepo, SpecialtyClassifierImpl());
  final prefs = await SharedPreferences.getInstance();
  final notificationBloc = NotificationBloc(prefs);
  final patientBloc = PatientBloc(
    holderService,
    selection,
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
  getIt.registerFactory<HolderService>(() => holderService);
  getIt.registerSingleton<HolderSelection>(selection);
  getIt.registerFactory<PatientBloc>(() => patientBloc);
  getIt.registerSingleton<NotificationBloc>(notificationBloc);
  getIt.registerSingleton<AiModelSelectionGuard>(
    AiModelSelectionGuard(FakeDeviceCapabilityService(), prefs),
  );
}
