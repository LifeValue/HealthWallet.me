import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:injectable/injectable.dart';
import 'package:pointycastle/export.dart';

import 'tcp_service.dart';

@lazySingleton
class ChunkTransferService {
  static const _chunkSize = 64 * 1024;

  final TcpService _tcpService;

  ChunkTransferService(this._tcpService);

  Future<void> sendFile(String filePath, String messageType) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    final totalChunks = (bytes.length / _chunkSize).ceil();
    final checksum = _computeChecksumFromBytes(bytes);

    for (var i = 0; i < totalChunks; i++) {
      final start = i * _chunkSize;
      final end =
          (start + _chunkSize > bytes.length) ? bytes.length : start + _chunkSize;
      final chunk = bytes.sublist(start, end);
      final encoded = base64Encode(chunk);

      await _tcpService.sendData(messageType, {
        'chunk_index': i,
        'total_chunks': totalChunks,
        'data': encoded,
        'checksum': checksum,
      });
    }
  }

  Future<void> receiveFile(
    Stream<Map<String, dynamic>> chunks,
    String outputPath,
  ) async {
    final completer = Completer<void>();
    final Map<int, Uint8List> receivedChunks = {};
    int? totalChunks;
    String? expectedChecksum;

    final subscription = chunks.listen(
      (payload) {
        final index = payload['chunk_index'] as int;
        final total = payload['total_chunks'] as int;
        final data = base64Decode(payload['data'] as String);

        totalChunks = total;
        expectedChecksum ??= payload['checksum'] as String?;
        receivedChunks[index] = Uint8List.fromList(data);

        if (receivedChunks.length == totalChunks) {
          _assembleAndComplete(
            receivedChunks,
            totalChunks!,
            outputPath,
            expectedChecksum,
            completer,
          );
        }
      },
      onError: (Object e) {
        if (!completer.isCompleted) {
          completer.completeError(e);
        }
      },
    );

    try {
      await completer.future;
    } finally {
      await subscription.cancel();
    }
  }

  void _assembleAndComplete(
    Map<int, Uint8List> receivedChunks,
    int totalChunks,
    String outputPath,
    String? expectedChecksum,
    Completer<void> completer,
  ) {
    try {
      final buffer = BytesBuilder(copy: false);
      for (var i = 0; i < totalChunks; i++) {
        final chunk = receivedChunks[i];
        if (chunk == null) {
          completer.completeError(
            StateError('Missing chunk $i'),
          );
          return;
        }
        buffer.add(chunk);
      }

      final assembled = buffer.takeBytes();
      File(outputPath).writeAsBytesSync(assembled);

      if (expectedChecksum != null) {
        final actualChecksum = _computeChecksumFromBytes(assembled);
        if (actualChecksum != expectedChecksum) {
          completer.completeError(
            StateError(
              'Checksum mismatch: expected $expectedChecksum, got $actualChecksum',
            ),
          );
          return;
        }
      }

      completer.complete();
    } catch (e) {
      if (!completer.isCompleted) {
        completer.completeError(e);
      }
    }
  }

  Future<String> computeChecksum(String filePath) async {
    final bytes = await File(filePath).readAsBytes();
    return _computeChecksumFromBytes(bytes);
  }

  Future<bool> verifyChecksum(String filePath, String expected) async {
    final actual = await computeChecksum(filePath);
    return actual == expected;
  }

  String _computeChecksumFromBytes(List<int> bytes) {
    final digest = SHA256Digest();
    final hash = digest.process(Uint8List.fromList(bytes));
    return base64Url.encode(hash);
  }
}
