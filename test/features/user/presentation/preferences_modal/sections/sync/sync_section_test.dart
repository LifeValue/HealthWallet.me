import 'package:bloc_test/bloc_test.dart' show MockBloc, whenListen;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/config/app_platform.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/features/desktop/backup/presentation/bloc/backup_bloc.dart';
import 'package:health_wallet/features/desktop/communication/data/models/device_pairing.dart';
import 'package:health_wallet/features/desktop/communication/presentation/bloc/communication_bloc.dart';
import 'package:health_wallet/features/desktop/lww_sync/presentation/bloc/lww_sync_bloc.dart';
import 'package:health_wallet/features/desktop/presentation/widgets/vpn_notice.dart';
import 'package:health_wallet/features/sync/presentation/bloc/sync_bloc.dart';
import 'package:health_wallet/features/user/presentation/preferences_modal/sections/sync/sync_section.dart';

class _MockCommunicationBloc
    extends MockBloc<CommunicationEvent, DesktopSyncState>
    implements CommunicationBloc {}

class _MockLwwSyncBloc extends MockBloc<LwwSyncEvent, LwwSyncState>
    implements LwwSyncBloc {}

class _MockBackupBloc extends MockBloc<BackupEvent, BackupState>
    implements BackupBloc {}

class _MockSyncBloc extends MockBloc<SyncEvent, SyncState>
    implements SyncBloc {}

final _en = lookupAppLocalizations(const Locale('en'));

final _pairing = DevicePairing(
  deviceId: 'desktop-1',
  deviceName: 'Office Mac',
  pairingKey: 'key',
  lastIp: '192.168.1.20',
  lastPort: 49152,
  pairedAt: DateTime(2026, 10, 29),
);

void main() {
  late _MockCommunicationBloc commBloc;
  late _MockSyncBloc syncBloc;

  Future<void> register(AppPlatform platform, DesktopSyncState state) async {
    commBloc = _MockCommunicationBloc();
    final lwwBloc = _MockLwwSyncBloc();
    final backupBloc = _MockBackupBloc();
    syncBloc = _MockSyncBloc();

    whenListen(
      commBloc,
      const Stream<DesktopSyncState>.empty(),
      initialState: state,
    );
    whenListen(
      lwwBloc,
      const Stream<LwwSyncState>.empty(),
      initialState: LwwSyncState.initial(),
    );
    whenListen(
      backupBloc,
      const Stream<BackupState>.empty(),
      initialState: BackupState.initial(),
    );
    whenListen(
      syncBloc,
      const Stream<SyncState>.empty(),
      initialState: const SyncState(),
    );

    getIt
      ..registerSingleton<AppPlatform>(platform)
      ..registerSingleton<CommunicationBloc>(commBloc)
      ..registerSingleton<LwwSyncBloc>(lwwBloc)
      ..registerSingleton<BackupBloc>(backupBloc);
  }

  tearDown(() async {
    await getIt.reset();
  });

  Future<void> pumpSection(
    WidgetTester tester, {
    required AppPlatform platform,
    required DesktopSyncState state,
  }) async {
    await register(platform, state);
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: BlocProvider<SyncBloc>.value(
            value: syncBloc,
            child: const SingleChildScrollView(child: SyncSection()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('on the desktop', () {
    testWidgets('warns that the VPN can block the phone when one is on', (
      tester,
    ) async {
      await pumpSection(
        tester,
        platform: AppPlatform.desktop,
        state: const DesktopSyncState(vpnDetected: true),
      );

      expect(find.byType(VpnNotice), findsOneWidget);
      expect(find.text(_en.desktopVpnBlocksPhone), findsOneWidget);
      expect(find.text(_en.desktopVpnDetected), findsNothing);
    });

    testWidgets('keeps the warning while a phone is connected', (
      tester,
    ) async {
      await pumpSection(
        tester,
        platform: AppPlatform.desktop,
        state: const DesktopSyncState(
          vpnDetected: true,
          connectionStatus: ConnectionStatus.connected,
        ),
      );

      expect(find.text(_en.desktopVpnBlocksPhone), findsOneWidget);
    });

    testWidgets('shows no warning without a VPN', (tester) async {
      await pumpSection(
        tester,
        platform: AppPlatform.desktop,
        state: const DesktopSyncState(),
      );

      expect(find.byType(VpnNotice), findsNothing);
      expect(find.text(_en.desktopVpnBlocksPhone), findsNothing);
    });
  });

  group('on the phone', () {
    testWidgets('keeps the disconnect-the-VPN wording', (tester) async {
      await pumpSection(
        tester,
        platform: AppPlatform.mobile,
        state: DesktopSyncState(
          vpnDetected: true,
          connectionStatus: ConnectionStatus.connected,
          pairedDevice: _pairing,
        ),
      );

      expect(find.text(_en.desktopVpnDetected), findsOneWidget);
      expect(find.text(_en.desktopVpnBlocksPhone), findsNothing);
    });
  });
}
