import 'dart:async';

import 'package:bloc_test/bloc_test.dart' show MockBloc, whenListen;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/config/app_platform.dart';
import 'package:health_wallet/core/config/constants/ai_model_config.dart';
import 'package:health_wallet/core/config/constants/shared_prefs_constants.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations_en.dart';
import 'package:health_wallet/core/services/device_capability_service.dart';
import 'package:health_wallet/core/widgets/app_button.dart';
import 'package:health_wallet/features/processing/domain/services/ai_model_download_service.dart';
import 'package:health_wallet/features/processing/presentation/bloc/processing_bloc.dart';
import 'package:health_wallet/features/processing/presentation/pages/load_model/bloc/load_model_bloc.dart';
import 'package:health_wallet/features/processing/presentation/widgets/ai_settings/ai_settings_dialog.dart';
import 'package:health_wallet/features/processing/presentation/widgets/cancel_download_dialog.dart';
import 'package:health_wallet/features/processing/presentation/widgets/custom_progress_indicator.dart';
import 'package:health_wallet/features/processing/presentation/widgets/model_management_dialog.dart';
import 'package:health_wallet/features/user/presentation/preferences_modal/sections/ai-model/ai_model_section.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../../../helpers/ai_settings_dialog_driver.dart';

/// Shows the states the test sends and records the events it is sent.
class _MockLoadModelBloc extends MockBloc<LoadModelEvent, LoadModelState>
    implements LoadModelBloc {
  final events = <LoadModelEvent>[];

  @override
  void add(LoadModelEvent event) => events.add(event);
}

/// Records the events sent to it instead of running them.
class _MockProcessingBloc extends MockBloc<ProcessingEvent, ProcessingState>
    implements ProcessingBloc {
  final events = <ProcessingEvent>[];

  @override
  void add(ProcessingEvent event) => events.add(event);
}

final _en = lookupAppLocalizations(const Locale('en'));

/// English with a model description that has no `**bold**` part.
class _PlainEn extends AppLocalizationsEn {
  static const description = 'Download a model to read your records.';

  @override
  String get onboardingAiModelDescription => description;
}

class _PlainDescriptionDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _PlainDescriptionDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<AppLocalizations> load(Locale locale) =>
      SynchronousFuture<AppLocalizations>(_PlainEn());

  @override
  bool shouldReload(_PlainDescriptionDelegate old) => false;
}

void main() {
  late _MockLoadModelBloc loadModelBloc;
  late _MockProcessingBloc processingBloc;
  late StreamController<LoadModelState> states;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    loadModelBloc = _MockLoadModelBloc();
    processingBloc = _MockProcessingBloc();
    states = StreamController<LoadModelState>();
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

  tearDown(() async {
    await getIt.reset();
    await states.close();
  });

  /// Shows the section on [state]; later states come from [states].
  Future<void> pumpSection(WidgetTester tester, LoadModelState state) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    whenListen(loadModelBloc, states.stream, initialState: state);
    await tester.pumpWidget(
      testApp(const SingleChildScrollView(child: AiModelSection())),
    );
    await tester.pump();
  }

  /// Taps [finder] and lets a dialog open; a spinner on screen keeps
  /// pumpAndSettle from ending, so this pumps a fixed time.
  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.tap(finder);
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  const ready = LoadModelState(
    status: LoadModelStatus.modelLoaded,
    deviceCapability: DeviceAiCapability.full,
    selectedVariant: AiModelVariant.qwen,
    downloadedVariants: {AiModelVariant.qwen: true},
  );
  const absent = LoadModelState(
    status: LoadModelStatus.modelAbsent,
    deviceCapability: DeviceAiCapability.full,
  );

  testWidgets('asks the bloc to check the models when shown', (tester) async {
    await pumpSection(tester, absent);

    expect(loadModelBloc.events, [const LoadModelInitialized()]);
    expect(find.text(_en.onboardingAiModelTitle), findsOneWidget);
  });

  group('with the model ready', () {
    testWidgets('shows it as ready with its manage and settings buttons', (
      tester,
    ) async {
      await pumpSection(tester, ready);

      expect(find.text(_en.aiModelReady), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(find.text(_en.aiModelManage), findsOneWidget);
      expect(find.text(_en.aiSettings), findsOneWidget);
      // No download prompt or status chip.
      expect(find.byType(AppButton), findsNothing);
      expect(find.text(_en.aiModelMissing), findsNothing);
    });

    testWidgets('Manage opens the model dialog', (tester) async {
      await pumpSection(tester, ready);

      await tap(tester, find.text(_en.aiModelManage));

      expect(find.byType(ModelManagementDialog), findsOneWidget);
    });

    testWidgets('the corner switch icon opens the model dialog', (
      tester,
    ) async {
      await pumpSection(tester, ready);

      await tap(tester, find.byIcon(Icons.swap_horiz).first);

      expect(find.byType(ModelManagementDialog), findsOneWidget);
    });

    testWidgets('AI settings closed outside the dialog saves nothing', (
      tester,
    ) async {
      await pumpSection(tester, ready);
      await openAiSettings(tester, find.text(_en.aiSettings));

      await tester.tapAt(const Offset(2, 2));
      for (var i = 0; i < 5; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.byType(AiTokenSettingsDialog), findsNothing);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys(), isEmpty);
      expect(processingBloc.events, isEmpty);
    });

    testWidgets('changed GPU layers are saved from AI settings', (
      tester,
    ) async {
      await pumpSection(tester, ready);
      await openAiSettings(tester, find.text(_en.aiSettings));

      // The second slider is the GPU layers (0 to 99).
      await moveAiSlider(tester, 1, 7);
      await tapSave(tester);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys(), {SharedPrefsConstants.aiGpuLayers});
      expect(prefs.getInt(SharedPrefsConstants.aiGpuLayers), 7);
      expect(processingBloc.events, isEmpty);
    });
  });

  group('with no model ready', () {
    testWidgets('nothing downloaded offers the download and explains it', (
      tester,
    ) async {
      await pumpSection(tester, absent);

      expect(find.text(_en.aiModelMissing), findsOneWidget);
      expect(
        find.textContaining(
          'Your data stays private on your device.',
          findRichText: true,
        ),
        findsOneWidget,
      );
      final button = tester.widget<AppButton>(find.byType(AppButton));
      expect(button.label, _en.aiModelEnableDownload);
      expect((button.icon! as Icon).icon, Icons.download);
      // The corner switch icon is offered on a capable device.
      expect(find.byIcon(Icons.swap_horiz), findsOneWidget);

      await tap(tester, find.byType(AppButton));

      expect(find.byType(ModelManagementDialog), findsOneWidget);
    });

    testWidgets('a translation without bold markup shows as plain text', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      whenListen(loadModelBloc, states.stream, initialState: absent);
      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('en'),
          // The first delegate of a type wins.
          localizationsDelegates: [
            _PlainDescriptionDelegate(),
            ...AppLocalizations.localizationsDelegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(child: AiModelSection()),
          ),
        ),
      );
      await tester.pump();

      expect(find.text(_PlainEn.description), findsOneWidget);
      expect(find.textContaining('**', findRichText: true), findsNothing);
    });

    testWidgets('a downloaded but unchosen model asks to select one', (
      tester,
    ) async {
      await pumpSection(
        tester,
        absent.copyWith(downloadedVariants: {AiModelVariant.qwen: true}),
      );

      expect(find.text(_en.aiModelNotSelected), findsOneWidget);
      expect(
        find.textContaining(
          'Your data stays private on your device.',
          findRichText: true,
        ),
        findsNothing,
      );
      final button = tester.widget<AppButton>(find.byType(AppButton));
      expect(button.label, _en.aiModelSelect);
      expect((button.icon! as Icon).icon, Icons.swap_horiz);
    });

    testWidgets('the corner switch icon opens the model dialog', (
      tester,
    ) async {
      await pumpSection(tester, absent);

      await tap(tester, find.byIcon(Icons.swap_horiz));

      expect(find.byType(ModelManagementDialog), findsOneWidget);
    });

    testWidgets('an unsupported device says no model fits and offers none', (
      tester,
    ) async {
      await pumpSection(
        tester,
        absent.copyWith(deviceCapability: DeviceAiCapability.unsupported),
      );

      expect(find.text(_en.aiModelNotAvailableForDevice), findsOneWidget);
      expect(
        find.text(_en.aiModelNotAvailableForDeviceDescription),
        findsOneWidget,
      );
      expect(find.byType(AppButton), findsNothing);
      expect(find.byIcon(Icons.swap_horiz), findsNothing);
    });

    testWidgets('an error shows the error chip and still offers the download', (
      tester,
    ) async {
      await pumpSection(
        tester,
        absent.copyWith(status: LoadModelStatus.error, errorMessage: 'boom'),
      );

      expect(find.text(_en.aiModelError), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.byType(AppButton), findsOneWidget);
      expect(find.text(_en.noInternetConnectionTitle), findsNothing);
    });
  });

  group('while a model downloads', () {
    testWidgets('shows the rounded progress and that it goes on in the '
        'background', (tester) async {
      await pumpSection(
        tester,
        absent.copyWith(
          status: LoadModelStatus.loading,
          downloadProgress: 42.4,
        ),
      );

      expect(find.text('${_en.aiModelDownloading} 42%'), findsOneWidget);
      final progress = tester.widget<CustomProgressIndicator>(
        find.byType(CustomProgressIndicator),
      );
      expect(progress.progress, closeTo(0.424, 1e-9));
      expect(progress.text, _en.aiModelDownloading);
      expect(
        find.text(_en.aiModelDownloadContinuesInBackground),
        findsOneWidget,
      );
      expect(find.byType(AppButton), findsNothing);
    });

    testWidgets('Cancel asks first; Continue keeps the download', (
      tester,
    ) async {
      await pumpSection(
        tester,
        absent.copyWith(status: LoadModelStatus.loading, downloadProgress: 62),
      );
      loadModelBloc.events.clear();

      await tap(tester, find.byType(CancelDownloadButton));
      expect(find.text(_en.cancelDownloadMessage), findsOneWidget);
      expect(loadModelBloc.events, isEmpty);

      await tap(tester, find.text(_en.continueButton));
      expect(find.text(_en.cancelDownloadMessage), findsNothing);
      expect(loadModelBloc.events, isEmpty);
    });

    testWidgets('a confirmed Cancel stops the downloads', (tester) async {
      await pumpSection(
        tester,
        absent.copyWith(status: LoadModelStatus.loading, downloadProgress: 62),
      );
      loadModelBloc.events.clear();

      await tap(tester, find.byType(CancelDownloadButton));
      await tap(tester, find.text(_en.cancelDownloadTitle).last);

      expect(loadModelBloc.events, [const LoadModelDownloadCancelled()]);
    });

    testWidgets('with no progress yet shows 0%', (tester) async {
      await pumpSection(
        tester,
        absent.copyWith(status: LoadModelStatus.loading),
      );

      expect(find.text('${_en.aiModelDownloading} 0%'), findsOneWidget);
      expect(
        tester
            .widget<CustomProgressIndicator>(
              find.byType(CustomProgressIndicator),
            )
            .progress,
        0,
      );
    });

    testWidgets('a status change redraws the section', (tester) async {
      await pumpSection(
        tester,
        absent.copyWith(status: LoadModelStatus.loading),
      );

      states.add(ready);
      await tester.pump();
      await tester.pump();

      expect(find.text(_en.aiModelManage), findsOneWidget);
      expect(find.byType(CustomProgressIndicator), findsNothing);
    });
  });

  group('no internet', () {
    testWidgets('a download that finds no internet says so until OK', (
      tester,
    ) async {
      await pumpSection(tester, absent);

      states.add(
        absent.copyWith(
          status: LoadModelStatus.error,
          errorMessage: kNoInternetErrorKey,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(_en.noInternetConnectionTitle), findsOneWidget);
      expect(find.text(_en.noInternetConnectionDescription), findsOneWidget);
      expect(find.byIcon(Icons.wifi_off), findsOneWidget);

      // Only OK closes it.
      await tester.tapAt(const Offset(2, 2));
      await tester.pumpAndSettle();
      expect(find.text(_en.noInternetConnectionTitle), findsOneWidget);

      await tester.tap(find.text(_en.ok));
      await tester.pumpAndSettle();
      expect(find.text(_en.noInternetConnectionTitle), findsNothing);
    });

    testWidgets('another error shows no dialog', (tester) async {
      await pumpSection(tester, absent);

      states.add(
        absent.copyWith(status: LoadModelStatus.error, errorMessage: 'boom'),
      );
      await tester.pumpAndSettle();

      expect(find.text(_en.noInternetConnectionTitle), findsNothing);
      expect(find.text(_en.aiModelError), findsOneWidget);
    });
  });
}
