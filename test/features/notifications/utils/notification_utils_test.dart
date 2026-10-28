import 'package:flutter/material.dart' hide Notification;
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/features/notifications/domain/entities/notification.dart';
import 'package:health_wallet/features/notifications/utils/notification_utils.dart';

import '../../../helpers/log_capture.dart';

void main() {
  final logs = captureLogs();
  final en = lookupAppLocalizations(const Locale('en'));
  const notification = Notification(text: 'Lab report.pdf is ready');

  Future<BuildContext> pumpContext(WidgetTester tester, Widget app) async {
    late BuildContext captured;
    await tester.pumpWidget(
      app is MaterialApp
          ? MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Builder(
                builder: (context) {
                  captured = context;
                  return const Scaffold();
                },
              ),
            )
          : Directionality(
              textDirection: TextDirection.ltr,
              child: Builder(
                builder: (context) {
                  captured = context;
                  return const SizedBox();
                },
              ),
            ),
    );
    return captured;
  }

  testWidgets('shows the title and the notification text', (tester) async {
    final context = await pumpContext(tester, const MaterialApp());

    showProcessingDoneNotification(context, notification);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text(en.processingDone), findsOneWidget);
    expect(find.text('Lab report.pdf is ready'), findsOneWidget);
    expect(logs, isEmpty);

    // Let the flushbar time out so no timer is left pending.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('calls onDismissed once the notification is gone', (
    tester,
  ) async {
    final context = await pumpContext(tester, const MaterialApp());
    var dismissed = 0;

    showProcessingDoneNotification(
      context,
      notification,
      onDismissed: () => dismissed++,
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(dismissed, 0);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    expect(dismissed, 1);
  });

  testWidgets('logs instead of throwing when it cannot be shown', (
    tester,
  ) async {
    // No navigator and no localizations: building the flushbar fails.
    final context = await pumpContext(tester, const SizedBox());

    showProcessingDoneNotification(context, notification);
    await tester.pump();

    expect(logs, loggedWarning('processing notification'));
  });
}
