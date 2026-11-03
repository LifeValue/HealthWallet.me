import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/config/constants/ai_model_config.dart';
import 'package:health_wallet/core/config/constants/app_constants.dart';
import 'package:health_wallet/core/config/constants/shared_prefs_constants.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/features/processing/domain/services/ai_model_download_service.dart';
import 'package:health_wallet/features/processing/presentation/widgets/ai_settings/ai_settings_dialog.dart';
import 'package:health_wallet/features/processing/presentation/widgets/ai_settings/ai_settings_token_section.dart';
import 'package:health_wallet/features/processing/presentation/widgets/ai_settings/ai_settings_vision_toggle.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../../helpers/ai_settings_dialog_driver.dart';

/// A download service whose reports the test sends and whose Deep Scan file
/// may be missing; it records the Deep Scan downloads the dialog starts.
class _DownloadService extends FakeAiModelDownloadService {
  final controller = StreamController<AiModelDownloadState>.broadcast();
  var mmprojOnDisk = true;
  final mmprojStarted = <AiModelVariant>[];

  @override
  Stream<AiModelDownloadState> get stateStream => controller.stream;

  Future<void> closeStream() => controller.close();

  @override
  Future<bool> checkMmprojExistsForVariant(AiModelVariant variant) async =>
      mmprojOnDisk;

  @override
  Future<void> startMmprojDownloadForVariant(AiModelVariant variant) async =>
      mmprojStarted.add(variant);
}

final _en = lookupAppLocalizations(const Locale('en'));

const _model = AiModelConfig.qwen;

void main() {
  late _DownloadService service;
  late AiSettingsResult? result;
  late bool closed;

  setUp(() {
    service = _DownloadService();
    getIt.registerSingleton<AiModelDownloadService>(service);
  });

  tearDown(() async {
    await getIt.reset();
    await service.closeStream();
  });

  /// Opens the dialog on these values from a button and keeps what it
  /// returns.
  Future<void> open(
    WidgetTester tester, {
    int tokens = 500,
    int gpuLayers = 10,
    int threads = 1,
    int contextSize = 2048,
    int recommendedGpuLayers = 20,
    int recommendedThreads = 1,
    int recommendedContextSize = 2048,
    bool useVision = false,
  }) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    result = null;
    closed = false;
    await tester.pumpWidget(
      testApp(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showDialog<AiSettingsResult>(
                context: context,
                builder: (_) => AiTokenSettingsDialog(
                  currentTokens: tokens,
                  currentGpuLayers: gpuLayers,
                  currentThreads: threads,
                  currentContextSize: contextSize,
                  recommendedGpuLayers: recommendedGpuLayers,
                  recommendedThreads: recommendedThreads,
                  recommendedContextSize: recommendedContextSize,
                  deviceRamMB: 8192,
                  activeModelConfig: _model,
                  currentUseVision: useVision,
                ),
              );
              closed = true;
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(AiTokenSettingsDialog), findsOneWidget);
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> save(WidgetTester tester) =>
      tap(tester, find.text(_en.setTokens));

  AiTokenOptionsSection tokens(WidgetTester tester) =>
      tester.widget(find.byType(AiTokenOptionsSection));

  AiVisionToggleSection vision(WidgetTester tester) =>
      tester.widget(find.byType(AiVisionToggleSection));

  Slider slider(WidgetTester tester, int index) =>
      tester.widget<Slider>(find.byType(Slider).at(index));

  Future<void> report(
    WidgetTester tester,
    AiModelDownloadStatus status, {
    bool isMmprojDownload = true,
    double progress = 0,
  }) async {
    service.controller.add(
      AiModelDownloadState(
        status: status,
        isMmprojDownload: isMmprojDownload,
        progress: progress,
        variant: _model.variant,
      ),
    );
    // The first pump delivers the report, the second draws what it changed.
    await tester.pump();
    await tester.pump();
  }

  group('closing', () {
    testWidgets('the back arrow returns the changes like Save', (tester) async {
      await open(tester);

      await tap(tester, find.text(_en.tokenPresetHigh));
      await tap(tester, find.byIcon(Icons.arrow_back_ios_new));

      expect(closed, isTrue);
      expect(result!.maxTokens, TokenPreset.high.tokens);
    });

    testWidgets('the close icon returns no change when nothing changed', (
      tester,
    ) async {
      await open(tester);

      await tap(tester, find.byIcon(Icons.close));

      expect(closed, isTrue);
      expect(result, isNotNull);
      expect(result!.changesModel, isFalse);
      expect(result!.useVision, isNull);
    });

    testWidgets('closing stops listening to the download service', (
      tester,
    ) async {
      await open(tester);
      expect(service.controller.hasListener, isTrue);

      await save(tester);

      expect(service.controller.hasListener, isFalse);
    });
  });

  group('token limit', () {
    testWidgets('a saved preset value opens on that preset', (tester) async {
      await open(tester, tokens: TokenPreset.high.tokens);

      expect(tokens(tester).selectedPreset, TokenPreset.high);
      expect(tokens(tester).customController.text, isEmpty);
    });

    testWidgets('a typed custom value is returned', (tester) async {
      await open(tester);

      await tap(tester, find.text(_en.tokenPresetCustom));
      expect(tokens(tester).selectedPreset, TokenPreset.custom);
      await tester.enterText(find.byType(TextField), '1234');
      await tester.pump();
      await save(tester);

      expect(result!.maxTokens, 1234);
      expect(result!.changesModel, isTrue);
    });

    testWidgets('a custom value over the limit is capped', (tester) async {
      await open(tester);

      await tap(tester, find.text(_en.tokenPresetCustom));
      await tester.enterText(find.byType(TextField), '999999');
      await tester.pump();
      await save(tester);

      expect(result!.maxTokens, AppConstants.maxAllowedTokens);
    });

    testWidgets('an empty custom value keeps the opening limit', (
      tester,
    ) async {
      await open(tester);

      await tap(tester, find.text(_en.tokenPresetCustom));
      await tester.enterText(find.byType(TextField), '');
      await tester.pump();
      await save(tester);

      expect(result!.maxTokens, isNull);
    });

    testWidgets('switching from a preset to another returns the new one', (
      tester,
    ) async {
      await open(tester, tokens: TokenPreset.high.tokens);

      await tap(tester, find.text(_en.tokenPresetLow));
      await save(tester);

      expect(result!.maxTokens, TokenPreset.low.tokens);
    });
  });

  group('load settings', () {
    testWidgets('a context size that is no step sits on the second step and '
        'is kept by an unchanged Save', (tester) async {
      await open(tester, contextSize: 3000);

      expect(slider(tester, 0).value, 1);
      expect(find.text('3000'), findsOneWidget);
      await save(tester);

      expect(result!.contextSize, isNull);
    });

    testWidgets('a moved context slider returns that step', (tester) async {
      await open(tester);

      slider(tester, 0).onChanged!(3);
      await tester.pump();
      await save(tester);

      expect(result!.contextSize, 4096);
      expect(result!.changesModel, isTrue);
    });

    testWidgets('changed GPU layers and threads are returned', (tester) async {
      await open(tester);

      final maxThreads = Platform.numberOfProcessors.clamp(1, 8);
      expect(slider(tester, 1).max, 99);
      expect(slider(tester, 2).max, maxThreads);
      slider(tester, 1).onChanged!(33);
      slider(tester, 2).onChanged!(maxThreads.toDouble());
      await tester.pump();
      await save(tester);

      expect(result!.gpuLayers, 33);
      expect(result!.threads, maxThreads == 1 ? isNull : maxThreads);
      expect(result!.changesModel, isTrue);
    });

    testWidgets('tapping the recommendation picks the recommended GPU layers', (
      tester,
    ) async {
      await open(tester);

      await tap(tester, find.text('${_en.recommended}: 20'));
      await save(tester);

      expect(result!.gpuLayers, 20);
    });

    testWidgets('the saved load settings are written, the rest left alone', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await const AiSettingsResult(
        maxTokens: 100,
        gpuLayers: 5,
        threads: 3,
        contextSize: 1024,
        useVision: true,
      ).saveLoadSettings(prefs);

      expect(prefs.getKeys(), {
        SharedPrefsConstants.aiGpuLayers,
        SharedPrefsConstants.aiThreads,
        SharedPrefsConstants.aiContextSize,
      });
      expect(prefs.getInt(SharedPrefsConstants.aiGpuLayers), 5);
      expect(prefs.getInt(SharedPrefsConstants.aiThreads), 3);
      expect(prefs.getInt(SharedPrefsConstants.aiContextSize), 1024);
    });

    test('only a load setting or the token limit changes the model', () {
      expect(const AiSettingsResult(useVision: true).changesModel, isFalse);
      expect(const AiSettingsResult(threads: 2).changesModel, isTrue);
      expect(const AiSettingsResult(gpuLayers: 0).changesModel, isTrue);
    });
  });

  group('memory estimate', () {
    String chip(int contextSize, {required bool withVision}) {
      final overhead = _model.modelSizeMB >= 2000 ? 700 : 400;
      final estimate =
          _model.modelSizeMB +
          (withVision ? _model.mmprojSizeMB : 0) +
          contextSize * 170 ~/ 1024 +
          overhead;
      return _en.deviceInfoChip(
        Platform.operatingSystem,
        '8.0',
        Platform.numberOfProcessors,
        estimate,
      );
    }

    testWidgets('counts the Deep Scan file and the context size', (
      tester,
    ) async {
      await open(tester, useVision: true);
      expect(find.text(chip(2048, withVision: true)), findsOneWidget);

      await tap(
        tester,
        find.descendant(
          of: find.byType(AiVisionToggleSection),
          matching: find.text(_en.on),
        ),
      );
      expect(find.text(chip(2048, withVision: false)), findsOneWidget);

      slider(tester, 0).onChanged!(0);
      await tester.pump();
      expect(find.text(chip(512, withVision: false)), findsOneWidget);
    });
  });

  group('Deep Scan', () {
    Future<void> toggle(WidgetTester tester) => tap(
      tester,
      find.descendant(
        of: find.byType(AiVisionToggleSection),
        matching: find.text(vision(tester).useVision ? _en.on : _en.off),
      ),
    );

    testWidgets('turned off is returned as off', (tester) async {
      await open(tester, useVision: true);

      await toggle(tester);
      await save(tester);

      expect(result!.useVision, isFalse);
      expect(result!.changesModel, isFalse);
    });

    testWidgets('turning it on with the file on disk turns it on at once', (
      tester,
    ) async {
      await open(tester);

      await toggle(tester);

      expect(vision(tester).useVision, isTrue);
      expect(find.text(_en.deepScanDownloadTitle), findsNothing);
    });

    testWidgets('turning it on without the file asks to download it, and '
        'a confirm starts the download', (tester) async {
      service.mmprojOnDisk = false;
      await open(tester);

      await toggle(tester);

      expect(find.text(_en.deepScanDownloadTitle), findsOneWidget);
      expect(
        find.text(_en.deepScanDownloadMessage(_model.mmprojSizeMB)),
        findsOneWidget,
      );
      expect(vision(tester).useVision, isFalse);

      await tap(tester, find.text(_en.aiModelEnableDownload));

      expect(service.mmprojStarted, [_model.variant]);
      expect(find.text(_en.deepScanDownloadTitle), findsNothing);
      expect(vision(tester).useVision, isFalse);
    });

    testWidgets('a cancelled download prompt starts nothing', (tester) async {
      service.mmprojOnDisk = false;
      await open(tester);

      await toggle(tester);
      await tap(tester, find.text(_en.cancel));

      expect(service.mmprojStarted, isEmpty);
      expect(find.text(_en.deepScanDownloadTitle), findsNothing);
      expect(vision(tester).useVision, isFalse);
    });

    testWidgets('a running Deep Scan download shows its progress, and its '
        'completion turns Deep Scan on', (tester) async {
      await open(tester);

      await report(tester, AiModelDownloadStatus.downloading, progress: 37);

      expect(vision(tester).isMmprojDownloading, isTrue);
      expect(vision(tester).mmprojProgress, 37);
      expect(find.text('37%'), findsOneWidget);

      await report(tester, AiModelDownloadStatus.completed);

      expect(vision(tester).isMmprojDownloading, isFalse);
      expect(vision(tester).mmprojProgress, 0);
      expect(vision(tester).useVision, isTrue);
      await save(tester);
      expect(result!.useVision, isTrue);
    });

    for (final status in [
      AiModelDownloadStatus.error,
      AiModelDownloadStatus.cancelled,
    ]) {
      testWidgets('a Deep Scan download ending in ${status.name} leaves it '
          'off', (tester) async {
        await open(tester);
        await report(tester, AiModelDownloadStatus.downloading, progress: 60);
        expect(vision(tester).isMmprojDownloading, isTrue);

        await report(tester, status);

        expect(vision(tester).isMmprojDownloading, isFalse);
        expect(vision(tester).mmprojProgress, 0);
        expect(vision(tester).useVision, isFalse);
      });
    }

    testWidgets('a model download report is ignored', (tester) async {
      await open(tester);

      await report(
        tester,
        AiModelDownloadStatus.downloading,
        isMmprojDownload: false,
        progress: 50,
      );
      expect(vision(tester).isMmprojDownloading, isFalse);

      await report(
        tester,
        AiModelDownloadStatus.completed,
        isMmprojDownload: false,
      );
      expect(vision(tester).useVision, isFalse);
    });

    testWidgets('an idle Deep Scan report changes nothing', (tester) async {
      await open(tester);
      await report(tester, AiModelDownloadStatus.downloading, progress: 20);

      await report(tester, AiModelDownloadStatus.idle);

      expect(vision(tester).isMmprojDownloading, isTrue);
      expect(vision(tester).mmprojProgress, 20);
    });
  });
}
