import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/app/app.dart';
import 'package:health_wallet/core/di/injection.dart' hide PdfStorageService;
import 'package:health_wallet/core/navigation/app_router.dart';
import 'package:health_wallet/core/navigation/observers/order_route_observer.dart';
import 'package:health_wallet/core/services/biometric_auth_service.dart';
import 'package:health_wallet/core/services/pdf_storage_service.dart';
import 'package:health_wallet/features/notifications/bloc/notification_bloc.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/records/domain/entity/record_note/record_note.dart';
import 'package:health_wallet/features/records/domain/repository/records_repository.dart';
import 'package:health_wallet/features/records/presentation/bloc/records_bloc.dart';
import 'package:health_wallet/features/scan/domain/entity/processing_session.dart';
import 'package:health_wallet/features/scan/domain/repository/scan_repository.dart';
import 'package:health_wallet/features/scan/domain/services/document_reference_service.dart';
import 'package:health_wallet/features/scan/domain/services/text_recognition_service.dart';
import 'package:health_wallet/features/scan/presentation/bloc/scan_bloc.dart';
import 'package:health_wallet/features/scan/presentation/helpers/ocr_processing_helper.dart';
import 'package:health_wallet/features/sync/data/data_source/local/sync_local_data_source.dart';
import 'package:health_wallet/features/sync/domain/entities/source.dart';
import 'package:health_wallet/features/sync/domain/entities/sync_qr_data.dart';
import 'package:health_wallet/features/sync/domain/repository/sync_repository.dart';
import 'package:health_wallet/features/sync/domain/services/source_type_service.dart';
import 'package:health_wallet/features/sync/domain/services/wallet_patient_service.dart';
import 'package:health_wallet/features/sync/domain/use_case/get_sources_use_case.dart';
import 'package:health_wallet/features/sync/presentation/bloc/sync_bloc.dart';
import 'package:health_wallet/features/user/domain/entity/user.dart';
import 'package:health_wallet/features/user/domain/repository/user_repository.dart';
import 'package:health_wallet/features/user/domain/services/default_patient_service.dart';
import 'package:health_wallet/features/user/domain/services/patient_deduplication_service.dart';
import 'package:health_wallet/features/user/domain/services/patient_selection_service.dart';
import 'package:health_wallet/features/user/presentation/bloc/user_bloc.dart';
import 'package:health_wallet/features/user/presentation/preferences_modal/sections/patient/bloc/patient_bloc.dart';
import 'package:health_wallet/features/user/presentation/preferences_modal/sections/patient/services/patient_edit_service.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  }) async =>
      [];

  @override
  Future<List<IFhirResource>> getRelatedResourcesForEncounter({
    required String encounterId,
    String? sourceId,
  }) async =>
      [];

  @override
  Future<List<IFhirResource>> getRelatedResources({
    required IFhirResource resource,
  }) async =>
      [];

  @override
  Future<IFhirResource?> resolveReference(String reference) async => null;

  @override
  Future<int> addRecordNote({
    required String resourceId,
    String? sourceId,
    required String content,
  }) async =>
      0;

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
  }) async =>
      [];

  @override
  Future<String> saveObservation(IFhirResource observation) async => '';

  @override
  Future<void> updatePatient(IFhirResource patient) async {}

  @override
  Future<List<IFhirResource>> searchResources({
    required String query,
    List<FhirType> resourceTypes = const [],
    String? sourceId,
    int limit = 50,
  }) async =>
      [];

  @override
  Future<({Uint8List bytes, String patientName})> buildIpsExport({
    String? sourceId,
    String? patientId,
  }) async =>
      (bytes: Uint8List(0), patientName: 'Unknown');
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

class FakeScanRepository extends Fake implements ScanRepository {
  @override
  Future<List<ProcessingSession>> getProcessingSessions() async => [];

  @override
  Future<int> editProcessingSession(ProcessingSession session) async => 0;

  @override
  Future<int> deleteProcessingSession(ProcessingSession session) async => 0;

  @override
  Future<bool> checkModelExistence() async => false;

  @override
  Future<void> cancelGeneration() async {}

  @override
  Future<void> waitForStreamCompletion() async {}

  @override
  Future disposeModel() async {}
}

class FakeSyncLocalDataSource extends Fake implements SyncLocalDataSource {}

// ---------------------------------------------------------------------------
// Mock classes for concrete types that cannot be easily constructed in tests
// (e.g. they depend on native plugins or database connections)
// ---------------------------------------------------------------------------

class MockTextRecognitionService extends Mock
    implements TextRecognitionService {}

class MockDocumentReferenceService extends Mock
    implements DocumentReferenceService {}

class MockPatientEditService extends Mock implements PatientEditService {}

// ---------------------------------------------------------------------------
// Test
// ---------------------------------------------------------------------------

void main() {
  testWidgets('App starts', (WidgetTester tester) async {
    // Provide fake SharedPreferences values before any code touches it
    SharedPreferences.setMockInitialValues({});

    // Reset the service locator to a clean state
    await getIt.reset();

    // --- Fake repositories & services ---
    final fakeUserRepo = FakeUserRepository();
    final fakeBiometricAuth = FakeBiometricAuthService();
    final fakeRecordsRepo = FakeRecordsRepository();
    final fakeSyncRepo = FakeSyncRepository();
    final fakeScanRepo = FakeScanRepository();

    final deduplicationService =
        PatientDeduplicationService(fakeRecordsRepo, fakeSyncRepo);
    final selectionService = PatientSelectionService(deduplicationService);
    final getSourcesUseCase = GetSourcesUseCase(fakeSyncRepo);
    final walletPatientService = WalletPatientService(fakeSyncRepo);
    final sourceTypeService =
        SourceTypeService(walletPatientService, fakeSyncRepo);

    // --- Blocs (constructed with fake dependencies) ---
    final userBloc = UserBloc(fakeUserRepo, fakeBiometricAuth);
    final syncBloc = SyncBloc(
      fakeSyncRepo,
      fakeRecordsRepo,
      DefaultPatientService(fakeRecordsRepo, FakeSyncLocalDataSource()),
    );
    final recordsBloc = RecordsBloc(fakeRecordsRepo);
    final prefs = await SharedPreferences.getInstance();
    final scanBloc = ScanBloc(
      PdfStorageService(),
      fakeScanRepo,
      OcrProcessingHelper(MockTextRecognitionService()),
      fakeSyncRepo,
      MockDocumentReferenceService(),
      deduplicationService,
      sourceTypeService,
      fakeRecordsRepo,
      prefs,
    );
    final notificationBloc = NotificationBloc(prefs);
    final patientBloc = PatientBloc(
      fakeRecordsRepo,
      deduplicationService,
      MockPatientEditService(),
    );

    // --- Register everything the App widget resolves from getIt ---
    getIt.registerSingleton<AppRouter>(AppRouter());
    getIt.registerFactory<AppRouteObserver>(() => AppRouteObserver());
    getIt.registerFactory<UserBloc>(() => userBloc);
    getIt.registerFactory<SyncBloc>(() => syncBloc);
    getIt.registerFactory<RecordsBloc>(() => recordsBloc);
    getIt.registerSingleton<ScanBloc>(scanBloc);
    getIt.registerFactory<GetSourcesUseCase>(() => getSourcesUseCase);
    getIt.registerFactory<RecordsRepository>(() => fakeRecordsRepo);
    getIt.registerFactory<SyncRepository>(() => fakeSyncRepo);
    getIt.registerFactory<PatientDeduplicationService>(
        () => deduplicationService);
    getIt.registerFactory<PatientSelectionService>(() => selectionService);
    getIt.registerFactory<PatientBloc>(() => patientBloc);
    getIt.registerSingleton<NotificationBloc>(notificationBloc);

    // Build the App widget and pump a single frame.
    // Using pump() (not pumpAndSettle) because the route pages may have
    // their own getIt dependencies that are not registered in this test.
    // A single frame is enough to verify that MaterialApp is in the tree.
    await tester.pumpWidget(const App());
    await tester.pump();

    expect(find.byType(MaterialApp), findsOneWidget);

    // Cleanup
    await userBloc.close();
    await syncBloc.close();
    await recordsBloc.close();
    await scanBloc.close();
    await notificationBloc.close();
    await patientBloc.close();
  });
}
