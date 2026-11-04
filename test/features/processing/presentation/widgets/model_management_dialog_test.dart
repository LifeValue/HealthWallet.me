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
    expect(find.text(_en.aiModelDeleteMessage(qwen.modelSizeMB)), findsOne);
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
}
