import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/features/desktop/communication/data/services/message_router.dart';
import 'package:health_wallet/features/desktop/handover/data/services/handover_sender_service.dart';
import 'package:health_wallet/features/desktop/handover/data/services/handover_service.dart';
import 'package:health_wallet/features/desktop/handover/domain/entity/handover_protocol.dart';
import 'package:health_wallet/features/desktop/handover/domain/entity/handover_session.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapped_property.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_encounter.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_observation.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_patient.dart';
import 'package:health_wallet/features/processing/domain/entity/processing_session.dart';
import 'package:health_wallet/features/processing/domain/entity/staged_resource.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../desktop_test_fakes.dart';
import '../../handover_test_fakes.dart';

/// The phone's sender and the desktop's receiver over one fake link.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;
  late Directory tmp;
  late ({FakeTcpService phone, FakeTcpService desktop}) pair;
  late MessageRouter phoneRouter;
  late MessageRouter desktopRouter;
  late SharedPreferences prefs;
  late HandoverSenderService sender;
  late HandoverService receiver;
  late List<IncomingHandoverEvent> received;
  late List<DesktopHandoverEvent> fromDesktop;
  late List<HandoverSession> desktopTransfers;

  HandoverService newReceiver() => HandoverService(
    pair.desktop,
    desktopRouter,
    prefs,
  )..temporaryDirectory = () async => tmp;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('handover_transfer_test');
    tmp = Directory(p.join(dir.path, 'tmp'))..createSync();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    pair = linkedPair();
    phoneRouter = MessageRouter(pair.phone);
    desktopRouter = MessageRouter(pair.desktop);
    sender = HandoverSenderService(pair.phone, phoneRouter, prefs)..start();
    receiver = newReceiver()..start();
    received = [];
    fromDesktop = [];
    desktopTransfers = [];
    receiver.phoneEvents.listen(received.add);
    receiver.transfers.listen(desktopTransfers.add);
    sender.desktopEvents.listen(fromDesktop.add);
  });

  tearDown(() async {
    sender.dispose();
    await receiver.dispose();
    phoneRouter.dispose();
    desktopRouter.dispose();
    await pair.phone.close();
    await pair.desktop.close();
    await dir.delete(recursive: true);
  });

  /// Lets messages and file writes run; the files are real, so this waits a
  /// little real time, not just event-loop turns.
  Future<void> settle([int turns = 20]) async {
    for (var i = 0; i < turns; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }
  }

  /// Waits until [done] holds; fails after a few seconds.
  Future<void> until(bool Function() done) async {
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (!done()) {
      if (DateTime.now().isAfter(deadline)) fail('timed out waiting');
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }

  String writeFile(String path, List<int> bytes) {
    final file = File(p.join(dir.path, path))
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes);
    return file.path;
  }

  List<int> randomBytes(int n) {
    final r = Random(n);
    return List.generate(n, (_) => r.nextInt(256));
  }

  group('transfer', () {
    test(
      'sends every page in order, in chunks, byte for byte, with the phone '
      'session id',
      () async {
        // A first page over two chunks, and two pages with the same name.
        final big = randomBytes(HandoverProtocol.chunkBytes * 2 + 17);
        final paths = [
          writeFile('a/scan.jpg', big),
          writeFile('b/scan.jpg', [1, 2, 3]),
        ];

        final result = await sender.send(
          'phone-session',
          paths,
          phase1Data: {'patient': <String, dynamic>{}},
        );
        await until(() => received.isNotEmpty);

        expect(result.status, HandoverStatus.sent);
        expect(result.progress, 1);
        expect(pair.phone.sentOf(HandoverMessage.chunk), hasLength(4));
        final event = received.single as IncomingHandoverReceived;
        expect(event.sessionId, 'phone-session');
        expect(event.phase1Data, {'patient': <String, dynamic>{}});
        expect(event.filePaths, hasLength(2));
        expect(File(event.filePaths[0]).readAsBytesSync(), big);
        expect(File(event.filePaths[1]).readAsBytesSync(), [1, 2, 3]);
        expect(desktopTransfers.last.status, HandoverStatus.sent);
      },
    );

    test('received files are deleted once processing has its copy', () async {
      await sender.send('s', [
        writeFile('x.jpg', const [7]),
      ]);
      await settle();
      final path = (received.single as IncomingHandoverReceived).filePaths[0];
      expect(File(path).existsSync(), isTrue);

      await receiver.discardFiles('s');

      expect(File(path).existsSync(), isFalse);
    });

    test('a missing file fails before anything is sent', () async {
      final result = await sender.send('s', [p.join(dir.path, 'gone.jpg')]);

      expect(result.failure, HandoverFailure.fileNotFound);
      expect(pair.phone.sent, isEmpty);
    });

    test('a document over the limit is refused on both ends', () async {
      final path = p.join(dir.path, 'huge.pdf');
      File(path).openSync(mode: FileMode.write)
        ..truncateSync(HandoverProtocol.maxTotalBytes + 1)
        ..closeSync();

      final result = await sender.send('s', [path]);
      expect(result.failure, HandoverFailure.tooLarge);
      expect(pair.phone.sent, isEmpty);

      // A phone that claims more anyway is rejected by the desktop.
      pair.desktop.deliver(HandoverMessage.offer, {
        'session_id': 's2',
        'v': HandoverProtocol.version,
        'files': [
          {'name': 'a.pdf', 'size': HandoverProtocol.maxTotalBytes + 1},
        ],
      });
      await settle();
      expect(pair.desktop.sentOf(HandoverMessage.reject).single, {
        'session_id': 's2',
        'reason': 'too_large',
      });
    });

    test('an older phone is told it speaks another version', () async {
      // What a phone from before the chunked transfer sends.
      pair.desktop.deliver(HandoverMessage.offer, {
        'session_id': 'old',
        'file_count': 1,
        'total_bytes': 3,
      });
      await settle();

      expect(pair.desktop.sentOf(HandoverMessage.reject).single, {
        'session_id': 'old',
        'reason': 'version',
      });
      expect(pair.desktop.sentOf(HandoverMessage.accept), isEmpty);
    });

    test('an older desktop is reported as needing an update', () async {
      pair.phone.onSend = (type, payload) async {
        if (type == HandoverMessage.offer) {
          pair.phone.deliver(HandoverMessage.reject, {
            'session_id': payload['session_id'],
            'reason': 'version',
          });
        }
      };

      final result = await sender.send('s', [
        writeFile('a.jpg', const [1]),
      ]);

      expect(result.failure, HandoverFailure.desktopOutdated);
      expect(pair.phone.sentOf(HandoverMessage.chunk), isEmpty);
    });

    test('a desktop that never answers is not waited for forever', () async {
      // A desktop app from before this protocol ignores the offer.
      pair.phone.onSend = (_, _) async {};
      sender.acceptTimeout = const Duration(milliseconds: 50);

      final result = await sender.send('s', [
        writeFile('a.jpg', const [1]),
      ]);

      expect(result.failure, HandoverFailure.notAccepted);
    });

    test(
      'an accept that arrives while the offer is still being sent counts',
      () async {
        // E.g. MPC: the desktop answers before the platform call returns.
        pair.phone.onSend = (type, payload) async {
          if (type == HandoverMessage.offer) {
            pair.phone.deliver(HandoverMessage.accept, {
              'session_id': payload['session_id'],
            });
            await Future<void>.delayed(const Duration(milliseconds: 20));
          }
        };

        final result = await sender.send('s', [
          writeFile('a.jpg', const [1]),
        ]);

        expect(result.status, HandoverStatus.sent);
      },
    );

    test(
      'a drop mid-transfer ends as connection lost, and the desktop drops '
      'the partial files when the phone is back',
      () async {
        final path = writeFile(
          'a.jpg',
          randomBytes(HandoverProtocol.chunkBytes * 3),
        );
        final forward = pair.phone.onSend!;
        var chunks = 0;
        pair.phone.onSend = (type, payload) async {
          await forward(type, payload);
          if (type == HandoverMessage.chunk && ++chunks == 1) {
            setLinkUp(pair, false);
          }
        };

        final result = await sender.send('s', [path]);
        await settle();
        expect(result.failure, HandoverFailure.connectionLost);
        expect(tmp.listSync(recursive: true), isNotEmpty);

        setLinkUp(pair, true);
        await settle();

        expect(tmp.listSync(recursive: true).whereType<File>(), isEmpty);
        expect(received.single, isA<IncomingHandoverCancelled>());
        // The desktop confirmed, so the phone won't send it again.
        expect(prefs.getString(HandoverSenderService.outboxKey), isNull);
      },
    );

    test('cancelling stops sending and tells the desktop', () async {
      final path = writeFile(
        'a.jpg',
        randomBytes(HandoverProtocol.chunkBytes * 3),
      );
      final forward = pair.phone.onSend!;
      pair.phone.onSend = (type, payload) async {
        await forward(type, payload);
        if (type == HandoverMessage.chunk) sender.cancelTransfer('s');
      };

      final result = await sender.send('s', [path]);
      await until(
        () =>
            received.isNotEmpty &&
            tmp.listSync(recursive: true).whereType<File>().isEmpty,
      );

      expect(result.failure, HandoverFailure.cancelled);
      expect(pair.phone.sentOf(HandoverMessage.chunk), hasLength(1));
      expect(received.single, isA<IncomingHandoverCancelled>());
      expect(tmp.listSync(recursive: true).whereType<File>(), isEmpty);
    });

    test(
      'a chunk out of order fails the transfer and tells the phone',
      () async {
        pair.desktop.deliver(HandoverMessage.offer, {
          'session_id': 's',
          'v': HandoverProtocol.version,
          'files': [
            {'name': 'a.jpg', 'size': 10},
          ],
        });
        pair.desktop.deliver(HandoverMessage.chunk, {
          'session_id': 's',
          'index': 0,
          'offset': 5,
          'data': base64Encode(List.filled(5, 1)),
        });
        await settle();

        expect(received, isEmpty);
        expect(desktopTransfers.last.failure, HandoverFailure.failed);
        expect(
          (fromDesktop.single as DesktopHandoverFailed).failure,
          HandoverFailure.failed,
        );
        expect(tmp.listSync(recursive: true).whereType<File>(), isEmpty);
      },
    );

    test('a transfer that stops arriving times out', () async {
      receiver.idleTimeout = const Duration(milliseconds: 30);
      pair.desktop.deliver(HandoverMessage.offer, {
        'session_id': 's',
        'v': HandoverProtocol.version,
        'files': [
          {'name': 'a.jpg', 'size': 10},
        ],
      });
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await settle();

      expect(desktopTransfers.last.failure, HandoverFailure.timeout);
      expect(
        (fromDesktop.single as DesktopHandoverFailed).failure,
        HandoverFailure.timeout,
      );
    });
  });

  group('messages to the phone', () {
    const draft = HandoverDraft(
      patient: StagedPatient(
        draft: MappingPatient(id: 'patient-1'),
        mode: ImportMode.createNew,
      ),
      encounter: StagedEncounter(draft: MappingEncounter(id: 'visit-1')),
      resources: [
        MappingObservation(
          id: 'obs-1',
          observationName: MappedProperty(value: 'Glucose'),
        ),
      ],
    );

    test('the draft keeps its ids on the way', () async {
      await receiver.sendResult('s', draft);
      await settle();

      final result = fromDesktop.single as DesktopHandoverResult;
      expect(result.sessionId, 's');
      expect(result.draft.patient.draft!.id, 'patient-1');
      expect(result.draft.encounter.draft!.id, 'visit-1');
      expect(result.draft.resources.single.id, 'obs-1');
      expect(
        HandoverDraft.of(
          const ProcessingSession(
            id: 's',
            patient: StagedPatient(draft: MappingPatient(id: 'patient-1')),
          ),
        ).patient.draft!.id,
        'patient-1',
      );
    });

    test(
      'wait for the phone across a restart and stop once acknowledged',
      () async {
        setLinkUp(pair, false);
        await receiver.sendResult('s', draft);
        await receiver.sendSaved('s');
        await settle();
        expect(fromDesktop, isEmpty);

        // The desktop app restarts before the phone comes back.
        await receiver.dispose();
        receiver = newReceiver()..start();
        setLinkUp(pair, true);
        await settle();

        expect(fromDesktop.map((e) => e.runtimeType), [
          DesktopHandoverResult,
          DesktopHandoverSaved,
        ]);
        await sender.acknowledge('s', HandoverMessage.result);
        await sender.acknowledge('s', HandoverMessage.saved);
        await settle();
        expect(prefs.getString(HandoverService.outboxKey), isNull);

        setLinkUp(pair, false);
        setLinkUp(pair, true);
        await settle();
        expect(fromDesktop, hasLength(2));
      },
    );

    test('a draft is sent once per session until it is forgotten', () async {
      await receiver.sendResult('s', draft);
      await sender.acknowledge('s', HandoverMessage.result);
      await receiver.sendResult('s', draft);
      await settle();
      expect(fromDesktop, hasLength(1));

      await receiver.forget('s');
      await receiver.sendResult('s', draft);
      await settle();
      expect(fromDesktop, hasLength(2));
    });

    test('the phone\'s save and cancel reach the desktop once', () async {
      setLinkUp(pair, false);
      await sender.reportSaved('a');
      await sender.withdraw('b');
      setLinkUp(pair, true);
      await settle();

      expect(received.map((e) => e.runtimeType), [
        IncomingHandoverSaved,
        IncomingHandoverCancelled,
      ]);
      expect(prefs.getString(HandoverSenderService.outboxKey), isNull);
    });
  });
}
