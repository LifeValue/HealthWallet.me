import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/features/desktop/communication/data/services/chunk_transfer_service.dart';
import 'package:health_wallet/features/desktop/communication/data/services/message_router.dart';
import 'package:health_wallet/features/desktop/communication/data/services/tcp_service.dart';

import '../../../desktop_test_fakes.dart';

const chunkSize = 64 * 1024;

void main() {
  late Directory dir;
  late FakeTcpService tcp;
  late ChunkTransferService service;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('chunk_transfer_test');
    tcp = FakeTcpService();
    service = ChunkTransferService(tcp);
  });

  tearDown(() async {
    await tcp.close();
    await dir.delete(recursive: true);
  });

  String sha(List<int> bytes) =>
      base64Url.encode(crypto.sha256.convert(bytes).bytes);

  Future<String> writeFile(String name, List<int> bytes) async {
    final file = File('${dir.path}/$name');
    await file.writeAsBytes(bytes);
    return file.path;
  }

  /// Sends [bytes] and feeds the captured chunks to [ChunkTransferService.receiveFile].
  Future<Uint8List> roundTrip(
    List<int> bytes, {
    List<Map<String, dynamic>> Function(List<Map<String, dynamic>>)? reorder,
  }) async {
    final source = await writeFile('source.bin', bytes);
    await service.sendFile(source, 'file.chunk');
    var chunks = tcp.sentOf('file.chunk');
    if (reorder != null) chunks = reorder(chunks);

    final output = '${dir.path}/out.bin';
    await service.receiveFile(Stream.fromIterable(chunks), output);
    return File(output).readAsBytes();
  }

  group('sendFile', () {
    test('a file smaller than a chunk goes in one chunk', () async {
      final bytes = randomBytes(10);
      await service.sendFile(await writeFile('a', bytes), 'f');

      expect(tcp.sent, hasLength(1));
      final chunk = tcp.sent.single;
      expect(chunk.type, 'f');
      expect(chunk.payload, {
        'chunk_index': 0,
        'total_chunks': 1,
        'data': base64Encode(bytes),
        'checksum': sha(bytes),
      });
    });

    test('exactly one chunk of data is one chunk', () async {
      await service.sendFile(await writeFile('a', randomBytes(chunkSize)), 'f');

      expect(tcp.sent, hasLength(1));
      expect(
        base64Decode(tcp.sent.single.payload['data']),
        hasLength(chunkSize),
      );
    });

    test('one byte over a chunk adds a 1-byte last chunk', () async {
      final bytes = randomBytes(chunkSize + 1);
      await service.sendFile(await writeFile('a', bytes), 'f');

      final chunks = tcp.sentOf('f');
      expect(chunks.map((c) => c['chunk_index']), [0, 1]);
      expect(chunks.map((c) => c['total_chunks']), [2, 2]);
      expect(base64Decode(chunks[0]['data']), bytes.sublist(0, chunkSize));
      expect(base64Decode(chunks[1]['data']), [bytes.last]);
      expect(chunks.map((c) => c['checksum']).toSet(), {sha(bytes)});
    });

    test('an empty file sends nothing at all', () async {
      await service.sendFile(await writeFile('empty', const []), 'f');

      expect(tcp.sent, isEmpty);
    });

    test('a missing file throws before sending', () async {
      await expectLater(
        service.sendFile('${dir.path}/missing', 'f'),
        throwsA(isA<FileSystemException>()),
      );
      expect(tcp.sent, isEmpty);
    });

    test('a send failure stops the transfer', () async {
      var calls = 0;
      tcp.onSend = (_, _) async {
        if (++calls == 2) throw const SocketException('link down');
      };

      await expectLater(
        service.sendFile(await writeFile('a', randomBytes(chunkSize * 3)), 'f'),
        throwsA(isA<SocketException>()),
      );
      expect(tcp.sent, hasLength(2));
    });
  });

  group('round trip', () {
    for (final size in [
      1,
      chunkSize - 1,
      chunkSize,
      chunkSize + 1,
      3 * chunkSize + 17,
    ]) {
      test('$size bytes arrive identical', () async {
        final bytes = randomBytes(size, seed: size);
        expect(await roundTrip(bytes), bytes);
      });
    }

    test('chunks arriving out of order are reassembled by index', () async {
      final bytes = randomBytes(4 * chunkSize + 5);
      final received = await roundTrip(
        bytes,
        reorder: (chunks) => chunks.reversed.toList(),
      );
      expect(received, bytes);
    });

    test('a duplicated chunk does not corrupt the file', () async {
      final bytes = randomBytes(3 * chunkSize);
      final received = await roundTrip(
        bytes,
        reorder: (chunks) => [chunks[0], chunks[1], chunks[1], chunks[2]],
      );
      expect(received, bytes);
    });
  });

  group('receiveFile failures', () {
    Map<String, dynamic> chunk(
      int index,
      int total,
      List<int> data, {
      String? checksum,
    }) => {
      'chunk_index': index,
      'total_chunks': total,
      'data': base64Encode(data),
      'checksum': ?checksum,
    };

    test('a corrupted chunk fails with a checksum mismatch', () async {
      final bytes = randomBytes(100);
      final corrupted = List<int>.of(bytes)..[50] ^= 0xFF;

      await expectLater(
        service.receiveFile(
          Stream.value(chunk(0, 1, corrupted, checksum: sha(bytes))),
          '${dir.path}/out',
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('Checksum mismatch'),
          ),
        ),
      );
    });

    test('a chunk index outside the range fails as a missing chunk', () async {
      await expectLater(
        service.receiveFile(
          Stream.fromIterable([
            chunk(0, 2, [1]),
            chunk(5, 2, [2]),
          ]),
          '${dir.path}/out',
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            'Missing chunk 1',
          ),
        ),
      );
      expect(File('${dir.path}/out').existsSync(), isFalse);
    });

    test('without a checksum the data is written as received', () async {
      final output = '${dir.path}/out';
      await service.receiveFile(
        Stream.fromIterable([
          chunk(1, 2, [3, 4]),
          chunk(0, 2, [1, 2]),
        ]),
        output,
      );
      expect(File(output).readAsBytesSync(), [1, 2, 3, 4]);
    });

    test('a stream error fails the transfer', () async {
      final controller = StreamController<Map<String, dynamic>>();
      final result = service.receiveFile(controller.stream, '${dir.path}/out');
      controller
        ..add(chunk(0, 2, [1]))
        ..addError(const SocketException('dropped'));

      await expectLater(result, throwsA(isA<SocketException>()));
      await controller.close();
    });

    test('an unwritable output path fails the transfer', () async {
      await expectLater(
        service.receiveFile(
          Stream.value(chunk(0, 1, [1])),
          '${dir.path}/no/such/dir/out',
        ),
        throwsA(isA<FileSystemException>()),
      );
    });

    test(
      'the stream closing before the last chunk fails the transfer',
      () async {
        await expectLater(
          service
              .receiveFile(Stream.value(chunk(0, 2, [1])), '${dir.path}/out')
              .timeout(const Duration(seconds: 2)),
          throwsA(isNot(isA<TimeoutException>())),
        );
      },
      skip:
          'BUG: receiveFile has no onDone handler, so a stream that ends '
          'early (link dropped, sender gave up, empty file with 0 chunks) '
          'leaves it waiting forever (chunk_transfer_service.dart:51-76).',
    );

    test(
      'a corrupted file is not left at the output path',
      () async {
        final bytes = randomBytes(100);
        final output = '${dir.path}/out';
        await expectLater(
          service.receiveFile(
            Stream.value(chunk(0, 1, [1, 2, 3], checksum: sha(bytes))),
            output,
          ),
          throwsStateError,
        );
        expect(File(output).existsSync(), isFalse);
      },
      skip:
          'BUG: the assembled bytes are written to outputPath before the '
          'checksum is checked, so a failed transfer leaves a corrupted file '
          'there (chunk_transfer_service.dart:105-117).',
    );
  });

  group('checksums', () {
    test('computeChecksum is base64url SHA-256 of the file', () async {
      final bytes = randomBytes(1000);
      final path = await writeFile('c', bytes);

      expect(await service.computeChecksum(path), sha(bytes));
      expect(await service.verifyChecksum(path, sha(bytes)), isTrue);
      expect(await service.verifyChecksum(path, sha([1])), isFalse);
    });
  });

  test('a file crosses a real encrypted TCP link intact', () async {
    final key = testPairingKey();
    final desktop = TcpService();
    final mobile = TcpService()..deviceDisplayName = 'Phone';
    final router = MessageRouter(desktop);
    addTearDown(() {
      router.dispose();
      mobile.dispose();
      desktop.dispose();
    });

    final address = await desktop
        .startServer(pairingKey: key, port: 0)
        .timeout(const Duration(seconds: 10));
    final connected = desktop.connectionState
        .firstWhere((s) => s == ConnectionState.connected)
        .timeout(const Duration(seconds: 10));
    await mobile.connectToServer(
      ip: address.ip,
      port: address.port,
      pairingKey: key,
    );
    await connected;

    final bytes = randomBytes(5 * chunkSize + 123);
    final source = await writeFile('payload.bin', bytes);
    final output = '${dir.path}/received.bin';

    final receiving = ChunkTransferService(
      desktop,
    ).receiveFile(router.on('file.chunk'), output);
    await ChunkTransferService(mobile).sendFile(source, 'file.chunk');
    await receiving.timeout(const Duration(seconds: 20));

    expect(File(output).readAsBytesSync(), bytes);
  });
}
