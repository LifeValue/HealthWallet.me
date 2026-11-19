import 'dart:async';
import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/services/attachment_files_lock.dart';
import 'package:health_wallet/features/desktop/backup/data/services/backup_service.dart';
import 'package:health_wallet/features/desktop/backup/data/services/safety_copy_expiry_scheduler.dart';
import 'package:health_wallet/features/desktop/backup/domain/entity/backup_entry.dart';
import 'package:logger/logger.dart';

import '../../../../../helpers/log_capture.dart';
import 'backup_test_support.dart';

/// The timer runs on [FakeAsync] time and the clock reads it, so a test moves
/// time by hand. The backups are real files in a temporary folder; their
/// I/O completes on the real event loop, which [settle] waits for.
void main() {
  final logs = captureLogs();
  final fx = BackupFixture();
  late BackupService service;
  late AttachmentFilesLock lock;
  late FakeAsync time;
  late SafetyCopyExpiryScheduler scheduler;

  /// The fake "now" when the test starts: the real time, to the second, so
  /// the backups `createSnapshot` stamps with the real time are near it.
  late DateTime t0;

  /// How far the wall clock ran ahead of the timers, as while the computer
  /// sleeps.
  var slept = Duration.zero;

  DateTime now() => t0.add(time.elapsed).add(slept);

  setUp(() async {
    await fx.setUp();
    service = fx.service();
    lock = AttachmentFilesLock();
    time = FakeAsync();
    slept = Duration.zero;
    final real = DateTime.now();
    t0 = DateTime(
      real.year,
      real.month,
      real.day,
      real.hour,
      real.minute,
      real.second,
    );
    final testZone = Zone.current;
    scheduler = SafetyCopyExpiryScheduler(
      service,
      lock,
      clock: now,
      // A fake timer whose callback runs in the test's zone, where the real
      // file I/O it starts can complete.
      createTimer: (delay, onFire) =>
          time.run((_) => Timer(delay, () => testZone.run(onFire))),
    );
  });

  tearDown(() async {
    await scheduler.dispose();
    await fx.tearDown();
  });

  /// Lets queued change events reach the scheduler, then waits for its
  /// check to finish.
  Future<void> settle() async {
    await pumpEventQueue();
    await scheduler.idle;
  }

  /// Moves fake time on by [step] (firing a timer that falls due) and
  /// settles.
  Future<void> elapse(Duration step) async {
    time.elapse(step);
    await settle();
  }

  /// A safety copy whose metadata says it was made at [at].
  Future<BackupEntry> copyMadeAt(
    DateTime at, {
    bool isSafetyCopy = true,
  }) async {
    final entry = await service.createSnapshot(isSafetyCopy: isSafetyCopy);
    final dated = entry.copyWith(timestamp: at);
    await service.saveBackupMetadata(dated);
    return dated;
  }

  bool exists(BackupEntry entry) => File(entry.filePath).existsSync();

  Future<Set<String>> listedIds() async =>
      (await service.listBackups()).map((e) => e.id).toSet();

  Matcher loggedInfo(String message) => contains(
    isA<LogEvent>().having(
      (e) => '${e.message}',
      'message',
      contains(message),
    ),
  );

  test('deletes a copy exactly when it expires', () async {
    await service.setSafetyCopyRetentionDays(1);
    final copy = await copyMadeAt(t0);

    await scheduler.start();
    await settle();
    expect(scheduler.nextCheck, t0.add(const Duration(days: 1)));

    await elapse(const Duration(days: 1) - const Duration(seconds: 1));
    expect(exists(copy), isTrue);
    expect(await listedIds(), {copy.id});

    await elapse(const Duration(seconds: 1));
    expect(exists(copy), isFalse);
    expect(await listedIds(), isEmpty);
    expect(time.pendingTimers, isEmpty);
    expect(scheduler.nextCheck, isNull);
    expect(logs, loggedInfo('next safety copy expiry check at'));
    expect(logs, loggedInfo('deleted the expired safety copy ${copy.id}'));
  });

  test('with two copies, deletes the second one at its own time', () async {
    await service.setSafetyCopyRetentionDays(1);
    final first = await copyMadeAt(t0);
    final second = await copyMadeAt(t0.add(const Duration(hours: 5)));
    await scheduler.start();
    await settle();

    await elapse(const Duration(days: 1));
    expect(exists(first), isFalse);
    expect(exists(second), isTrue);
    expect(scheduler.nextCheck, t0.add(const Duration(days: 1, hours: 5)));

    await elapse(const Duration(hours: 5) - const Duration(seconds: 1));
    expect(exists(second), isTrue);

    await elapse(const Duration(seconds: 1));
    expect(exists(second), isFalse);
    expect(time.pendingTimers, isEmpty);
  });

  test('a shorter retention deletes the older copies at once; a longer one '
      'deletes nothing and moves the timer later', () async {
    final day10 = await copyMadeAt(t0.subtract(const Duration(days: 10)));
    final day2 = await copyMadeAt(t0.subtract(const Duration(days: 2)));
    await scheduler.start();
    await settle();
    expect(scheduler.nextCheck, t0.add(const Duration(days: 20)));

    await service.setSafetyCopyRetentionDays(5);
    await settle();

    // No time passed.
    expect(time.elapsed, Duration.zero);
    expect(exists(day10), isFalse);
    expect(exists(day2), isTrue);
    expect(scheduler.nextCheck, t0.add(const Duration(days: 3)));

    await service.setSafetyCopyRetentionDays(60);
    await settle();

    expect(exists(day2), isTrue);
    expect(await listedIds(), {day2.id});
    expect(scheduler.nextCheck, t0.add(const Duration(days: 58)));
    expect(time.pendingTimers, hasLength(1));
  });

  test('the safety copy a restore makes sets the timer', () async {
    final backup = await copyMadeAt(t0, isSafetyCopy: false);
    await scheduler.start();
    await settle();
    expect(time.pendingTimers, isEmpty);

    // What the backup bloc does: keep the backup, save the safety copy,
    // restore.
    late BackupEntry safety;
    await scheduler.keepWhile(backup.id, () async {
      safety = await service.createSnapshot(
        isSafetyCopy: true,
        keepId: backup.id,
      );
      await service.restoreFromFile(backup.filePath);
    });
    await settle();

    final expiry = safety.timestamp.add(const Duration(days: 30));
    expect(scheduler.nextCheck, expiry);
    expect(time.pendingTimers, hasLength(1));

    await elapse(expiry.difference(now()));
    expect(exists(safety), isFalse);
    expect(exists(backup), isTrue);
  });

  test('a backup deleted or a folder changed sets the timer again', () async {
    await service.setSafetyCopyRetentionDays(1);
    final first = await copyMadeAt(t0);
    final second = await copyMadeAt(t0.add(const Duration(hours: 2)));
    await scheduler.start();
    await settle();

    await service.deleteBackup(first.id);
    await settle();
    expect(scheduler.nextCheck, t0.add(const Duration(days: 1, hours: 2)));

    await service.setBackupDirectory(fx.docs.path);
    await settle();
    expect(scheduler.nextCheck, isNull);
    expect(time.pendingTimers, isEmpty);
    expect(exists(second), isTrue);
  });

  test('at start-up, deletes a copy that expired while the app was '
      'closed', () async {
    final expired = await copyMadeAt(t0.subtract(const Duration(days: 31)));
    final kept = await copyMadeAt(t0.subtract(const Duration(days: 1)));

    await scheduler.start();
    await settle();

    expect(exists(expired), isFalse);
    expect(exists(kept), isTrue);
    expect(scheduler.nextCheck, t0.add(const Duration(days: 29)));
  });

  test(
    'a timer that fires late, after a sleep, deletes everything due',
    () async {
      await service.setSafetyCopyRetentionDays(1);
      final first = await copyMadeAt(t0);
      final second = await copyMadeAt(t0.add(const Duration(hours: 3)));
      final later = await copyMadeAt(t0.add(const Duration(days: 10)));
      await scheduler.start();
      await settle();
      expect(scheduler.nextCheck, t0.add(const Duration(days: 1)));

      // The computer sleeps two days: the wall clock moves on, the timer
      // doesn't, so it fires two days late.
      slept = const Duration(days: 2);
      await elapse(const Duration(days: 1));

      expect(exists(first), isFalse);
      expect(exists(second), isFalse);
      expect(exists(later), isTrue);
      expect(scheduler.nextCheck, t0.add(const Duration(days: 11)));
    },
  );

  test('keeps the copy a restore uses until the restore is over', () async {
    await service.setSafetyCopyRetentionDays(1);
    final copy = await copyMadeAt(t0);
    await scheduler.start();
    await settle();

    await scheduler.keepWhile(copy.id, () async {
      await elapse(const Duration(days: 2));
      expect(exists(copy), isTrue);
      // Kept, so the timer isn't set to it again.
      expect(scheduler.nextCheck, isNull);
      expect(time.pendingTimers, isEmpty);
    });
    await settle();

    expect(exists(copy), isFalse);
  });

  test('waits for a restore holding the attachment files lock', () async {
    await service.setSafetyCopyRetentionDays(1);
    final copy = await copyMadeAt(t0);
    await scheduler.start();
    await settle();

    final release = Completer<void>();
    final restore = lock.exclusive(() => release.future);
    time.elapse(const Duration(days: 1));
    await pumpEventQueue();
    expect(exists(copy), isTrue);

    release.complete();
    await restore;
    await settle();
    expect(exists(copy), isFalse);
  });

  test('checks never overlap: changes during a check run one more', () async {
    await service.setSafetyCopyRetentionDays(1);
    final copy = await copyMadeAt(t0);
    await scheduler.start();
    await settle();

    final release = Completer<void>();
    final held = lock.exclusive(() => release.future);
    time.elapse(const Duration(days: 1));
    final second = scheduler.check();
    final third = scheduler.check();
    release.complete();
    await held;
    await Future.wait([second, third]);
    await settle();

    expect(exists(copy), isFalse);
    expect(
      logs.where((e) => '${e.message}'.contains('timer deleted')),
      hasLength(1),
    );
    expect(logs, isNot(loggedWarning('could not delete safety copy')));
  });

  test('dispose cancels the timer and stops listening', () async {
    await service.setSafetyCopyRetentionDays(1);
    final copy = await copyMadeAt(t0);
    await scheduler.start();
    await settle();
    expect(time.pendingTimers, hasLength(1));

    await scheduler.dispose();

    expect(time.pendingTimers, isEmpty);
    expect(scheduler.nextCheck, isNull);
    await elapse(const Duration(days: 2));
    await service.setSafetyCopyRetentionDays(2);
    await settle();
    expect(exists(copy), isTrue);
    expect(time.pendingTimers, isEmpty);
  });

  test('sets no timer without safety copies', () async {
    await copyMadeAt(t0, isSafetyCopy: false);

    await scheduler.start();
    await settle();

    expect(time.pendingTimers, isEmpty);
    expect(scheduler.nextCheck, isNull);
    expect(logs, loggedInfo('no safety copy to expire'));
  });

  test('does nothing before it is started', () async {
    await service.setSafetyCopyRetentionDays(1);
    final copy = await copyMadeAt(t0.subtract(const Duration(days: 3)));

    await scheduler.check();
    await settle();

    expect(exists(copy), isTrue);
    expect(time.pendingTimers, isEmpty);
  });

  test('a copy that could not be deleted is tried again an hour later, not '
      'in a loop', () async {
    await service.setSafetyCopyRetentionDays(1);
    final copy = await copyMadeAt(t0.subtract(const Duration(days: 3)));
    final failing = fx.failingExpiryService();
    final testZone = Zone.current;
    final retrying = SafetyCopyExpiryScheduler(
      failing,
      lock,
      clock: now,
      createTimer: (delay, onFire) =>
          time.run((_) => Timer(delay, () => testZone.run(onFire))),
    );
    addTearDown(retrying.dispose);

    await retrying.start();
    await pumpEventQueue();
    await retrying.idle;

    expect(exists(copy), isTrue);
    expect(retrying.nextCheck, t0.add(SafetyCopyExpiryScheduler.retryDelay));
    expect(time.pendingTimers, hasLength(1));

    failing.failDeletes = false;
    time.elapse(SafetyCopyExpiryScheduler.retryDelay);
    await pumpEventQueue();
    await retrying.idle;
    expect(exists(copy), isFalse);
  });

  test('an unreadable folder sets no timer and is logged', () async {
    final plain = File('${fx.root.path}/plain')..writeAsStringSync('x');
    await service.setBackupDirectory('${plain.path}/backups');

    await scheduler.start();
    await settle();

    expect(time.pendingTimers, isEmpty);
    expect(logs, loggedWarning('could not read the safety copies'));
  });
}
