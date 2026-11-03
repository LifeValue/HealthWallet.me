import 'package:bloc_test/bloc_test.dart' show MockBloc, whenListen;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/config/app_platform.dart';
import 'package:health_wallet/core/config/constants/shared_prefs_constants.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/features/processing/domain/services/ai_model_download_service.dart';
import 'package:health_wallet/features/processing/presentation/bloc/processing_bloc.dart';
import 'package:health_wallet/features/processing/presentation/pages/load_model/bloc/load_model_bloc.dart';
import 'package:health_wallet/features/processing/presentation/widgets/ai_settings/ai_settings_dialog.dart';
import 'package:health_wallet/features/processing/presentation/widgets/ai_settings/ai_settings_token_section.dart';
import 'package:health_wallet/features/user/presentation/preferences_modal/sections/ai-model/ai_model_section.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../../../helpers/ai_settings_dialog_driver.dart';

class _MockLoadModelBloc extends MockBloc<LoadModelEvent, LoadModelState>
    implements LoadModelBloc {}

/// Records the events sent to it instead of running them.
class _MockProcessingBloc extends MockBloc<ProcessingEvent, ProcessingState>
    implements ProcessingBloc {
  final events = <ProcessingEvent>[];

  @override
  void add(ProcessingEvent event) => events.add(event);
}

final _en = lookupAppLocalizations(const Locale('en'));

void main() {
  late _MockProcessingBloc processingBloc;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    final loadModelBloc = _MockLoadModelBloc();
    whenListen(
      loadModelBloc,
      const Stream<LoadModelState>.empty(),
      initialState: const LoadModelState(status: LoadModelStatus.modelLoaded),
    );
    processingBloc = _MockProcessingBloc();
    whenListen(
      processingBloc,
      const Stream<ProcessingState>.empty(),
      initialState: const ProcessingState(),
    );
    getIt
      ..registerSingleton<AppPlatform>(AppPlatform.mobile)
      ..registerSingleton<LoadModelBloc>(loadModelBloc)
      ..registerSingleton<ProcessingBloc>(processingBloc)
      ..registerSingleton<AiModelDownloadService>(
        FakeAiModelDownloadService(),
      );
  });

  tearDown(getIt.reset);

  Future<void> openSettings(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      testApp(const SingleChildScrollView(child: AiModelSection())),
    );
    await tester.pump();
    await openAiSettings(tester, find.text(_en.aiSettings));
  }

  testWidgets('a fresh install shows 4,096 tokens', (tester) async {
    await openSettings(tester);

    final tokens = tester.widget<AiTokenOptionsSection>(
      find.byType(AiTokenOptionsSection),
    );
    expect(tokens.selectedPreset, TokenPreset.custom);
    expect(tokens.customController.text, '4096');
  });

  testWidgets('a Save with no change writes nothing', (tester) async {
    await openSettings(tester);

    await tapSave(tester);

    expect(find.byType(AiTokenSettingsDialog), findsNothing);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys(), isEmpty);
    expect(processingBloc.events, isEmpty);
  });

  testWidgets('a changed context size is the only value saved', (
    tester,
  ) async {
    await openSettings(tester);

    // The first slider is the context size; its first step is 512.
    tester.widget<Slider>(find.byType(Slider).first).onChanged!(0);
    await tester.pump();
    await tapSave(tester);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys(), {SharedPrefsConstants.aiContextSize});
    expect(prefs.getInt(SharedPrefsConstants.aiContextSize), 512);
    expect(processingBloc.events, isEmpty);
  });

  testWidgets('a changed token limit is saved', (tester) async {
    await openSettings(tester);

    await tapTokenPreset(tester, _en.tokenPresetHigh);
    await tapSave(tester);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys(), {SharedPrefsConstants.aiMaxTokens});
    expect(
      prefs.getInt(SharedPrefsConstants.aiMaxTokens),
      TokenPreset.high.tokens,
    );
  });

  testWidgets('Deep Scan reaches the ProcessingBloc, which saves it', (
    tester,
  ) async {
    await openSettings(tester);

    await toggleDeepScan(tester);
    await tapSave(tester);

    expect(processingBloc.events, [const VisionToggled(useVision: true)]);
    // The bloc saves it; the section does not write it a second time.
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys(), isEmpty);
  });
}
