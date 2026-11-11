import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/config/constants/ai_model_config.dart';
import 'package:health_wallet/core/config/constants/shared_prefs_constants.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/features/notifications/bloc/notification_bloc.dart';
import 'package:health_wallet/features/processing/domain/services/ai_model_selection_guard.dart';
import 'package:health_wallet/features/processing/presentation/widgets/ai_model_switch_notice_listener.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/fake_device_capability_service.dart';

void main() {
  late SharedPreferences prefs;
  late AiModelSelectionGuard guard;
  late NotificationBloc notifications;

  Future<void> start(AiModelVariant selected) async {
    SharedPreferences.setMockInitialValues({
      SharedPrefsConstants.aiSelectedModel: selected.name,
    });
    prefs = await SharedPreferences.getInstance();
    final device = FakeDeviceCapabilityService()
      ..advancedModelSupported = false;
    guard = AiModelSelectionGuard(device, prefs);
    await guard.replaceUnsupportedModel();
    notifications = NotificationBloc(prefs);
  }

  tearDown(() => notifications.close());

  Future<void> pump(WidgetTester tester, {Locale? locale}) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AiModelSwitchNoticeListener(
          guard: guard,
          notificationBloc: notifications,
          child: const SizedBox(),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('says once that Lite replaced the Advanced model', (
    tester,
  ) async {
    await tester.runAsync(() => start(AiModelVariant.qwen35x4b));

    await pump(tester);

    final added = notifications.state.notifications;
    expect(added, hasLength(1));
    expect(added.single.text, 'Now using the Lite model');
    expect(
      added.single.description,
      'The Advanced model needs more memory than this device has, so the '
      'Lite model is used.',
    );
    expect(added.single.read, isFalse);

    // A later start (the listener built again) adds nothing more.
    await tester.pumpWidget(const SizedBox());
    await pump(tester);
    expect(notifications.state.notifications, hasLength(1));
  });

  testWidgets('names the replaced model in the app language', (tester) async {
    await tester.runAsync(() => start(AiModelVariant.qwen35x4b));

    await pump(tester, locale: const Locale('de'));

    expect(
      notifications.state.notifications.single.description,
      'Das Modell Erweitert benötigt mehr Arbeitsspeicher, als dieses Gerät '
      'hat, daher wird das Lite-Modell verwendet.',
    );
  });

  testWidgets('says nothing when the selected model fits', (tester) async {
    await tester.runAsync(() => start(AiModelVariant.qwen));

    await pump(tester);

    expect(notifications.state.notifications, isEmpty);
  });
}
