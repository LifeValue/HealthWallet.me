import 'package:bloc_test/bloc_test.dart' show MockBloc, whenListen;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/config/constants/ai_model_config.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/core/services/device_capability_service.dart';
import 'package:health_wallet/features/processing/presentation/pages/load_model/bloc/load_model_bloc.dart';
import 'package:health_wallet/features/processing/presentation/widgets/model_management_dialog.dart';

import '../../../../helpers/ai_settings_dialog_driver.dart';

/// Records the events it is sent instead of running them.
class _MockLoadModelBloc extends MockBloc<LoadModelEvent, LoadModelState>
    implements LoadModelBloc {
  final events = <LoadModelEvent>[];

  @override
  void add(LoadModelEvent event) => events.add(event);
}

final _en = lookupAppLocalizations(const Locale('en'));

void main() {
  late _MockLoadModelBloc bloc;
  final qwen = AiModelConfig.fromVariant(AiModelVariant.qwen);
  final name = qwen.localizedName(_en);

  setUp(() {
    bloc = _MockLoadModelBloc();
    whenListen(
      bloc,
      const Stream<LoadModelState>.empty(),
      initialState: const LoadModelState(
        status: LoadModelStatus.modelLoaded,
        deviceCapability: DeviceAiCapability.full,
        selectedVariant: AiModelVariant.qwen,
        downloadedVariants: {AiModelVariant.qwen: true},
      ),
    );
    getIt.registerSingleton<LoadModelBloc>(bloc);
  });

  tearDown(getIt.reset);

  /// Opens the dialog and taps the downloaded model's trash icon.
  Future<void> tapDelete(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(testApp(const ModelManagementDialog()));
    await tester.pump();

    // Only a downloaded model has the trash icon.
    final trash = find.byWidgetPredicate(
      (w) =>
          w is SvgPicture &&
          '${w.bytesLoader}'.contains('trash-can') &&
          w.width == 18,
    );
    expect(trash, findsOne);
    await tester.tap(trash);
    await tester.pumpAndSettle();
  }

  Iterable<LoadModelEvent> deletes() =>
      bloc.events.whereType<LoadModelDeleteRequested>();

  testWidgets('the trash icon asks first, naming the model and its size', (
    tester,
  ) async {
    await tapDelete(tester);

    expect(find.text(_en.aiModelDeleteTitle(name)), findsOne);
    expect(
      find.text(_en.aiModelDeleteMessage(qwen.modelSizeMB)),
      findsOne,
    );
    expect(deletes(), isEmpty, reason: 'nothing is deleted before the answer');
  });

  testWidgets('Cancel keeps the model', (tester) async {
    await tapDelete(tester);

    await tester.tap(find.text(_en.cancel));
    await tester.pumpAndSettle();

    expect(find.text(_en.aiModelDeleteTitle(name)), findsNothing);
    expect(deletes(), isEmpty);
  });

  testWidgets('Delete deletes that model', (tester) async {
    await tapDelete(tester);

    await tester.tap(find.text(_en.delete));
    await tester.pumpAndSettle();

    expect(deletes(), [const LoadModelDeleteRequested(AiModelVariant.qwen)]);
    expect(find.text(_en.aiModelDeleteTitle(name)), findsNothing);
  });

  group('a model that is downloading', () {
    Future<void> openDownloading(WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await getIt.reset();
      bloc = _MockLoadModelBloc();
      whenListen(
        bloc,
        const Stream<LoadModelState>.empty(),
        initialState: const LoadModelState(
          status: LoadModelStatus.loading,
          deviceCapability: DeviceAiCapability.full,
          downloadingVariants: {AiModelVariant.qwen: true},
          variantProgress: {AiModelVariant.qwen: 74},
        ),
      );
      getIt.registerSingleton<LoadModelBloc>(bloc);
      await tester.pumpWidget(testApp(const ModelManagementDialog()));
      await tester.pump();
    }

    Iterable<LoadModelEvent> cancels() =>
        bloc.events.whereType<LoadModelDownloadCancelled>();

    testWidgets('shows its progress and a Cancel', (tester) async {
      await openDownloading(tester);

      expect(find.text('${_en.aiModelDownloading} 74%'), findsOne);
      expect(find.text(_en.cancel), findsOne, reason: 'only that model');
    });

    testWidgets('Cancel asks first; Continue keeps downloading', (
      tester,
    ) async {
      await openDownloading(tester);

      await tester.tap(find.text(_en.cancel));
      await tester.pumpAndSettle();
      expect(find.text(_en.cancelDownloadMessage), findsOne);
      expect(cancels(), isEmpty);

      await tester.tap(find.text(_en.continueButton));
      await tester.pumpAndSettle();
      expect(find.text(_en.cancelDownloadMessage), findsNothing);
      expect(cancels(), isEmpty);
    });

    testWidgets('confirming stops that model\'s download only', (tester) async {
      await openDownloading(tester);

      await tester.tap(find.text(_en.cancel));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_en.cancelDownloadTitle).last);
      await tester.pumpAndSettle();

      expect(cancels(), [
        const LoadModelDownloadCancelled(variant: AiModelVariant.qwen),
      ]);
    });
  });

  group('the Advanced model', () {
    final advanced = AiModelConfig.fromVariant(AiModelVariant.qwen35x4b);

    Future<void> open(
      WidgetTester tester, {
      required DeviceAiCapability capability,
      required bool advancedModelSupported,
    }) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await getIt.reset();
      bloc = _MockLoadModelBloc();
      whenListen(
        bloc,
        const Stream<LoadModelState>.empty(),
        initialState: LoadModelState(
          status: LoadModelStatus.modelAbsent,
          deviceCapability: capability,
          advancedModelSupported: advancedModelSupported,
        ),
      );
      getIt.registerSingleton<LoadModelBloc>(bloc);
      await tester.pumpWidget(testApp(const ModelManagementDialog()));
      await tester.pump();
    }

    Finder advancedCard() => find.ancestor(
      of: find.text(advanced.localizedName(_en)),
      matching: find.byType(GestureDetector),
    );

    Iterable<LoadModelEvent> downloads() =>
        bloc.events.whereType<LoadModelDownloadInitiated>();

    testWidgets('is offered on an iPhone with 8 GB', (tester) async {
      await open(
        tester,
        capability: DeviceAiCapability.full,
        advancedModelSupported: true,
      );

      expect(find.text(_en.medGemmaIncompatibleDevice), findsNothing);
      final download = find.descendant(
        of: advancedCard().first,
        matching: find.text(_en.download),
      );
      expect(download, findsOne);
      await tester.tap(download);
      expect(downloads(), [
        const LoadModelDownloadInitiated(variant: AiModelVariant.qwen35x4b),
      ]);
    });

    testWidgets('needs more memory on a 6 GB iPhone, where Lite still '
        'downloads', (tester) async {
      await open(
        tester,
        capability: DeviceAiCapability.full,
        advancedModelSupported: false,
      );

      expect(
        find.descendant(
          of: advancedCard().first,
          matching: find.text(_en.medGemmaIncompatibleDevice),
        ),
        findsOne,
      );
      expect(
        find.descendant(
          of: advancedCard().first,
          matching: find.text(_en.download),
        ),
        findsNothing,
      );
      expect(find.text(_en.download), findsWidgets, reason: 'Lite');
    });

    testWidgets('needs more memory on a phone without Deep Scan', (
      tester,
    ) async {
      await open(
        tester,
        capability: DeviceAiCapability.basicOnly,
        advancedModelSupported: false,
      );

      expect(find.text(_en.medGemmaIncompatibleDevice), findsOne);
    });

    testWidgets('on an unsupported device only the notice above explains', (
      tester,
    ) async {
      await open(
        tester,
        capability: DeviceAiCapability.unsupported,
        advancedModelSupported: false,
      );

      expect(find.text(_en.aiModelNotAvailableForDeviceDescription), findsOne);
      expect(find.text(_en.medGemmaIncompatibleDevice), findsNothing);
      expect(
        find.descendant(
          of: advancedCard().first,
          matching: find.text(_en.download),
        ),
        findsNothing,
      );
    });
  });
}
