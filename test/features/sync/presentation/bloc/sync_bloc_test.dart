import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/l10n/app_strings_provider.dart';
import 'package:health_wallet/features/records/domain/repository/records_repository.dart';
import 'package:health_wallet/features/sync/domain/repository/sync_repository.dart';
import 'package:health_wallet/features/sync/ehrs/fasten/domain/entities/sync_qr_data.dart';
import 'package:health_wallet/features/sync/presentation/bloc/sync_bloc.dart';
import 'package:health_wallet/features/user/domain/services/default_patient_service.dart';

class _FakeSyncRepository extends Fake implements SyncRepository {
  Exception? syncError;

  @override
  void setBearerToken(String token) {}

  @override
  void setBaseUrl(String baseUrl) {}

  @override
  Future<void> syncResources({required String endpoint}) async {
    if (syncError != null) throw syncError!;
  }

  @override
  Future<void> saveSyncQrData(SyncQrData qrData) async {}
}

class _FakeRecordsRepository extends Fake implements RecordsRepository {}

class _FakeDefaultPatientService extends Fake implements DefaultPatientService {
  @override
  Future<void> createAndSetAsMain() async {}
}

final _qr = jsonEncode({
  'token': 'not-a-jwt',
  'server_base_urls': ['https://fasten.local'],
  'sync_endpoint': '/sync',
});

void main() {
  late _FakeSyncRepository syncRepository;

  SyncBloc bloc(String locale) => SyncBloc(
    syncRepository,
    _FakeRecordsRepository(),
    _FakeDefaultPatientService(),
    AppStringsProvider.forLocale(Locale(locale)),
  );

  Future<SyncState> syncedState(SyncBloc bloc) {
    final done = bloc.stream.firstWhere((s) => !s.isLoading);
    bloc.add(SyncData(qrData: _qr));
    return done;
  }

  setUp(() => syncRepository = _FakeSyncRepository());

  test('reports a successful sync in Romanian', () async {
    final state = await syncedState(bloc('ro'));
    expect(state.successMessage, 'Datele au fost sincronizate cu succes!');
  });

  test('reports a successful sync in English, spelled right', () async {
    final state = await syncedState(bloc('en'));
    expect(state.successMessage, 'Data was successfully synced!');
  });

  final errors = {
    'Connection refused':
        'Conexiunea a eșuat. Verifică rețeaua și încearcă din nou.',
    'HTTP 404': 'Punctul de sincronizare nu a fost găsit. Verifică configurația serverului.',
    'HTTP 401': 'Autentificarea a eșuat. Verifică tokenul.',
  };
  errors.forEach((cause, message) {
    test('reports "$cause" in Romanian', () async {
      syncRepository.syncError = Exception(cause);
      final state = await syncedState(bloc('ro'));
      expect(state.errorMessage, message);
    });
  });

  test('reports an unknown failure in Romanian with its cause', () async {
    syncRepository.syncError = Exception('boom');
    final state = await syncedState(bloc('ro'));
    expect(
      state.errorMessage,
      'Sincronizarea datelor a eșuat: Exception: boom',
    );
  });
}
