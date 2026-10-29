import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:airdrop/airdrop.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/records/domain/entity/record_note/record_note.dart';
import 'package:health_wallet/features/share_records/data/crypto/share_crypto.dart';
import 'package:health_wallet/features/share_records/data/service/secure_share_session.dart';
import 'package:health_wallet/features/share_records/data/service/share_records_service.dart';
import 'package:health_wallet/features/share_records/domain/entity/entity.dart';

import '../../../../fixtures/fhir/fhir_fixtures.dart';
import '../../share_test_helpers.dart';

const _airdropChannel = MethodChannel('dev.lifevalue.airdrop');

/// Records the calls the service makes to the native airdrop plugin.
class _NativeAirdrop {
  final calls = <MethodCall>[];
  Object? Function(MethodCall call)? onCall;

  void install() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_airdropChannel, (call) async {
          calls.add(call);
          return onCall?.call(call);
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_airdropChannel, null),
    );
  }

  /// Simulates the native side invoking [method] on the Dart side.
  Future<void> emit(String method, [Object? arguments]) async {
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          _airdropChannel.name,
          _airdropChannel.codec.encodeMethodCall(MethodCall(method, arguments)),
          (_) {},
        );
  }
}

Uint8List _bytes(SharePayload payload) =>
    Uint8List.fromList(utf8.encode(jsonEncode(payload.toJson())));

/// [payload] as plain JSON maps, the way it arrives on the wire.
Map<String, dynamic> _wireJson(SharePayload payload) =>
    jsonDecode(jsonEncode(payload.toJson())) as Map<String, dynamic>;

Uint8List _jsonBytes(Map<String, dynamic> json) =>
    Uint8List.fromList(utf8.encode(jsonEncode(json)));

const _sessionId = '3f2b8c1e-9a4d-4e6f-8b7a-1c2d3e4f5a6b';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  late _NativeAirdrop native;
  late ShareRecordsService service;

  setUp(() {
    root = mockPathProvider();
    native = _NativeAirdrop()..install();
    service = ShareRecordsService();
  });

  Future<SharePayload> payloadWithAttachment() => service.createPayload(
    resources: [
      record(observationJson(value: {'valueString': 'Negative'}), id: 'o1'),
      record(
        documentReferenceJson(
          attachments: [
            {
              'title': 'scan.png',
              'data': base64Encode([137, 80, 78, 71]),
            },
          ],
        ),
      ),
    ],
    deviceName: 'Jane\'s iPhone',
    expiresInSeconds: 120,
    notesMap: {
      'o1': [RecordNote(content: 'seen', timestamp: DateTime.utc(2024))],
    },
    activeFilters: const ['Observation', 'DocumentReference'],
  );

  SecureShareSession newSession() {
    final session = service.createSecureSession();
    addTearDown(session.dispose);
    return session;
  }

  group('sending', () {
    test('createPayload builds a view-only bundle', () async {
      final payload = await payloadWithAttachment();
      expect(payload.senderDeviceName, 'Jane\'s iPhone');
      expect(payload.expiresInSeconds, 120);
      expect(payload.activeFilters, ['Observation', 'DocumentReference']);
      expect(payload.bundle.entry, hasLength(2));
      expect(payload.bundle.entry.first['_notes'], isNotEmpty);
    });

    test(
      'prepareFilesForSending writes only the encrypted envelope',
      () async {
        final payload = await payloadWithAttachment();

        final path = await service.prepareFilesForSending(
          payload,
          newSession(),
        );

        expect(path, '${root.path}/tmp/share_${payload.id}.bin');
        final written = File(path!).readAsBytesSync();
        expect(ShareEnvelope.looksLikeEnvelope(written), isTrue);
        expect(ShareEnvelope.decode(written).ciphertext, isNotEmpty);
        expect(
          utf8.decode(written, allowMalformed: true),
          isNot(contains('Jane')),
        );
        expect(native.calls.single.method, 'addFiles');
        expect(native.calls.single.arguments, {
          'filePaths': [path],
        });
      },
    );

    test('prepareFilesForSending returns null when the plugin fails', () async {
      native.onCall = (_) => throw PlatformException(code: 'NO_PEER');
      final payload = await payloadWithAttachment();

      expect(
        await service.prepareFilesForSending(payload, newSession()),
        isNull,
      );
    });

    test(
      'prepareFilesForSending removes the temp file when the plugin fails',
      () async {
        native.onCall = (_) => throw PlatformException(code: 'NO_PEER');
        final payload = await payloadWithAttachment();

        await service.prepareFilesForSending(payload, newSession());

        expect(
          File('${root.path}/tmp/share_${payload.id}.bin').existsSync(),
          isFalse,
        );
      },
    );

    test('cleanupTempFile deletes the file and ignores missing ones', () async {
      final file = File('${root.path}/tmp/share_x.json')
        ..writeAsStringSync('{}');

      await service.cleanupTempFile(file.path);
      expect(file.existsSync(), isFalse);

      await expectLater(service.cleanupTempFile(file.path), completes);
    });
  });

  group('receiving', () {
    test('parsePayload restores records, notes and attachments', () async {
      final payload = await payloadWithAttachment();

      final container = await service.parsePayload(_bytes(payload));

      expect(container, isNotNull);
      expect(container!.sessionId, payload.id);
      expect(container.senderDeviceName, 'Jane\'s iPhone');
      expect(container.viewDuration, const Duration(seconds: 120));
      expect(container.isExpired, isFalse);
      expect(container.activeFilters, ['Observation', 'DocumentReference']);
      expect(container.records.map((r) => r.fhirType), [
        FhirType.Observation,
        FhirType.DocumentReference,
      ]);
      expect(container.notes.values.single.single.content, 'seen');

      final sessionDir = '${root.path}/tmp/share_session_${payload.id}';
      expect(container.tempAttachmentPaths, ['$sessionDir/scan.png']);
      expect(File('$sessionDir/scan.png').readAsBytesSync(), [137, 80, 78, 71]);
    });

    test('parsePayload reuses an existing session directory', () async {
      final payload = await payloadWithAttachment();
      Directory(
        '${root.path}/tmp/share_session_${payload.id}',
      ).createSync(recursive: true);

      final container = await service.parsePayload(_bytes(payload));
      expect(container?.records, hasLength(2));
    });

    final corrupted = <String, List<int>>{
      'invalid UTF-8': [0xff, 0xfe, 0xfd],
      'truncated JSON': utf8.encode('{"id":"abc","timestamp":"2024-01-0'),
      'a JSON list': utf8.encode('[]'),
      'missing required fields': utf8.encode('{"id":"abc"}'),
      'empty': const [],
    };
    for (final MapEntry(key: name, value: bytes) in corrupted.entries) {
      test('parsePayload returns null for $name', () async {
        final container = await service.parsePayload(Uint8List.fromList(bytes));
        expect(container, isNull);
      });
    }

    test(
      'parsePayload returns null for a truncated real payload',
      () async {
        final bytes = _bytes(await payloadWithAttachment());
        final container = await service.parsePayload(
          Uint8List.sublistView(bytes, 0, bytes.length ~/ 2),
        );
        expect(container, isNull);
      },
    );

    test('readReceivedFile returns the bytes and deletes the file', () async {
      final file = File('${root.path}/tmp/received.bin')
        ..writeAsBytesSync([1, 2, 3]);

      expect(await service.readReceivedFile(file.path), [1, 2, 3]);
      expect(file.existsSync(), isFalse);
    });

    test('readReceivedFile returns null for a missing file', () async {
      expect(
        await service.readReceivedFile('${root.path}/tmp/nope.bin'),
        isNull,
      );
    });
  });

  group('session ids', () {
    test('isValidSessionId accepts UUIDs and nothing else', () {
      expect(ShareRecordsService.isValidSessionId(_sessionId), isTrue);
      expect(
        ShareRecordsService.isValidSessionId(_sessionId.toUpperCase()),
        isTrue,
      );
      for (final id in [
        '',
        '.',
        '..',
        '../../x',
        'abc',
        '$_sessionId/../x',
        '../$_sessionId',
        _sessionId.replaceAll('-', ''),
      ]) {
        expect(ShareRecordsService.isValidSessionId(id), isFalse, reason: id);
      }
    });

    test('payloads from createPayload carry a valid id', () async {
      final payload = await payloadWithAttachment();
      expect(ShareRecordsService.isValidSessionId(payload.id), isTrue);
    });

    for (final badId in ['../../x', 'not-a-uuid', '']) {
      test(
        'a share whose id is "$badId" is rejected and writes nothing',
        () async {
          final json = _wireJson(await payloadWithAttachment())..['id'] = badId;

          final container = await service.parsePayload(_jsonBytes(json));

          expect(container, isNull);
          expect(Directory('${root.path}/tmp').listSync(), isEmpty);
          expect(
            root.listSync().map((e) => e.path.split('/').last).toSet(),
            {'Documents', 'tmp'},
          );
        },
      );
    }

    test('a share that fails to parse leaves no attachments behind', () async {
      final json = _wireJson(await payloadWithAttachment())
        ..['id'] = _sessionId;
      final bundle = json['bundle'] as Map<String, dynamic>;
      // An entry whose resource isn't an object fails the whole share after
      // the attachment of the earlier entry has been restored.
      bundle['entry'] = [
        ...bundle['entry'] as List,
        {'resource': <Object>[]},
      ];

      final container = await service.parsePayload(_jsonBytes(json));

      expect(container, isNull);
      expect(
        Directory('${root.path}/tmp/share_session_$_sessionId').existsSync(),
        isFalse,
      );
    });
  });

  group('cleanupSessionTempDir', () {
    late Directory tmp;
    late File sentinel;

    setUp(() {
      tmp = Directory('${root.path}/tmp');
      sentinel = File('${tmp.path}/keep.txt')..writeAsStringSync('keep');
    });

    test('deletes the session directory with all its attachments', () async {
      final dir = Directory('${tmp.path}/share_session_$_sessionId')
        ..createSync();
      for (final name in ['a.png', 'b.pdf', 'c.bin']) {
        File('${dir.path}/$name').writeAsBytesSync([1, 2, 3]);
      }

      await service.cleanupSessionTempDir(_sessionId);

      expect(dir.existsSync(), isFalse);
      expect(sentinel.existsSync(), isTrue);
    });

    test('deletes an empty session directory (no attachments)', () async {
      final dir = Directory('${tmp.path}/share_session_$_sessionId')
        ..createSync();

      await service.cleanupSessionTempDir(_sessionId);

      expect(dir.existsSync(), isFalse);
      expect(sentinel.existsSync(), isTrue);
    });

    // A failed delete is simulated, not made with chmod: the CI container
    // runs the tests as root, which ignores file permissions.
    test('completes when the session directory cannot be deleted', () async {
      final attempts = <String>[];

      await IOOverrides.runZoned(
        () => expectLater(service.cleanupSessionTempDir(_sessionId), completes),
        createDirectory: (path) => _UndeletableDirectory(path, attempts),
      );

      expect(attempts, [endsWith('/share_session_$_sessionId')]);
    });

    test('completes when the session directory does not exist', () async {
      await expectLater(service.cleanupSessionTempDir(_sessionId), completes);
      expect(sentinel.existsSync(), isTrue);
    });

    for (final badId in ['', '.', '..', '../tmp', '../../x']) {
      test('ignores the id "$badId" and never deletes anything', () async {
        final cwdMarker = File('${Directory.current.path}/pubspec.yaml');
        Directory('${tmp.path}/share_session_').createSync();

        await service.cleanupSessionTempDir(badId);

        expect(tmp.existsSync(), isTrue);
        expect(sentinel.existsSync(), isTrue);
        expect(Directory('${tmp.path}/share_session_').existsSync(), isTrue);
        expect(cwdMarker.existsSync(), isTrue);
      });
    }
  });

  group('plugin forwarding', () {
    final calls =
        <String, (Future<void> Function(ShareRecordsService), Object?)>{
          'startDiscovery': (
            (s) => s.startDiscovery(useBluetooth: false),
            {'useBluetooth': false},
          ),
          'selectDevice': (
            (s) => s.selectPeer('peer-1'),
            {'deviceId': 'peer-1'},
          ),
          'startSymmetricDiscovery': ((s) => s.startSymmetricDiscovery(), null),
          'acceptInvitation': (
            (s) => s.acceptInvitation('inv-1'),
            {'invitationId': 'inv-1'},
          ),
          'rejectInvitation': (
            (s) => s.rejectInvitation('inv-2'),
            {'invitationId': 'inv-2'},
          ),
          'disconnect': ((s) => s.disconnect(), null),
          'cancelTransfer': ((s) => s.cancelTransfer(), null),
          'startReady': ((s) => s.startReady(), {'useBluetooth': true}),
          'sendKillSignal': ((s) => s.sendKillSignal(), null),
          'sendExtendRequest': (
            (s) => s.sendExtendRequest(durationSeconds: 600),
            {'durationSeconds': 600},
          ),
          'sendExtendAccepted': (
            (s) => s.sendExtendAccepted(durationSeconds: 300),
            {'durationSeconds': 300},
          ),
          'sendExtendRejected': ((s) => s.sendExtendRejected(), null),
          'sendViewingStarted': ((s) => s.sendViewingStarted(), null),
          'receiveDataInMemory': (
            (s) => s.startReceivingInMemory(),
            {
              'peer': ShareRecordsService.localPeerType.name,
              'useBluetooth': true,
            },
          ),
        };

    for (final MapEntry(key: method, value: (invoke, args)) in calls.entries) {
      test(method, () async {
        await invoke(service);
        expect(native.calls.single.method, method);
        expect(native.calls.single.arguments, args);
      });
    }

    test('localPeerType matches the host platform', () {
      expect(
        ShareRecordsService.localPeerType,
        Platform.isIOS ? PeerType.ios : PeerType.android,
      );
    });
  });

  group('native events', () {
    Future<void> expectEvent<T>(
      Stream<T> stream,
      String method,
      Object? arguments,
      Object? matcher,
    ) async {
      final next = stream.first;
      await native.emit(method, arguments);
      expect(await next.timeout(const Duration(seconds: 1)), matcher);
    }

    test('invitations, peers and health updates', () async {
      await expectEvent(
        service.invitationStream,
        'onInvitation',
        {'invitationId': 'inv-1', 'senderDeviceName': 'Pixel'},
        {'invitationId': 'inv-1', 'senderDeviceName': 'Pixel'},
      );
      await expectEvent(
        service.peerDiscoveryStream,
        'onPeerDiscovery',
        {'deviceId': 'd1'},
        {'deviceId': 'd1'},
      );
      await expectEvent(
        service.connectionHealthStream,
        'onConnectionHealth',
        {'rssi': -40},
        {'rssi': -40},
      );
    });

    test('received data and files', () async {
      final next = service.receivedDataStream.first;
      await native.emit('onDataReceived', {
        'fileName': 'share.json',
        'data': Uint8List.fromList([1, 2]),
        'totalFiles': 1,
        'currentFile': 1,
      });
      final data = await next;
      expect(data.fileName, 'share.json');
      expect(data.data, [1, 2]);

      await expectEvent(
        service.receivedFilesStream,
        'onFilesReceived',
        ['/tmp/a.json'],
        ['/tmp/a.json'],
      );
    });

    test('secure sessions exchange keys over session messages', () async {
      // The mocked plugin relays this phone's messages to a sender session
      // and delivers the sender's replies as onSessionMessage events.
      final toSender = StreamController<Uint8List>.broadcast();
      addTearDown(toSender.close);
      native.onCall = (call) {
        if (call.method == 'sendSessionMessage') {
          toSender.add((call.arguments as Map)['data'] as Uint8List);
        }
        return null;
      };
      final sender = SecureShareSession(
        _PeerTransport(
          toSender.stream,
          (message) => native.emit('onSessionMessage', {'data': message}),
        ),
      );
      addTearDown(sender.dispose);
      final receiver = newSession();

      final envelope = await sender.seal(utf8.encode('hello'));
      final senderCode = sender.awaitReceiver();
      final receiverCode = await receiver.open(envelope);
      expect(await senderCode, receiverCode);

      await sender.confirm();
      expect(utf8.decode(await receiver.awaitPayload()), 'hello');
      expect(native.calls.single.method, 'sendSessionMessage');
    });

    test('session lifecycle signals', () async {
      await expectEvent(service.killSignalStream, 'onKillSignal', null, isNull);
      await expectEvent(
        service.sessionEndedStream,
        'onSessionEnded',
        null,
        isNull,
      );
      await expectEvent(
        service.sessionExtendRequestStream,
        'onSessionExtendRequest',
        {'durationSeconds': 600},
        600,
      );
      await expectEvent(
        service.sessionExtendAcceptedStream,
        'onSessionExtendAccepted',
        {'durationSeconds': 300},
        300,
      );
      await expectEvent(
        service.sessionExtendRejectedStream,
        'onSessionExtendRejected',
        null,
        isNull,
      );
      await expectEvent(
        service.viewingStartedStream,
        'onViewingStarted',
        null,
        isNull,
      );
      await expectEvent(
        service.invitationRejectedStream,
        'onInvitationRejected',
        null,
        isNull,
      );
      await expectEvent(
        service.wifiToggleNeededStream,
        'onWifiToggleNeeded',
        null,
        isNull,
      );
      await expectEvent(
        service.statusStream,
        'onConnectionStalled',
        null,
        TransferStatus.connectionStalled,
      );
      expect(service.progressStream, isA<Stream<TransferProgress>>());
    });
  });
}

class _PeerTransport implements ShareMessageTransport {
  @override
  final Stream<Uint8List> messages;
  final Future<void> Function(Uint8List message) _send;

  _PeerTransport(this.messages, this._send);

  @override
  Future<void> send(Uint8List message) => _send(message);
}

/// A directory that exists but can't be deleted; records each attempt.
class _UndeletableDirectory extends Fake implements Directory {
  _UndeletableDirectory(this.path, this.attempts);

  @override
  final String path;
  final List<String> attempts;

  @override
  Future<bool> exists() async => true;

  @override
  Future<FileSystemEntity> delete({bool recursive = false}) async {
    attempts.add(path);
    throw FileSystemException('Directory not empty', path);
  }
}
