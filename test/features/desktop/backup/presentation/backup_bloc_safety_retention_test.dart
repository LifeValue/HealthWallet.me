import 'package:flutter/widgets.dart' hide ConnectionState;
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/config/app_platform.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/l10n/app_strings_provider.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/features/desktop/backup/data/services/backup_service.dart';
import 'package:health_wallet/features/desktop/backup/domain/entity/backup_entry.dart';
import 'package:health_wallet/features/desktop/backup/domain/utils/safety_copy_retention.dart';
import 'package:health_wallet/features/desktop/backup/presentation/bloc/backup_bloc.dart';

import '../../desktop_test_fakes.dart';

/// Keeps the retention in memory as the service stores it on this desktop.
class _RetentionBackupService extends Fake implements BackupService {
  /// What is stored; null when nothing is.
  int? stored;

  /// Reading or saving the setting throws.
  bool fails = false;

  final saved = <int>[];
  int cleanUps = 0;

  @override
  Future<void> cleanUpOnStartup() async => cleanUps++;

  @override
  Future<List<BackupEntry>> listBackups() async => const [];

  @override
  Future<String> getBackupPath() async => '/backups';

  @override
  Future<bool> hasUserSelectedPath() async => true;

  @override
  Future<int> getSafetyCopyRetentionDays() async {
    if (fails) throw StateError('preferences unavailable');
    return stored ?? SafetyCopyRetention.defaultDays;
  }

  @override
  Future<void> setSafetyCopyRetentionDays(int days) async {
    if (fails) throw StateError('preferences unavailable');
    if (!SafetyCopyRetention.isValid(days)) throw ArgumentError.value(days);
    saved.add(days);
    stored = days;
  }
}

void main() {
  late FakeTcpService tcp;
  late _RetentionBackupService service;
  late BackupBloc bloc;
  final l10n = lookupAppLocalizations(const Locale('en'));

  setUp(() {
    getIt.registerSingleton<AppPlatform>(AppPlatform.desktop);
    tcp = FakeTcpService();
    service = _RetentionBackupService();
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

  test('starts at 30 days', () {
    expect(bloc.state.safetyCopyRetentionDays, 30);
  });

  test('reads the stored value with the history', () async {
    service.stored = 7;

    bloc.add(const BackupHistoryLoaded());
    final loaded = await bloc.stream.firstWhere((s) => s.backupPath != null);

    expect(loaded.safetyCopyRetentionDays, 7);
    expect(service.cleanUps, 1);
  });

  test('reads 30 days when nothing is stored', () async {
    bloc.add(const BackupHistoryLoaded());
    final loaded = await bloc.stream.firstWhere((s) => s.backupPath != null);

    expect(loaded.safetyCopyRetentionDays, 30);
  });

  test('a value that cannot be read keeps the one shown and still loads the '
      'history', () async {
    service.fails = true;

    bloc.add(const BackupHistoryLoaded());
    final loaded = await bloc.stream.firstWhere((s) => s.backupPath != null);

    expect(loaded.safetyCopyRetentionDays, 30);
    expect(loaded.error, isNull);
  });

  test('saves a new value and shows it', () async {
    bloc.add(const SafetyCopyRetentionChanged(90));
    final changed = await bloc.stream.firstWhere(
      (s) => s.safetyCopyRetentionDays == 90,
    );

    expect(service.saved, [90]);
    expect(changed.error, isNull);
  });

  test('saves changes in the order they were made', () async {
    bloc
      ..add(const SafetyCopyRetentionChanged(10))
      ..add(const SafetyCopyRetentionChanged(5));
    await bloc.stream.firstWhere((s) => s.safetyCopyRetentionDays == 5);

    expect(service.saved, [10, 5]);
    expect(service.stored, 5);
  });

  test('a value the service refuses is not shown and says so', () async {
    bloc.add(const SafetyCopyRetentionChanged(366));
    final failed = await bloc.stream.firstWhere((s) => s.error != null);

    expect(failed.error, l10n.backupSafetyRetentionSaveFailed);
    expect(failed.safetyCopyRetentionDays, 30);
    expect(service.saved, isEmpty);
  });

  test('a save that fails keeps the value shown', () async {
    service.stored = 14;
    bloc.add(const BackupHistoryLoaded());
    await bloc.stream.firstWhere((s) => s.safetyCopyRetentionDays == 14);
    service.fails = true;

    bloc.add(const SafetyCopyRetentionChanged(3));
    final failed = await bloc.stream.firstWhere((s) => s.error != null);

    expect(failed.error, l10n.backupSafetyRetentionSaveFailed);
    expect(failed.safetyCopyRetentionDays, 14);
  });
}
