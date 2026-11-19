import 'package:flutter/widgets.dart' hide ConnectionState;
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/config/app_platform.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/l10n/app_strings_provider.dart';
import 'package:health_wallet/features/desktop/backup/data/services/backup_service.dart';
import 'package:health_wallet/features/desktop/backup/domain/entity/backup_entry.dart';
import 'package:health_wallet/features/desktop/backup/presentation/bloc/backup_bloc.dart';
import 'package:health_wallet/features/processing/domain/entity/processing_session.dart';

import '../../desktop_test_fakes.dart';
import '../data/services/backup_test_support.dart';

/// Counts [unsaved] scans, or throws when it is null.
class _CountingBackupService extends Fake implements BackupService {
  int? unsaved;

  @override
  Future<int> countUnsavedScans() async =>
      unsaved ?? (throw StateError('database closed'));
}

final _backup = BackupEntry(
  id: 'b1',
  timestamp: DateTime(2026, 10, 28),
  sizeBytes: 1,
  recordCount: 1,
  checksum: 'abc',
  filePath: '/tmp/b1.db',
);

void main() {
  group('BackupService.countUnsavedScans', () {
    final fx = BackupFixture();

    setUp(fx.setUp);
    tearDown(fx.tearDown);

    Future<void> insertSession(String id, ProcessingStatus status) =>
        fx.db.customStatement(
          'INSERT INTO processing_sessions (id, file_paths, status) '
          'VALUES (?, ?, ?)',
          [id, '[]', status.toString()],
        );

    test('is 0 with no scan', () async {
      expect(await fx.service().countUnsavedScans(), 0);
    });

    test(
      'counts every scan, whatever its status: a saved one is gone',
      () async {
        await insertSession('s1', ProcessingStatus.draft);
        await insertSession('s2', ProcessingStatus.pending);
        await insertSession('s3', ProcessingStatus.cancelled);

        expect(await fx.service().countUnsavedScans(), 3);
      },
    );
  });

  group('selecting a backup on the desktop', () {
    late FakeTcpService tcp;
    late _CountingBackupService service;
    late BackupBloc bloc;

    setUp(() {
      getIt.registerSingleton<AppPlatform>(AppPlatform.desktop);
      tcp = FakeTcpService();
      service = _CountingBackupService();
      bloc = BackupBloc(
        service,
        tcp,
        AppStringsProvider.forLocale(const Locale('en')),
      );
    });

    tearDown(() async {
      await bloc.close();
      await tcp.close();
      await getIt.unregister<AppPlatform>();
    });

    test('counts the scans its restore would remove', () async {
      service.unsaved = 2;

      bloc.add(BackupSelected(_backup));
      final counted = await bloc.stream.firstWhere(
        (s) => s.unsavedScanCount == 2,
      );

      expect(counted.selectedBackup, _backup);
    });

    test('with none waiting, the count is 0', () async {
      service.unsaved = 0;

      bloc.add(BackupSelected(_backup));
      await bloc.stream.firstWhere((s) => s.selectedBackup == _backup);
      await pumpEventQueue();

      expect(bloc.state.unsavedScanCount, 0);
    });

    test('a count that fails leaves the line out', () async {
      service.unsaved = 2;
      bloc.add(BackupSelected(_backup));
      await bloc.stream.firstWhere((s) => s.unsavedScanCount == 2);
      service.unsaved = null;

      bloc.add(const BackupSelected(null));
      bloc.add(BackupSelected(_backup));
      await bloc.stream.firstWhere(
        (s) => s.selectedBackup == _backup && s.unsavedScanCount == 0,
      );
    });
  });
}
