import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/features/desktop/communication/data/services/message_router.dart';
import 'package:health_wallet/features/desktop/handover/data/services/handover_service.dart';
import 'package:health_wallet/features/desktop/handover/domain/entity/handover_protocol.dart';
import 'package:health_wallet/features/desktop/handover/presentation/bloc/handover_bloc.dart';
import 'package:health_wallet/features/processing/domain/entity/processing_session.dart';
import 'package:health_wallet/features/processing/domain/entity/staged_resource.dart';
import 'package:health_wallet/features/processing/presentation/bloc/processing_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../../helpers/eventually.dart';
import '../../../desktop_test_fakes.dart';
import '../../handover_test_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  late FakeTcpService tcp;
  late MessageRouter router;
  late HandoverService service;
  late FakeProcessingBloc processing;
  late HandoverBloc bloc;

  /// Lets messages and file writes run; the files are real, so this waits a
  /// little real time, not just event-loop turns.
  Future<void> settle([int turns = 30]) async {
    for (var i = 0; i < turns; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }
  }

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('handover_bloc_test');
    SharedPreferences.setMockInitialValues({});
    tcp = FakeTcpService();
    router = MessageRouter(tcp);
    service = HandoverService(
      tcp,
      router,
      await SharedPreferences.getInstance(),
    )..temporaryDirectory = () async => tmp;
    processing = FakeProcessingBloc();
    bloc = HandoverBloc(service, processing)..add(const HandoverInitialised());
    await settle();
  });

  tearDown(() async {
    await bloc.close();
    router.dispose();
    await processing.close();
    await tcp.close();
    await tmp.delete(recursive: true);
  });

  /// The phone sends a one-page document.
  Future<void> receive(String id, {Map<String, dynamic>? phase1}) async {
    tcp
      ..deliver(HandoverMessage.offer, {
        'session_id': id,
        'v': HandoverProtocol.version,
        'files': [
          {'name': 'page.jpg', 'size': 2},
        ],
        'phase1_data': ?phase1,
      })
      ..deliver(HandoverMessage.chunk, {
        'session_id': id,
        'index': 0,
        'offset': 0,
        'data': base64Encode([1, 2]),
      });
    await eventually(
      () => processing.events.whereType<DocumentImported>().any(
        (e) => e.sessionId == id,
      ),
    );
  }

  ProcessingState withSessions(
    List<ProcessingSession> sessions, [
    PipelineStatus status = const PipelineStatus.initial(),
  ]) => ProcessingState(status: status, sessions: sessions);

  ProcessingSession handover(
    String id,
    ProcessingStatus status, {
    double progress = 0,
  }) => ProcessingSession(
    id: id,
    status: status,
    progress: progress,
    origin: ProcessingOrigin.handover,
  );

  test(
    'a received document becomes a session with the phone\'s id, and its '
    'files go once processing has them',
    () async {
      await receive(
        's1',
        phase1: {
          'patient': stagedPatientToJson(const StagedPatient()),
        },
      );

      final imported = processing.events.whereType<DocumentImported>().single;
      expect(imported.sessionId, 's1');
      expect(imported.origin, ProcessingOrigin.handover);
      expect(imported.phase1Patient, isNotNull);
      expect(File(imported.filePaths.single).readAsBytesSync(), [1, 2]);

      processing.push(
        withSessions([handover('s1', ProcessingStatus.patientExtracted)]),
      );
      await eventually(() => !File(imported.filePaths.single).existsSync());
    },
  );

  test('the phone\'s visit and report come with its patient step', () async {
    await receive(
      's1',
      phase1: {
        'patient': stagedPatientToJson(const StagedPatient()),
        'encounter': stagedEncounterToJson(const StagedEncounter()),
        'diagnosticReport': stagedDiagnosticReportToJson(
          const StagedDiagnosticReport(),
        ),
      },
    );

    final imported = processing.events.whereType<DocumentImported>().single;
    expect(imported.phase1Patient, isNotNull);
    expect(imported.phase1Encounter, isNotNull);
    expect(imported.phase1DiagnosticReport, isNotNull);
  });

  test('an unreadable patient step is read again from the document', () async {
    await receive(
      's1',
      phase1: {
        'patient': {'draft': 'not a patient'},
      },
    );

    final imported = processing.events.whereType<DocumentImported>().single;
    expect(imported.sessionId, 's1');
    expect(imported.phase1Patient, isNull);
    expect(imported.phase1Encounter, isNull);
  });

  test('a document that fails before its session exists reaches the phone '
      'as failed, and its files go', () async {
    await receive('s1');
    final imported = processing.events.whereType<DocumentImported>().single;

    processing.push(
      withSessions(
        [],
        const PipelineStatus.failure(error: 'x', sessionId: 's1'),
      ),
    );
    await eventually(() => tcp.sentOf(HandoverMessage.failed).isNotEmpty);

    expect(tcp.sentOf(HandoverMessage.failed), [
      {'session_id': 's1', 'reason': 'failed'},
    ]);
    await eventually(() => !File(imported.filePaths.single).existsSync());
  });

  test('a handover with no room to process reaches the phone as failed, '
      'others don\'t', () async {
    await receive('s1');
    final sessions = [handover('s1', ProcessingStatus.pending)];
    processing
      ..push(withSessions(sessions))
      ..push(
        withSessions(
          sessions,
          const PipelineStatus.capacityFailure(sessionId: 'mine'),
        ),
      )
      ..push(
        withSessions(
          sessions,
          const PipelineStatus.capacityFailure(sessionId: 's1'),
        ),
      );
    await eventually(() => tcp.sentOf(HandoverMessage.failed).isNotEmpty);
    await settle();

    expect(tcp.sentOf(HandoverMessage.failed), [
      {'session_id': 's1', 'reason': 'failed'},
    ]);
  });

  test(
    'progress, the draft and a save on the desktop reach the phone',
    () async {
      await receive('s1');
      processing
        ..push(
          withSessions([
            handover('s1', ProcessingStatus.processing, progress: 0.5),
          ]),
        )
        ..push(withSessions([handover('s1', ProcessingStatus.draft)]))
        ..push(
          withSessions(
            [handover('s1', ProcessingStatus.draft)],
            const PipelineStatus.success(sessionId: 's1'),
          ),
        )
        // The review closes and the session goes: not a delete.
        ..push(withSessions([]));
      // Received files are deleted first, so the messages wait on real I/O.
      await eventually(() => tcp.sentOf(HandoverMessage.saved).isNotEmpty);

      expect(tcp.sentOf(HandoverMessage.progress).single['progress'], 0.5);
      expect(tcp.sentOf(HandoverMessage.result).single['session_id'], 's1');
      expect(tcp.sentOf(HandoverMessage.saved).single['session_id'], 's1');
      expect(tcp.sentOf(HandoverMessage.cancel), isEmpty);
    },
  );

  test(
    'an earlier handover\'s draft is never sent as another one\'s result',
    () async {
      processing.push(withSessions([handover('old', ProcessingStatus.draft)]));
      await settle();
      await receive('s2');
      processing.push(
        withSessions([
          handover('s2', ProcessingStatus.pending),
          handover('old', ProcessingStatus.draft),
        ]),
      );
      await settle();

      expect(
        tcp.sentOf(HandoverMessage.result).map((r) => r['session_id']),
        ['old'],
      );
    },
  );

  test('only failures of a handover\'s own session reach the phone', () async {
    await receive('s1');
    final sessions = [handover('s1', ProcessingStatus.pending)];
    processing
      ..push(withSessions(sessions))
      ..push(
        withSessions(
          sessions,
          const PipelineStatus.failure(error: 'x', sessionId: 'mine'),
        ),
      )
      ..push(
        withSessions(
          sessions,
          const PipelineStatus.failure(
            error: 'x',
            reason: PipelineFailureReason.modelNotFound,
            sessionId: 's1',
          ),
        ),
      );
    await eventually(() => tcp.sentOf(HandoverMessage.failed).isNotEmpty);
    await settle();

    expect(tcp.sentOf(HandoverMessage.failed), [
      {'session_id': 's1', 'reason': 'model_not_found'},
    ]);
  });

  test('a session deleted on the desktop goes back to the phone', () async {
    await receive('s1');
    processing
      ..push(withSessions([handover('s1', ProcessingStatus.draft)]))
      ..push(withSessions([]));
    await eventually(() => tcp.sentOf(HandoverMessage.cancel).isNotEmpty);

    expect(tcp.sentOf(HandoverMessage.cancel).single['session_id'], 's1');
  });

  test('the phone saving removes the desktop\'s draft quietly', () async {
    processing.push(withSessions([handover('s1', ProcessingStatus.draft)]));
    await settle();
    tcp.deliver(HandoverMessage.saved, {'session_id': 's1'});
    await settle();

    final saved = processing.events.whereType<SessionSavedElsewhere>().single;
    expect((saved.sessionId, saved.byDesktop), ('s1', false));

    processing.push(withSessions([]));
    await settle();
    expect(tcp.sentOf(HandoverMessage.cancel), isEmpty);
  });

  test('the phone taking it back removes the desktop\'s session as taken '
      'back, not as a plain clear', () async {
    processing.push(withSessions([handover('s1', ProcessingStatus.pending)]));
    await settle();
    tcp.deliver(HandoverMessage.cancel, {'session_id': 's1'});
    await settle();

    expect(
      processing.events.whereType<SessionTakenBack>().single.sessionId,
      's1',
    );
    expect(processing.events.whereType<SessionCleared>(), isEmpty);
  });

  test('a transfer shows while it arrives and goes when it is done', () async {
    tcp.deliver(HandoverMessage.offer, {
      'session_id': 's1',
      'v': HandoverProtocol.version,
      'files': [
        {'name': 'page.jpg', 'size': 2},
      ],
    });
    await eventually(() => bloc.state.transfers.isNotEmpty);
    expect(bloc.state.transfers.keys, ['s1']);

    tcp.deliver(HandoverMessage.chunk, {
      'session_id': 's1',
      'index': 0,
      'offset': 0,
      'data': base64Encode([1, 2]),
    });
    await eventually(() => bloc.state.transfers.isEmpty);
  });
}
