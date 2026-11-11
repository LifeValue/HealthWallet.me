import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:health_wallet/core/config/app_platform.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/l10n/app_strings_provider.dart';
import 'package:health_wallet/core/utils/logger.dart';
import 'package:health_wallet/features/desktop/backup/data/services/backup_service.dart';
import 'package:health_wallet/features/desktop/backup/domain/entity/backup_entry.dart';
import 'package:health_wallet/features/desktop/backup/domain/entity/restore_result.dart';
import 'package:health_wallet/features/desktop/backup/domain/utils/backup_name_date.dart';
import 'package:health_wallet/features/desktop/backup/domain/utils/safety_copy_retention.dart';
import 'package:health_wallet/features/desktop/communication/data/services/tcp_service.dart';
import 'package:health_wallet/features/desktop/lww_sync/presentation/bloc/lww_sync_bloc.dart';
import 'package:health_wallet/features/home/presentation/bloc/home_bloc.dart';
import 'package:injectable/injectable.dart';

part 'backup_bloc.freezed.dart';
part 'backup_event.dart';
part 'backup_state.dart';

@lazySingleton
class BackupBloc extends Bloc<BackupEvent, BackupState> {
  final BackupService _backupService;
  final TcpService _tcpService;
  final AppStringsProvider _strings;

  StreamSubscription? _messageSub;
  StreamSubscription? _linkSub;
  static const _chunkSize = 64 * 1024;

  /// `backup.error` code sent when the desktop has no backup folder. Desktops
  /// from before the code send only the English `error` text, for this case.
  static const noBackupLocationCode = 'no_backup_location';

  /// `backup.error` code sent when the backup the phone asked for failed.
  static const backupFailedCode = 'backup_failed';

  /// `backup.error` code sent when the phone asks while a restore runs.
  static const restoreInProgressCode = 'restore_in_progress';

  /// Whether the start-up housekeeping already ran.
  bool _cleanedUp = false;

  BackupBloc(this._backupService, this._tcpService, this._strings)
    : super(BackupState.initial()) {
    on<BackupRequested>(_onBackupRequested, transformer: droppable());
    on<RestoreRequested>(_onRestoreRequested, transformer: droppable());
    on<BackupHistoryLoaded>(_onHistoryLoaded);
    on<BackupSelected>(_onBackupSelected, transformer: restartable());
    on<BackupDeleted>(_onBackupDeleted);
    on<BackupLocationChanged>(_onLocationChanged);
    on<BackupLocationReset>(_onLocationReset);
    on<SafetyCopyRetentionChanged>(
      _onSafetyCopyRetentionChanged,
      transformer: sequential(),
    );
    on<RemoteBackupRequested>(_onRemoteBackupRequested);
    on<PhoneBackupRequested>(_onPhoneBackupRequested);
    on<RemoteBackupStatusChanged>(_onRemoteBackupStatusChanged);
    on<RemoteBackupStatusReceived>(_onRemoteBackupStatusReceived);
    on<RemoteLinkLost>(_onRemoteLinkLost);

    _listenForMessages();
  }

  void _listenForMessages() {
    final isMobile = getIt<AppPlatform>().isMobile;

    if (isMobile) {
      _linkSub = _tcpService.connectionState
          .where((s) => s == ConnectionState.disconnected)
          .listen((_) => add(const RemoteLinkLost()));
    }

    _messageSub = _tcpService.messages.listen((message) {
      if (message.type != MessageType.data) return;
      try {
        final decoded =
            jsonDecode(message.payloadString) as Map<String, dynamic>;
        final type = decoded['type'] as String?;
        final payload = decoded['payload'] as Map<String, dynamic>? ?? {};

        if (!isMobile && type == 'backup.request') {
          add(const RemoteBackupRequested());
        }

        if (isMobile && type == 'backup.status') {
          debugPrint('[Backup] Received status from desktop: $payload');
          final backingUp = payload['backing_up'] as bool? ?? false;
          if (backingUp) {
            add(const RemoteBackupStatusChanged(isBackingUp: true));
          } else {
            add(
              RemoteBackupStatusReceived(
                ready: payload['ready'] as bool? ?? false,
                count: payload['count'] as int? ?? 0,
                lastBackupTime: payload['last_backup'] != null
                    ? DateTime.tryParse(payload['last_backup'] as String)
                    : null,
              ),
            );
          }
        }

        if (isMobile && type == 'backup.error') {
          add(
            RemoteBackupStatusChanged(
              isBackingUp: false,
              error: _remoteErrorMessage(payload['code'] as String?),
            ),
          );
        }

        if (isMobile && type == 'backup.complete') {
          add(
            RemoteBackupStatusReceived(
              ready: true,
              count: payload['count'] as int? ?? 0,
              lastBackupTime: payload['last_backup'] != null
                  ? DateTime.tryParse(payload['last_backup'] as String)
                  : null,
            ),
          );
        }
      } catch (e) {
        logger.w('[Backup] ignored an unreadable message', e);
      }
    });
  }

  void sendBackupStatus() {
    if (getIt<AppPlatform>().isMobile) return;
    if (!_tcpService.isConnected) return;

    debugPrint(
      '[Backup] Sending status: ready=${state.hasUserSelectedPath}, count=${state.backupHistory.length}',
    );
    _sendQuietly('backup.status', {
      'ready': state.hasUserSelectedPath,
      'count': state.backupHistory.length,
      if (state.backupHistory.isNotEmpty)
        'last_backup': state.backupHistory.first.timestamp.toIso8601String(),
    });
  }

  Future<void> _onBackupRequested(
    BackupRequested event,
    Emitter<BackupState> emit,
  ) async {
    if (state.isRestoring) {
      logger.w('[Backup] not backing up while a restore runs');
      if (event.fromPhone) _sendRestoreInProgress();
      return;
    }
    emit(
      state.copyWith(
        isBackingUp: true,
        progress: 0.0,
        error: null,
        restoreNotice: null,
      ),
    );

    try {
      final entry = await _backupService.createSnapshot(name: event.name);

      emit(state.copyWith(progress: 0.3));

      await _streamBackupToMobile(entry, emit);

      final history = await _backupService.listBackups();
      emit(
        state.copyWith(
          isBackingUp: false,
          progress: 1.0,
          backupHistory: history,
        ),
      );

      debugPrint('[Backup] Backup complete, sending status to mobile');
      sendBackupStatus();
    } catch (e) {
      emit(
        state.copyWith(
          isBackingUp: false,
          progress: 0.0,
          error: _failed(e, _strings.l10n.desktopBackupFailed),
        ),
      );
      if (event.fromPhone) {
        _sendQuietly('backup.error', {
          'code': backupFailedCode,
          // Shown by phones from before the code.
          'error': 'The backup failed on the desktop. Please try again.',
        });
      }
    }
  }

  Future<void> _streamBackupToMobile(
    BackupEntry entry,
    Emitter<BackupState> emit,
  ) async {
    if (!_tcpService.isConnected) return;

    final file = File(entry.filePath);
    final fileBytes = await file.readAsBytes();
    final totalChunks = (fileBytes.length / _chunkSize).ceil();

    await _tcpService.sendData('backup_start', {
      'id': entry.id,
      'timestamp': entry.timestamp.toIso8601String(),
      'sizeBytes': entry.sizeBytes,
      'recordCount': entry.recordCount,
      'checksum': entry.checksum,
      'totalChunks': totalChunks,
    });

    for (var i = 0; i < totalChunks; i++) {
      final start = i * _chunkSize;
      final end = (start + _chunkSize).clamp(0, fileBytes.length);
      final chunk = fileBytes.sublist(start, end);

      await _tcpService.sendData('backup_chunk', {
        'index': i,
        'data': base64Encode(chunk),
      });

      final progress = 0.3 + (0.7 * (i + 1) / totalChunks);
      emit(state.copyWith(progress: progress));
    }

    await _tcpService.sendData('backup_complete', {
      'id': entry.id,
      'checksum': entry.checksum,
    });
  }

  /// Makes the backup the current state on this desktop and the phone:
  /// first the phone's latest changes are synced, then received changes are
  /// held, a "Before restore" safety copy is made (the undo) and the backup
  /// restored; the phone then gets the restored rows. Nothing is restored
  /// without the safety copy.
  Future<void> _onRestoreRequested(
    RestoreRequested event,
    Emitter<BackupState> emit,
  ) async {
    if (state.isRestoring || state.isBackingUp) {
      logger.w('[Backup] restore ignored: a backup or restore is running');
      return;
    }
    emit(
      state.copyWith(
        isRestoring: true,
        progress: 0.0,
        error: null,
        restoreNotice: null,
      ),
    );

    final BackupEntry target;
    try {
      final backups = await _backupService.listBackups();
      target = backups.firstWhere(
        (b) => b.id == event.backupId,
        orElse: () => throw StateError('Backup not found: ${event.backupId}'),
      );
    } catch (e) {
      emit(
        state.copyWith(
          isRestoring: false,
          progress: 0.0,
          error: _failed(e, _strings.l10n.desktopBackupActionFailed),
        ),
      );
      return;
    }

    final sync = getIt<LwwSyncBloc>();
    var phoneOffline = false;
    if (sync.state.connected) {
      emit(state.copyWith(progress: 0.1));
      // The phone's latest changes go into the safety copy and the current
      // data. A false result was logged by the sync bloc.
      try {
        phoneOffline = !await sync.syncAndConfirmMatch();
      } catch (e) {
        logger.e(
          '[Backup] syncing with the phone before the restore failed',
          e,
        );
        phoneOffline = true;
      }
    }

    try {
      // Paused only after the sync: a paused desktop can't take the phone's
      // rows, so the tables would never match. Waits for a batch being
      // applied, so the safety copy holds it.
      await sync.pauseApplying();
      emit(state.copyWith(progress: 0.3));
      try {
        await _backupService.createSnapshot(
          name: _strings.l10n.backupSafetyName(
            backupNameDate(
              DateTime.now(),
              _strings.l10n.localeName,
              withTime: true,
            ),
          ),
          isSafetyCopy: true,
          // The backup being restored may be an expired safety copy itself.
          keepId: target.id,
        );
      } catch (e) {
        emit(
          state.copyWith(
            isRestoring: false,
            progress: 0.0,
            error: _failed(e, _strings.l10n.backupSafetyFailed),
          ),
        );
        return;
      }

      emit(state.copyWith(progress: 0.5));
      final RestoreResult result;
      try {
        result = await _backupService.restoreFromFile(target.filePath);
      } catch (e) {
        // The restore didn't commit; the safety copy stays in the list.
        final error = _failed(e, _strings.l10n.backupRestoreFailed);
        emit(
          state.copyWith(
            isRestoring: false,
            progress: 0.0,
            backupHistory: await _historyOrCurrent(),
            error: error,
          ),
        );
        return;
      }

      // Committed: whatever fails from here on is only logged.
      _afterRestore(sync);
      final notices = [
        if (phoneOffline) _strings.l10n.backupRestorePhoneOffline,
        if (result.filesNotRestored > 0)
          _strings.l10n.backupFilesNotRestored(result.filesNotRestored),
      ];
      emit(
        state.copyWith(
          isRestoring: false,
          progress: 1.0,
          backupHistory: await _historyOrCurrent(),
          restoreNotice: notices.isEmpty ? null : notices.join('\n\n'),
          // The restore replaced the scans with the backup's.
          unsavedScanCount: await _unsavedScanCount(),
        ),
      );
      sendBackupStatus();
    } finally {
      // Without it, sync stays held until the app restarts.
      sync.resumeApplying();
    }
  }

  /// Sends the restored rows to the phone (its outbox was filled by the
  /// restore; the digest on every connect covers an offline phone) and
  /// reloads the records.
  void _afterRestore(LwwSyncBloc sync) {
    try {
      sync.add(const LwwSyncEvent.localChanged());
    } catch (e) {
      logger.e('[Backup] could not tell sync about the restore', e);
    }
    try {
      getIt<HomeBloc>().add(const HomeInitialised());
    } catch (e) {
      logger.w('[Backup] could not reload the records after the restore', e);
    }
  }

  /// The backups in the folder, or the ones already shown when listing
  /// fails (logged).
  Future<List<BackupEntry>> _historyOrCurrent() async {
    try {
      return await _backupService.listBackups();
    } catch (e) {
      logger.e('[Backup] could not list the backups', e);
      return state.backupHistory;
    }
  }

  Future<void> _onHistoryLoaded(
    BackupHistoryLoaded event,
    Emitter<BackupState> emit,
  ) async {
    // Before the first listing, so expired safety copies aren't shown.
    if (!_cleanedUp && getIt<AppPlatform>().isDesktop) {
      _cleanedUp = true;
      await _backupService.cleanUpOnStartup();
    }
    try {
      final history = await _backupService.listBackups();
      final path = await _backupService.getBackupPath();
      final hasUserPath = await _backupService.hasUserSelectedPath();
      emit(
        state.copyWith(
          backupHistory: history,
          backupPath: path,
          hasUserSelectedPath: hasUserPath,
          safetyCopyRetentionDays: await _safetyCopyRetentionDays(),
          error: null,
        ),
      );

      sendBackupStatus();
    } catch (e) {
      emit(
        state.copyWith(
          error: _failed(e, _strings.l10n.desktopBackupActionFailed),
        ),
      );
    }
  }

  /// The stored safety copy retention, or the one shown when it can't be
  /// read (logged).
  Future<int> _safetyCopyRetentionDays() async {
    try {
      return await _backupService.getSafetyCopyRetentionDays();
    } catch (e) {
      logger.w('[Backup] could not read the safety copy retention', e);
      return state.safetyCopyRetentionDays;
    }
  }

  /// Saves the retention; the expired copies go at the next start-up.
  Future<void> _onSafetyCopyRetentionChanged(
    SafetyCopyRetentionChanged event,
    Emitter<BackupState> emit,
  ) async {
    try {
      await _backupService.setSafetyCopyRetentionDays(event.days);
      emit(state.copyWith(safetyCopyRetentionDays: event.days, error: null));
    } catch (e) {
      emit(
        state.copyWith(
          error: _failed(e, _strings.l10n.backupSafetyRetentionSaveFailed),
        ),
      );
    }
  }

  Future<void> _onBackupSelected(
    BackupSelected event,
    Emitter<BackupState> emit,
  ) async {
    emit(state.copyWith(selectedBackup: event.backup));
    if (event.backup == null) return;
    emit(state.copyWith(unsavedScanCount: await _unsavedScanCount()));
  }

  /// The scans a restore would remove, or 0 when they can't be counted
  /// (logged): the confirmation then only leaves out that line.
  Future<int> _unsavedScanCount() async {
    try {
      return await _backupService.countUnsavedScans();
    } catch (e) {
      logger.w('[Backup] could not count the unsaved scans', e);
      return 0;
    }
  }

  Future<void> _onBackupDeleted(
    BackupDeleted event,
    Emitter<BackupState> emit,
  ) async {
    try {
      await _backupService.deleteBackup(event.backupId);
      final history = await _backupService.listBackups();
      final selectedCleared = state.selectedBackup?.id == event.backupId
          ? null
          : state.selectedBackup;
      emit(
        state.copyWith(
          backupHistory: history,
          selectedBackup: selectedCleared,
          error: null,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          error: _failed(e, _strings.l10n.desktopBackupActionFailed),
        ),
      );
    }
  }

  Future<void> _onLocationChanged(
    BackupLocationChanged event,
    Emitter<BackupState> emit,
  ) async {
    try {
      await _backupService.setBackupDirectory(event.path);
      final history = await _backupService.listBackups();
      emit(
        state.copyWith(
          backupPath: event.path,
          backupHistory: history,
          hasUserSelectedPath: true,
          selectedBackup: null,
          error: null,
        ),
      );

      sendBackupStatus();
    } catch (e) {
      emit(
        state.copyWith(
          error: _failed(e, _strings.l10n.desktopBackupActionFailed),
        ),
      );
    }
  }

  Future<void> _onLocationReset(
    BackupLocationReset event,
    Emitter<BackupState> emit,
  ) async {
    try {
      await _backupService.resetBackupDirectory();
      final path = await _backupService.getBackupPath();
      final history = await _backupService.listBackups();
      emit(
        state.copyWith(
          backupPath: path,
          backupHistory: history,
          hasUserSelectedPath: false,
          selectedBackup: null,
          error: null,
        ),
      );

      sendBackupStatus();
    } catch (e) {
      emit(
        state.copyWith(
          error: _failed(e, _strings.l10n.desktopBackupActionFailed),
        ),
      );
    }
  }

  Future<void> _onRemoteBackupRequested(
    RemoteBackupRequested event,
    Emitter<BackupState> emit,
  ) async {
    if (state.isBackingUp) return;

    if (state.isRestoring) {
      _sendRestoreInProgress();
      return;
    }

    if (!state.hasUserSelectedPath) {
      _sendQuietly('backup.error', {
        'code': noBackupLocationCode,
        // Shown by phones from before the code.
        'error': 'No backup location set on desktop. Open the desktop app and choose a backup folder first.',
      });
      return;
    }

    // The phone asks only after its changes were acknowledged, so they are
    // already in this database.
    _sendQuietly('backup.status', {
      'ready': true,
      'backing_up': true,
      'count': state.backupHistory.length,
    });

    final name = _strings.l10n.desktopRemoteBackupName(
      backupNameDate(
        DateTime.now(),
        _strings.l10n.localeName,
        withTime: true,
      ),
    );
    add(BackupRequested(name: name, fromPhone: true));
  }

  void _sendRestoreInProgress() {
    _sendQuietly('backup.error', {
      'code': restoreInProgressCode,
      // Shown by phones from before the code.
      'error':
          'A restore is running on the desktop. Try again when it is done.',
    });
  }

  Future<void> _onPhoneBackupRequested(
    PhoneBackupRequested event,
    Emitter<BackupState> emit,
  ) async {
    emit(state.copyWith(isBackingUp: true, progress: 0.0, error: null));
    final drained = await getIt<LwwSyncBloc>().waitUntilDrained();
    if (!drained) {
      logger.w('[Backup] asking for a backup before every change was sent');
    }
    try {
      await _tcpService.sendData('backup.request', {});
    } on LinkNotConnectedException {
      emit(
        state.copyWith(
          isBackingUp: false,
          error: _strings.l10n.backupStatusNotConnected,
        ),
      );
    }
  }

  void _onRemoteBackupStatusChanged(
    RemoteBackupStatusChanged event,
    Emitter<BackupState> emit,
  ) {
    emit(
      state.copyWith(
        isBackingUp: event.isBackingUp,
        progress: event.isBackingUp ? 0.0 : 1.0,
        error: event.error,
      ),
    );
  }

  void _onRemoteBackupStatusReceived(
    RemoteBackupStatusReceived event,
    Emitter<BackupState> emit,
  ) {
    emit(
      state.copyWith(
        isBackingUp: false,
        desktopBackupReady: event.ready,
        desktopBackupCount: event.count,
        desktopLastBackupTime: event.lastBackupTime,
      ),
    );
  }

  /// A backup the desktop was making can't reach this phone any more, and
  /// its folder may change before the next connection reports it again.
  void _onRemoteLinkLost(RemoteLinkLost event, Emitter<BackupState> emit) {
    emit(state.copyWith(isBackingUp: false, desktopBackupReady: null));
  }

  @override
  Future<void> close() {
    _messageSub?.cancel();
    _linkSub?.cancel();
    return super.close();
  }

  /// Logs [error] and returns [message], the localized text shown instead.
  String _failed(Object error, String message) {
    logger.e('[Backup] $message', error);
    return message;
  }

  String _remoteErrorMessage(String? code) => switch (code) {
    null || noBackupLocationCode => _strings.l10n.desktopNoBackupLocation,
    _ => _strings.l10n.desktopBackupFailed,
  };

  /// Sends a message nobody waits for; a dropped link is logged, not thrown.
  void _sendQuietly(String type, Map<String, dynamic> payload) {
    _tcpService.sendData(type, payload).catchError((Object e) {
      logger.w('[$runtimeType] $type not sent', e);
    });
  }
}
