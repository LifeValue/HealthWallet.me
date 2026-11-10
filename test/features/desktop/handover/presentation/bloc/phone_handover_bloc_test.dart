import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/features/desktop/communication/data/services/message_router.dart';
import 'package:health_wallet/features/desktop/handover/data/services/handover_sender_service.dart';
import 'package:health_wallet/features/desktop/handover/domain/entity/handover_protocol.dart';
import 'package:health_wallet/features/desktop/handover/presentation/bloc/phone_handover_bloc.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_patient.dart';
import 'package:health_wallet/features/processing/domain/entity/processing_session.dart';
import 'package:health_wallet/features/processing/domain/entity/staged_resource.dart';
import 'package:health_wallet/features/processing/presentation/bloc/processing_bloc.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../desktop_test_fakes.dart';
import '../../handover_test_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;
  late FakeTcpService tcp;
  late MessageRouter router;
  late HandoverSenderService sender;
  late FakeProcessingBloc processing;
  late PhoneHandoverBloc bloc;

  const draft = {
    'patient': {
      'draft': null,
      'existing': null,
      'mode': 'createNew',
    },
    'resources': <Object>[],
  };

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('phone_handover_bloc_test');
    // 'sent' was handed over in an earlier run of the app.
    SharedPreferences.setMockInitialValues({
      HandoverSenderService.handedOverKey: ['sent'],
    });
    tcp = FakeTcpService();
    router = MessageRouter(tcp);
    sender = HandoverSenderService(
      tcp,
      router,
      await SharedPreferences.getInstance(),
    );
    processing = FakeProcessingBloc(
      const ProcessingState(
        sessions: [
          ProcessingSession(
            id: 'sent',
            filePaths: ['sent.jpg'],
            status: ProcessingStatus.handedOver,
          ),
          ProcessingSession(id: 'queued-1', filePaths: ['a.jpg']),
          ProcessingSession(id: 'queued-2', filePaths: ['b.jpg']),
        ],
      ),
    );
    bloc = PhoneHandoverBloc(sender, processing)
      ..add(const PhoneHandoverInitialised());
    await settle();
  });

  tearDown(() async {
    await bloc.close();
    sender.dispose();
    router.dispose();
    await processing.close();
    await tcp.close();
    await dir.delete(recursive: true);
  });

  group('what the desktop reports', () {
    test('a draft is applied to its own session only', () async {
      tcp.deliver(HandoverMessage.result, {
        'session_id': 'sent',
        'draft': draft,
      });
      await settle();

      final applied = processing.events.whereType<HandoverDraftReceived>();
      expect(applied.single.sessionId, 'sent');
      // The documents waiting on the phone are left alone.
      expect(processing.events.whereType<SessionCleared>(), isEmpty);
      expect(tcp.sentOf(HandoverMessage.ack).single, {
        'session_id': 'sent',
        'type': HandoverMessage.result,
      });
    });

    test(
      'a result for a session the phone no longer has is acknowledged and '
      'dropped',
      () async {
        // What a desktop resends after the phone restarted.
        tcp.deliver(HandoverMessage.result, {
          'session_id': 'from-last-week',
          'draft': draft,
        });
        await settle();

        expect(processing.events, isEmpty);
        expect(
          tcp.sentOf(HandoverMessage.ack).single['session_id'],
          'from-last-week',
        );
      },
    );

    test('a failure brings the session back, saying why', () async {
      tcp
        ..deliver(HandoverMessage.failed, {
          'session_id': 'sent',
          'reason': 'model_not_found',
        })
        ..deliver(HandoverMessage.failed, {
          'session_id': 'queued-1',
          'reason': 'failed',
        });
      await settle();

      expect(
        processing.events.whereType<HandoverReturned>().map(
          (e) => (e.sessionId, e.reason),
        ),
        [
          ('sent', HandoverReturnReason.noModelOnDesktop),
          ('queued-1', HandoverReturnReason.failedOnDesktop),
        ],
      );
    });

    test('a delete on the desktop brings the session back', () async {
      tcp.deliver(HandoverMessage.cancel, {'session_id': 'sent'});
      await settle();

      expect(
        processing.events.whereType<HandoverReturned>().single.reason,
        HandoverReturnReason.deletedOnDesktop,
      );
      expect(
        tcp.sentOf(HandoverMessage.ack).single['type'],
        HandoverMessage.cancel,
      );
    });

    test(
      'a save on the desktop removes the phone\'s copy without telling the '
      'desktop it was deleted',
      () async {
        tcp.deliver(HandoverMessage.saved, {'session_id': 'sent'});
        await settle();
        expect(
          processing.events.whereType<SessionSavedElsewhere>().single.byDesktop,
          isTrue,
        );

        processing.push(
          const ProcessingState(
            sessions: [ProcessingSession(id: 'queued-1')],
          ),
        );
        await settle();
        expect(tcp.sentOf(HandoverMessage.cancel), isEmpty);
      },
    );

    test('progress is kept per session', () async {
      tcp.deliver(HandoverMessage.progress, {
        'session_id': 'sent',
        'progress': 0.4,
      });
      await settle();

      expect(bloc.state.desktopProgress, {'sent': 0.4});
    });
  });

  group('what the phone does', () {
    test('deleting a handed-over session withdraws it from the desktop', () {
      processing.push(
        const ProcessingState(sessions: [ProcessingSession(id: 'queued-1')]),
      );

      return expectLater(
        settle().then((_) => tcp.sentOf(HandoverMessage.cancel)),
        completion([
          {'session_id': 'sent'},
        ]),
      );
    });

    test('taking it back withdraws it and returns it', () async {
      bloc.add(const PhoneHandoverTakeBackRequested(sessionId: 'sent'));
      await settle();

      expect(tcp.sentOf(HandoverMessage.cancel).single['session_id'], 'sent');
      expect(
        processing.events.whereType<HandoverReturned>().single.reason,
        HandoverReturnReason.withdrawn,
      );
    });

    test('saving the desktop\'s draft here tells the desktop', () async {
      // Still a scan: it's the handed-over list that says where it went.
      const session = ProcessingSession(
        id: 'sent',
        status: ProcessingStatus.draft,
      );
      processing.push(const ProcessingState(sessions: [session]));
      await settle();
      processing
        ..push(
          const ProcessingState(
            status: PipelineStatus.success(sessionId: 'sent'),
            sessions: [session],
          ),
        )
        // The review closes and the session goes.
        ..push(const ProcessingState());
      await settle();

      expect(tcp.sentOf(HandoverMessage.saved).single['session_id'], 'sent');
      expect(tcp.sentOf(HandoverMessage.cancel), isEmpty);
      expect(bloc.state.handedOver, isEmpty);
    });

    test(
      'sessions not loaded yet at start-up are not taken for deleted ones',
      () async {
        final starting = FakeProcessingBloc();
        final restarted = PhoneHandoverBloc(sender, starting)
          ..add(const PhoneHandoverInitialised());
        await settle();
        expect(restarted.state.handedOver, {'sent'});

        starting.push(
          const ProcessingState(
            sessions: [
              ProcessingSession(
                id: 'sent',
                status: ProcessingStatus.handedOver,
              ),
            ],
          ),
        );
        await settle();
        expect(tcp.sentOf(HandoverMessage.cancel), isEmpty);
        expect(restarted.state.handedOver, {'sent'});

        await restarted.close();
        await starting.close();
      },
    );

    test(
      'a session is marked handed over once every file arrived, not before',
      () async {
        final file = File(p.join(dir.path, 'a.jpg'))..writeAsBytesSync([1]);
        processing.push(
          ProcessingState(
            sessions: [
              ProcessingSession(
                id: 'new',
                filePaths: [file.path],
                patient: const StagedPatient(draft: MappingPatient()),
              ),
            ],
          ),
        );
        tcp.onSend = (type, payload) async {
          if (type == HandoverMessage.offer) {
            expect(payload['phase1_data'], isNotNull);
            tcp.deliver(HandoverMessage.accept, {'session_id': 'new'});
          }
        };

        bloc.add(const PhoneHandoverSendRequested(sessionId: 'new'));
        await settle(60);

        expect(
          processing.events.whereType<SessionHandedOver>().single.sessionId,
          'new',
        );
        expect(bloc.state.transfers['new']!.progress, 1);
        // ('sent' isn't in this list any more, so it counts as deleted.)
        expect(bloc.state.handedOver, {'new'});
        expect(sender.handedOver, {'new'});
      },
    );

    test('a refused handover leaves the session on the phone', () async {
      final file = File(p.join(dir.path, 'a.jpg'))..writeAsBytesSync([1]);
      processing.push(
        ProcessingState(
          sessions: [
            ProcessingSession(id: 'new', filePaths: [file.path]),
          ],
        ),
      );
      tcp.onSend = (type, payload) async {
        if (type == HandoverMessage.offer) {
          expect(payload.containsKey('phase1_data'), isFalse);
          tcp.deliver(HandoverMessage.reject, {
            'session_id': 'new',
            'reason': 'version',
          });
        }
      };

      bloc.add(const PhoneHandoverSendRequested(sessionId: 'new'));
      await settle(60);

      expect(processing.events.whereType<SessionHandedOver>(), isEmpty);
    });
  });
}

Future<void> settle([int turns = 20]) async {
  for (var i = 0; i < turns; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}
