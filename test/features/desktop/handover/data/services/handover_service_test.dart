import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/features/desktop/communication/data/services/message_router.dart';
import 'package:health_wallet/features/desktop/handover/data/services/handover_service.dart';
import 'package:health_wallet/features/desktop/handover/domain/entity/handover_session.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_encounter.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_patient.dart';
import 'package:health_wallet/features/processing/domain/entity/processing_session.dart';
import 'package:health_wallet/features/processing/domain/entity/staged_resource.dart';
import 'package:health_wallet/features/processing/presentation/bloc/processing_bloc.dart';
import 'package:path/path.dart' as p;

import '../../../desktop_test_fakes.dart';
import '../../handover_test_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory docs;
  late FakeTcpService tcp;
  late MessageRouter router;
  late FakeProcessingBloc bloc;
  late HandoverService service;
  late List<HandoverSession> offers;
  late List<String> filesReceived;
  late List<String> completed;
  late List<HandoverSession> updates;
  late StreamSubscription<HandoverSession> updatesSub;

  setUp(() async {
    docs = await Directory.systemTemp.createTemp('handover_service_test');
    mockPathProvider(docs);
    tcp = FakeTcpService();
    router = MessageRouter(tcp);
    bloc = FakeProcessingBloc();
    service = HandoverService(router, tcp, bloc);
    offers = [];
    filesReceived = [];
    completed = [];
    updates = [];
    updatesSub = service.sessionUpdates.listen(updates.add);
    service.startListening(
      onOfferReceived: offers.add,
      onFileReceived: filesReceived.add,
      onProcessingComplete: completed.add,
    );
  });

  tearDown(() async {
    await updatesSub.cancel();
    service.dispose();
    router.dispose();
    await bloc.close();
    await tcp.close();
    clearPathProviderMock();
    await docs.delete(recursive: true);
  });

  Future<HandoverSession> nextUpdate(bool Function(HandoverSession) test) =>
      service.sessionUpdates
          .firstWhere(test)
          .timeout(const Duration(seconds: 10));

  Future<void> offer(
    String sessionId,
    int fileCount, {
    Map<String, dynamic>? phase1,
  }) async {
    final received = nextUpdate((s) => s.sessionId == sessionId);
    tcp.deliver('handover.offer', {
      'session_id': sessionId,
      'file_count': fileCount,
      'total_bytes': 0,
      'phase1_data': ?phase1,
    });
    await received;
  }

  /// Delivers one file and waits until it is written (or failed).
  Future<HandoverSession> sendFile(
    String sessionId,
    int index,
    String name,
    List<int> bytes,
  ) {
    final written = nextUpdate(
      (s) =>
          s.sessionId == sessionId &&
          (s.receivedCount > index || s.status == HandoverStatus.error),
    );
    tcp.deliver('handover.file', {
      'session_id': sessionId,
      'file_index': index,
      'file_name': name,
      'data': base64Encode(bytes),
    });
    return written;
  }

  Future<DocumentImported> imported() => bloc.addedEvents
      .firstWhere((e) => e is DocumentImported)
      .then((e) => e as DocumentImported)
      .timeout(const Duration(seconds: 10));

  Future<DocumentImported> receiveAll(
    String sessionId,
    List<List<int>> files, {
    Map<String, dynamic>? phase1,
  }) async {
    await offer(sessionId, files.length, phase1: phase1);
    final started = imported();
    for (var i = 0; i < files.length; i++) {
      await sendFile(sessionId, i, 'page$i.jpg', files[i]);
    }
    return started;
  }

  ProcessingState stateWith(
    ProcessingStatus status, {
    double progress = 0,
    PipelineStatus pipeline = const PipelineStatus.initial(),
    ProcessingOrigin origin = ProcessingOrigin.handover,
  }) => ProcessingState(
    status: pipeline,
    sessions: [
      ProcessingSession(
        id: 'proc-1',
        status: status,
        progress: progress,
        origin: origin,
      ),
    ],
  );

  List<Map<String, dynamic>> sentFor(String type) => tcp.sentOf(type);

  group('offer', () {
    test('accepts it and reports a receiving session', () async {
      await offer('s1', 3);

      expect(sentFor('handover.accept'), [
        {'session_id': 's1'},
      ]);
      expect(
        offers.single,
        const HandoverSession(sessionId: 's1', fileCount: 3),
      );
      expect(updates.single.status, HandoverStatus.receiving);
    });

    test('after stopListening offers are ignored', () async {
      service.stopListening();
      tcp.deliver('handover.offer', {'session_id': 's1', 'file_count': 1});
      await flushEvents();

      expect(offers, isEmpty);
      expect(tcp.sent, isEmpty);
    });
  });

  group('files', () {
    test('writes each file byte for byte and reports progress', () async {
      final page0 = randomBytes(300 * 1024, seed: 1);
      final page1 = randomBytes(10, seed: 2);
      await offer('s1', 2);

      final first = await sendFile('s1', 0, 'page0.jpg', page0);
      expect(first.receivedCount, 1);
      expect(first.progress, 0.25);
      expect(filesReceived, ['s1']);

      final started = imported();
      await sendFile('s1', 1, 'scan.final.png', page1);
      final event = await started;
      await flushEvents();

      expect(event.origin, ProcessingOrigin.handover);
      expect(event.phase1Patient, isNull);
      expect(event.filePaths, hasLength(2));
      expect(File(event.filePaths[0]).readAsBytesSync(), page0);
      expect(File(event.filePaths[1]).readAsBytesSync(), page1);
      for (final path in event.filePaths) {
        expect(p.dirname(path), p.join(docs.path, 'imports'));
      }
      expect(
        p.basename(event.filePaths[0]),
        matches(RegExp(r'^page0_\d+\.jpg$')),
      );
      expect(
        p.basename(event.filePaths[1]),
        matches(RegExp(r'^scan\.final_\d+\.png$')),
      );
      expect(updates.last.status, HandoverStatus.processing);
      expect(updates.last.progress, 0.5);
    });

    test('an empty file is stored as an empty file', () async {
      final event = await receiveAll('s1', [const []]);

      expect(File(event.filePaths.single).readAsBytesSync(), isEmpty);
    });

    test('a file for an unknown session is ignored', () async {
      tcp.deliver('handover.file', {
        'session_id': 'nobody',
        'file_index': 0,
        'file_name': 'a.jpg',
        'data': base64Encode([1]),
      });
      await flushEvents(50);

      expect(filesReceived, isEmpty);
      expect(Directory(p.join(docs.path, 'imports')).existsSync(), isFalse);
    });

    test('undecodable data fails the session and tells the phone', () async {
      await offer('s1', 1);
      final failed = nextUpdate((s) => s.status == HandoverStatus.error);
      tcp.deliver('handover.file', {
        'session_id': 's1',
        'file_index': 0,
        'file_name': 'a.jpg',
        'data': '%%% not base64 %%%',
      });

      final session = await failed;
      expect(session.error, contains('FormatException'));
      final progress = sentFor('handover.progress').single;
      expect(progress['session_id'], 's1');
      expect(progress['status'], 'error');
      expect(progress['error'], session.error);
      expect(bloc.events, isEmpty);
    });

    test(
      'a duplicated file message does not start processing early',
      () async {
        await offer('s1', 2);
        await sendFile('s1', 0, 'page0.jpg', [1]);
        await sendFile('s1', 0, 'page0.jpg', [1]);
        await flushEvents(50);

        expect(bloc.events, isEmpty);
      },
      skip:
          'BUG: file_index is ignored; receivedCount is the number of '
          'handover.file messages, so a duplicate makes the session start '
          'processing with one page twice and another page missing; a late '
          'extra file starts processing a second time '
          '(handover_service.dart:103-116).',
    );

    void deliverFile(String sessionId, int index, String name, List<int> b) {
      tcp.deliver('handover.file', {
        'session_id': sessionId,
        'file_index': index,
        'file_name': name,
        'data': base64Encode(b),
      });
    }

    test(
      'pages arriving back to back keep their order',
      () async {
        await offer('s1', 2);
        final started = imported();
        deliverFile('s1', 0, 'a.jpg', randomBytes(8 * 1024 * 1024));
        deliverFile('s1', 1, 'b.jpg', [2]);

        final event = await started;
        expect(event.filePaths.map(p.basename).map((n) => n[0]), ['a', 'b']);
      },
      skip:
          'BUG: files are appended to _receivedFiles when their async write '
          'finishes, not by file_index, so a large first page followed by a '
          'small second page is handed to processing as [page 2, page 1] '
          '(handover_service.dart:94-103).',
    );

    test(
      'two pages with the same file name are both kept',
      () async {
        await offer('s1', 2);
        final started = imported();
        deliverFile('s1', 0, 'scan.jpg', [1, 1, 1]);
        deliverFile('s1', 1, 'scan.jpg', [2, 2]);

        final event = await started;
        expect(event.filePaths.toSet(), hasLength(2));
        expect(File(event.filePaths[0]).readAsBytesSync(), [1, 1, 1]);
        expect(File(event.filePaths[1]).readAsBytesSync(), [2, 2]);
      },
      skip:
          'BUG: the stored name is <base>_<millisecond><ext>; two files with '
          'the same base name handled in the same millisecond get the same '
          'path, the second overwrites the first and processing gets one '
          'page twice (handover_service.dart:95-103).',
    );
  });

  group('phase 1 data', () {
    final phase1 = {
      'patient': stagedPatientToJson(const StagedPatient()),
      'encounter': stagedEncounterToJson(const StagedEncounter()),
      'diagnosticReport': stagedDiagnosticReportToJson(
        const StagedDiagnosticReport(),
      ),
    };

    test('is passed to processing', () async {
      final event = await receiveAll('s1', [
        [1],
      ], phase1: phase1);

      expect(event.phase1Patient, const StagedPatient());
      expect(event.phase1Encounter, const StagedEncounter());
      expect(event.phase1DiagnosticReport, const StagedDiagnosticReport());
    });

    test('patient alone is enough', () async {
      final event = await receiveAll(
        's1',
        [
          [1],
        ],
        phase1: {'patient': phase1['patient']},
      );

      expect(event.phase1Patient, isNotNull);
      expect(event.phase1Encounter, isNull);
      expect(event.phase1DiagnosticReport, isNull);
    });

    test(
      'runs step 2 once the patient is extracted, then sends results',
      () async {
        await receiveAll('s1', [
          [1],
        ], phase1: phase1);

        // Session created: with phase 1 data it is not activated yet.
        bloc.push(
          stateWith(
            ProcessingStatus.pending,
            pipeline: const PipelineStatus.sessionCreated(
              session: ProcessingSession(id: 'proc-1'),
            ),
          ),
        );
        await flushEvents();
        expect(bloc.events.whereType<SessionActivated>(), isEmpty);

        final remaining = bloc.addedEvents
            .firstWhere((e) => e is ProcessRemainingResources)
            .timeout(const Duration(seconds: 5));
        bloc
          ..push(stateWith(ProcessingStatus.patientExtracted))
          ..push(stateWith(ProcessingStatus.patientExtracted));
        expect(
          (await remaining as ProcessRemainingResources).sessionId,
          'proc-1',
        );
        expect(
          bloc.events.whereType<SessionActivated>().map((e) => e.sessionId),
          ['proc-1'],
        );
        // No step 1 result: the phone already has the patient.
        expect(sentFor('handover.step1_complete'), isEmpty);

        final done = nextUpdate((s) => s.status == HandoverStatus.complete);
        bloc.push(stateWith(ProcessingStatus.draft));
        await done;

        expect(
          updates.map((u) => u.status),
          contains(HandoverStatus.sendingResults),
        );
        expect(sentFor('handover.result'), [
          {'session_id': 's1', 'resources': <dynamic>[]},
        ]);
        expect(completed, ['s1']);
        expect(updates.last.progress, 1.0);
        expect(updates.last.receivedCount, 1);
      },
    );
  });

  group('processing without phase 1 data', () {
    setUp(() async {
      await receiveAll('s1', [
        [1],
        [2],
      ]);
    });

    test('activates the new session once it is created', () async {
      bloc.push(
        stateWith(
          ProcessingStatus.pending,
          pipeline: const PipelineStatus.sessionCreated(
            session: ProcessingSession(id: 'proc-1'),
          ),
        ),
      );
      await flushEvents();

      expect(
        bloc.events.whereType<SessionActivated>().map((e) => e.sessionId),
        ['proc-1'],
      );
    });

    test('forwards progress, scaled into 0.5..0.8', () async {
      bloc
        ..push(stateWith(ProcessingStatus.processingPatient, progress: 0.0))
        ..push(stateWith(ProcessingStatus.processing, progress: 0.5));
      await flushEvents();

      expect(sentFor('handover.progress'), [
        {'session_id': 's1', 'progress': 0.5, 'status': 'processing'},
        {'session_id': 's1', 'progress': 0.65, 'status': 'processing'},
      ]);
      expect(updates.last.progress, 0.65);
    });

    test(
      'reports step 1 when the patient is extracted and stops listening',
      () async {
        bloc.push(stateWith(ProcessingStatus.patientExtracted));
        await flushEvents();

        expect(sentFor('handover.step1_complete'), [
          {'session_id': 's1'},
        ]);
        expect(updates.last.status, HandoverStatus.complete);
        expect(updates.last.progress, 1.0);
        expect(completed, ['s1']);

        bloc.push(stateWith(ProcessingStatus.processing, progress: 0.9));
        await flushEvents();
        expect(sentFor('handover.progress'), isEmpty);
      },
    );

    test('a processing failure is reported to the phone', () async {
      bloc.push(
        stateWith(
          ProcessingStatus.pending,
          pipeline: const PipelineStatus.failure(error: 'model crashed'),
        ),
      );
      await flushEvents();

      expect(updates.last.status, HandoverStatus.error);
      expect(updates.last.error, 'model crashed');
      expect(updates.last.failure, HandoverFailure.failed);
      expect(sentFor('handover.progress').single, {
        'session_id': 's1',
        'progress': 0.5,
        'status': 'error',
        'error': 'model crashed',
      });
    });

    test('a missing model is sent to the phone with its reason', () async {
      const error = 'Exception: Model file not found';
      bloc.push(
        stateWith(
          ProcessingStatus.pending,
          pipeline: const PipelineStatus.failure(
            error: error,
            reason: PipelineFailureReason.modelNotFound,
          ),
        ),
      );
      await flushEvents();

      expect(updates.last.failure, HandoverFailure.modelNotFound);
      expect(sentFor('handover.progress').single, {
        'session_id': 's1',
        'progress': 0.5,
        'status': 'error',
        'error': error,
        'reason': HandoverFailure.modelNotFoundReason,
      });
    });

    test('states without a handover session are ignored', () async {
      bloc
        ..push(const ProcessingState())
        ..push(
          stateWith(ProcessingStatus.processing, origin: ProcessingOrigin.scan),
        );
      await flushEvents();

      expect(sentFor('handover.progress'), isEmpty);
      expect(bloc.events.whereType<SessionActivated>(), isEmpty);
    });

    test('resendPendingResults repeats the last result', () async {
      bloc.push(stateWith(ProcessingStatus.patientExtracted));
      await flushEvents();
      tcp.sent.clear();

      await service.resendPendingResults();

      expect(tcp.sent.map((s) => s.type), ['handover.step1_complete']);
      expect(tcp.sent.single.payload, {'session_id': 's1'});
    });

    test('a failing resend is swallowed', () async {
      bloc.push(stateWith(ProcessingStatus.patientExtracted));
      await flushEvents();
      tcp.onSend = (_, _) async => throw const SocketException('down');

      await expectLater(service.resendPendingResults(), completes);
    });
  });

  test(
    'a draft left over from an earlier handover is not sent as this result',
    () async {
      await receiveAll(
        's2',
        [
          [1],
        ],
        phase1: {'patient': stagedPatientToJson(const StagedPatient())},
      );

      // The new import has not produced its session yet; an older handover
      // session is still waiting in draft for review.
      bloc.push(
        const ProcessingState(
          status: PipelineStatus.loading(),
          sessions: [
            ProcessingSession(
              id: 'old-handover',
              status: ProcessingStatus.draft,
              origin: ProcessingOrigin.handover,
            ),
          ],
        ),
      );
      await flushEvents();

      expect(sentFor('handover.result'), isEmpty);
      expect(completed, isEmpty);
    },
    skip:
        'BUG: HandoverService picks the processing session with '
        'firstWhereOrNull(origin == handover), not the one its '
        'DocumentImported created, so an earlier handover draft is sent '
        'as the result of the new session id and the new session is marked '
        'complete (handover_service.dart:174-177, 218-220, 260-268).',
  );

  test('the result carries the drafted patient and encounter', () async {
    await receiveAll(
      's1',
      [
        [1],
      ],
      phase1: {'patient': stagedPatientToJson(const StagedPatient())},
    );
    final patient = MappingPatient.empty();
    final encounter = MappingEncounter.empty();

    final done = nextUpdate((s) => s.status == HandoverStatus.complete);
    bloc.push(
      ProcessingState(
        sessions: [
          ProcessingSession(
            id: 'proc-1',
            status: ProcessingStatus.draft,
            origin: ProcessingOrigin.handover,
            patient: StagedPatient(draft: patient),
            encounter: StagedEncounter(draft: encounter),
          ),
        ],
      ),
    );
    await done;

    final result = sentFor('handover.result').single;
    expect(result['patient'], jsonDecode(jsonEncode(patient.toJson())));
    expect(result['encounter'], jsonDecode(jsonEncode(encounter.toJson())));
  });

  test('a failure sending results marks the session as failed', () async {
    await receiveAll(
      's1',
      [
        [1],
      ],
      phase1: {'patient': stagedPatientToJson(const StagedPatient())},
    );
    tcp.onSend = (type, _) async {
      if (type == 'handover.result') throw const SocketException('down');
    };

    final failed = nextUpdate((s) => s.status == HandoverStatus.error);
    bloc.push(stateWith(ProcessingStatus.draft));

    expect((await failed).error, contains('down'));
    expect(completed, isEmpty);
  });

  test('nothing is resent before any result exists', () async {
    await service.resendPendingResults();

    expect(tcp.sent, isEmpty);
  });
}
