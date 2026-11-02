import 'package:flutter/widgets.dart' hide ConnectionState;
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/config/app_platform.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/l10n/app_strings_provider.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/features/desktop/backup/data/services/backup_service.dart';
import 'package:health_wallet/features/desktop/backup/presentation/bloc/backup_bloc.dart';
import 'package:health_wallet/features/desktop/communication/data/services/tcp_service.dart';

import '../../desktop_test_fakes.dart';

class _UnusedBackupService extends Fake implements BackupService {}

void main() {
  final ro = lookupAppLocalizations(const Locale('ro'));
  late FakeTcpService tcp;
  late BackupBloc bloc;

  BackupBloc buildBloc(AppPlatform platform) {
    getIt.registerSingleton<AppPlatform>(platform);
    return BackupBloc(
      _UnusedBackupService(),
      tcp,
      AppStringsProvider.forLocale(const Locale('ro')),
    );
  }

  setUp(() => tcp = FakeTcpService());

  tearDown(() async {
    await bloc.close();
    await tcp.close();
    await getIt.unregister<AppPlatform>();
  });

  group('on the phone, a desktop backup error', () {
    setUp(() => bloc = buildBloc(AppPlatform.mobile));

    Future<String?> errorFor(Map<String, dynamic> payload) async {
      tcp.deliver('backup.error', payload);
      await bloc.stream.firstWhere((s) => s.error != null);
      return bloc.state.error;
    }

    test('with the no-location code is shown in the app language', () async {
      expect(
        await errorFor({'code': BackupBloc.noBackupLocationCode}),
        ro.desktopNoBackupLocation,
      );
    });

    test('from a desktop without the code is the no-location case', () async {
      expect(
        await errorFor({'error': 'No backup location set on desktop.'}),
        ro.desktopNoBackupLocation,
      );
    });

    test('with an unknown code is a generic backup failure', () async {
      expect(await errorFor({'code': 'disk_full'}), ro.desktopBackupFailed);
    });
  });

  group('on the phone, the desktop\'s backup folder', () {
    setUp(() => bloc = buildBloc(AppPlatform.mobile));

    test('is unknown until the desktop reports it', () async {
      expect(bloc.state.desktopBackupReady, isNull);

      tcp.deliver('backup.status', {'ready': false, 'count': 0});
      await bloc.stream.firstWhere((s) => s.desktopBackupReady != null);
      expect(bloc.state.desktopBackupReady, isFalse);
    });

    test(
      'is unknown again, and no backup is running, once the link drops',
      () async {
        tcp.deliver('backup.status', {'ready': true, 'count': 1});
        await bloc.stream.firstWhere((s) => s.desktopBackupReady == true);
        tcp.deliver('backup.status', {'ready': true, 'backing_up': true});
        await bloc.stream.firstWhere((s) => s.isBackingUp);

        tcp.emitState(ConnectionState.disconnected);
        await bloc.stream.firstWhere((s) => !s.isBackingUp);
        expect(bloc.state.desktopBackupReady, isNull);
      },
    );
  });

  test(
    'the desktop answers a backup request without a folder with the code',
    () async {
      bloc = buildBloc(AppPlatform.desktop);

      tcp.deliver('backup.request', {});
      await pumpEventQueue();

      final sent = tcp.sentOf('backup.error').single;
      expect(sent['code'], BackupBloc.noBackupLocationCode);
      // Phones from before the code show this text.
      expect(sent['error'], startsWith('No backup location set on desktop.'));
    },
  );
}
