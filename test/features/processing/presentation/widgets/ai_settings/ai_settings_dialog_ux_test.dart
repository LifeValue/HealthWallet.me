import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/config/constants/ai_model_config.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/core/widgets/app_button.dart';
import 'package:health_wallet/features/processing/domain/services/ai_model_download_service.dart';
import 'package:health_wallet/features/processing/presentation/widgets/ai_settings/ai_settings_dialog.dart';
import 'package:health_wallet/features/processing/presentation/widgets/ai_settings/ai_settings_token_section.dart';
import 'package:health_wallet/features/processing/presentation/widgets/ai_settings/ai_settings_vision_toggle.dart';

import '../../../../../helpers/ai_settings_dialog_driver.dart';

final _en = lookupAppLocalizations(const Locale('en'));

const _model = AiModelConfig.qwen;

void main() {
  late AiSettingsResult? result;
  late bool closed;

  setUp(() {
    getIt.registerSingleton<AiModelDownloadService>(
      FakeAiModelDownloadService(),
    );
  });

  tearDown(getIt.reset);

  /// Opens the dialog from a button on 500 tokens, 10 GPU layers, 1 thread
  /// and a 2048 context size, without Deep Scan, and keeps what it returns.
  Future<void> open(WidgetTester tester) async {
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
                builder: (_) => const AiTokenSettingsDialog(
                  currentTokens: 500,
                  currentGpuLayers: 10,
                  currentThreads: 1,
                  currentContextSize: 2048,
                  recommendedGpuLayers: 20,
                  recommendedThreads: 1,
                  recommendedContextSize: 2048,
                  deviceRamMB: 8192,
                  activeModelConfig: _model,
                  currentUseVision: false,
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

  Finder sliderFinder(int index) => find.byType(Slider).at(index);

  Slider slider(WidgetTester tester, int index) =>
      tester.widget<Slider>(sliderFinder(index));

  /// The memory estimate chip for a context size, without Deep Scan.
  String chip(int contextSize) {
    final estimate =
        _model.modelSizeMB +
        contextSize * 170 ~/ 1024 +
        (_model.modelSizeMB >= 2000 ? 700 : 400);
    return _en.deviceInfoChip(
      Platform.operatingSystem,
      '8.0',
      Platform.numberOfProcessors,
      estimate,
    );
  }

  /// Changes every setting the dialog offers.
  Future<void> changeEverything(WidgetTester tester) async {
    await moveAiSlider(tester, 0, 3);
    await moveAiSlider(tester, 1, 42);
    await tap(tester, find.text(_en.tokenPresetHigh));
    await tap(
      tester,
      find.descendant(
        of: find.byType(AiVisionToggleSection),
        matching: find.text(_en.off),
      ),
    );
  }

  group('closing', () {
    testWidgets('Cancel sits next to Set as an outlined button', (
      tester,
    ) async {
      await open(tester);

      final cancel = tester.widget<AppButton>(
        find.byKey(AiTokenSettingsDialog.cancelKey),
      );
      expect(cancel.label, _en.cancel);
      expect(cancel.variant, AppButtonVariant.outlined);
      final set = tester.widget<AppButton>(
        find.byKey(AiTokenSettingsDialog.setKey),
      );
      expect(set.label, _en.setTokens);
      expect(
        tester.getCenter(find.byKey(AiTokenSettingsDialog.cancelKey)).dy,
        tester.getCenter(find.byKey(AiTokenSettingsDialog.setKey)).dy,
      );
      expect(
        tester.getCenter(find.byKey(AiTokenSettingsDialog.cancelKey)).dx,
        lessThan(tester.getCenter(find.byKey(AiTokenSettingsDialog.setKey)).dx),
      );
    });

    for (final MapEntry(key: name, value: key)
        in aiSettingsDiscardKeys.entries) {
      testWidgets('$name closes with no result after changes', (tester) async {
        await open(tester);
        await changeEverything(tester);

        await tap(tester, find.byKey(key));

        expect(find.byType(AiTokenSettingsDialog), findsNothing);
        expect(closed, isTrue);
        expect(result, isNull);
      });
    }

    testWidgets('Set returns the changes', (tester) async {
      await open(tester);
      await changeEverything(tester);

      await tap(tester, find.byKey(AiTokenSettingsDialog.setKey));

      expect(closed, isTrue);
      expect(result!.contextSize, 4096);
      expect(result!.gpuLayers, 42);
      expect(result!.maxTokens, TokenPreset.high.tokens);
      expect(result!.useVision, isTrue);
      expect(result!.threads, isNull);
    });
  });

  group('answer length options', () {
    testWidgets('each preset shows its size with a plain hint', (tester) async {
      await open(tester);

      expect(find.text('~100 · a few values'), findsOneWidget);
      expect(find.text('~500 · a short report'), findsOneWidget);
      expect(find.text('~2,000 · a full report'), findsOneWidget);
      expect(find.textContaining('tokens'), findsNothing);
    });
  });

  group('value bubble', () {
    testWidgets('every slider shows its value bubble while dragged', (
      tester,
    ) async {
      await open(tester);

      for (var i = 0; i < 3; i++) {
        final theme = SliderTheme.of(tester.element(sliderFinder(i)));
        expect(theme.showValueIndicator, ShowValueIndicator.onDrag);
      }
      expect(slider(tester, 1).label, '10');
      expect(slider(tester, 2).label, '1');
    });

    testWidgets('the context size bubble shows the size, not the step', (
      tester,
    ) async {
      await open(tester);
      expect(slider(tester, 0).label, '2048');

      await tester.ensureVisible(sliderFinder(0));
      await tester.pumpAndSettle();
      final rect = tester.getRect(sliderFinder(0));
      final gesture = await tester.startGesture(rect.center);
      await tester.pump();
      await gesture.moveTo(rect.centerRight);
      await tester.pump();

      expect(slider(tester, 0).value, 3);
      expect(slider(tester, 0).label, '4096');
      expect(find.text('4096'), findsOneWidget);

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('a moved GPU slider shows the new number', (tester) async {
      await open(tester);

      slider(tester, 1).onChanged!(33);
      await tester.pump();

      expect(slider(tester, 1).label, '33');
      expect(find.text('33'), findsOneWidget);
    });
  });

  group('reporting', () {
    testWidgets('a drag reaches the dialog only when the user lets go', (
      tester,
    ) async {
      await open(tester);
      expect(find.text(chip(2048)), findsOneWidget);

      await tester.ensureVisible(sliderFinder(0));
      await tester.pumpAndSettle();
      final rect = tester.getRect(sliderFinder(0));
      final gesture = await tester.startGesture(rect.center);
      await tester.pump();
      await gesture.moveTo(rect.centerLeft);
      await tester.pump();

      // The thumb and the number follow the drag, the estimate does not yet.
      expect(slider(tester, 0).value, 0);
      expect(find.text('512'), findsOneWidget);
      expect(find.text(chip(2048)), findsOneWidget);

      await gesture.up();
      await tester.pumpAndSettle();

      expect(find.text(chip(512)), findsOneWidget);
      expect(slider(tester, 0).value, 0);

      await tap(tester, find.byKey(AiTokenSettingsDialog.setKey));
      expect(result!.contextSize, 512);
    });

    testWidgets('a slider moved but not let go of is not applied', (
      tester,
    ) async {
      await open(tester);

      slider(tester, 1).onChanged!(50);
      await tester.pump();
      expect(find.text('50'), findsOneWidget);

      await tap(tester, find.byKey(AiTokenSettingsDialog.setKey));
      expect(result!.gpuLayers, isNull);
    });

    testWidgets('Recommended moves the slider back', (tester) async {
      await open(tester);

      await tap(tester, find.text('${_en.recommended}: 20'));

      expect(slider(tester, 1).value, 20);
      expect(find.text('20'), findsOneWidget);

      await moveAiSlider(tester, 0, 0);
      expect(find.text(chip(512)), findsOneWidget);
      await tap(tester, find.text('${_en.recommended}: 2048'));

      expect(slider(tester, 0).value, 2);
      expect(find.text('2048'), findsOneWidget);
      expect(find.text(chip(2048)), findsOneWidget);

      await tap(tester, find.byKey(AiTokenSettingsDialog.setKey));
      expect(result!.gpuLayers, 20);
      expect(result!.contextSize, isNull);
    });

    testWidgets('Recommended during an unfinished drag wins over the drag', (
      tester,
    ) async {
      await open(tester);

      slider(tester, 1).onChanged!(70);
      await tester.pump();
      expect(find.text('70'), findsOneWidget);

      await tap(tester, find.text('${_en.recommended}: 20'));

      expect(slider(tester, 1).value, 20);
      expect(find.text('70'), findsNothing);
      expect(find.text('20'), findsOneWidget);
    });
  });
}
