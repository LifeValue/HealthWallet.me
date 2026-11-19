import 'package:bloc_test/bloc_test.dart' show MockBloc, whenListen;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/features/desktop/communication/presentation/bloc/communication_bloc.dart';
import 'package:health_wallet/features/desktop/lww_sync/presentation/bloc/lww_sync_bloc.dart';
import 'package:health_wallet/features/desktop/presentation/widgets/sync_dialog.dart';
import 'package:health_wallet/features/desktop/presentation/widgets/sync_status_card.dart';

/// Records the events the Sync Now button sends instead of running them.
class _MockLwwSyncBloc extends MockBloc<LwwSyncEvent, LwwSyncState>
    implements LwwSyncBloc {
  final events = <LwwSyncEvent>[];

  @override
  void add(LwwSyncEvent event) => events.add(event);
}

final _l10n = lookupAppLocalizations(const Locale('en'));

const _connected = DesktopSyncState(
  connectionStatus: ConnectionStatus.connected,
);

void main() {
  late _MockLwwSyncBloc lwwBloc;

  setUp(() {
    lwwBloc = _MockLwwSyncBloc();
    whenListen(
      lwwBloc,
      const Stream<LwwSyncState>.empty(),
      initialState: LwwSyncState.initial(),
    );
    getIt.registerSingleton<LwwSyncBloc>(lwwBloc);
  });

  tearDown(() => getIt.unregister<LwwSyncBloc>());

  /// The sync dialog's section and the desktop page's card both offer Sync
  /// Now; each is pumped the same way.
  final widgets = <String, Widget Function(DesktopSyncState, LwwSyncState)>{
    'sync dialog': (comm, sync) =>
        SyncSection(commState: comm, syncState: sync),
    'sync status card': (comm, sync) =>
        SyncStatusCard(commState: comm, syncState: sync),
  };

  for (final MapEntry(key: name, value: build) in widgets.entries) {
    group(name, () {
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
              body: BlocProvider<LwwSyncBloc>.value(
                value: lwwBloc,
                child: build(comm, sync),
              ),
            ),
          ),
        );
      }

      testWidgets('Sync Now asks for a sync the user requested', (
        tester,
      ) async {
        await pump(tester, _connected, LwwSyncState.initial());

        await tester.tap(find.text(_l10n.desktopSyncNow));

        expect(lwwBloc.events, [const SyncTriggered(userRequested: true)]);
      });

      testWidgets('after a failure, shows it and still offers Sync Now', (
        tester,
      ) async {
        await pump(
          tester,
          _connected,
          const LwwSyncState(
            syncStatus: LwwSyncStatus.error,
            error: 'the other device could not save some changes',
          ),
        );

        expect(find.text(_l10n.desktopSyncFailed), findsOneWidget);
        await tester.tap(find.text(_l10n.desktopSyncNow));
        expect(lwwBloc.events, [const SyncTriggered(userRequested: true)]);
      });

      testWidgets('offers no Sync Now while syncing', (tester) async {
        await pump(
          tester,
          _connected,
          const LwwSyncState(syncStatus: LwwSyncStatus.syncing),
        );

        expect(find.byType(LinearProgressIndicator), findsOneWidget);
        await tester.tap(find.text(_l10n.desktopSyncing).last);
        expect(lwwBloc.events, isEmpty);
      });

      testWidgets('offers no Sync Now without a connected device', (
        tester,
      ) async {
        await pump(tester, const DesktopSyncState(), LwwSyncState.initial());

        await tester.tap(find.text(_l10n.desktopSyncNow));
        expect(lwwBloc.events, isEmpty);
      });
    });
  }
}
