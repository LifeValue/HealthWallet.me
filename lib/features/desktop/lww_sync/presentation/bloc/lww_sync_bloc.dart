import 'dart:async';
import 'dart:convert';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/features/desktop/backup/presentation/bloc/backup_bloc.dart';
import 'package:health_wallet/features/desktop/communication/data/services/tcp_service.dart';
import 'package:health_wallet/features/desktop/lww_sync/data/services/change_watcher_service.dart';
import 'package:health_wallet/features/desktop/lww_sync/data/services/lww_sync_service.dart';
import 'package:health_wallet/features/desktop/lww_sync/data/services/offline_queue_service.dart';
import 'package:health_wallet/features/desktop/lww_sync/domain/entity/sync_delta.dart';
import 'package:injectable/injectable.dart';

part 'lww_sync_event.dart';
part 'lww_sync_state.dart';
part 'lww_sync_bloc.freezed.dart';

@lazySingleton
class LwwSyncBloc extends Bloc<LwwSyncEvent, LwwSyncState> {
  final LwwSyncService _syncService;
  final ChangeWatcherService _changeWatcher;
  final OfflineQueueService _offlineQueue;
  final TcpService _tcpService;

  StreamSubscription? _connectionSub;
  StreamSubscription? _messageSub;

  LwwSyncBloc(
    this._syncService,
    this._changeWatcher,
    this._offlineQueue,
    this._tcpService,
  ) : super(LwwSyncState.initial()) {
    on<LwwSyncInitialised>(_onInitialised);
    on<SyncTriggered>(_onSyncTriggered);
    on<DeltaReceived>(_onDeltaReceived);
    on<ConnectionChanged>(_onConnectionChanged);
    on<TableStatusReceived>(_onTableStatusReceived);
    on<SyncVerifyReceived>(_onSyncVerifyReceived);
  }

  Future<void> _onInitialised(
    LwwSyncInitialised event,
    Emitter<LwwSyncState> emit,
  ) async {
    final lastSync = await _syncService.getLastSyncTimestamp();
    emit(state.copyWith(
      lastSyncTime: lastSync,
      pendingChangeCount: _offlineQueue.pendingCount,
    ));

    _connectionSub = _tcpService.connectionState.listen((tcpState) {
      final connected = tcpState == ConnectionState.connected;
      add(ConnectionChanged(isConnected: connected));
    });

    _messageSub = _tcpService.messages.listen((message) {
      if (message.type != MessageType.data) return;

      try {
        final decoded = jsonDecode(message.payloadString) as Map<String, dynamic>;
        final type = decoded['type'] as String?;

        if (type == 'sync.delta') {
          final payload = decoded['payload'] as Map<String, dynamic>;
          final delta = SyncDelta.fromJson(payload);
          add(DeltaReceived(delta: delta));
        } else if (type == 'sync.ack') {
          final payload = decoded['payload'] as Map<String, dynamic>;
          final tableName = payload['table_name'] as String;
          final ts = payload['timestamp'] as int;
          _offlineQueue.acknowledge(
            tableName,
            DateTime.fromMillisecondsSinceEpoch(ts),
          );
        } else if (type == 'sync.status') {
          final payload = decoded['payload'] as Map<String, dynamic>;
          final remoteCounts = payload.map<String, int>(
            (k, v) => MapEntry(k, (v as num).toInt()),
          );
          add(TableStatusReceived(remoteCounts: remoteCounts));
        } else if (type == 'sync.verify') {
          final payload = decoded['payload'] as Map<String, dynamic>;
          final remoteCounts = payload.map<String, int>(
            (k, v) => MapEntry(k, (v as num).toInt()),
          );
          add(SyncVerifyReceived(remoteCounts: remoteCounts));
        } else if (type == 'sync.file_request') {
          final payload = decoded['payload'] as Map<String, dynamic>;
          final paths = (payload['paths'] as List).cast<String>();
          _handleFileRequest(paths);
        } else if (type == 'sync.file_data') {
          final payload = decoded['payload'] as Map<String, dynamic>;
          final fileData = payload.map<String, String>(
            (k, v) => MapEntry(k, v as String),
          );
          _handleFileData(fileData);
        }
      } catch (_) {}
    });

    await _syncService.backfillExistingRows();
    await _syncService.fixBrokenAttachmentUrls();

    _changeWatcher.startWatching();

    await _syncService.cleanupTombstones();
  }

  Future<void> _onSyncTriggered(
    SyncTriggered event,
    Emitter<LwwSyncState> emit,
  ) async {
    if (state.syncStatus == LwwSyncStatus.syncing) return;

    emit(state.copyWith(
      syncStatus: LwwSyncStatus.syncing,
      error: null,
      isSynced: false,
      sentRows: 0,
      receivedRows: 0,
      completedTables: 0,
      totalTables: LwwSyncService.syncedTables.length,
    ));

    try {
      final since = state.lastSyncTime ?? DateTime.fromMillisecondsSinceEpoch(0);
      var totalSent = 0;

      for (var i = 0; i < LwwSyncService.syncedTables.length; i++) {
        final table = LwwSyncService.syncedTables[i];
        emit(state.copyWith(
          currentTable: table,
          completedTables: i,
        ));

        final delta = await _syncService.computeDelta(table, since);
        if (delta.rows.isNotEmpty) {
          if (_tcpService.isConnected) {
            await _tcpService.sendData('sync.delta', delta.toJson());
          } else {
            await _offlineQueue.enqueue(delta);
          }
          totalSent += delta.rows.length;
          emit(state.copyWith(sentRows: totalSent));
        }
      }

      final now = DateTime.now();
      await _syncService.setLastSyncTimestamp(now);

      emit(state.copyWith(
        syncStatus: LwwSyncStatus.idle,
        lastSyncTime: now,
        isSynced: totalSent == 0,
        pendingChangeCount: _offlineQueue.pendingCount,
        currentTable: null,
        completedTables: LwwSyncService.syncedTables.length,
      ));

      if (_tcpService.isConnected) {
        final counts = await _syncService.getTableRowCounts();
        await _tcpService.sendData('sync.status', counts);

        try {
          getIt<BackupBloc>().sendBackupStatus();
        } catch (_) {}
      }
    } catch (e) {
      emit(state.copyWith(
        syncStatus: LwwSyncStatus.error,
        error: e.toString(),
        currentTable: null,
      ));
    }
  }

  Future<void> _onDeltaReceived(
    DeltaReceived event,
    Emitter<LwwSyncState> emit,
  ) async {
    emit(state.copyWith(
      syncStatus: LwwSyncStatus.syncing,
      error: null,
      isSynced: false,
      currentTable: event.delta.tableName,
    ));

    try {
      final applied = await _syncService.applyDelta(event.delta);

      emit(state.copyWith(
        receivedRows: state.receivedRows + applied,
      ));

      if (event.delta.tableName == 'fhir_resource') {
        await _syncService.fixBrokenAttachmentUrls();
      }

      if (_tcpService.isConnected) {
        await _tcpService.sendData('sync.ack', {
          'table_name': event.delta.tableName,
          'timestamp': event.delta.timestamp.millisecondsSinceEpoch,
        });
      }

      final now = DateTime.now();
      await _syncService.setLastSyncTimestamp(now);

      emit(state.copyWith(
        syncStatus: LwwSyncStatus.idle,
        lastSyncTime: now,
        currentTable: null,
      ));
    } catch (e) {
      emit(state.copyWith(
        syncStatus: LwwSyncStatus.error,
        error: e.toString(),
        currentTable: null,
      ));
    }
  }

  Future<void> _onConnectionChanged(
    ConnectionChanged event,
    Emitter<LwwSyncState> emit,
  ) async {
    if (event.isConnected) {
      emit(state.copyWith(
        isSynced: false,
        sentRows: 0,
        receivedRows: 0,
      ));

      await Future<void>.delayed(const Duration(milliseconds: 200));

      try {
        final counts = await _syncService.getTableRowCounts();
        await _tcpService.sendData('sync.status', counts);
      } catch (_) {}

      final flushed = await _offlineQueue.flush();
      if (flushed > 0) {}

      add(const SyncTriggered());
    } else {
      emit(state.copyWith(isSynced: false));
    }

    emit(state.copyWith(
      pendingChangeCount: _offlineQueue.pendingCount,
    ));
  }

  Future<void> _onTableStatusReceived(
    TableStatusReceived event,
    Emitter<LwwSyncState> emit,
  ) async {
    final localCounts = await _syncService.getTableRowCounts();
    var sentAny = false;

    for (final table in LwwSyncService.syncedTables) {
      final localCount = localCounts[table] ?? 0;
      final remoteCount = event.remoteCounts[table] ?? 0;

      if (localCount > 0 && localCount != remoteCount) {
        emit(state.copyWith(
          syncStatus: LwwSyncStatus.syncing,
          currentTable: table,
        ));

        final delta = await _syncService.computeDelta(
          table,
          DateTime.fromMillisecondsSinceEpoch(0),
        );
        if (delta.rows.isNotEmpty && _tcpService.isConnected) {
          await _tcpService.sendData('sync.delta', delta.toJson());
          emit(state.copyWith(
            sentRows: state.sentRows + delta.rows.length,
          ));
          sentAny = true;
        }
      }
    }

    if (sentAny) {
      await _syncService.setLastSyncTimestamp(DateTime.now());
    }

    emit(state.copyWith(
      syncStatus: LwwSyncStatus.idle,
      currentTable: null,
    ));

    await Future<void>.delayed(const Duration(seconds: 1));
    if (_tcpService.isConnected) {
      try {
        final updatedCounts = await _syncService.getTableRowCounts();
        await _tcpService.sendData('sync.verify', updatedCounts);
      } catch (_) {}
    }
  }

  Future<void> _onSyncVerifyReceived(
    SyncVerifyReceived event,
    Emitter<LwwSyncState> emit,
  ) async {
    final localCounts = await _syncService.getTableRowCounts();
    var allMatch = true;

    for (final table in LwwSyncService.syncedTables) {
      final localCount = localCounts[table] ?? 0;
      final remoteCount = event.remoteCounts[table] ?? 0;
      if (localCount != remoteCount) {
        allMatch = false;
      }
    }

    if (allMatch) {
      emit(state.copyWith(isSynced: true));
    } else {
      emit(state.copyWith(isSynced: false));
    }

    await _requestMissingFiles();
  }

  Future<void> _requestMissingFiles() async {
    if (!_tcpService.isConnected) return;

    try {
      final missing = await _syncService.getMissingAttachmentPaths();
      if (missing.isEmpty) return;

      await _tcpService.sendData('sync.file_request', {'paths': missing});
    } catch (_) {}
  }

  Future<void> _handleFileRequest(List<String> paths) async {
    try {
      final resolved = await _syncService.resolveFileRequests(paths);
      if (resolved.isEmpty) return;

      await _tcpService.sendData('sync.file_data', resolved);
    } catch (_) {}
  }

  Future<void> _handleFileData(Map<String, String> fileData) async {
    try {
      await _syncService.saveReceivedFiles(fileData);
    } catch (_) {}
  }

  @override
  Future<void> close() {
    _connectionSub?.cancel();
    _messageSub?.cancel();
    _changeWatcher.stopWatching();
    return super.close();
  }
}
