import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:injectable/injectable.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pointycastle/export.dart';

import 'package:health_wallet/core/data/local/app_database.dart';
import 'package:health_wallet/features/desktop/communication/data/services/message_router.dart';
import 'package:health_wallet/features/desktop/communication/data/services/tcp_service.dart';

@lazySingleton
class MobileBackupHandler {
  static const _chunkSize = 64 * 1024;

  final MessageRouter _messageRouter;
  final TcpService _tcpService;
  final AppDatabase _database;

  StreamSubscription<Map<String, dynamic>>? _requestSubscription;
  bool _isSending = false;

  MobileBackupHandler(
    this._messageRouter,
    this._tcpService,
    this._database,
  );

  void start() {
    _requestSubscription = _messageRouter.on('backup.request').listen(
      _handleBackupRequest,
    );
  }

  Future<void> _handleBackupRequest(Map<String, dynamic> payload) async {
    if (_isSending) return;

    _isSending = true;
    String? snapshotPath;

    try {
      snapshotPath = await _createSnapshot();
      final snapshotFile = File(snapshotPath);

      final checksum = await _computeChecksum(snapshotFile);
      final sizeBytes = await snapshotFile.length();
      final recordCount = await _getRecordCount();
      final timestamp = DateTime.now().toIso8601String();

      await _tcpService.sendData('backup.meta', {
        'checksum': checksum,
        'sizeBytes': sizeBytes,
        'recordCount': recordCount,
        'timestamp': timestamp,
      });

      await _sendChunks(snapshotFile, sizeBytes);

      await _tcpService.sendData('backup.complete', {});
    } catch (_) {
    } finally {
      if (snapshotPath != null) {
        try {
          await File(snapshotPath).delete();
        } catch (_) {}
      }
      _isSending = false;
    }
  }

  Future<String> _createSnapshot() async {
    final tempDir = await getTemporaryDirectory();
    final snapshotPath = p.join(
      tempDir.path,
      'healthwallet_backup_${DateTime.now().millisecondsSinceEpoch}.db',
    );

    await _database.customStatement("VACUUM INTO ?", [snapshotPath]);

    return snapshotPath;
  }

  Future<String> _computeChecksum(File file) async {
    final bytes = await file.readAsBytes();
    final digest = SHA256Digest();
    final hash = digest.process(Uint8List.fromList(bytes));
    return hash.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  Future<int> _getRecordCount() async {
    final result = await _database.customSelect(
      'SELECT COUNT(*) as count FROM fhir_resource',
      readsFrom: {_database.fhirResource},
    ).getSingle();
    return result.data['count'] as int;
  }

  Future<void> _sendChunks(File file, int sizeBytes) async {
    final bytes = await file.readAsBytes();
    final totalChunks = (sizeBytes / _chunkSize).ceil();

    for (var seq = 0; seq < totalChunks; seq++) {
      final start = seq * _chunkSize;
      final end = (start + _chunkSize).clamp(0, sizeBytes);
      final chunk = bytes.sublist(start, end);
      final encoded = base64Encode(chunk);

      await _tcpService.sendData('backup.chunk', {
        'seq': seq,
        'total': totalChunks,
        'data': encoded,
      });
    }
  }

  void dispose() {
    _requestSubscription?.cancel();
    _requestSubscription = null;
  }
}
