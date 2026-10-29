import 'dart:async';
import 'dart:convert';

import 'package:airdrop/airdrop.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/records/domain/entity/record_note/record_note.dart';
import 'package:health_wallet/features/records/domain/repository/records_repository.dart';
import 'package:health_wallet/features/share_records/core/ephemeral_session_manager.dart';
import 'package:health_wallet/features/share_records/data/service/secure_share_session.dart';
import 'package:health_wallet/features/share_records/data/service/share_preferences_service.dart';
import 'package:health_wallet/features/share_records/data/service/share_records_service.dart';
import 'package:health_wallet/features/share_records/domain/entity/entity.dart';
import 'package:health_wallet/features/share_records/domain/services/receive_mode_service.dart';
import 'package:health_wallet/features/share_records/presentation/bloc/share_records_bloc.dart';
import 'package:health_wallet/features/share_records/presentation/bloc/share_records_event.dart';
import 'package:health_wallet/features/share_records/presentation/bloc/share_records_state.dart';

import '../../../../fixtures/fhir/fhir_fixtures.dart';
import '../../share_test_helpers.dart';

/// One end of an in-memory message link between this phone and the peer.
class _End implements ShareMessageTransport {
  final _inbox = StreamController<Uint8List>.broadcast();
  late _End peer;

  @override
  Stream<Uint8List> get messages => _inbox.stream;

  @override
  Future<void> send(Uint8List message) async => peer._inbox.add(message);

  Future<void> close() => _inbox.close();
}

/// The plugin-facing service, with the other phone's messages wired to
/// [peerEnd] and every call the bloc makes recorded in [calls].
class _FakeShareRecordsService extends Fake implements ShareRecordsService {
  final local = _End();
  final peerEnd = _End();
  final calls = <String>[];
  final receivedData = StreamController<ReceivedData>.broadcast();
  final sessionEnded = StreamController<void>.broadcast();
  final killSignal = StreamController<void>.broadcast();
  final viewingStarted = StreamController<void>.broadcast();
  bool killFails = false;

  /// While set, [parsePayload] waits for it: the window in which a cancel
  /// can land after the key arrived but before the records open.
  Completer<void>? parseGate;
  Uint8List? sentEnvelope;
  EphemeralRecordsContainer? parsedContainer;

  _FakeShareRecordsService() {
    local.peer = peerEnd;
    peerEnd.peer = local;
  }

  Future<void> close() async {
    await local.close();
    await peerEnd.close();
    await receivedData.close();
    await sessionEnded.close();
    await killSignal.close();
    await viewingStarted.close();
  }

  @override
  SecureShareSession createSecureSession() => SecureShareSession(local);

  @override
  Future<SharePayload> createPayload({
    required List<IFhirResource> resources,
    required String deviceName,
    int expiresInSeconds = 300,
    Map<String, List<RecordNote>> notesMap = const {},
    List<String> activeFilters = const [],
  }) async => SharePayload(
    id: 'payload-1',
    timestamp: DateTime.utc(2026),
    senderDeviceName: deviceName,
    bundle: const SharePayloadBundle(entry: []),
  );

  @override
  Future<String?> prepareFilesForSending(
    SharePayload payload,
    SecureShareSession session,
  ) async {
    sentEnvelope = await session.seal(utf8.encode('{"id":"payload-1"}'));
    return '/tmp/share_payload-1.bin';
  }

  @override
  Future<EphemeralRecordsContainer?> parsePayload(Uint8List bytes) async {
    calls.add('parsePayload');
    await parseGate?.future;
    return parsedContainer;
  }

  @override
  Future<void> deleteSessionFiles(String sessionId) async =>
      calls.add('deleteSessionFiles:$sessionId');

  @override
  Future<void> cleanupTempFile(String filePath) async =>
      calls.add('cleanupTempFile');

  @override
  Future<void> sendKillSignal() async {
    calls.add('sendKillSignal');
    if (killFails) throw StateError('peer unreachable');
  }

  @override
  Future<void> disconnect() async => calls.add('disconnect');

  @override
  Future<void> selectPeer(String deviceId) async => calls.add('selectPeer');

  @override
  Future<void> sendViewingStarted() async => calls.add('sendViewingStarted');

  @override
  Future<void> startSymmetricDiscovery() async {}

  @override
  Stream<ReceivedData> get receivedDataStream => receivedData.stream;

  @override
  Stream<void> get sessionEndedStream => sessionEnded.stream;

  @override
  Stream<TransferProgress> get progressStream => const Stream.empty();
  @override
  Stream<TransferStatus> get statusStream => const Stream.empty();
  @override
  Stream<Map<String, dynamic>> get peerDiscoveryStream => const Stream.empty();
  @override
  Stream<Map<String, dynamic>> get invitationStream => const Stream.empty();
  @override
  Stream<List<String>> get receivedFilesStream => const Stream.empty();
  @override
  Stream<void> get killSignalStream => killSignal.stream;
  @override
  Stream<int> get sessionExtendRequestStream => const Stream.empty();
  @override
  Stream<int> get sessionExtendAcceptedStream => const Stream.empty();
  @override
  Stream<void> get sessionExtendRejectedStream => const Stream.empty();
  @override
  Stream<void> get viewingStartedStream => viewingStarted.stream;
  @override
  Stream<void> get invitationRejectedStream => const Stream.empty();
  @override
  Stream<void> get wifiToggleNeededStream => const Stream.empty();
  @override
  Stream<Map<String, dynamic>> get connectionHealthStream =>
      const Stream.empty();
}

class _FakeRecordsRepository extends Fake implements RecordsRepository {
  final calls = <String>[];
  Map<String, List<RecordNote>>? sharedNotes;

  @override
  Future<List<IFhirResource>> getRelatedResources({
    required IFhirResource resource,
  }) async => [];

  @override
  Future<List<RecordNote>> getRecordNotes(String resourceId) async => [];

  @override
  void showSharedNotes(Map<String, List<RecordNote>> notes) {
    calls.add('showSharedNotes');
    sharedNotes = notes;
  }

  @override
  void clearSharedNotes() {
    calls.add('clearSharedNotes');
    sharedNotes = null;
  }
}

class _FakePreferences extends Fake implements SharePreferencesService {
  @override
  Future<Duration> getDefaultViewingDuration() async =>
      const Duration(minutes: 5);
}

class _FakeReceiveModeService extends Fake implements ReceiveModeService {
  @override
  bool get isListening => false;
}

/// Waits for [condition] while the bloc, isolates and streams make progress.
Future<void> _until(bool Function() condition) async {
  for (var i = 0; i < 300 && !condition(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  expect(condition(), isTrue, reason: 'condition not reached in time');
}

/// Moves the app through the lifecycle as the platform would, so the bloc
/// and the session manager both hear it.
void _lifecycle(AppLifecycleState state) =>
    TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(state);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeShareRecordsService service;
  late _FakeRecordsRepository repository;
  late ShareRecordsBloc bloc;

  final sharedNote = RecordNote(content: 'seen', timestamp: DateTime.utc(2026));
  EphemeralRecordsContainer container({
    Duration viewDuration = const Duration(minutes: 5),
  }) => EphemeralRecordsContainer(
    sessionId: 'session-1',
    senderDeviceName: 'Pixel 8',
    receivedAt: DateTime.now(),
    viewDuration: viewDuration,
    records: [record(conditionJson(), id: 'c1')],
    notes: {
      'c1': [sharedNote],
    },
  );

  setUp(() {
    _lifecycle(AppLifecycleState.resumed);
    service = _FakeShareRecordsService()..parsedContainer = container();
    repository = _FakeRecordsRepository();
    getIt.registerSingleton<ReceiveModeService>(_FakeReceiveModeService());
    bloc = ShareRecordsBloc(service, repository, _FakePreferences())
      ..add(const ShareRecordsEvent.initialized());
  });

  tearDown(() async {
    if (!bloc.isClosed) await bloc.close();
    await service.close();
    await getIt.reset();
    _lifecycle(AppLifecycleState.resumed);
  });

  group('receiver', () {
    late SecureShareSession sender;
    late Future<String> senderCode;

    /// Plays the sender: transfers an envelope and answers the key exchange.
    Future<void> receiveShare() async {
      sender = SecureShareSession(service.peerEnd);
      addTearDown(sender.dispose);
      final envelope = await sender.seal(utf8.encode('{"id":"x"}'));
      senderCode = sender.awaitReceiver();
      service.receivedData.add(
        ReceivedData(
          fileName: 'share.bin',
          data: envelope,
          totalFiles: 1,
          currentFile: 1,
        ),
      );
      await _until(() => bloc.state.phase == SharePhase.verifyingCode);
    }

    /// Receives a share and confirms the codes, so the records are open.
    Future<void> openShare() async {
      await receiveShare();
      await senderCode;
      await sender.confirm();
      await _until(() => bloc.state.phase == SharePhase.viewingRecords);
    }

    /// The records, their files and their notes are all gone.
    void expectDestroyed() {
      expect(bloc.state.phase, SharePhase.sessionEnded);
      expect(bloc.state.receivedData, isNull);
      expect(bloc.state.isDataDestroyed, isTrue);
      expect(EphemeralSessionManager.instance.hasActiveSession, isFalse);
      expect(service.calls, contains('deleteSessionFiles:session-1'));
      expect(repository.calls.last, 'clearSharedNotes');
    }

    test('opens the records after the sender confirms the code', () async {
      await receiveShare();
      expect(await senderCode, bloc.state.verificationCode);

      await sender.confirm();
      await _until(() => bloc.state.phase == SharePhase.viewingRecords);

      expect(bloc.state.receivedData?.sessionId, 'session-1');
      expect(bloc.state.verificationCode, isNull);
      expect(repository.sharedNotes?['c1'], [sharedNote]);
      expect(service.calls, contains('sendViewingStarted'));
    });

    group('session end', () {
      test('the sender ending the session destroys the records', () async {
        await openShare();

        service.killSignal.add(null);
        await _until(() => bloc.state.phase == SharePhase.sessionEnded);

        expectDestroyed();
      });

      test('a dropped link destroys open records and their files', () async {
        await openShare();

        service.sessionEnded.add(null);
        await _until(() => bloc.state.phase == SharePhase.sessionEnded);

        expectDestroyed();
      });

      test('leaving asks first, then tells the sender', () async {
        await openShare();

        bloc.add(const ShareRecordsEvent.navigationExitDetected());
        await _until(() => bloc.state.showExitConfirmationDialog);
        bloc.add(const ShareRecordsEvent.continueViewing());
        await _until(() => !bloc.state.showExitConfirmationDialog);
        expect(bloc.state.phase, SharePhase.viewingRecords);

        bloc.add(const ShareRecordsEvent.dataDestructionConfirmed());
        await _until(() => bloc.state.phase == SharePhase.sessionEnded);

        expectDestroyed();
        expect(service.calls, contains('sendKillSignal'));
      });
    });

    group('expiry', () {
      test(
        'the records are destroyed when the viewing time runs out',
        () async {
          service.parsedContainer = container(
            viewDuration: const Duration(seconds: 1),
          );
          await openShare();

          await _until(() => bloc.state.phase == SharePhase.sessionEnded);

          expectDestroyed();
        },
      );
    });

    group('backgrounding', () {
      test('leaving the app destroys open records', () async {
        await openShare();

        _lifecycle(AppLifecycleState.inactive);
        _lifecycle(AppLifecycleState.hidden);
        _lifecycle(AppLifecycleState.paused);
        await _until(() => bloc.state.phase == SharePhase.sessionEnded);

        expectDestroyed();
      });

      test('Control Center or a system prompt keeps the records', () async {
        await openShare();

        _lifecycle(AppLifecycleState.inactive);
        await Future<void>.delayed(const Duration(milliseconds: 200));

        expect(bloc.state.phase, SharePhase.viewingRecords);
        expect(EphemeralSessionManager.instance.hasActiveSession, isTrue);
      });

      test('leaving while comparing codes keeps the records closed', () async {
        await receiveShare();
        await senderCode;

        _lifecycle(AppLifecycleState.inactive);
        _lifecycle(AppLifecycleState.hidden);
        await _until(() => bloc.state.phase == SharePhase.sessionEnded);
        await sender.confirm().catchError((_) {});
        await Future<void>.delayed(const Duration(milliseconds: 200));

        expect(bloc.state.phase, SharePhase.sessionEnded);
        expect(bloc.state.receivedData, isNull);
        expect(repository.calls, isNot(contains('showSharedNotes')));
      });
    });

    group('cancel', () {
      test('a cancel while comparing codes keeps the records closed', () async {
        await receiveShare();
        await senderCode;

        bloc.add(const ShareRecordsEvent.dataDestructionConfirmed());
        await _until(() => bloc.state.phase == SharePhase.sessionEnded);
        await sender.confirm().catchError((_) {});
        await Future<void>.delayed(const Duration(milliseconds: 200));

        expect(bloc.state.phase, SharePhase.sessionEnded);
        expect(bloc.state.receivedData, isNull);
        expect(repository.calls, isNot(contains('showSharedNotes')));
        expect(service.calls, contains('sendKillSignal'));
      });

      test('a cancel while decrypting keeps the records closed', () async {
        service.parseGate = Completer<void>();
        await receiveShare();
        await senderCode;
        await sender.confirm();
        await _until(() => service.calls.contains('parsePayload'));

        bloc.add(const ShareRecordsEvent.dataDestructionConfirmed());
        await _until(() => bloc.state.phase == SharePhase.sessionEnded);
        service.parseGate!.complete();
        await _until(
          () => service.calls.contains('deleteSessionFiles:session-1'),
        );
        await Future<void>.delayed(const Duration(milliseconds: 100));

        expect(bloc.state.phase, SharePhase.sessionEnded);
        expect(bloc.state.receivedData, isNull);
        expect(EphemeralSessionManager.instance.hasActiveSession, isFalse);
        expect(repository.calls, isNot(contains('showSharedNotes')));
      });
    });

    group('cleanup', () {
      test('closing the screen destroys open records', () async {
        await openShare();

        await bloc.close();

        expect(EphemeralSessionManager.instance.hasActiveSession, isFalse);
        expect(service.calls, contains('deleteSessionFiles:session-1'));
        expect(repository.calls.last, 'clearSharedNotes');
        expect(service.calls.last, 'disconnect');
      });
    });
  });

  group('peer list', () {
    PeerDevice peer(String id, String name) =>
        PeerDevice(deviceId: id, deviceName: name, osType: 'ios');

    test('keeps two iPhones with the same name apart', () async {
      bloc
        ..add(ShareRecordsEvent.peerDiscovered(peer('mpc_a', 'iPhone')))
        ..add(ShareRecordsEvent.peerDiscovered(peer('mpc_b', 'iPhone')));
      await _until(() => bloc.state.discoveredPeers.length == 2);

      expect(bloc.state.discoveredPeers.map((p) => p.deviceId), [
        'mpc_a',
        'mpc_b',
      ]);
    });

    test('merges one phone seen over BLE and MPC under its MPC id', () async {
      bloc
        ..add(ShareRecordsEvent.peerDiscovered(peer('mpc_a', 'iPhone')))
        ..add(
          ShareRecordsEvent.peerDiscovered(peer('ble-uuid-1', 'iPhone')),
        );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(bloc.state.discoveredPeers.map((p) => p.deviceId), ['mpc_a']);
    });
  });

  group('sender', () {
    late SecureShareSession receiver;
    late String code;

    /// Sends one record and plays the receiver up to showing the code.
    Future<void> shareUntilCode({Duration? viewingDuration}) async {
      bloc
        ..add(const ShareRecordsEvent.sendModeSelected())
        ..add(
          ShareRecordsEvent.allRecordsSelected([
            record(conditionJson(), id: 'c1'),
          ]),
        );
      if (viewingDuration != null) {
        bloc.add(ShareRecordsEvent.viewingDurationChanged(viewingDuration));
      }
      await _until(() => bloc.state.selection.isNotEmpty);
      bloc.add(const ShareRecordsEvent.peerSelected('peer-1'));
      await _until(() => service.sentEnvelope != null);

      receiver = SecureShareSession(service.peerEnd);
      addTearDown(receiver.dispose);
      code = await receiver.open(service.sentEnvelope!);
      await _until(() => bloc.state.phase == SharePhase.verifyingCode);
    }

    /// Continues to the confirmed codes, with the key delivered.
    Future<void> shareAndConfirm({Duration? viewingDuration}) async {
      await shareUntilCode(viewingDuration: viewingDuration);
      expect(bloc.state.verificationCode, code);

      bloc.add(const ShareRecordsEvent.verificationConfirmed());
      await _until(() => bloc.state.phase == SharePhase.awaitingViewer);
      await receiver.awaitPayload();
    }

    /// Continues until the receiver reports it opened the records.
    Future<void> shareUntilViewing({Duration? viewingDuration}) async {
      await shareAndConfirm(viewingDuration: viewingDuration);
      service.viewingStarted.add(null);
      await _until(() => bloc.state.phase == SharePhase.monitoringSession);
    }

    group('session end', () {
      test(
        'ending the session after the codes match kills it remotely',
        () async {
          await shareAndConfirm();

          bloc.add(const ShareRecordsEvent.killSessionRequested());
          await _until(() => bloc.state.phase == SharePhase.sessionEnded);

          expect(service.calls, contains('sendKillSignal'));
          expect(bloc.state.remoteEndUnconfirmed, isFalse);
        },
      );

      test('an undelivered kill is reported to the sender', () async {
        await shareAndConfirm();
        service.killFails = true;

        bloc.add(const ShareRecordsEvent.killSessionRequested());
        await _until(() => bloc.state.phase == SharePhase.sessionEnded);

        expect(bloc.state.remoteEndUnconfirmed, isTrue);
      });

      test('a dropped link before the codes match is a decline', () async {
        await shareUntilCode();

        service.sessionEnded.add(null);
        await _until(() => bloc.state.phase == SharePhase.sessionEnded);

        expect(bloc.state.statusMessage, 'Receiver declined invitation');
      });

      test('a dropped link after the codes match is not a decline', () async {
        await shareAndConfirm();

        service.sessionEnded.add(null);
        await _until(() => bloc.state.phase == SharePhase.sessionEnded);

        expect(bloc.state.statusMessage, 'Remote session terminated');
      });

      test('the receiver leaving ends the monitored session', () async {
        await shareUntilViewing();

        service.sessionEnded.add(null);
        await _until(() => bloc.state.phase == SharePhase.sessionEnded);

        expect(bloc.state.statusMessage, 'Remote session terminated');
        expect(bloc.state.isSessionActive, isFalse);
      });
    });

    group('expiry', () {
      test('the countdown running out also ends it remotely', () async {
        await shareUntilViewing(viewingDuration: const Duration(seconds: 1));
        expect(bloc.state.sessionStartedAt, isNotNull);

        await _until(() => bloc.state.phase == SharePhase.sessionEnded);
        expect(bloc.state.statusMessage, 'Session expired');
        await _until(() => service.calls.last == 'disconnect');

        expect(service.calls, contains('sendKillSignal'));
      });
    });

    group('backgrounding', () {
      test('locking the screen keeps the session', () async {
        await shareAndConfirm();

        _lifecycle(AppLifecycleState.inactive);
        _lifecycle(AppLifecycleState.hidden);
        _lifecycle(AppLifecycleState.paused);
        await Future<void>.delayed(const Duration(milliseconds: 200));

        expect(bloc.state.phase, SharePhase.awaitingViewer);
        expect(service.calls, isNot(contains('sendKillSignal')));
      });
    });

    group('cleanup', () {
      test('closing the screen deletes the encrypted file', () async {
        await shareAndConfirm();

        await bloc.close();

        expect(service.calls, contains('cleanupTempFile'));
        expect(service.calls.last, 'disconnect');
      });
    });
  });
}
