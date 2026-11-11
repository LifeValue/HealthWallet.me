import 'package:bloc_test/bloc_test.dart' show MockBloc, whenListen;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/config/app_platform.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/features/desktop/communication/data/models/device_pairing.dart';
import 'package:health_wallet/features/desktop/communication/presentation/bloc/communication_bloc.dart';
import 'package:health_wallet/features/desktop/lww_sync/presentation/bloc/lww_sync_bloc.dart';
import 'package:health_wallet/features/desktop/presentation/widgets/sync_dialog.dart';

class _MockCommunicationBloc
    extends MockBloc<CommunicationEvent, DesktopSyncState>
    implements CommunicationBloc {}

class _MockLwwSyncBloc extends MockBloc<LwwSyncEvent, LwwSyncState>
    implements LwwSyncBloc {}

final _l10n = lookupAppLocalizations(const Locale('en'));

const _connected = DesktopSyncState(
  connectionStatus: ConnectionStatus.connected,
);

/// Synced a minute ago with "Desk", 3 rows sent and 2 received.
LwwSyncState _lastSync({String? peer = 'Desk', bool inSync = true}) =>
    LwwSyncState(
      connected: true,
      tablesMatch: inSync,
      lastSyncTime: DateTime.now().subtract(const Duration(minutes: 1)),
      lastSyncPeerName: peer,
      sentRows: 3,
      receivedRows: 2,
    );

void main() {
  late _MockCommunicationBloc commBloc;
  late _MockLwwSyncBloc lwwBloc;

  void register({
    DesktopSyncState comm = _connected,
    LwwSyncState? sync,
    AppPlatform platform = AppPlatform.desktop,
  }) {
    whenListen(
      commBloc,
      const Stream<DesktopSyncState>.empty(),
      initialState: comm,
    );
    whenListen(
      lwwBloc,
      const Stream<LwwSyncState>.empty(),
      initialState: sync ?? LwwSyncState.initial(),
    );
    getIt
      ..registerSingleton<CommunicationBloc>(commBloc)
      ..registerSingleton<LwwSyncBloc>(lwwBloc)
      ..registerSingleton<AppPlatform>(platform);
  }

  setUp(() {
    commBloc = _MockCommunicationBloc();
    lwwBloc = _MockLwwSyncBloc();
  });

  tearDown(getIt.reset);

  Widget app(Widget child) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );

  Future<void> pumpSection(
    WidgetTester tester, {
    DesktopSyncState comm = _connected,
    required LwwSyncState sync,
  }) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      app(SyncSection(commState: comm, syncState: sync)),
    );
  }

  testWidgets('the dialog shows the sync state of both blocs and closes from '
      'its close button', (tester) async {
    register(sync: _lastSync());
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      app(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => SyncDialog.show(context),
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text(_l10n.syncTitle), findsOneWidget);
    expect(find.text(_l10n.desktopSyncNow), findsOneWidget);
    expect(find.textContaining('· Desk'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.text(_l10n.syncTitle), findsNothing);
  });

  testWidgets('the last sync names the device it was with and what moved', (
    tester,
  ) async {
    register();
    await pumpSection(tester, sync: _lastSync());

    expect(find.text(_l10n.desktopSyncRecent), findsOneWidget);
    expect(find.textContaining('· Desk'), findsOneWidget);
    expect(find.text(_l10n.desktopSyncHistoryTransfer(3, 2)), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
  });

  testWidgets('a last sync not confirmed in sync shows the sync icon, and no '
      'transfer line when nothing moved', (tester) async {
    register();
    await pumpSection(
      tester,
      sync: _lastSync(inSync: false).copyWith(sentRows: 0, receivedRows: 0),
    );

    expect(find.byIcon(Icons.sync), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_outline), findsNothing);
    expect(find.text(_l10n.desktopSyncHistoryTransfer(0, 0)), findsNothing);
  });

  testWidgets('without the peer\'s name, the last sync names the connected '
      'device', (tester) async {
    register();
    await pumpSection(
      tester,
      comm: _connected.copyWith(connectedDeviceName: 'Laptop'),
      sync: _lastSync(peer: null),
    );

    expect(find.textContaining('· Laptop'), findsOneWidget);
  });

  testWidgets('with no name known, the phone names its paired desktop and the '
      'desktop an unknown device', (tester) async {
    final paired = _connected.copyWith(
      pairedDevice: DevicePairing(
        deviceId: 'desktop',
        deviceName: 'Paired desk',
        pairingKey: 'key',
        lastIp: '10.0.0.2',
        lastPort: 49152,
        pairedAt: DateTime(2026, 10, 1),
      ),
    );

    register(platform: AppPlatform.mobile);
    await pumpSection(tester, comm: paired, sync: _lastSync(peer: null));
    expect(find.textContaining('· Paired desk'), findsOneWidget);

    await getIt.reset();
    register();
    await pumpSection(tester, comm: paired, sync: _lastSync(peer: null));
    expect(
      find.textContaining('· ${_l10n.desktopUnknownDevice}'),
      findsOneWidget,
    );
  });
}
