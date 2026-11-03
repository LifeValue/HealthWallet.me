import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/config/constants/ai_model_config.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/features/processing/domain/services/ai_model_download_service.dart';
import 'package:health_wallet/features/processing/presentation/widgets/ai_settings/ai_settings_dialog.dart';
import 'package:health_wallet/features/processing/presentation/widgets/ai_settings/ai_settings_vision_toggle.dart';

final _en = lookupAppLocalizations(const Locale('en'));

/// The download service the AI settings dialog listens to: no download runs
/// and the Deep Scan file is already on the device.
class FakeAiModelDownloadService extends Fake
    implements AiModelDownloadService {
  @override
  Stream<AiModelDownloadState> get stateStream => const Stream.empty();

  @override
  Future<bool> checkMmprojExistsForVariant(AiModelVariant variant) async =>
      true;
}

/// An English app around [home].
Widget testApp(Widget home) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: home),
);

/// Pumps a few frames without waiting for every animation to end, since a
/// screen behind the dialog may show a spinner.
Future<void> _pumpFrames(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Lets work started outside the test's fake clock run on.
Future<void> _runReal(WidgetTester tester) => tester.runAsync(
  () => Future<void>.delayed(const Duration(milliseconds: 20)),
);

/// Taps [opener] and waits for the AI settings dialog. Opening it reads the
/// device's RAM through real I/O, which never completes on the test's fake
/// clock, so the tap runs on the real one.
Future<void> openAiSettings(WidgetTester tester, Finder opener) async {
  await tester.runAsync(() => tester.tap(opener));
  for (var i = 0; i < 100; i++) {
    await _runReal(tester);
    await tester.pump();
    if (find.byType(AiTokenSettingsDialog).evaluate().isNotEmpty) break;
  }
  expect(find.byType(AiTokenSettingsDialog), findsOneWidget);
  await _pumpFrames(tester);
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await _pumpFrames(tester);
}

/// Taps the dialog's Save button and lets the screen that opened it apply
/// the result.
Future<void> tapSave(WidgetTester tester) async {
  await _tapVisible(tester, find.text(_en.setTokens));
  for (var i = 0; i < 5; i++) {
    await _runReal(tester);
    await tester.pump();
  }
}

/// Picks the token preset titled [title].
Future<void> tapTokenPreset(WidgetTester tester, String title) =>
    _tapVisible(tester, find.text(title));

/// Flips the Deep Scan toggle.
Future<void> toggleDeepScan(WidgetTester tester) => _tapVisible(
  tester,
  find.descendant(
    of: find.byType(AiVisionToggleSection),
    matching: find.text(_en.off),
  ),
);
