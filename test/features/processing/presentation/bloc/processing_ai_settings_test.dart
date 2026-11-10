import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/config/constants/shared_prefs_constants.dart';
import 'package:health_wallet/core/l10n/app_strings_provider.dart';
import 'package:health_wallet/features/holders/domain/services/holder_selection.dart';
import 'package:health_wallet/features/holders/domain/services/holder_service.dart';
import 'package:health_wallet/features/processing/domain/deep_scan_defaults.dart';
import 'package:health_wallet/features/processing/domain/entity/processing_session.dart';
import 'package:health_wallet/features/processing/domain/repository/processing_repository.dart';
import 'package:health_wallet/features/processing/domain/services/document_reference_service.dart';
import 'package:health_wallet/features/processing/domain/services/layout_extraction/layout_extraction_service.dart';
import 'package:health_wallet/features/processing/domain/services/layout_extraction/layout_extractor_registry.dart';
import 'package:health_wallet/features/processing/domain/services/ocr_processing_service.dart';
import 'package:health_wallet/features/processing/presentation/bloc/processing_bloc.dart';
import 'package:health_wallet/features/records/domain/repository/records_repository.dart';
import 'package:health_wallet/features/sync/domain/repository/sync_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../share_records/share_test_helpers.dart';

class _FakeProcessingRepository extends Fake implements ProcessingRepository {
  int disposes = 0;

  @override
  Future<List<ProcessingSession>> getProcessingSessions() async => const [
    ProcessingSession(id: 'saved'),
  ];

  @override
  Future<void> disposeModel() async => disposes++;
}

class _FakeOcrProcessingHelper extends Fake implements OcrProcessingHelper {}

class _FakeSyncRepository extends Fake implements SyncRepository {}

class _FakeRecordsRepository extends Fake implements RecordsRepository {}

class _FakeDocumentReferenceService extends Fake
    implements DocumentReferenceService {}

class _FakeHolderService extends Fake implements HolderService {}

class _FakeHolderSelection extends Fake implements HolderSelection {}

/// The bloc reads the platform from `dart:io`, so on a test host it runs as
/// the desktop; the mobile side of the reset is covered by
/// `ai_settings_reset_test.dart`.
final _hostIsDesktop =
    Platform.isMacOS || Platform.isLinux || Platform.isWindows;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeProcessingRepository repository;
  final blocs = <ProcessingBloc>[];

  setUp(() {
    mockPathProvider();
    repository = _FakeProcessingRepository();
  });

  tearDown(() async {
    for (final bloc in blocs) {
      await bloc.close();
    }
    blocs.clear();
  });

  Future<ProcessingBloc> newBloc() async {
    final bloc = ProcessingBloc(
      repository,
      _FakeOcrProcessingHelper(),
      _FakeSyncRepository(),
      _FakeDocumentReferenceService(),
      _FakeHolderService(),
      _FakeHolderSelection(),
      _FakeRecordsRepository(),
      await SharedPreferences.getInstance(),
      AppStringsProvider.forLocale(const Locale('en')),
      LayoutExtractionService(
        repository,
        _FakeOcrProcessingHelper(),
        LayoutExtractorRegistry(const []),
        _FakeHolderService(),
        _FakeRecordsRepository(),
      ),
    );
    blocs.add(bloc);
    return bloc;
  }

  /// Starts the app once: a new bloc over the same saved preferences.
  Future<ProcessingBloc> start() async {
    final bloc = await newBloc();
    final loaded = bloc.stream.firstWhere(
      (s) => s.status is Initial && s.sessions.isNotEmpty,
    );
    bloc.add(const ProcessingInitialised());
    await loaded.timeout(const Duration(seconds: 5));
    return bloc;
  }

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  group('one-time reset of mistakenly saved AI settings', () {
    test('a fresh install keeps nothing saved and uses the defaults', () async {
      SharedPreferences.setMockInitialValues({});

      final bloc = await start();
      final prefs = await SharedPreferences.getInstance();

      expect(prefs.getInt(SharedPrefsConstants.aiMaxTokens), isNull);
      expect(prefs.getBool(SharedPrefsConstants.aiUseVision), isNull);
      expect(bloc.state.useVision, defaultDeepScan(_hostIsDesktop));
      expect(
        prefs.getBool(SharedPrefsConstants.aiMistakenSettingsReset),
        isTrue,
      );
    });

    test('the first start after the update removes the 500 token limit '
        'and, on the desktop, Deep Scan saved off', () async {
      SharedPreferences.setMockInitialValues({
        SharedPrefsConstants.aiMaxTokens: 500,
        SharedPrefsConstants.aiUseVision: false,
        SharedPrefsConstants.aiContextSize: 2048,
      });

      final bloc = await start();
      final prefs = await SharedPreferences.getInstance();

      expect(prefs.getInt(SharedPrefsConstants.aiMaxTokens), isNull);
      expect(
        prefs.getBool(SharedPrefsConstants.aiUseVision),
        _hostIsDesktop ? isNull : isFalse,
      );
      expect(bloc.state.useVision, defaultDeepScan(_hostIsDesktop));
      // A setting the bug did not change is kept.
      expect(prefs.getInt(SharedPrefsConstants.aiContextSize), 2048);
    });

    test('runs only once: values saved after it are kept', () async {
      SharedPreferences.setMockInitialValues({
        SharedPrefsConstants.aiMaxTokens: 500,
      });
      await start();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt(SharedPrefsConstants.aiMaxTokens), isNull);

      // The user now picks 500 and Deep Scan off on purpose.
      await prefs.setInt(SharedPrefsConstants.aiMaxTokens, 500);
      await prefs.setBool(SharedPrefsConstants.aiUseVision, false);

      final second = await start();

      expect(prefs.getInt(SharedPrefsConstants.aiMaxTokens), 500);
      expect(prefs.getBool(SharedPrefsConstants.aiUseVision), isFalse);
      expect(second.state.useVision, isFalse);
    });

    test('other saved values are kept', () async {
      SharedPreferences.setMockInitialValues({
        SharedPrefsConstants.aiMaxTokens: 2000,
        SharedPrefsConstants.aiUseVision: true,
      });

      final bloc = await start();
      final prefs = await SharedPreferences.getInstance();

      expect(prefs.getInt(SharedPrefsConstants.aiMaxTokens), 2000);
      expect(prefs.getBool(SharedPrefsConstants.aiUseVision), isTrue);
      expect(bloc.state.useVision, isTrue);
    });
  });

  group('Deep Scan', () {
    test('toggling it updates the running screen and is saved', () async {
      SharedPreferences.setMockInitialValues({});
      final bloc = await start();
      final prefs = await SharedPreferences.getInstance();

      bloc.add(VisionToggled(useVision: !bloc.state.useVision));
      await settle();
      final toggled = !defaultDeepScan(_hostIsDesktop);

      expect(bloc.state.useVision, toggled);
      expect(prefs.getBool(SharedPrefsConstants.aiUseVision), toggled);
    });

    test('quick toggles apply in order and the last one wins', () async {
      SharedPreferences.setMockInitialValues({});
      final bloc = await newBloc();
      final prefs = await SharedPreferences.getInstance();

      bloc
        ..add(const VisionToggled(useVision: true))
        ..add(const VisionToggled(useVision: false))
        ..add(const VisionToggled(useVision: true));
      await settle();
      await settle();

      expect(bloc.state.useVision, isTrue);
      expect(prefs.getBool(SharedPrefsConstants.aiUseVision), isTrue);
    });
  });

  group('token capacity', () {
    test('a new limit is saved and the model reloaded', () async {
      SharedPreferences.setMockInitialValues({});
      final bloc = await newBloc();
      final prefs = await SharedPreferences.getInstance();

      bloc.add(const TokenCapacityUpdated(newMaxTokens: 2048, sessionId: 'x'));
      await settle();

      expect(prefs.getInt(SharedPrefsConstants.aiMaxTokens), 2048);
      expect(repository.disposes, 1);
    });

    test('without a new limit only the model is reloaded', () async {
      SharedPreferences.setMockInitialValues({});
      final bloc = await newBloc();
      final prefs = await SharedPreferences.getInstance();

      bloc.add(const TokenCapacityUpdated(sessionId: 'x'));
      await settle();

      expect(prefs.getInt(SharedPrefsConstants.aiMaxTokens), isNull);
      expect(repository.disposes, 1);
    });
  });
}
