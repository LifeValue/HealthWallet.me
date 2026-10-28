import 'dart:io';

import 'package:airdrop/airdrop.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/l10n/app_strings_provider.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/records/domain/entity/record_note/record_note.dart';
import 'package:health_wallet/features/records/domain/repository/records_repository.dart';
import 'package:health_wallet/features/share_records/core/ephemeral_session_manager.dart';
import 'package:health_wallet/features/share_records/data/mapper/fhir_bundle_mapper.dart';
import 'package:health_wallet/features/share_records/data/service/share_preferences_service.dart';
import 'package:health_wallet/features/share_records/data/service/share_records_service.dart';
import 'package:health_wallet/features/share_records/domain/entity/entity.dart';
import 'package:health_wallet/features/share_records/domain/services/receive_mode_service.dart';
import 'package:health_wallet/features/share_records/domain/services/share_log_buffer.dart';
import 'package:health_wallet/features/share_records/presentation/bloc/share_records_bloc.dart';
import 'package:health_wallet/features/share_records/presentation/bloc/share_records_event.dart';
import 'package:health_wallet/features/share_records/presentation/bloc/share_records_state.dart';

import '../../../../fixtures/fhir/fhir_fixtures.dart';
import '../../share_test_helpers.dart';

const _sessionId = '3f2b8c1e-9a4d-4e6f-8b7a-1c2d3e4f5a6b';
const _payloadPath = '/tmp/share_payload.json';

/// Records the calls the BLoC makes; [preparedPath] is what
/// `prepareFilesForSending` returns (null for a failure).
class _FakeShareRecordsService extends Fake implements ShareRecordsService {
  String? preparedPath = _payloadPath;
  String? Function()? preparedPathFor;
  EphemeralRecordsContainer? parsed;
  final calls = <String>[];
  final cleanedFiles = <String>[];
  final cleanedSessions = <String>[];

  @override
  Future<void> disconnect() async => calls.add('disconnect');

  @override
  Future<void> selectPeer(String deviceId) async =>
      calls.add('selectPeer $deviceId');

  @override
  Future<void> startDiscovery({bool useBluetooth = true}) async =>
      calls.add('startDiscovery');

  @override
  Future<void> startSymmetricDiscovery() async =>
      calls.add('startSymmetricDiscovery');

  @override
  Future<void> startReceivingInMemory() async =>
      calls.add('startReceivingInMemory');

  @override
  Future<void> acceptInvitation(String invitationId) async =>
      calls.add('acceptInvitation $invitationId');

  @override
  Future<void> sendKillSignal() async => calls.add('sendKillSignal');

  @override
  Future<void> sendViewingStarted() async => calls.add('sendViewingStarted');

  @override
  Future<SharePayload> createPayload({
    required List<IFhirResource> resources,
    required String deviceName,
    int expiresInSeconds = 300,
    Map<String, List<RecordNote>> notesMap = const {},
    List<String> activeFilters = const [],
  }) => FhirBundleMapper.toSharePayload(
    records: resources,
    deviceName: deviceName,
    expiresInSeconds: expiresInSeconds,
  );

  @override
  Future<String?> prepareFilesForSending(SharePayload payload) async {
    calls.add('prepareFilesForSending');
    // Yields like the real file write, so concurrent handlers interleave.
    await Future<void>.delayed(Duration.zero);
    return preparedPathFor?.call() ?? preparedPath;
  }

  @override
  Future<void> cleanupTempFile(String filePath) async =>
      cleanedFiles.add(filePath);

  @override
  Future<void> cleanupSessionTempDir(String sessionId) async =>
      cleanedSessions.add(sessionId);

  @override
  Future<EphemeralRecordsContainer?> parseReceivedData(
    ReceivedData receivedData,
  ) async => parsed;

  @override
  Future<EphemeralRecordsContainer?> parseReceivedFile(String filePath) async =>
      parsed;
}

/// Related-resource and note lookups find nothing; note writes are recorded.
class _FakeRecordsRepository extends Fake implements RecordsRepository {
  final addedNotes = <String>[];
  final deletedNotes = <int>[];
  bool failNoteWrites = false;

  @override
  Future<List<IFhirResource>> getRelatedResources({
    required IFhirResource resource,
  }) async => [];

  @override
  Future<List<RecordNote>> getRecordNotes(String resourceId) async => [];

  @override
  Future<int> addRecordNote({
    required String resourceId,
    String? sourceId,
    required String content,
  }) async {
    if (failNoteWrites) throw StateError('db closed');
    addedNotes.add(content);
    return addedNotes.length;
  }

  @override
  Future<int> deleteRecordNote(RecordNote note) async {
    if (failNoteWrites) throw StateError('db closed');
    deletedNotes.add(note.id);
    return 1;
  }
}

class _FakeSharePreferencesService extends Fake
    implements SharePreferencesService {}

class _FakeReceiveModeService extends Fake implements ReceiveModeService {
  @override
  bool get isListening => false;
}

EphemeralRecordsContainer _container({
  Map<String, List<RecordNote>> notes = const {},
  List<IFhirResource>? records,
}) => EphemeralRecordsContainer(
  sessionId: _sessionId,
  senderDeviceName: 'Pixel',
  receivedAt: DateTime.now(),
  viewDuration: const Duration(minutes: 5),
  records: records ?? [record(observationJson(), id: 'o1')],
  notes: notes,
  tempAttachmentPaths: const [],
);

ReceivedData _data() => ReceivedData(
  fileName: 'share.json',
  data: Uint8List(0),
  totalFiles: 1,
  currentFile: 1,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory logs;
  late _FakeShareRecordsService service;
  late _FakeRecordsRepository repository;
  late ShareRecordsBloc bloc;
  var closed = false;

  setUp(() {
    logs = Directory.systemTemp.createTempSync('hw_share_bloc_');
    ShareLogBuffer.debugOverrideInstance(
      ShareLogBuffer.forTesting(enabled: false, directory: logs),
    );
    getIt.registerSingleton<ReceiveModeService>(_FakeReceiveModeService());
    service = _FakeShareRecordsService();
    repository = _FakeRecordsRepository();
    bloc = ShareRecordsBloc(
      service,
      repository,
      _FakeSharePreferencesService(),
      AppStringsProvider.forLocale(const Locale('en')),
    );
    closed = false;
  });

  tearDown(() async {
    if (!closed) await bloc.close();
    EphemeralSessionManager.instance.destroySession();
    await getIt.reset();
    ShareLogBuffer.debugOverrideInstance(null);
    logs.deleteSync(recursive: true);
  });

  Future<ShareRecordsState> settle() async {
    await pumpEventQueue();
    return bloc.state;
  }

  Future<void> closeBloc() async {
    closed = true;
    await bloc.close();
  }

  /// Puts the BLoC in send mode with one record selected and a peer chosen,
  /// so the payload has been written to temp.
  Future<void> selectPeerToSend() async {
    bloc
      ..add(const ShareRecordsEvent.sendModeSelected())
      ..add(
        ShareRecordsEvent.recordToggled(record(observationJson(), id: 'o1')),
      )
      ..add(
        const ShareRecordsEvent.peerDiscovered(
          PeerDevice(deviceId: 'a', deviceName: 'Pixel'),
        ),
      )
      ..add(const ShareRecordsEvent.peerSelected('a'));
    await settle();
  }

  group('sending', () {
    test('selecting a peer writes the payload and connects', () async {
      await selectPeerToSend();

      expect(bloc.state.phase, SharePhase.connecting);
      expect(bloc.state.selectedPeer?.deviceId, 'a');
      expect(
        service.calls,
        containsAllInOrder(['prepareFilesForSending', 'selectPeer a']),
      );
      expect(service.cleanedFiles, isEmpty);
    });

    test('a payload that cannot be written fails without connecting', () async {
      service.preparedPath = null;

      await selectPeerToSend();

      expect(bloc.state.phase, SharePhase.error);
      expect(bloc.state.errorMessage, isNotNull);
      expect(service.calls, isNot(contains('selectPeer a')));
    });

    test('selecting a peer again deletes the previous payload', () async {
      await selectPeerToSend();
      service.preparedPath = '/tmp/share_second.json';

      bloc.add(const ShareRecordsEvent.peerSelected('a'));
      await settle();

      expect(service.cleanedFiles, [_payloadPath]);
    });

    test('two quick peer selections run one after the other', () async {
      var prepared = 0;
      service.preparedPathFor = () => '/tmp/share_${++prepared}.json';
      bloc
        ..add(const ShareRecordsEvent.sendModeSelected())
        ..add(
          ShareRecordsEvent.recordToggled(record(observationJson(), id: 'o1')),
        )
        ..add(const ShareRecordsEvent.peerSelected('a'))
        ..add(const ShareRecordsEvent.peerSelected('a'));
      await settle();

      await closeBloc();

      // Concurrent handlers would both write before either deletes, leaking
      // the first payload.
      expect(service.cleanedFiles, ['/tmp/share_1.json', '/tmp/share_2.json']);
    });

    test('transfer started moves to transferring', () async {
      await selectPeerToSend();

      bloc.add(const ShareRecordsEvent.transferStarted());
      final state = await settle();

      expect(state.phase, SharePhase.transferring);
      expect(state.isSessionActive, isTrue);
    });

    test(
      'a completed transfer deletes the payload and waits for the receiver',
      () async {
        await selectPeerToSend();

        bloc.add(const ShareRecordsEvent.transferCompleted());
        final state = await settle();

        expect(service.cleanedFiles, [_payloadPath]);
        expect(state.phase, SharePhase.connecting);
        expect(state.isSessionActive, isTrue);
      },
    );

    test(
      'a completed transfer after viewing started monitors the session',
      () async {
        await selectPeerToSend();

        bloc
          ..add(const ShareRecordsEvent.transferStarted())
          ..add(const ShareRecordsEvent.viewingStartedReceived())
          ..add(const ShareRecordsEvent.transferCompleted());
        final state = await settle();

        expect(state.phase, SharePhase.monitoringSession);
        expect(state.sessionStartedAt, isNotNull);
        expect(service.cleanedFiles, [_payloadPath]);
      },
    );

    test('a failed connection is retried up to three times', () async {
      await selectPeerToSend();

      bloc.add(const ShareRecordsEvent.transferFailed('lost'));
      final state = await settle();

      expect(state.connectionRetryCount, 1);
      expect(state.phase, SharePhase.discoveringPeers);
      expect(service.calls.last, 'startDiscovery');
      expect(service.cleanedFiles, isEmpty);
    });

    test('a failed transfer that is not retried deletes the payload', () async {
      await selectPeerToSend();
      bloc.add(const ShareRecordsEvent.wifiToggleRequested());

      bloc.add(const ShareRecordsEvent.transferFailed('lost'));
      final state = await settle();

      expect(state.phase, SharePhase.error);
      expect(state.errorMessage, 'lost');
      expect(state.isSessionActive, isFalse);
      expect(service.cleanedFiles, [_payloadPath]);
    });

    test('a failure while selecting records is ignored', () async {
      bloc.add(const ShareRecordsEvent.sendModeSelected());
      await settle();

      bloc.add(const ShareRecordsEvent.transferFailed('late'));
      final state = await settle();

      expect(state.phase, SharePhase.selectingRecords);
      expect(state.errorMessage, isNull);
    });

    test('closing the BLoC deletes a payload still in temp', () async {
      await selectPeerToSend();

      await closeBloc();

      expect(service.cleanedFiles, [_payloadPath]);
      expect(service.cleanedSessions, isEmpty);
    });

    test(
      'closing after the payload was deleted deletes nothing more',
      () async {
        await selectPeerToSend();
        bloc.add(const ShareRecordsEvent.transferCompleted());
        await settle();

        await closeBloc();

        expect(service.cleanedFiles, [_payloadPath]);
      },
    );

    test('a cancelled transfer disconnects and goes idle', () async {
      await selectPeerToSend();

      bloc.add(const ShareRecordsEvent.transferCancelled());
      final state = await settle();

      expect(state.mode, ShareMode.idle);
      expect(state.isSessionActive, isFalse);
      expect(service.calls.last, 'disconnect');
    });
  });

  group('receiving', () {
    test('received data starts a viewing session', () async {
      service.parsed = _container(
        notes: {
          'o1': [RecordNote(content: 'seen', timestamp: DateTime.utc(2024))],
        },
      );

      bloc.add(ShareRecordsEvent.dataReceived(_data()));
      final state = await settle();

      expect(state.phase, SharePhase.viewingRecords);
      expect(state.receivedData?.sessionId, _sessionId);
      expect(state.isSessionActive, isTrue);
      expect(repository.addedNotes, ['seen']);
      expect(service.calls, contains('sendViewingStarted'));
    });

    test('data that cannot be parsed shows an error', () async {
      bloc.add(ShareRecordsEvent.dataReceived(_data()));
      final state = await settle();

      expect(state.phase, SharePhase.error);
      expect(state.receivedData, isNull);
    });

    test('received files are parsed into a session', () async {
      service.parsed = _container();

      bloc.add(const ShareRecordsEvent.filesReceived(['/tmp/a.json']));
      expect((await settle()).phase, SharePhase.viewingRecords);
    });

    test('a received file that cannot be parsed shows an error', () async {
      bloc.add(const ShareRecordsEvent.filesReceived(['/tmp/a.json']));
      expect((await settle()).phase, SharePhase.error);
    });

    test('a receiver failure is retried by listening again', () async {
      bloc
        ..add(const ShareRecordsEvent.invitationAccepted('inv'))
        ..add(const ShareRecordsEvent.transferFailed('lost'));
      final state = await settle();

      expect(state.connectionRetryCount, 1);
      expect(service.calls, contains('startReceivingInMemory'));
    });
  });

  group('ending a received session', () {
    Future<void> startViewing() async {
      service.parsed = _container(
        notes: {
          'o1': [RecordNote(content: 'seen', timestamp: DateTime.utc(2024))],
        },
      );
      bloc.add(ShareRecordsEvent.dataReceived(_data()));
      await settle();
    }

    test('asking to leave shows the confirmation, continue hides it', () async {
      await startViewing();

      bloc.add(const ShareRecordsEvent.sessionEndRequested());
      expect((await settle()).showExitConfirmationDialog, isTrue);

      bloc.add(const ShareRecordsEvent.continueViewing());
      expect((await settle()).showExitConfirmationDialog, isFalse);
    });

    test('leaving by navigation asks for confirmation', () async {
      await startViewing();

      bloc.add(const ShareRecordsEvent.navigationExitDetected());
      expect((await settle()).showExitConfirmationDialog, isTrue);
    });

    test(
      'destroying the data deletes the session directory by id and the notes',
      () async {
        await startViewing();

        bloc.add(const ShareRecordsEvent.dataDestroyed());
        final state = await settle();

        expect(service.cleanedSessions, [_sessionId]);
        expect(repository.deletedNotes, [1]);
        expect(state.phase, SharePhase.sessionEnded);
        expect(state.receivedData, isNull);
        expect(state.isDataDestroyed, isTrue);
        expect(state.sessionEndReason, ShareSessionEndReason.dataDeleted);
      },
    );

    test(
      'confirming destruction tells the sender and deletes the data',
      () async {
        await startViewing();

        bloc.add(const ShareRecordsEvent.dataDestructionConfirmed());
        await Future<void>.delayed(const Duration(milliseconds: 600));
        final state = await settle();

        expect(service.calls, contains('sendKillSignal'));
        expect(service.cleanedSessions, [_sessionId]);
        expect(state.phase, SharePhase.sessionEnded);
      },
    );

    test('backgrounding the app destroys the received data', () async {
      await startViewing();

      bloc.add(const ShareRecordsEvent.appBackgrounded());
      await Future<void>.delayed(const Duration(milliseconds: 600));
      await settle();

      expect(service.cleanedSessions, [_sessionId]);
    });

    test('a note that cannot be deleted does not stop the cleanup', () async {
      await startViewing();
      repository.failNoteWrites = true;

      bloc.add(const ShareRecordsEvent.dataDestroyed());
      final state = await settle();

      expect(service.cleanedSessions, [_sessionId]);
      expect(state.phase, SharePhase.sessionEnded);
    });

    test('destroying without received data deletes no directory', () async {
      bloc.add(const ShareRecordsEvent.dataDestroyed());
      await settle();

      expect(service.cleanedSessions, isEmpty);
    });

    test(
      'closing the BLoC while viewing deletes the session directory',
      () async {
        await startViewing();

        await closeBloc();

        expect(service.cleanedSessions, [_sessionId]);
      },
    );
  });
}
