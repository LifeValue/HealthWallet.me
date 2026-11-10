import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/l10n/app_strings_provider.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/features/wallet_pass/domain/entity/emergency_card_data.dart';
import 'package:health_wallet/features/wallet_pass/domain/entity/wallet_pass_labels.dart';
import 'package:health_wallet/features/wallet_pass/domain/repository/wallet_pass_repository.dart';
import 'package:health_wallet/features/wallet_pass/domain/service/emergency_card_builder.dart';
import 'package:health_wallet/features/wallet_pass/presentation/bloc/wallet_pass_bloc.dart';

import '../../../share_records/share_test_helpers.dart';

const _appleWallet = MethodChannel(
  'com.techstackapps.healthwallet/apple_wallet',
);
const _googleWallet =
    'dev.flutter.pigeon.flutter_google_wallet.GoogleWalletApi';

final _en = lookupAppLocalizations(const Locale('en'));

const _card = EmergencyCardData(patientName: 'Jane Doe', bloodType: 'A+');

class _FakeCardBuilder extends Fake implements EmergencyCardBuilder {
  Error? error;
  int calls = 0;

  @override
  Future<EmergencyCardData> build({
    required String patientId,
    List<String>? sourceIds,
  }) async {
    calls++;
    if (error != null) throw error!;
    return _card;
  }
}

class _FakeWalletPassRepository extends Fake implements WalletPassRepository {
  Error? error;
  WalletPassLabels? labels;

  @override
  Future<Uint8List> generateApplePass({
    required EmergencyCardData cardData,
    required String patientId,
    required WalletPassLabels labels,
  }) async {
    if (error != null) throw error!;
    this.labels = labels;
    return Uint8List.fromList([1, 2, 3]);
  }

  @override
  Future<String> generateGooglePassJson({
    required EmergencyCardData cardData,
    required String patientId,
    required WalletPassLabels labels,
  }) async {
    if (error != null) throw error!;
    this.labels = labels;
    return '{"pass":true}';
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late Directory root;
  late _FakeCardBuilder builder;
  late _FakeWalletPassRepository repository;
  late WalletPassBloc bloc;

  /// What the native Apple Wallet side saw: whether the pass file existed
  /// when `addPass` was called, and its path.
  late List<(String, bool)> addPassCalls;
  Exception? addPassError;
  late List<String> googleCalls;

  setUp(() {
    root = mockPathProvider();
    builder = _FakeCardBuilder();
    repository = _FakeWalletPassRepository();
    bloc = WalletPassBloc(
      builder,
      repository,
      AppStringsProvider.forLocale(const Locale('en')),
    );
    addPassCalls = [];
    addPassError = null;
    googleCalls = [];

    messenger.setMockMethodCallHandler(_appleWallet, (call) async {
      final path = (call.arguments as Map)['filePath'] as String;
      addPassCalls.add((path, File(path).existsSync()));
      if (addPassError != null) throw addPassError!;
      return null;
    });
    for (final method in ['initWalletClient', 'savePassesJwt']) {
      messenger.setMockMessageHandler('$_googleWallet.$method', (_) async {
        googleCalls.add(method);
        return const StandardMessageCodec().encodeMessage(<Object?>[null]);
      });
    }
  });

  tearDown(() async {
    await bloc.close();
    messenger.setMockMethodCallHandler(_appleWallet, null);
    for (final method in ['initWalletClient', 'savePassesJwt']) {
      messenger.setMockMessageHandler('$_googleWallet.$method', null);
    }
  });

  File passFile() => File('${root.path}/tmp/HealthWallet_Emergency.pkpass');

  Future<List<WalletPassStatus>> request(WalletPassType type) async {
    final statuses = <WalletPassStatus>[];
    final sub = bloc.stream.listen((s) => statuses.add(s.status));
    bloc.add(WalletPassRequested(type: type, patientId: 'p1'));
    // The handler does real file I/O, so wait for its last state rather
    // than for the microtask queue.
    await bloc.stream
        .firstWhere(
          (s) =>
              s.status == WalletPassStatus.passAddedToWallet ||
              s.status == WalletPassStatus.failure,
        )
        .timeout(const Duration(seconds: 5));
    await pumpEventQueue();
    await sub.cancel();
    return statuses;
  }

  test('a second tap while a pass is being made is dropped', () async {
    final done = bloc.stream
        .firstWhere(
          (s) =>
              s.status == WalletPassStatus.passAddedToWallet ||
              s.status == WalletPassStatus.failure,
        )
        .timeout(const Duration(seconds: 5));
    bloc
      ..add(
        const WalletPassRequested(type: WalletPassType.apple, patientId: 'p1'),
      )
      ..add(
        const WalletPassRequested(type: WalletPassType.apple, patientId: 'p1'),
      );
    await done;
    await pumpEventQueue();

    expect(builder.calls, 1);
    expect(addPassCalls, hasLength(1));
  });

  group('Apple Wallet', () {
    test('adds the pass, then deletes its temp file', () async {
      final statuses = await request(WalletPassType.apple);

      expect(statuses, [
        WalletPassStatus.loading,
        WalletPassStatus.dataReady,
        WalletPassStatus.passGenerated,
        WalletPassStatus.passAddedToWallet,
      ]);
      expect(bloc.state.cardData, _card);
      expect(bloc.state.passBytes, [1, 2, 3]);
      expect(addPassCalls, [(passFile().path, true)]);
      expect(passFile().existsSync(), isFalse);
    });

    test('uses the app-language labels when none are given', () async {
      await request(WalletPassType.apple);

      expect(repository.labels, isNotNull);
    });

    test('deletes the temp file when addPass throws', () async {
      addPassError = PlatformException(code: 'ADD_FAILED');

      final statuses = await request(WalletPassType.apple);

      expect(statuses.last, WalletPassStatus.failure);
      expect(bloc.state.errorMessage, _en.walletPassFailed);
      expect(addPassCalls, hasLength(1));
      expect(passFile().existsSync(), isFalse);
    });

    test('fails without a file when the pass cannot be built', () async {
      repository.error = StateError('no signing key');

      final statuses = await request(WalletPassType.apple);

      expect(statuses, [
        WalletPassStatus.loading,
        WalletPassStatus.dataReady,
        WalletPassStatus.failure,
      ]);
      expect(bloc.state.errorMessage, _en.walletPassFailed);
      expect(addPassCalls, isEmpty);
      expect(passFile().existsSync(), isFalse);
    });
  });

  group('Google Wallet', () {
    test('saves the pass JWT', () async {
      final statuses = await request(WalletPassType.google);
      await pumpEventQueue();

      expect(statuses, [
        WalletPassStatus.loading,
        WalletPassStatus.dataReady,
        WalletPassStatus.passGenerated,
        WalletPassStatus.passAddedToWallet,
      ]);
      expect(bloc.state.googlePassJson, '{"pass":true}');
      expect(googleCalls, containsAll(['initWalletClient', 'savePassesJwt']));
      expect(passFile().existsSync(), isFalse);
    });

    test('fails when the pass JSON cannot be built', () async {
      repository.error = StateError('no service account');

      final statuses = await request(WalletPassType.google);

      expect(statuses.last, WalletPassStatus.failure);
      expect(googleCalls, isEmpty);
    });

    test(
      'a failed save is reported as a failure',
      () async {
        messenger.setMockMessageHandler(
          '$_googleWallet.savePassesJwt',
          (_) async => const StandardMessageCodec().encodeMessage(<Object?>[
            'SAVE_FAILED',
            'cancelled',
            null,
          ]),
        );

        final statuses = await request(WalletPassType.google);
        await pumpEventQueue();

        expect(statuses.last, WalletPassStatus.failure);
        expect(bloc.state.errorMessage, _en.walletPassFailed);
        expect(bloc.state.errorMessage, isNot(contains('SAVE_FAILED')));
      },
    );

    test('a failed wallet client start is reported as a failure', () async {
      messenger.setMockMessageHandler(
        '$_googleWallet.initWalletClient',
        (_) async => const StandardMessageCodec().encodeMessage(<Object?>[
          'INIT_FAILED',
          'no Play services',
          null,
        ]),
      );

      final statuses = await request(WalletPassType.google);

      expect(statuses.last, WalletPassStatus.failure);
      expect(googleCalls, isNot(contains('savePassesJwt')));
    });
  });

  test('fails when the card data cannot be read', () async {
    builder.error = StateError('no patient');

    final statuses = await request(WalletPassType.apple);

    expect(statuses, [WalletPassStatus.loading, WalletPassStatus.failure]);
    expect(bloc.state.errorMessage, _en.walletPassFailed);
  });

  test('the failure message is in the app language', () async {
    await bloc.close();
    bloc = WalletPassBloc(
      builder,
      repository,
      AppStringsProvider.forLocale(const Locale('ro')),
    );
    builder.error = StateError('no patient');

    await request(WalletPassType.google);

    final ro = lookupAppLocalizations(const Locale('ro'));
    expect(bloc.state.errorMessage, ro.walletPassFailed);
    expect(ro.walletPassFailed, isNot(_en.walletPassFailed));
  });

  test('a new request clears the previous failure', () async {
    builder.error = StateError('no patient');
    await request(WalletPassType.apple);
    builder.error = null;

    final statuses = await request(WalletPassType.apple);

    expect(statuses.first, WalletPassStatus.loading);
    expect(statuses.last, WalletPassStatus.passAddedToWallet);
    expect(bloc.state.errorMessage, isNull);
  });
}
