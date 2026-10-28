import 'dart:async';
import 'dart:convert';

import 'package:airdrop/airdrop.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/records/domain/entity/record_note/record_note.dart';
import 'package:health_wallet/features/records/domain/repository/records_repository.dart';
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
  bool killFails = false;
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
  Future<EphemeralRecordsContainer?> parsePayload(Uint8List bytes) async =>
      parsedContainer;

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
  Stream<void> get killSignalStream => const Stream.empty();
  @override
  Stream<int> get sessionExtendRequestStream => const Stream.empty();
  @override
  Stream<int> get sessionExtendAcceptedStream => const Stream.empty();
  @override
  Stream<void> get sessionExtendRejectedStream => const Stream.empty();
  @override
  Stream<void> get viewingStartedStream => const Stream.empty();
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeShareRecordsService service;
  late _FakeRecordsRepository repository;
  late ShareRecordsBloc bloc;

  final sharedNote = RecordNote(content: 'seen', timestamp: DateTime.utc(2026));
  EphemeralRecordsContainer container() => EphemeralRecordsContainer(
    sessionId: 'session-1',
    senderDeviceName: 'Pixel 8',
    receivedAt: DateTime.now(),
    viewDuration: const Duration(minutes: 5),
    records: [record(conditionJson(), id: 'c1')],
    notes: {
      'c1': [sharedNote],
    },
  );

  setUp(() {
    service = _FakeShareRecordsService()..parsedContainer = container();
    repository = _FakeRecordsRepository();
    getIt.registerSingleton<ReceiveModeService>(_FakeReceiveModeService());
    bloc = ShareRecordsBloc(service, repository, _FakePreferences())
      ..add(const ShareRecordsEvent.initialized());
  });

  tearDown(() async {
    await bloc.close();
    await service.close();
    await getIt.reset();
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

    test('a dropped link destroys open records and their files', () async {
      await receiveShare();
      await senderCode;
      await sender.confirm();
      await _until(() => bloc.state.phase == SharePhase.viewingRecords);

      service.sessionEnded.add(null);
      await _until(() => bloc.state.phase == SharePhase.sessionEnded);

      expect(bloc.state.receivedData, isNull);
      expect(service.calls, contains('deleteSessionFiles:session-1'));
      expect(repository.calls.last, 'clearSharedNotes');
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

    /// Sends one record and plays the receiver up to the confirmed codes.
    Future<void> shareAndConfirm() async {
      bloc
        ..add(const ShareRecordsEvent.sendModeSelected())
        ..add(
          ShareRecordsEvent.allRecordsSelected([
            record(conditionJson(), id: 'c1'),
          ]),
        );
      await _until(() => bloc.state.selection.isNotEmpty);
      bloc.add(const ShareRecordsEvent.peerSelected('peer-1'));
      await _until(() => service.sentEnvelope != null);

      receiver = SecureShareSession(service.peerEnd);
      addTearDown(receiver.dispose);
      final code = await receiver.open(service.sentEnvelope!);
      await _until(() => bloc.state.phase == SharePhase.verifyingCode);
      expect(bloc.state.verificationCode, code);

      bloc.add(const ShareRecordsEvent.verificationConfirmed());
      await _until(() => bloc.state.phase == SharePhase.awaitingViewer);
      await receiver.awaitPayload();
    }

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

    test('a dropped link after the codes match is not a decline', () async {
      await shareAndConfirm();

      service.sessionEnded.add(null);
      await _until(() => bloc.state.phase == SharePhase.sessionEnded);

      expect(bloc.state.statusMessage, 'Remote session terminated');
    });
  });
}
