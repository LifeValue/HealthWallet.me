import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/features/share_records/presentation/bloc/share_records_state.dart';
import 'package:health_wallet/features/share_records/presentation/views/session_ended_view.dart';

final _ro = lookupAppLocalizations(const Locale('ro'));

Future<void> _pump(WidgetTester tester, ShareSessionEndReason reason) =>
    tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ro'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SessionEndedView(
            state: ShareRecordsState(sessionEndReason: reason),
          ),
        ),
      ),
    );

void main() {
  testWidgets('a declined invitation shows the declined texts', (
    tester,
  ) async {
    await _pump(tester, ShareSessionEndReason.invitationDeclined);

    expect(find.text(_ro.shareInvitationDeclined), findsOneWidget);
    expect(find.text(_ro.shareInvitationDeclinedMessage), findsOneWidget);
    expect(find.text(_ro.shareSessionComplete), findsNothing);
  });

  for (final reason in [
    ShareSessionEndReason.terminated,
    ShareSessionEndReason.expired,
  ]) {
    testWidgets('a ${reason.name} session shows the session-complete texts', (
      tester,
    ) async {
      await _pump(tester, reason);

      expect(find.text(_ro.shareSessionComplete), findsOneWidget);
      expect(find.text(_ro.shareSessionCompleteMessage), findsOneWidget);
      expect(find.text(_ro.shareInvitationDeclined), findsNothing);
    });
  }
}
