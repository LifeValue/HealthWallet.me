import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:injectable/injectable.dart';
import 'package:path/path.dart' as p;
import 'package:pointycastle/export.dart';

import 'package:health_wallet/features/desktop/backup/data/services/backup_service.dart';
import 'package:health_wallet/features/desktop/backup/domain/entity/backup_entry.dart';
import 'package:health_wallet/features/desktop/communication/data/services/message_router.dart';
import 'package:health_wallet/features/desktop/communication/data/services/tcp_service.dart';

enum BackupReceiveStatus { idle, receivingMeta, receivingChunks, verifying, complete, failed }

@lazySingleton
class DesktopBackupReceiver {
  final MessageRouter _messageRouter;
  final TcpService _tcpService;
  final BackupService _backupService;

  StreamSubscription<Map<String, dynamic>>? _metaSubscription;
  StreamSubscription<Map<String, dynamic>>? _chunkSubscription;
  StreamSubscription<Map<String, dynamic>>? _completeSubscription;

  final _statusController = StreamController<BackupReceiveStatus>.broadcast();
  final _progressController = StreamController<double>.broadcast();

  String? _expectedChecksum;
  int _expectedSize = 0;
  int _expectedRecordCount = 0;
  String? _timestamp;
  IOSink? _chunkSink;
  String? _tempFilePath;
  int _receivedChunks = 0;
  int _totalChunks = 0;

  Stream<BackupReceiveStatus> get status => _statusController.stream;
  Stream<double> get progress => _progressController.stream;

  DesktopBackupReceiver(
    this._messageRouter,
    this._tcpService,
    this._backupService,
  );

  void start() {
    _metaSubscription = _messageRouter.on('backup.meta').listen(_handleMeta);
    _chunkSubscription = _messageRouter.on('backup.chunk').listen(_handleChunk);
    _completeSubscription = _messageRouter.on('backup.complete').listen(_handleComplete);
  }

  Future<void> requestBackup() async {
    _reset();
    _updateStatus(BackupReceiveStatus.receivingMeta);
    await _tcpService.sendData('backup.request', {});
  }

  void _handleMeta(Map<String, dynamic> payload) {
    _expectedChecksum = payload['checksum'] as String;
    _expectedSize = payload['sizeBytes'] as int;
    _expectedRecordCount = payload['recordCount'] as int;
    _timestamp = payload['timestamp'] as String;

    _updateStatus(BackupReceiveStatus.receivingChunks);
  }

  Future<void> _handleChunk(Map<String, dynamic> payload) async {
    final seq = payload['seq'] as int;
    final total = payload['total'] as int;
    final data = payload['data'] as String;

    if (_chunkSink == null) {
      _totalChunks = total;
      _receivedChunks = 0;
      final backupDir = await _backupService.getBackupDirectory();
      _tempFilePath = p.join(backupDir.path, 'incoming_backup.db.tmp');
      _chunkSink = File(_tempFilePath!).openWrite();
    }

    final decoded = base64Decode(data);
    _chunkSink!.add(decoded);
    _receivedChunks++;

    final progressValue = _receivedChunks / _totalChunks;
    _progressController.add(progressValue);
  }

  Future<void> _handleComplete(Map<String, dynamic> payload) async {
    _updateStatus(BackupReceiveStatus.verifying);

    try {
      await _chunkSink?.flush();
      await _chunkSink?.close();
      _chunkSink = null;

      if (_tempFilePath == null || _expectedChecksum == null) {
        throw StateError('Received complete before meta or chunks');
      }

      final tempFile = File(_tempFilePath!);
      final actualChecksum = await _computeChecksum(tempFile);

      if (actualChecksum != _expectedChecksum) {
        await tempFile.delete();
        _updateStatus(BackupReceiveStatus.failed);
        return;
      }

      final backupDir = await _backupService.getBackupDirectory();
      final timestamp = DateTime.parse(_timestamp!);
      final id = timestamp.millisecondsSinceEpoch.toString();
      final fileName = 'healthwallet_backup_$id.db';
      final finalPath = p.join(backupDir.path, fileName);

      await tempFile.rename(finalPath);

      final entry = BackupEntry(
        id: id,
        timestamp: timestamp,
        sizeBytes: _expectedSize,
        recordCount: _expectedRecordCount,
        checksum: _expectedChecksum!,
        filePath: finalPath,
      );

      await _backupService.saveBackupMetadata(entry);

      _updateStatus(BackupReceiveStatus.complete);
    } catch (_) {
      _updateStatus(BackupReceiveStatus.failed);
    }
  }

  Future<String> _computeChecksum(File file) async {
    final bytes = await file.readAsBytes();
    final digest = SHA256Digest();
    final hash = digest.process(Uint8List.fromList(bytes));
    return hash.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  void _updateStatus(BackupReceiveStatus newStatus) {
    _statusController.add(newStatus);
  }

  void _reset() {
    _expectedChecksum = null;
    _expectedSize = 0;
    _expectedRecordCount = 0;
    _timestamp = null;
    _chunkSink = null;
    _tempFilePath = null;
    _receivedChunks = 0;
    _totalChunks = 0;
  }

  void dispose() {
    _metaSubscription?.cancel();
    _chunkSubscription?.cancel();
    _completeSubscription?.cancel();
    _metaSubscription = null;
    _chunkSubscription = null;
    _completeSubscription = null;
    _chunkSink?.close();
    _statusController.close();
    _progressController.close();
  }
}
