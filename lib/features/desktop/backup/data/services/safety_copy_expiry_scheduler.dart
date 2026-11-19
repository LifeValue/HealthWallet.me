import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:health_wallet/core/services/attachment_files_lock.dart';
import 'package:health_wallet/core/utils/logger.dart';
import 'package:health_wallet/features/desktop/backup/data/services/backup_service.dart';
import 'package:injectable/injectable.dart';

/// Creates the timer for the next expiry: [Timer.new] in the app.
typedef ExpiryTimerFactory = Timer Function(
  Duration delay,
  void Function() onFire,
);

/// Deletes each "Before restore" safety copy at the moment it expires (its
/// timestamp plus `BackupService.getSafetyCopyRetentionDays`) while the
/// desktop app runs, so a copy doesn't outlive its retention in an app left
/// open in the tray.
///
/// Desktop only: `main_desktop.dart` calls [start], and quitting [dispose]s
/// it. Each check deletes every copy due at that moment, then sets one timer
/// to the earliest expiry left. A check runs on [start], when the timer
/// fires, and on every `BackupService.changes` (a backup or safety copy
/// written, a backup deleted, the folder or the retention changed), so a
/// shorter retention deletes the copies already older at once. A timer that
/// fires late, after the computer slept, still deletes all that is due.
///
/// Checks never overlap: one asked for while another runs follows it. The
/// deletes run holding [AttachmentFilesLock], so they wait for a restore
/// placing its files; the copy a restore uses is kept while [keepWhile]
/// runs. Scan files of a deleted copy are left to the start-up
/// `ScanFileSweeper`.
@lazySingleton
class SafetyCopyExpiryScheduler {
  SafetyCopyExpiryScheduler(
    this._backups,
    this._filesLock, {
    @ignoreParam DateTime Function()? clock,
    @ignoreParam ExpiryTimerFactory? createTimer,
  }) : _clock = clock ?? DateTime.now,
       _createTimer = createTimer ?? Timer.new;

  final BackupService _backups;
  final AttachmentFilesLock _filesLock;
  final DateTime Function() _clock;
  final ExpiryTimerFactory _createTimer;

  /// When the copies a check could not delete are tried again.
  static const retryDelay = Duration(hours: 1);

  final _expired = StreamController<int>.broadcast();

  /// The ids [keepWhile] protects, with how many callers hold each.
  final _inUse = <String, int>{};

  StreamSubscription<void>? _changes;
  Timer? _timer;
  DateTime? _nextCheck;
  bool _started = false;
  bool _disposed = false;
  Future<void>? _running;
  bool _again = false;

  /// How many copies a check deleted, each time it deleted some.
  Stream<int> get expired => _expired.stream;

  /// When the timer is set to fire; null without a timer.
  @visibleForTesting
  DateTime? get nextCheck => _nextCheck;

  /// Completes once no check runs or waits.
  @visibleForTesting
  Future<void> get idle async {
    for (var running = _running; running != null; running = _running) {
      await running;
    }
  }

  /// Deletes what expired while the app was closed and sets the timer.
  /// Later calls do nothing.
  Future<void> start() {
    if (_started || _disposed) return Future.value();
    _started = true;
    _changes = _backups.changes.listen((_) => unawaited(check()));
    return check();
  }

  /// Runs [work] keeping the backup [backupId] even past its expiry: the
  /// one a restore is using. A check follows, for a copy it kept.
  Future<T> keepWhile<T>(String backupId, Future<T> Function() work) async {
    _inUse.update(backupId, (n) => n + 1, ifAbsent: () => 1);
    try {
      return await work();
    } finally {
      final left = _inUse[backupId]! - 1;
      if (left == 0) {
        _inUse.remove(backupId);
      } else {
        _inUse[backupId] = left;
      }
      unawaited(check());
    }
  }

  /// Deletes every safety copy due now, then sets the timer to the next
  /// expiry. Does nothing before [start] or after [dispose].
  Future<void> check() {
    if (!_started || _disposed) return Future.value();
    final running = _running;
    if (running != null) {
      _again = true;
      return running;
    }
    final run = _run();
    _running = run;
    return run;
  }

  Future<void> _run() async {
    try {
      do {
        _again = false;
        final now = await _expireDue();
        await _arm(now);
      } while (_again && !_disposed);
    } catch (e, s) {
      logger.e('[Backup] the safety copy expiry check failed', e, s);
    } finally {
      _running = null;
    }
  }

  /// Deletes the copies due, holding the files lock, and returns the time
  /// they were due at.
  Future<DateTime> _expireDue() async {
    late DateTime now;
    final deleted = await _filesLock.exclusive(() {
      now = _clock();
      return _backups.deleteExpiredSafetyCopies(
        now: now,
        keep: _inUse.keys.toSet(),
      );
    });
    if (deleted > 0) {
      logger.i('[Backup] the expiry timer deleted $deleted safety copies');
      if (!_expired.isClosed) _expired.add(deleted);
    }
    return now;
  }

  /// Sets the timer to the earliest expiry after [now]. A copy still there
  /// although due at [now] could not be deleted, and is tried again after
  /// [retryDelay] at the latest.
  Future<void> _arm(DateTime now) async {
    _cancelTimer();
    final List<DateTime> expiries;
    try {
      expiries = await _backups.safetyCopyExpiries(keep: _inUse.keys.toSet());
    } catch (e, s) {
      logger.e(
        '[Backup] could not read the safety copies; no expiry timer',
        e,
        s,
      );
      return;
    }
    if (_disposed) return;
    _cancelTimer();

    DateTime? next;
    var failed = false;
    for (final expiry in expiries) {
      if (!expiry.isAfter(now)) {
        failed = true;
      } else if (next == null || expiry.isBefore(next)) {
        next = expiry;
      }
    }
    if (failed) {
      final retry = now.add(retryDelay);
      if (next == null || retry.isBefore(next)) next = retry;
    }
    if (next == null) {
      logger.i('[Backup] no safety copy to expire; no timer set');
      return;
    }

    var delay = next.difference(_clock());
    if (delay.isNegative) delay = Duration.zero;
    _nextCheck = next;
    logger.i(
      '[Backup] next safety copy expiry check at ${next.toIso8601String()}',
    );
    _timer = _createTimer(delay, _onTimer);
  }

  void _onTimer() {
    _timer = null;
    _nextCheck = null;
    logger.i('[Backup] the safety copy expiry timer fired');
    unawaited(check());
  }

  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
    _nextCheck = null;
  }

  /// Cancels the timer and stops listening; nothing is checked afterwards.
  @disposeMethod
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _cancelTimer();
    await _changes?.cancel();
    _changes = null;
    await _expired.close();
  }
}
