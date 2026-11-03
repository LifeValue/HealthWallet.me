import 'dart:async';

import 'package:bloc_test/bloc_test.dart' show MockBloc, whenListen;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/config/app_platform.dart';
import 'package:health_wallet/core/config/constants/shared_prefs_constants.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/core/services/device_capability_service.dart';
import 'package:health_wallet/features/dashboard/presentation/helpers/page_view_navigation_controller.dart';
import 'package:health_wallet/features/processing/domain/deep_scan_defaults.dart';
import 'package:health_wallet/features/processing/domain/entity/processing_session.dart';
import 'package:health_wallet/features/processing/domain/services/ai_model_download_service.dart';
import 'package:health_wallet/features/processing/presentation/bloc/processing_bloc.dart';
import 'package:health_wallet/features/processing/presentation/pages/processing/processing_page.dart';
import 'package:health_wallet/features/processing/presentation/widgets/ai_settings/ai_settings_dialog.dart';
import 'package:health_wallet/features/processing/presentation/widgets/ai_settings/ai_settings_token_section.dart';
import 'package:health_wallet/features/processing/presentation/widgets/ai_settings/ai_settings_vision_toggle.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../../helpers/ai_settings_dialog_driver.dart';

/// Records the events the page sends instead of running them.
class _MockProcessingBloc extends MockBloc<ProcessingEvent, ProcessingState>
    implements ProcessingBloc {
  final events = <ProcessingEvent>[];

  @override
  void add(ProcessingEvent event) => events.add(event);
}

class _FakeDeviceCapabilityService extends Fake
    implements DeviceCapabilityService {
  @override
  Future<DeviceAiCapability> getCapability() async => DeviceAiCapability.full;
}

final _en = lookupAppLocalizations(const Locale('en'));

void main() {
  tearDown(getIt.reset);

  Future<void> register(AppPlatform platform) async {
    getIt
      ..registerSingleton<AppPlatform>(platform)
      ..registerSingleton<AiModelDownloadService>(FakeAiModelDownloadService())
      ..registerSingleton<SharedPreferences>(
        await SharedPreferences.getInstance(),
      );
  }

  group('AiTokenSettingsDialog', () {
    late AiSettingsResult? result;
    late bool closed;

    /// Pumps a button that opens the dialog and keeps what it returns.
    Future<void> pumpOpener(WidgetTester tester) async {
      result = null;
      closed = false;
      await tester.pumpWidget(
        testApp(
          Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await AiTokenSettingsDialog.show(context);
                closed = true;
              },
              child: const Text('open'),
            ),
          ),
        ),
      );
      await openAiSettings(tester, find.text('open'));
    }

    for (final platform in AppPlatform.values) {
      testWidgets('opens with Deep Scan '
          '${defaultDeepScan(platform.isDesktop) ? 'on' : 'off'} '
          'on ${platform.name} when nothing is saved', (tester) async {
        SharedPreferences.setMockInitialValues({});
        await register(platform);
        await pumpOpener(tester);

        expect(
          tester
              .widget<AiVisionToggleSection>(
                find.byType(AiVisionToggleSection),
              )
              .useVision,
          defaultDeepScan(platform.isDesktop),
        );
      });
    }

    testWidgets('a saved Deep Scan wins over the default', (tester) async {
      SharedPreferences.setMockInitialValues({
        SharedPrefsConstants.aiUseVision: false,
      });
      await register(AppPlatform.desktop);
      await pumpOpener(tester);

      expect(
        tester
            .widget<AiVisionToggleSection>(find.byType(AiVisionToggleSection))
            .useVision,
        isFalse,
      );
    });

    testWidgets('a fresh install opens on 4,096 tokens', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await register(AppPlatform.mobile);
      await pumpOpener(tester);

      final tokens = tester.widget<AiTokenOptionsSection>(
        find.byType(AiTokenOptionsSection),
      );
      expect(tokens.selectedPreset, TokenPreset.custom);
      expect(tokens.customController.text, '4096');
    });

    testWidgets('a saved limit that is no preset opens as custom and an '
        'unchanged Save keeps it', (tester) async {
      SharedPreferences.setMockInitialValues({
        SharedPrefsConstants.aiMaxTokens: 1000,
      });
      await register(AppPlatform.mobile);
      await pumpOpener(tester);

      final tokens = tester.widget<AiTokenOptionsSection>(
        find.byType(AiTokenOptionsSection),
      );
      expect(tokens.selectedPreset, TokenPreset.custom);
      expect(tokens.customController.text, '1000');

      await tapSave(tester);

      expect(result!.maxTokens, isNull);
      expect(result!.changesModel, isFalse);
    });

    testWidgets('a Save with no change returns no changed value', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      await register(AppPlatform.mobile);
      await pumpOpener(tester);

      await tapSave(tester);

      expect(closed, isTrue);
      expect(result, isNotNull);
      expect(result!.maxTokens, isNull);
      expect(result!.gpuLayers, isNull);
      expect(result!.threads, isNull);
      expect(result!.contextSize, isNull);
      expect(result!.useVision, isNull);
      expect(result!.changesModel, isFalse);
    });

    testWidgets('returns only the values the user changed', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await register(AppPlatform.desktop);
      await pumpOpener(tester);

      await tapTokenPreset(tester, _en.tokenPresetMedium);
      await toggleDeepScan(tester);
      await tapSave(tester);

      expect(result!.maxTokens, TokenPreset.medium.tokens);
      expect(result!.useVision, isFalse);
      expect(result!.gpuLayers, isNull);
      expect(result!.threads, isNull);
      expect(result!.contextSize, isNull);
      expect(result!.changesModel, isTrue);
    });
  });

  group('the Processing screen', () {
    late _MockProcessingBloc bloc;
    late StreamController<ProcessingState> states;

    const session = ProcessingSession(id: 's1');

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      bloc = _MockProcessingBloc();
      states = StreamController<ProcessingState>();
      whenListen(
        bloc,
        states.stream,
        initialState: const ProcessingState(sessions: [session]),
      );
      await register(AppPlatform.mobile);
      getIt
        ..registerSingleton<PageViewNavigationController>(
          PageViewNavigationController(),
        )
        ..registerSingleton<DeviceCapabilityService>(
          _FakeDeviceCapabilityService(),
        );
    });

    tearDown(() => states.close());

    Future<void> openFromProcessingPage(WidgetTester tester) async {
      await tester.pumpWidget(
        testApp(
          BlocProvider<ProcessingBloc>.value(
            value: bloc,
            child: const ProcessingPage(sessionId: 's1'),
          ),
        ),
      );
      bloc.events.clear();
      await openAiSettings(tester, find.byIcon(Icons.tune));
    }

    testWidgets('a Save with no change writes nothing and does not restart '
        'mapping', (tester) async {
      await openFromProcessingPage(tester);

      await tapSave(tester);

      expect(find.byType(AiTokenSettingsDialog), findsNothing);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys(), isEmpty);
      expect(bloc.events, isEmpty);
    });

    testWidgets('a changed token limit alone is saved through the bloc and '
        'restarts mapping', (tester) async {
      await openFromProcessingPage(tester);

      await tapTokenPreset(tester, _en.tokenPresetHigh);
      await tapSave(tester);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys(), isEmpty);
      expect(bloc.events, [
        TokenCapacityUpdated(
          newMaxTokens: TokenPreset.high.tokens,
          sessionId: 's1',
        ),
      ]);
    });

    testWidgets('a changed context size alone is saved and restarts mapping '
        'without a new token limit', (tester) async {
      await openFromProcessingPage(tester);

      // The first slider is the context size; its first step is 512.
      tester.widget<Slider>(find.byType(Slider).first).onChanged!(0);
      await tester.pump();
      await tapSave(tester);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys(), {SharedPrefsConstants.aiContextSize});
      expect(prefs.getInt(SharedPrefsConstants.aiContextSize), 512);
      expect(bloc.events, [const TokenCapacityUpdated(sessionId: 's1')]);
    });

    testWidgets('Deep Scan alone goes through VisionToggled without '
        'restarting mapping', (tester) async {
      await openFromProcessingPage(tester);

      await toggleDeepScan(tester);
      await tapSave(tester);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys(), isEmpty);
      expect(bloc.events, [const VisionToggled(useVision: true)]);
    });
  });
}
