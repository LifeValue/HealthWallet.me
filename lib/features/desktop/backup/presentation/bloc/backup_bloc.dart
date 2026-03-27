import 'dart:convert';
import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

import 'package:health_wallet/features/desktop/backup/data/services/backup_service.dart';
import 'package:health_wallet/features/desktop/backup/domain/entity/backup_entry.dart';
import 'package:health_wallet/features/desktop/communication/data/services/tcp_service.dart';

part 'backup_event.dart';
part 'backup_state.dart';
part 'backup_bloc.freezed.dart';

@injectable
class BackupBloc extends Bloc<BackupEvent, BackupState> {
  final BackupService _backupService;
  final TcpService _tcpService;

  static const _chunkSize = 64 * 1024;

  BackupBloc(this._backupService, this._tcpService)
      : super(BackupState.initial()) {
    on<BackupRequested>(_onBackupRequested);
    on<RestoreRequested>(_onRestoreRequested);
    on<BackupHistoryLoaded>(_onHistoryLoaded);
    on<BackupSelected>(_onBackupSelected);
    on<BackupDeleted>(_onBackupDeleted);
    on<BackupLocationChanged>(_onLocationChanged);
    on<BackupLocationReset>(_onLocationReset);
  }

  Future<void> _onBackupRequested(
    BackupRequested event,
    Emitter<BackupState> emit,
  ) async {
    emit(state.copyWith(isBackingUp: true, progress: 0.0, error: null));

    try {
      final entry = await _backupService.createSnapshot();

      emit(state.copyWith(progress: 0.3));

      await _streamBackupToMobile(entry, emit);

      final history = await _backupService.listBackups();
      emit(state.copyWith(
        isBackingUp: false,
        progress: 1.0,
        backupHistory: history,
      ));
    } catch (e) {
      emit(state.copyWith(
        isBackingUp: false,
        progress: 0.0,
        error: e.toString(),
      ));
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

  Future<void> _onRestoreRequested(
    RestoreRequested event,
    Emitter<BackupState> emit,
  ) async {
    emit(state.copyWith(isRestoring: true, progress: 0.0, error: null));

    try {
      final backups = await _backupService.listBackups();
      final target = backups.firstWhere(
        (b) => b.id == event.backupId,
        orElse: () => throw StateError('Backup not found: ${event.backupId}'),
      );

      emit(state.copyWith(progress: 0.2));

      await _backupService.restoreFromFile(target.filePath);

      emit(state.copyWith(progress: 1.0));

      emit(state.copyWith(
        isRestoring: false,
        progress: 1.0,
      ));
    } catch (e) {
      emit(state.copyWith(
        isRestoring: false,
        progress: 0.0,
        error: e.toString(),
      ));
    }
  }

  Future<void> _onHistoryLoaded(
    BackupHistoryLoaded event,
    Emitter<BackupState> emit,
  ) async {
    try {
      final history = await _backupService.listBackups();
      final path = await _backupService.getBackupPath();
      emit(state.copyWith(backupHistory: history, backupPath: path, error: null));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  void _onBackupSelected(
    BackupSelected event,
    Emitter<BackupState> emit,
  ) {
    emit(state.copyWith(selectedBackup: event.backup));
  }

  Future<void> _onBackupDeleted(
    BackupDeleted event,
    Emitter<BackupState> emit,
  ) async {
    try {
      await _backupService.deleteBackup(event.backupId);
      final history = await _backupService.listBackups();
      final selectedCleared =
          state.selectedBackup?.id == event.backupId ? null : state.selectedBackup;
      emit(state.copyWith(
        backupHistory: history,
        selectedBackup: selectedCleared,
        error: null,
      ));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> _onLocationChanged(
    BackupLocationChanged event,
    Emitter<BackupState> emit,
  ) async {
    try {
      await _backupService.setBackupDirectory(event.path);
      final history = await _backupService.listBackups();
      emit(state.copyWith(
        backupPath: event.path,
        backupHistory: history,
        selectedBackup: null,
        error: null,
      ));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
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
      emit(state.copyWith(
        backupPath: path,
        backupHistory: history,
        selectedBackup: null,
        error: null,
      ));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }
}
