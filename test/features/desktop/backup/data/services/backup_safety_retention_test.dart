import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/config/constants/shared_prefs_constants.dart';
import 'package:health_wallet/features/desktop/backup/data/services/backup_service.dart';
import 'package:health_wallet/features/desktop/backup/domain/entity/backup_entry.dart';
import 'package:health_wallet/features/desktop/backup/domain/utils/safety_copy_retention.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'backup_test_support.dart';

void main() {
  final fx = BackupFixture();
  late BackupService service;

  setUp(() async {
    await fx.setUp();
    service = fx.service();
  });
  tearDown(fx.tearDown);

  Future<SharedPreferences> prefs() => SharedPreferences.getInstance();

  /// A backup made [age] ago (its metadata says so).
  Future<BackupEntry> backupMade(
    Duration age, {
    bool isSafetyCopy = true,
  }) async {
    final entry = await service.createSnapshot(isSafetyCopy: isSafetyCopy);
    final aged = entry.copyWith(timestamp: DateTime.now().subtract(age));
    await service.saveBackupMetadata(aged);
    return aged;
  }

  Future<Set<String>> listedIds() async =>
      (await service.listBackups()).map((e) => e.id).toSet();

  group('safetyCopyExpiry', () {
    test('counts calendar days and keeps the time of day, so a change to '
        'or from summer time in between does not move it', () {
      // Made in summer time, expiring after the autumn change (and the
      // other way round): the clock time stays the same wherever the test
      // runs.
      for (final made in [
        DateTime(2026, 10, 12, 17, 34, 5),
        DateTime(2026, 3, 10, 8, 15),
      ]) {
        final expiry = BackupService.safetyCopyExpiry(made, 30);
        final expected = DateTime(
          made.year,
          made.month,
          made.day + 30,
          made.hour,
          made.minute,
          made.second,
        );
        expect(
          (expiry.year, expiry.month, expiry.day, expiry.hour, expiry.minute),
          (
            expected.year,
            expected.month,
            expected.day,
            made.hour,
            made.minute,
          ),
        );
      }
    });

    test('rolls over month and year ends', () {
      expect(
        BackupService.safetyCopyExpiry(DateTime(2026, 12, 20, 9), 30),
        DateTime(2027, 1, 19, 9),
      );
    });

    test('a UTC time adds whole days', () {
      final made = DateTime.utc(2026, 10, 12, 14, 34);
      expect(
        BackupService.safetyCopyExpiry(made, 30),
        made.add(const Duration(days: 30)),
      );
    });
  });

  group('getSafetyCopyRetentionDays', () {
    test('is 30 days when nothing is stored', () async {
      expect(await service.getSafetyCopyRetentionDays(), 30);
      expect(SafetyCopyRetention.defaultDays, 30);
    });

    for (final days in [1, 7, 365]) {
      test('is the stored $days', () async {
        await (await prefs()).setInt(
          SharedPrefsConstants.safetyCopyRetentionDays,
          days,
        );

        expect(await service.getSafetyCopyRetentionDays(), days);
      });
    }

    for (final days in [0, -3, 366, 100000]) {
      test('falls back to 30 for the stored $days', () async {
        await (await prefs()).setInt(
          SharedPrefsConstants.safetyCopyRetentionDays,
          days,
        );

        expect(await service.getSafetyCopyRetentionDays(), 30);
      });
    }

    test('falls back to 30 for a value that is not a whole number', () async {
      await (await prefs()).setString(
        SharedPrefsConstants.safetyCopyRetentionDays,
        '7',
      );
      expect(await service.getSafetyCopyRetentionDays(), 30);

      await (await prefs()).setDouble(
        SharedPrefsConstants.safetyCopyRetentionDays,
        7.0,
      );
      expect(await service.getSafetyCopyRetentionDays(), 30);
    });
  });

  group('setSafetyCopyRetentionDays', () {
    test('stores the value on this desktop only', () async {
      await service.setSafetyCopyRetentionDays(90);

      expect(
        (await prefs()).getInt(SharedPrefsConstants.safetyCopyRetentionDays),
        90,
      );
      expect(await service.getSafetyCopyRetentionDays(), 90);
      // Nothing about it is written to the backup folder.
      expect(fx.backups.listSync(), isEmpty);
    });

    for (final days in [0, 366, -1]) {
      test('rejects $days and keeps the stored value', () async {
        await service.setSafetyCopyRetentionDays(14);

        await expectLater(
          service.setSafetyCopyRetentionDays(days),
          throwsArgumentError,
        );

        expect(await service.getSafetyCopyRetentionDays(), 14);
      });
    }

    test('deletes nothing when the value changes', () async {
      final old = await backupMade(const Duration(days: 20));

      await service.setSafetyCopyRetentionDays(1);

      expect(await listedIds(), {old.id});
      expect(File(old.filePath).existsSync(), isTrue);
    });
  });

  group('deleteExpiredSafetyCopies', () {
    test('expires existing safety copies by the stored value, counted from '
        'when each was made', () async {
      final day3 = await backupMade(const Duration(days: 3));
      final day8 = await backupMade(const Duration(days: 8));
      final day20 = await backupMade(const Duration(days: 20));
      final user = await backupMade(
        const Duration(days: 400),
        isSafetyCopy: false,
      );

      // Made while the default applied: none of them is 30 days old.
      expect(await service.deleteExpiredSafetyCopies(), 0);

      await service.setSafetyCopyRetentionDays(7);
      expect(await service.deleteExpiredSafetyCopies(), 2);

      expect(await listedIds(), {day3.id, user.id});
      expect(File(day8.filePath).existsSync(), isFalse);
      expect(File(day20.filePath).existsSync(), isFalse);
    });

    test(
      'a shorter value deletes the older copies at the next expiry run',
      () async {
        final day10 = await backupMade(const Duration(days: 10));
        final day2 = await backupMade(const Duration(days: 2));
        await service.setSafetyCopyRetentionDays(5);
        expect(await listedIds(), {day10.id, day2.id});

        await service.cleanUpOnStartup();

        expect(await listedIds(), {day2.id});
      },
    );

    test('a longer value keeps copies the default would delete', () async {
      final day40 = await backupMade(const Duration(days: 40));
      await service.setSafetyCopyRetentionDays(60);

      await service.cleanUpOnStartup();

      expect(await listedIds(), {day40.id});
    });

    test('uses 30 days when the stored value is invalid', () async {
      final day20 = await backupMade(const Duration(days: 20));
      final day31 = await backupMade(const Duration(days: 31));
      await (await prefs()).setInt(
        SharedPrefsConstants.safetyCopyRetentionDays,
        0,
      );

      expect(await service.deleteExpiredSafetyCopies(), 1);

      expect(await listedIds(), {day20.id});
      expect(File(day31.filePath).existsSync(), isFalse);
    });

    test('counts the retention back from the given time', () async {
      final copy = await service.createSnapshot(isSafetyCopy: true);
      await service.setSafetyCopyRetentionDays(3);
      final now = DateTime.now();

      expect(
        await service.deleteExpiredSafetyCopies(
          now: now.add(const Duration(days: 2)),
        ),
        0,
      );
      expect(
        await service.deleteExpiredSafetyCopies(
          now: now.add(const Duration(days: 4)),
        ),
        1,
      );
      expect(File(copy.filePath).existsSync(), isFalse);
    });

    test('a copy expires at the very moment its retention ends', () async {
      await service.setSafetyCopyRetentionDays(1);
      final copy = await backupMade(Duration.zero);
      final expiry = copy.timestamp.add(const Duration(days: 1));

      expect(
        await service.deleteExpiredSafetyCopies(
          now: expiry.subtract(const Duration(microseconds: 1)),
        ),
        0,
      );
      expect(await service.deleteExpiredSafetyCopies(now: expiry), 1);
      expect(File(copy.filePath).existsSync(), isFalse);
    });

    test('runs one at a time, so calls made together delete a copy '
        'once', () async {
      final old = await backupMade(const Duration(days: 40));

      final counts = await Future.wait([
        service.deleteExpiredSafetyCopies(),
        service.deleteExpiredSafetyCopies(),
        service.deleteExpiredSafetyCopies(),
      ]);

      expect(counts, [1, 0, 0]);
      expect(await listedIds(), isNot(contains(old.id)));
    });

    test('keeps the copy being restored even past the retention', () async {
      final old = await backupMade(const Duration(days: 10));
      await service.setSafetyCopyRetentionDays(1);

      expect(await service.deleteExpiredSafetyCopies(keep: {old.id}), 0);

      expect(await listedIds(), {old.id});
    });
  });

  group('safetyCopyExpiries', () {
    test('is when each safety copy expires, without user backups and the '
        'ids kept', () async {
      await service.setSafetyCopyRetentionDays(2);
      final a = await backupMade(const Duration(days: 1));
      final b = await backupMade(const Duration(hours: 1));
      await backupMade(const Duration(hours: 2), isSafetyCopy: false);

      expect(
        await service.safetyCopyExpiries(),
        unorderedEquals([
          a.timestamp.add(const Duration(days: 2)),
          b.timestamp.add(const Duration(days: 2)),
        ]),
      );
      expect(await service.safetyCopyExpiries(keep: {a.id}), [
        b.timestamp.add(const Duration(days: 2)),
      ]);
    });
  });

  group('changes', () {
    late List<int> fired;
    late StreamSubscription<void> sub;
    var count = 0;

    setUp(() {
      fired = [];
      count = 0;
      sub = service.changes.listen((_) => fired.add(++count));
    });
    tearDown(() => sub.cancel());

    Future<int> firedAfter(Future<void> Function() action) async {
      fired.clear();
      await action();
      await pumpEventQueue();
      return fired.length;
    }

    test('fires after a backup, a delete, a retention or folder change and '
        'an expiry that deleted a copy', () async {
      late BackupEntry entry;
      expect(
        await firedAfter(() async => entry = await service.createSnapshot()),
        greaterThan(0),
      );
      expect(await firedAfter(() => service.deleteBackup(entry.id)), 1);
      expect(
        await firedAfter(() => service.setSafetyCopyRetentionDays(3)),
        1,
      );
      expect(
        await firedAfter(() => service.setBackupDirectory(fx.backups.path)),
        1,
      );
      expect(await firedAfter(service.resetBackupDirectory), 1);
      await service.setBackupDirectory(fx.backups.path);

      await backupMade(const Duration(days: 4));
      expect(await firedAfter(service.deleteExpiredSafetyCopies), 1);
    });

    test('does not fire for an expiry that deleted nothing', () async {
      await backupMade(const Duration(days: 1));

      expect(await firedAfter(service.deleteExpiredSafetyCopies), 0);
    });
  });

  group('SafetyCopyRetention.parseDays', () {
    test('takes whole numbers from 1 to 365', () {
      expect(SafetyCopyRetention.parseDays('1'), 1);
      expect(SafetyCopyRetention.parseDays(' 30 '), 30);
      expect(SafetyCopyRetention.parseDays('365'), 365);
    });

    test('rejects numbers out of range and anything else', () {
      for (final input in [
        '0',
        '366',
        '-1',
        '+5',
        '7.5',
        '1e2',
        'abc',
        '',
        ' ',
        '99999999999999999999',
      ]) {
        expect(SafetyCopyRetention.parseDays(input), isNull, reason: input);
      }
    });
  });
}
