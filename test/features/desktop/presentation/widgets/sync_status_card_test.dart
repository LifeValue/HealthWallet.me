import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/features/desktop/communication/presentation/bloc/communication_bloc.dart';
import 'package:health_wallet/features/desktop/lww_sync/presentation/bloc/lww_sync_bloc.dart';
import 'package:health_wallet/features/desktop/presentation/widgets/sync_status_card.dart';

final _l10n = lookupAppLocalizations(const Locale('en'));

const _connected = DesktopSyncState(
  connectionStatus: ConnectionStatus.connected,
);

/// Connected, nothing waiting either way, and both sides' tables match.
const _inSync = LwwSyncState(connected: true, tablesMatch: true);

void main() {
  Future<void> pump(
    WidgetTester tester,
    DesktopSyncState comm,
    LwwSyncState sync,
  ) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SyncStatusCard(commState: comm, syncState: sync),
        ),
      ),
    );
  }

  final statuses = <String, (DesktopSyncState, LwwSyncState, String)>{
    'a failure': (
      _connected,
      const LwwSyncState(syncStatus: LwwSyncStatus.error),
      _l10n.desktopSyncError,
    ),
    'in sync': (_connected, _inSync, _l10n.desktopSyncInSync),
    'connected, not compared yet': (
      _connected,
      LwwSyncState.initial(),
      _l10n.desktopSyncReady,
    ),
    'no device': (
      const DesktopSyncState(),
      LwwSyncState.initial(),
      _l10n.desktopSyncOffline,
    ),
  };
  for (final MapEntry(key: name, value: (comm, sync, label))
      in statuses.entries) {
    testWidgets('shows $name', (tester) async {
      await pump(tester, comm, sync);
      expect(find.text(label), findsOneWidget);
    });
  }

  testWidgets('marks in sync with a check', (tester) async {
    await pump(tester, _connected, _inSync);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });

  testWidgets('shows what moved and what still waits, and when it never '
      'synced', (tester) async {
    await pump(
      tester,
      _connected,
      const LwwSyncState(sentRows: 3, receivedRows: 2, pendingChangeCount: 4),
    );

    expect(find.text(_l10n.desktopSyncNotYet), findsOneWidget);
    expect(find.text(_l10n.desktopSyncTransferValue(3, 2)), findsOneWidget);
    expect(find.text(_l10n.desktopSyncPendingValue(4)), findsOneWidget);
  });
}
