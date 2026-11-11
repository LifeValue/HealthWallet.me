import 'package:bloc_test/bloc_test.dart' show MockBloc, whenListen;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations_en.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/features/desktop/backup/domain/entity/backup_entry.dart';
import 'package:health_wallet/features/desktop/backup/presentation/bloc/backup_bloc.dart';
import 'package:health_wallet/features/desktop/communication/data/models/device_pairing.dart';
import 'package:health_wallet/features/desktop/communication/presentation/bloc/communication_bloc.dart';
import 'package:health_wallet/features/desktop/lww_sync/presentation/bloc/lww_sync_bloc.dart';
import 'package:health_wallet/features/home/presentation/home_page.dart';

class _MockCommunicationBloc
    extends MockBloc<CommunicationEvent, DesktopSyncState>
    implements CommunicationBloc {}

class _MockLwwSyncBloc extends MockBloc<LwwSyncEvent, LwwSyncState>
    implements LwwSyncBloc {}

class _MockBackupBloc extends MockBloc<BackupEvent, BackupState>
    implements BackupBloc {}

final _en = lookupAppLocalizations(const Locale('en'));
final _ro = lookupAppLocalizations(const Locale('ro'));

/// A label no card can fit, to check it ends in an ellipsis.
const _longLabel = 'A connection label far too long for any status card';

/// English strings with the card labels replaced.
class _LabelL10n extends AppLocalizationsEn {
  _LabelL10n({this.connection, this.backup});

  final String? connection;
  final String? backup;

  @override
  String get connectionLabel => connection ?? super.connectionLabel;

  @override
  String get backupLabel => backup ?? super.backupLabel;
}

class _LabelDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _LabelDelegate({this.connection, this.backup});

  final String? connection;
  final String? backup;

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<AppLocalizations> load(Locale locale) =>
      SynchronousFuture(_LabelL10n(connection: connection, backup: backup));

  @override
  bool shouldReload(_LabelDelegate old) => false;
}

final _pairing = DevicePairing(
  deviceId: 'phone-1',
  deviceName: 'Pixel',
  pairingKey: 'key',
  lastIp: '10.0.0.2',
  lastPort: 49152,
  pairedAt: DateTime(2026, 10, 1),
);

BackupEntry _backupAt(DateTime timestamp) => BackupEntry(
  id: 'b1',
  name: 'backup',
  timestamp: timestamp,
  sizeBytes: 1024,
  recordCount: 3,
  checksum: 'abc',
  filePath: '/tmp/backup.db',
);

/// The app's Matter font, so label widths match the running app rather than
/// the test font's square glyphs.
Future<void> _loadMatterFont() async {
  final loader = FontLoader('Matter');
  for (final file in const [
    'Matter-Regular.ttf',
    'Matter-Medium.ttf',
    'Matter-SemiBold.ttf',
    'Matter-Bold.ttf',
  ]) {
    loader.addFont(rootBundle.load('assets/font/matter-font/$file'));
  }
  await loader.load();
}

void main() {
  late _MockCommunicationBloc communicationBloc;
  late _MockLwwSyncBloc lwwSyncBloc;
  late _MockBackupBloc backupBloc;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await _loadMatterFont();
  });

  setUp(() async {
    await getIt.reset();
    communicationBloc = _MockCommunicationBloc();
    lwwSyncBloc = _MockLwwSyncBloc();
    backupBloc = _MockBackupBloc();
    getIt
      ..registerSingleton<CommunicationBloc>(communicationBloc)
      ..registerSingleton<LwwSyncBloc>(lwwSyncBloc)
      ..registerSingleton<BackupBloc>(backupBloc);
  });

  tearDownAll(getIt.reset);

  Future<void> pumpCards(
    WidgetTester tester, {
    DesktopSyncState connection = const DesktopSyncState(),
    LwwSyncState sync = const LwwSyncState(),
    BackupState backup = const BackupState(
      hasUserSelectedPath: true,
      backupPath: '/tmp',
    ),
    Brightness brightness = Brightness.light,
    Locale locale = const Locale('en'),
    LocalizationsDelegate<AppLocalizations> l10n = AppLocalizations.delegate,
  }) async {
    whenListen(
      communicationBloc,
      const Stream<DesktopSyncState>.empty(),
      initialState: connection,
    );
    whenListen(
      lwwSyncBloc,
      const Stream<LwwSyncState>.empty(),
      initialState: sync,
    );
    whenListen(
      backupBloc,
      const Stream<BackupState>.empty(),
      initialState: backup,
    );
    tester.view.physicalSize = const Size(1200, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: brightness),
        locale: locale,
        localizationsDelegates: [
          l10n,
          ...AppLocalizations.localizationsDelegates.where(
            (d) => d is! LocalizationsDelegate<AppLocalizations>,
          ),
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: Center(child: HomeStatusCardsForTesting())),
      ),
    );
    // Not pumpAndSettle: a syncing or backing-up card spins forever.
    await tester.pump();
  }

  /// The card showing [label]: the tap target that wraps it.
  Finder card(String label) => find
      .ancestor(of: find.text(label), matching: find.byType(GestureDetector))
      .first;

  Color? labelColor(WidgetTester tester, String label) =>
      tester.widget<Text>(find.text(label)).style?.color;

  Color? iconColor(WidgetTester tester, IconData icon) =>
      tester.widget<Icon>(find.byIcon(icon)).color;

  bool isEllipsized(WidgetTester tester, String text) =>
      tester.renderObject<RenderParagraph>(find.text(text)).didExceedMaxLines;

  Finder spinnerIn(String label) => find.descendant(
    of: card(label),
    matching: find.byType(CircularProgressIndicator),
  );

  group('sync card', () {
    testWidgets('neutral state is light grey in dark mode', (tester) async {
      await pumpCards(tester, brightness: Brightness.dark);

      expect(iconColor(tester, Icons.sync), AppColors.textSecondaryDark);
      expect(labelColor(tester, _en.syncLabel), AppColors.textSecondaryDark);
      expect(find.text(_en.syncStatusNotSynced), findsOneWidget);
    });

    testWidgets('neutral state is dark grey in light mode', (tester) async {
      await pumpCards(tester);

      expect(iconColor(tester, Icons.sync), AppColors.textSecondary);
      expect(labelColor(tester, _en.syncLabel), AppColors.textSecondary);
      expect(find.text(_en.syncStatusNotSynced), findsOneWidget);
    });

    testWidgets('neutral state shows how long ago the last sync was', (
      tester,
    ) async {
      await pumpCards(
        tester,
        brightness: Brightness.dark,
        sync: LwwSyncState(
          lastSyncTime: DateTime.now().subtract(const Duration(hours: 3)),
        ),
      );

      expect(find.text(_en.timeAgoHours(3)), findsOneWidget);
      expect(iconColor(tester, Icons.sync), AppColors.textSecondaryDark);
    });

    testWidgets('syncing shows a primary spinner instead of the icon', (
      tester,
    ) async {
      await pumpCards(
        tester,
        sync: const LwwSyncState(syncStatus: LwwSyncStatus.syncing),
      );

      expect(find.byIcon(Icons.sync), findsNothing);
      final spinner = spinnerIn(_en.syncLabel);
      expect(spinner, findsOneWidget);
      expect(
        tester.widget<CircularProgressIndicator>(spinner).color,
        AppColors.primary,
      );
      expect(labelColor(tester, _en.syncLabel), AppColors.primary);
      expect(find.text(_en.syncStatusSyncing), findsOneWidget);
    });

    testWidgets('in sync is green', (tester) async {
      await pumpCards(
        tester,
        sync: const LwwSyncState(connected: true, tablesMatch: true),
      );

      expect(iconColor(tester, Icons.sync), AppColors.success);
      expect(labelColor(tester, _en.syncLabel), AppColors.success);
      expect(find.text(_en.syncStatusInSync), findsOneWidget);
    });

    testWidgets('an error is red', (tester) async {
      await pumpCards(
        tester,
        sync: const LwwSyncState(syncStatus: LwwSyncStatus.error),
      );

      expect(iconColor(tester, Icons.sync), AppColors.error);
      expect(labelColor(tester, _en.syncLabel), AppColors.error);
      expect(find.text(_en.syncStatusNotSynced), findsOneWidget);
    });

    testWidgets('pending changes are orange with their count', (tester) async {
      await pumpCards(tester, sync: const LwwSyncState(pendingChangeCount: 2));

      expect(iconColor(tester, Icons.sync), AppColors.warning);
      expect(labelColor(tester, _en.syncLabel), AppColors.warning);
      expect(find.text(_en.syncStatusPending(2)), findsOneWidget);
    });
  });

  group('backup card', () {
    testWidgets('backing up shows a primary spinner and working', (
      tester,
    ) async {
      await pumpCards(
        tester,
        backup: const BackupState(
          hasUserSelectedPath: true,
          backupPath: '/tmp',
          isBackingUp: true,
        ),
      );

      expect(find.byIcon(Icons.shield_outlined), findsNothing);
      final spinner = spinnerIn(_en.backupLabel);
      expect(spinner, findsOneWidget);
      expect(
        tester.widget<CircularProgressIndicator>(spinner).color,
        AppColors.primary,
      );
      expect(find.text(_en.backupStatusWorking), findsOneWidget);
    });

    testWidgets('no folder chosen is orange, even with past backups', (
      tester,
    ) async {
      await pumpCards(
        tester,
        backup: BackupState(backupHistory: [_backupAt(DateTime(2026))]),
      );

      expect(iconColor(tester, Icons.shield_outlined), AppColors.warning);
      expect(find.text(_en.backupStatusNoFolder), findsOneWidget);
    });

    testWidgets('a last backup is green with how long ago it was', (
      tester,
    ) async {
      await pumpCards(
        tester,
        backup: BackupState(
          hasUserSelectedPath: true,
          backupPath: '/tmp',
          backupHistory: [
            _backupAt(DateTime.now().subtract(const Duration(hours: 2))),
          ],
        ),
      );

      expect(iconColor(tester, Icons.shield_outlined), AppColors.success);
      expect(labelColor(tester, _en.backupLabel), AppColors.success);
      expect(find.text(_en.timeAgoHours(2)), findsOneWidget);
    });

    testWidgets('a backup known only from the desktop counts as one', (
      tester,
    ) async {
      await pumpCards(
        tester,
        backup: BackupState(
          hasUserSelectedPath: true,
          backupPath: '/tmp',
          desktopLastBackupTime: DateTime.now().subtract(
            const Duration(hours: 5),
          ),
        ),
      );

      expect(iconColor(tester, Icons.shield_outlined), AppColors.success);
      expect(find.text(_en.timeAgoHours(5)), findsOneWidget);
    });

    testWidgets('no backup yet is orange', (tester) async {
      await pumpCards(tester);

      expect(iconColor(tester, Icons.shield_outlined), AppColors.warning);
      expect(find.text(_en.backupStatusNoBackup), findsOneWidget);
    });
  });

  group('connection card', () {
    testWidgets('connected is green with the phone name', (tester) async {
      await pumpCards(
        tester,
        connection: const DesktopSyncState(
          connectionStatus: ConnectionStatus.connected,
          connectedDeviceName: 'Pixel 9',
        ),
      );

      expect(iconColor(tester, Icons.link), AppColors.success);
      expect(labelColor(tester, _en.connectionLabel), AppColors.success);
      expect(find.text('Pixel 9'), findsOneWidget);
    });

    testWidgets('connected without a phone name says connected', (
      tester,
    ) async {
      await pumpCards(
        tester,
        connection: const DesktopSyncState(
          connectionStatus: ConnectionStatus.connected,
        ),
      );

      expect(find.text(_en.connectionStatusConnected), findsOneWidget);
    });

    testWidgets('discovering is orange and connecting', (tester) async {
      await pumpCards(
        tester,
        connection: const DesktopSyncState(
          connectionStatus: ConnectionStatus.discovering,
        ),
      );

      expect(iconColor(tester, Icons.link_off), AppColors.warning);
      expect(find.text(_en.connectionStatusConnecting), findsOneWidget);
    });

    testWidgets('a paired phone that is away is red and disconnected', (
      tester,
    ) async {
      await pumpCards(
        tester,
        connection: DesktopSyncState(pairedDevice: _pairing),
      );

      expect(iconColor(tester, Icons.link_off), AppColors.error);
      expect(labelColor(tester, _en.connectionLabel), AppColors.error);
      expect(find.text(_en.connectionStatusDisconnected), findsOneWidget);
    });

    testWidgets('no paired phone is red and not paired', (tester) async {
      await pumpCards(tester);

      expect(iconColor(tester, Icons.link_off), AppColors.error);
      expect(find.text(_en.connectionStatusNotPaired), findsOneWidget);
    });

    testWidgets('without a communication bloc it falls back to not paired', (
      tester,
    ) async {
      await getIt.unregister<CommunicationBloc>();

      await pumpCards(tester);

      expect(iconColor(tester, Icons.link_off), AppColors.error);
      expect(find.text(_en.connectionLabel), findsOneWidget);
      expect(find.text(_en.connectionStatusNotPaired), findsOneWidget);
    });
  });

  group('card width', () {
    testWidgets('every card is between 140 and 200 wide', (tester) async {
      await pumpCards(tester);

      for (final label in [
        _en.connectionLabel,
        _en.syncLabel,
        _en.backupLabel,
      ]) {
        final width = tester.getSize(card(label)).width;
        expect(width, inInclusiveRange(140, 200), reason: label);
      }
    });

    testWidgets('a longer Romanian label grows the card and shows in full', (
      tester,
    ) async {
      await pumpCards(tester, locale: const Locale('ro'));

      final label = _ro.backupLabel;
      expect(find.text(label), findsOneWidget);
      expect(isEllipsized(tester, label), isFalse);
      // The old fixed 140 cut this label off.
      expect(tester.getSize(card(label)).width, greaterThan(140));
      expect(tester.getSize(card(label)).width, lessThanOrEqualTo(200));
    });

    testWidgets('"Copie de rezervă" shows in full', (tester) async {
      const label = 'Copie de rezervă';
      await pumpCards(tester, l10n: const _LabelDelegate(backup: label));

      expect(isEllipsized(tester, label), isFalse);
      expect(tester.getSize(card(label)).width, inInclusiveRange(140, 200));
    });

    testWidgets('a label too long for 200 ends in an ellipsis', (
      tester,
    ) async {
      await pumpCards(
        tester,
        l10n: const _LabelDelegate(connection: _longLabel),
      );

      expect(isEllipsized(tester, _longLabel), isTrue);
      expect(tester.getSize(card(_longLabel)).width, 200);
      expect(tester.takeException(), isNull);
    });
  });
}
