import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/l10n/app_strings_provider.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/features/desktop/communication/presentation/bloc/communication_bloc.dart';
import 'package:health_wallet/features/desktop/lww_sync/presentation/bloc/lww_sync_bloc.dart';
import 'package:health_wallet/features/desktop/tray/data/services/tray_service.dart';

void main() {
  final ro = lookupAppLocalizations(const Locale('ro'));

  List<String?> labels(TrayService tray) =>
      tray.buildMenuItems().map((item) => item.label).toList();

  test('the tray menu is in the app language', () async {
    final tray = TrayService(AppStringsProvider.forLocale(const Locale('ro')));
    await tray.updateMenu(
      connectionStatus: ConnectionStatus.connected,
      deviceName: 'iPhone',
      syncStatus: LwwSyncStatus.syncing,
    );

    expect(labels(tray), [
      'HealthWallet.me',
      null,
      ro.trayHideWindow,
      null,
      ro.desktopConnectedTo('iPhone'),
      ro.traySyncStatus(ro.desktopSyncing),
      null,
      ro.trayQuit('HealthWallet.me'),
    ]);
  });

  test('the tray menu follows a language change', () async {
    final strings = AppStringsProvider();
    final tray = TrayService(strings);
    await tray.updateMenu();
    expect(labels(tray), contains('No device connected'));

    strings.update(ro);

    expect(labels(tray), contains(ro.trayNoDeviceConnected));
    expect(labels(tray), contains(ro.traySyncStatus(ro.trayUpToDate)));
  });
}
