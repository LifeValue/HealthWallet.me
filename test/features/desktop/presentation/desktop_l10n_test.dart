import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/core/l10n/display_names.dart';
import 'package:health_wallet/features/desktop/communication/presentation/bloc/communication_bloc.dart';
import 'package:health_wallet/features/desktop/handover/domain/entity/handover_session.dart';
import 'package:health_wallet/features/desktop/presentation/widgets/connection_chip.dart';

void main() {
  final ro = lookupAppLocalizations(const Locale('ro'));

  Future<void> pumpChip(WidgetTester tester, DesktopSyncState state) =>
      tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ro'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: ConnectionChip(state: state)),
        ),
      );

  testWidgets('the connection chip is in the app language', (tester) async {
    await pumpChip(tester, const DesktopSyncState());
    expect(find.text(ro.desktopDisconnected), findsOneWidget);

    await pumpChip(
      tester,
      const DesktopSyncState(connectionStatus: ConnectionStatus.discovering),
    );
    expect(find.text(ro.desktopDiscovering), findsOneWidget);

    await pumpChip(
      tester,
      const DesktopSyncState(
        connectionStatus: ConnectionStatus.connected,
        connectionTransport: ConnectionTransport.tcp,
      ),
    );
    expect(find.text(ro.desktopTransportWifi), findsOneWidget);
  });

  test('every handover failure has its own message', () {
    final messages = {
      for (final failure in HandoverFailure.values)
        failure: failure.localizedMessage(ro),
    };

    expect(messages[HandoverFailure.modelNotFound], ro.noAiModelOnDesktop);
    expect(messages.values.toSet(), hasLength(HandoverFailure.values.length));
  });
}
