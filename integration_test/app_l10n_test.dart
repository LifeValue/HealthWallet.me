// Boots the real mobile app and checks it in German and Romanian: translated
// tab bar and dashboard, vital units in the app language and the chosen
// region, and no Flutter error such as a layout overflow.
//
//   fvm flutter test integration_test/app_l10n_test.dart -d <simulator id>
//
// Run it on a simulator kept for tests: it loads the demo data when there
// are no records, and leaves the app in Romanian, with the Europe region and
// onboarding and the dashboard tutorial marked as seen. Restoring the previous
// values does not work, because iOS loses preference writes made just before
// the test runner closes the app.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/config/constants/region_preset.dart';
import 'package:health_wallet/core/config/constants/shared_prefs_constants.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/features/sync/presentation/bloc/sync_bloc.dart';
import 'package:health_wallet/features/user/presentation/bloc/user_bloc.dart';
import 'package:health_wallet/main.dart' as app;
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _onboardingKey = 'hasSeenOnboarding';

/// The dashboard's first-run tutorial overlay; marked as shown so it does not
/// cover the screen.
const _tutorialKey = 'sync_placeholder_tutorial_shown';

/// Units the demo and Fasten data spell out in English, and imperial units
/// that the Europe region must convert.
const _englishOrImperialUnits = [
  'beats/min',
  'breaths/min',
  'pounds',
  'inches',
  '°F',
];

/// Waits, without pumping frames, until [condition] holds.
Future<void> _waitUntil(bool Function() condition) async {
  final end = DateTime.now().add(const Duration(seconds: 30));
  while (!condition()) {
    if (DateTime.now().isAfter(end)) {
      throw TestFailure('Timed out waiting for the app to start');
    }
    await Future<void>.delayed(Duration.zero);
  }
}

Future<void> _pumpUntil(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 250));
    if (finder.evaluate().isNotEmpty) return;
  }
  final shown = find
      .byType(Text)
      .evaluate()
      .map((e) => (e.widget as Text).data)
      .whereType<String>()
      .take(30)
      .join(' | ');
  throw TestFailure('Timed out waiting for $finder. On screen: $shown');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the app is translated in German and Romanian', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(SharedPrefsConstants.appLocale, 'de');
    await prefs.setString(
      SharedPrefsConstants.regionPreset,
      RegionPreset.europe.name,
    );
    await prefs.setBool(_onboardingKey, true);
    await prefs.setBool(_tutorialKey, true);

    // bootstrap() replaces the test binding's error handler with one that
    // silences errors. Put the binding's back as soon as that happens, before
    // the first frame, so any Flutter error, an overflow included, fails the
    // test with its message.
    final testErrorHandler = FlutterError.onError;
    app.main();
    await _waitUntil(() => FlutterError.onError != testErrorHandler);
    FlutterError.onError = testErrorHandler;

    final de = lookupAppLocalizations(const Locale('de'));
    await _pumpUntil(tester, find.text(de.dashboardTitle));
    await tester.pump(const Duration(seconds: 1));

    for (final label in [
      de.dashboardTitle,
      de.recordsTitle,
      de.documentScanTitle,
      de.importTitle,
    ]) {
      expect(find.text(label), findsWidgets, reason: 'German tab "$label"');
    }
    // A fresh install has no records; load the demo data as the empty
    // dashboard's "Load demo data" button does once a country is chosen.
    if (find.text(de.homeVitalSigns).evaluate().isEmpty) {
      tester
          .element(find.text(de.dashboardTitle).first)
          .read<SyncBloc>()
          .add(const LoadDemoData());
    }
    await _pumpUntil(tester, find.text(de.homeVitalSigns));

    tester
        .element(find.text(de.dashboardTitle).first)
        .read<UserBloc>()
        .add(const UserLocaleChanged(Locale('ro')));
    final ro = lookupAppLocalizations(const Locale('ro'));
    await _pumpUntil(tester, find.text(ro.dashboardTitle));
    await _pumpUntil(tester, find.text(ro.homeVitalSigns));
    await tester.pump(const Duration(seconds: 1));

    // The temperature card is shown even with the list collapsed, so the
    // region's unit must be on screen.
    expect(find.text('°C'), findsWidgets, reason: 'Europe temperature unit');
    for (final unit in _englishOrImperialUnits) {
      expect(find.text(unit), findsNothing, reason: 'unit "$unit" on screen');
    }
  });
}
