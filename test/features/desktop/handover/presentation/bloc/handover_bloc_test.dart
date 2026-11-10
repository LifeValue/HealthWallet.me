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

  /// Waits until [done] holds; fails after a few seconds.
  Future<void> until(bool Function() done) async {
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (!done()) {
      if (DateTime.now().isAfter(deadline)) fail('timed out waiting');
      await Future<void>.delayed(const Duration(milliseconds: 5));
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
    await until(
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
      await until(() => !File(imported.filePaths.single).existsSync());
    },
  );

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
      await settle();

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
    await settle();

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

  test('the phone taking it back clears the desktop\'s session', () async {
    processing.push(withSessions([handover('s1', ProcessingStatus.pending)]));
    await settle();
    tcp.deliver(HandoverMessage.cancel, {'session_id': 's1'});
    await settle();

    expect(
      processing.events.whereType<SessionCleared>().single.session.id,
      's1',
    );
  });

  test('a transfer shows while it arrives and goes when it is done', () async {
    tcp.deliver(HandoverMessage.offer, {
      'session_id': 's1',
      'v': HandoverProtocol.version,
      'files': [
        {'name': 'page.jpg', 'size': 2},
      ],
    });
    await settle();
    expect(bloc.state.transfers.keys, ['s1']);

    tcp.deliver(HandoverMessage.chunk, {
      'session_id': 's1',
      'index': 0,
      'offset': 0,
      'data': base64Encode([1, 2]),
    });
    await until(() => bloc.state.transfers.isEmpty);
  });
}
