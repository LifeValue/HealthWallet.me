import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/l10n/app_strings_provider.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/features/records/domain/repository/records_repository.dart';
import 'package:health_wallet/features/sync/domain/repository/sync_repository.dart';
import 'package:health_wallet/features/sync/ehrs/fasten/domain/entities/sync_qr_data.dart';
import 'package:health_wallet/features/sync/presentation/bloc/sync_bloc.dart';
import 'package:health_wallet/features/user/domain/services/default_patient_service.dart';

class _FakeSyncRepository extends Fake implements SyncRepository {
  /// Errors thrown by `syncResources`, one per server tried, in order; a
  /// null entry means that server succeeds.
  List<Object?> syncErrors = [];
  Error? readError;
  SyncQrData? savedQr;
  String? lastSyncTime;
  final baseUrls = <String>[];
  final tokens = <String>[];

  @override
  void setBearerToken(String token) => tokens.add(token);

  @override
  void setBaseUrl(String baseUrl) => baseUrls.add(baseUrl);

  @override
  Future<void> syncResources({required String endpoint}) async {
    final index = baseUrls.length - 1;
    final error = index < syncErrors.length ? syncErrors[index] : null;
    // The cases mix Exceptions and Errors, so throw them as they are.
    if (error != null) Error.throwWithStackTrace(error, StackTrace.current);
  }

  @override
  Future<void> saveSyncQrData(SyncQrData qrData) async => savedQr = qrData;

  @override
  Future<SyncQrData?> getCurrentSyncQrData() async {
    if (readError != null) throw readError!;
    return savedQr;
  }

  @override
  Future<String?> getLastSyncTimestamp() async => lastSyncTime;
}

class _FakeRecordsRepository extends Fake implements RecordsRepository {
  Error? loadError;
  bool demoLoaded = false;

  @override
  Future<void> loadDemoData() async {
    if (loadError != null) throw loadError!;
    demoLoaded = true;
  }

  @override
  Future<bool> hasDemoData() async => demoLoaded;
}

class _FakeDefaultPatientService extends Fake implements DefaultPatientService {
  Error? error;
  int calls = 0;

  @override
  Future<void> createAndSetAsMain() async {
    calls++;
    if (error != null) throw error!;
  }
}

String _qrJson({List<String> urls = const ['https://fasten.local']}) =>
    jsonEncode({
      'token': 'not-a-jwt',
      'server_base_urls': urls,
      'sync_endpoint': '/sync',
    });

final _en = lookupAppLocalizations(const Locale('en'));
final _ro = lookupAppLocalizations(const Locale('ro'));

DioException _dio(DioExceptionType type, {int? status, Object? error}) =>
    DioException(
      requestOptions: RequestOptions(path: '/sync'),
      type: type,
      error: error,
      response: status == null
          ? null
          : Response(
              requestOptions: RequestOptions(path: '/sync'),
              statusCode: status,
            ),
    );

void main() {
  late _FakeSyncRepository syncRepository;
  late _FakeRecordsRepository recordsRepository;
  late _FakeDefaultPatientService patientService;
  final blocs = <SyncBloc>[];

  SyncBloc bloc([String locale = 'en']) {
    final created = SyncBloc(
      syncRepository,
      recordsRepository,
      patientService,
      AppStringsProvider.forLocale(Locale(locale)),
    );
    blocs.add(created);
    return created;
  }

  Future<SyncState> sync(SyncBloc bloc, [String? qr]) {
    final done = bloc.stream.firstWhere((s) => !s.isLoading);
    bloc.add(SyncData(qrData: qr ?? _qrJson()));
    return done;
  }

  setUp(() {
    syncRepository = _FakeSyncRepository();
    recordsRepository = _FakeRecordsRepository();
    patientService = _FakeDefaultPatientService();
  });

  tearDown(() async {
    for (final b in blocs) {
      await b.close();
    }
    blocs.clear();
  });

  group('sync', () {
    test('reports a successful sync in Romanian', () async {
      final state = await sync(bloc('ro'));
      expect(state.successMessage, 'Datele au fost sincronizate cu succes!');
    });

    test('reports a successful sync in English, spelled right', () async {
      final state = await sync(bloc());
      expect(state.successMessage, 'Data was successfully synced!');
    });

    test('a successful sync saves the QR data and marks it synced', () async {
      final b = bloc();
      final statuses = <SyncStatus>[];
      final sub = b.stream.listen((s) => statuses.add(s.syncStatus));

      final state = await sync(b);
      await pumpEventQueue();
      await sub.cancel();

      expect(statuses.first, SyncStatus.syncing);
      expect(state.syncStatus, SyncStatus.synced);
      expect(state.errorMessage, isNull);
      expect(state.syncDialogShown, isTrue);
      expect(state.lastSyncTime, isNotNull);
      expect(syncRepository.savedQr?.syncEndpoint, '/sync');
      expect(syncRepository.tokens, ['not-a-jwt']);
      expect(patientService.calls, 1);
      expect(b.state.hasSyncedData, isTrue);
    });

    test('falls back to the next server when one fails', () async {
      syncRepository.syncErrors = [
        _dio(DioExceptionType.connectionError),
        null,
      ];

      final state = await sync(
        bloc(),
        _qrJson(urls: ['https://a.local', 'https://b.local']),
      );

      expect(syncRepository.baseUrls, ['https://a.local', 'https://b.local']);
      expect(state.syncStatus, SyncStatus.synced);
    });

    test('reports the last server error when every server fails', () async {
      syncRepository.syncErrors = [
        _dio(DioExceptionType.connectionError),
        _dio(DioExceptionType.badResponse, status: 401),
      ];

      final state = await sync(
        bloc(),
        _qrJson(urls: ['https://a.local', 'https://b.local']),
      );

      expect(state.errorMessage, _en.syncErrorAuthentication);
      expect(state.syncStatus, SyncStatus.initial);
      expect(syncRepository.savedQr, isNull);
    });
  });

  group('sync errors are classified by type', () {
    final cases = <String, (Object, String)>{
      'a connection error': (
        _dio(DioExceptionType.connectionError),
        _ro.syncErrorConnection,
      ),
      'a connection timeout': (
        _dio(DioExceptionType.connectionTimeout),
        _ro.syncErrorConnection,
      ),
      'a receive timeout': (
        _dio(DioExceptionType.receiveTimeout),
        _ro.syncErrorConnection,
      ),
      'a send timeout': (
        _dio(DioExceptionType.sendTimeout),
        _ro.syncErrorConnection,
      ),
      'a bad certificate': (
        _dio(DioExceptionType.badCertificate),
        _ro.syncErrorConnection,
      ),
      'an unknown Dio error caused by a socket': (
        _dio(
          DioExceptionType.unknown,
          error: const SocketException('Connection refused'),
        ),
        _ro.syncErrorConnection,
      ),
      'a socket error': (
        const SocketException('Connection refused'),
        _ro.syncErrorConnection,
      ),
      'a TLS handshake error': (
        const HandshakeException('bad cert'),
        _ro.syncErrorConnection,
      ),
      'a timeout': (TimeoutException('slow'), _ro.syncErrorConnection),
      'HTTP 404': (
        _dio(DioExceptionType.badResponse, status: 404),
        _ro.syncErrorEndpointNotFound,
      ),
      'HTTP 401': (
        _dio(DioExceptionType.badResponse, status: 401),
        _ro.syncErrorAuthentication,
      ),
      'HTTP 403': (
        _dio(DioExceptionType.badResponse, status: 403),
        _ro.syncErrorAuthentication,
      ),
      'HTTP 500': (
        _dio(DioExceptionType.badResponse, status: 500),
        _ro.syncErrorGeneric,
      ),
      'a cancelled request': (
        _dio(DioExceptionType.cancel),
        _ro.syncErrorGeneric,
      ),
      'an unknown Dio error without a cause': (
        _dio(DioExceptionType.unknown),
        _ro.syncErrorGeneric,
      ),
      'an unreadable response': (
        const FormatException('Unexpected character'),
        _ro.syncErrorInvalidFormat,
      ),
      'an unexpected error': (StateError('boom'), _ro.syncErrorGeneric),
    };
    cases.forEach((cause, expected) {
      test('reports $cause in Romanian', () async {
        syncRepository.syncErrors = [expected.$1];
        final state = await sync(bloc('ro'));
        expect(state.errorMessage, expected.$2);
        expect(state.isLoading, isFalse);
        expect(state.successMessage, isNull);
      });
    });

    test(
      'error text that only looks like a status is not classified',
      () async {
        syncRepository.syncErrors = [Exception('HTTP 404 Connection refused')];
        final state = await sync(bloc('ro'));
        expect(state.errorMessage, _ro.syncErrorGeneric);
      },
    );

    test('the generic message carries no exception text', () async {
      syncRepository.syncErrors = [Exception('boom at /secret/path')];
      final state = await sync(bloc('ro'));
      expect(
        state.errorMessage,
        'Sincronizarea datelor a eșuat. Încearcă din nou.',
      );
      expect(state.errorMessage, isNot(contains('boom')));
    });
  });

  group('invalid QR codes', () {
    for (final (name, qr) in [
      ('not JSON', 'hello'),
      ('a JSON list', '[1, 2]'),
      ('JSON without the sync keys', '{"foo": 1}'),
    ]) {
      test('$name reports an invalid format without syncing', () async {
        final state = await sync(bloc(), qr);

        expect(state.errorMessage, _en.syncErrorInvalidFormat);
        expect(state.syncStatus, SyncStatus.initial);
        expect(syncRepository.baseUrls, isEmpty);
        expect(patientService.calls, 0);
      });
    }

    test('a new sync clears the previous error', () async {
      final b = bloc();
      await sync(b, 'hello');

      final cleared = b.stream.firstWhere((s) => s.isLoading);
      b.add(SyncData(qrData: _qrJson()));
      expect((await cleared).errorMessage, isNull);
    });
  });

  group('initialisation', () {
    test('a saved QR code means synced', () async {
      syncRepository.savedQr = SyncQrData.fromJson(
        jsonDecode(_qrJson()) as Map<String, dynamic>,
      );
      syncRepository.lastSyncTime = '2026-10-01T10:00:00';
      final b = bloc();

      b.add(const SyncInitialised());
      final state = await b.stream.firstWhere((s) => !s.isLoading);

      expect(state.syncStatus, SyncStatus.synced);
      expect(state.lastSyncTime, '2026-10-01T10:00:00');
      expect(state.syncQrData, isNotNull);
    });

    test('no saved QR code means not synced', () async {
      final b = bloc();

      b.add(const SyncInitialised());
      final state = await b.stream.firstWhere((s) => !s.isLoading);

      expect(state.syncStatus, SyncStatus.initial);
      expect(state.errorMessage, isNull);
    });

    test('a failed read shows the generic message only', () async {
      syncRepository.readError = StateError('prefs broken');
      final b = bloc('ro');

      b.add(const SyncInitialised());
      final state = await b.stream.firstWhere((s) => !s.isLoading);

      expect(state.errorMessage, _ro.syncErrorGeneric);
      expect(state.errorMessage, isNot(contains('prefs')));
    });
  });

  group('scanner and cancel', () {
    test('opening the scanner, scanning again and cancelling', () async {
      final b = bloc();

      b.add(const SyncScanQRCode());
      expect((await b.stream.first).isQRScanning, isTrue);

      b.add(const SyncScanNewPressed());
      expect((await b.stream.first).syncStatus, SyncStatus.syncing);

      b.add(const SyncCancel());
      final cancelled = await b.stream.first;
      expect(cancelled.isQRScanning, isFalse);
      expect(cancelled.syncStatus, SyncStatus.initial);
      expect(cancelled.isLoading, isFalse);
    });
  });

  group('demo data', () {
    test('loading demo data marks it present', () async {
      final b = bloc();

      b.add(const LoadDemoData());
      final state = await b.stream.firstWhere((s) => s.hasDemoData);

      expect(recordsRepository.demoLoaded, isTrue);
      expect(patientService.calls, 1);
      expect(state.errorMessage, isNull);
    });

    test('a second load is seen to finish, though the demo data was '
        'already there', () async {
      final b = bloc();

      b.add(const LoadDemoData());
      await b.stream.firstWhere((s) => s.demoLoads == 1);
      b.add(const LoadDemoData());
      final second = await b.stream.firstWhere((s) => s.demoLoads == 2);

      expect(second.hasDemoData, isTrue);
    });

    test('a failed demo load shows the generic message only', () async {
      recordsRepository.loadError = StateError('asset missing');
      final b = bloc('ro');

      b.add(const LoadDemoData());
      final state = await b.stream.firstWhere((s) => s.errorMessage != null);
      await pumpEventQueue();

      expect(state.errorMessage, _ro.syncErrorGeneric);
      expect(b.state.hasDemoData, isFalse);
    });

    test('a repeated failure clears the message first, so it shows '
        'again', () async {
      recordsRepository.loadError = StateError('asset missing');
      final b = bloc();
      final messages = <String?>[];
      final sub = b.stream.listen((s) => messages.add(s.errorMessage));
      addTearDown(sub.cancel);

      b.add(const LoadDemoData());
      await pumpEventQueue();
      b.add(const LoadDemoData());
      await pumpEventQueue();

      final changes = <String?>[
        for (var i = 0; i < messages.length; i++)
          if (i == 0 || messages[i] != messages[i - 1]) messages[i],
      ];
      expect(changes.where((m) => m != null), hasLength(2));
      expect(
        changes,
        containsAllInOrder([_en.syncErrorGeneric, null, _en.syncErrorGeneric]),
      );
    });
  });

  group('tutorial', () {
    test('trigger, confirm and reset', () async {
      final b = bloc();

      b.add(const TriggerTutorial());
      expect((await b.stream.first).shouldShowTutorial, isTrue);

      b.add(const DemoDataConfirmed());
      expect((await b.stream.first).demoDataConfirmed, isTrue);

      b.add(const ResetTutorial());
      final reset = await b.stream.first;
      expect(reset.shouldShowTutorial, isFalse);
      expect(reset.demoDataConfirmed, isFalse);
      expect(reset.syncDialogShown, isFalse);
    });
  });

  test('DataHandled for a failure changes nothing', () async {
    final b = bloc();

    b.add(const DataHandled(sourceId: 'demo_data', isSuccess: false));
    await pumpEventQueue();

    expect(b.state, const SyncState());
  });
}
