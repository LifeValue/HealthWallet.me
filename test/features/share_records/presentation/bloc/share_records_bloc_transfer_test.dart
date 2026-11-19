import 'dart:async';
import 'dart:convert';
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
import 'package:health_wallet/features/share_records/data/service/secure_share_session.dart';
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

const _payloadPath = '/tmp/share_payload.bin';

/// A peer that never answers: the key exchange waits until it is disposed.
class _SilentTransport implements ShareMessageTransport {
  @override
  Stream<Uint8List> get messages => const Stream.empty();

  @override
  Future<void> send(Uint8List message) async {}
}

/// Records the calls the BLoC makes; [preparedPath] is what
/// `prepareFilesForSending` returns (null for a failure).
class _FakeShareRecordsService extends Fake implements ShareRecordsService {
  String? preparedPath = _payloadPath;
  String? Function()? preparedPathFor;

  /// When set, writing the payload waits for it, so a test can act while the
  /// payload is being written.
  Completer<void>? prepareGate;
  Uint8List? receivedFileBytes;
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
  SecureShareSession createSecureSession() =>
      SecureShareSession(_SilentTransport());

  @override
  Future<String?> prepareFilesForSending(
    SharePayload payload,
    SecureShareSession session,
  ) async {
    calls.add('prepareFilesForSending');
    // Seals like the real service, which starts the session's key exchange,
    // and like it returns null when sealing fails (a closed session).
    try {
      await session.seal(utf8.encode('{}'));
    } on SecureShareCancelled {
      return null;
    }
    calls.add('payloadSealed');
    // Yields like the real file write, so concurrent handlers interleave.
    await Future<void>.delayed(Duration.zero);
    await prepareGate?.future;
    return preparedPathFor?.call() ?? preparedPath;
  }

  @override
  Future<void> cleanupTempFile(String filePath) async =>
      cleanedFiles.add(filePath);

  @override
  Future<void> cleanupSessionTempDir(String sessionId) async =>
      cleanedSessions.add(sessionId);

  @override
  Future<Uint8List?> readReceivedFile(String filePath) async =>
      receivedFileBytes;
}

/// Related-resource and note lookups find nothing.
class _FakeRecordsRepository extends Fake implements RecordsRepository {
  @override
  Future<List<IFhirResource>> getRelatedResources({
    required IFhirResource resource,
  }) async => [];

  @override
  Future<List<RecordNote>> getRecordNotes(String resourceId) async => [];

  @override
  void clearSharedNotes() {}
}

class _FakeSharePreferencesService extends Fake
    implements SharePreferencesService {}

class _FakeReceiveModeService extends Fake implements ReceiveModeService {
  @override
  bool get isListening => false;
}

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

  /// Sealing a payload generates real keys, which takes longer than one pass
  /// of the event queue on a slow machine (CI): wait until [done], or about
  /// 3 s.
  Future<void> waitFor(bool Function() done) async {
    for (var i = 0; i < 300 && !done(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    await settle();
  }

  int connections(String deviceId) =>
      service.calls.where((c) => c == 'selectPeer $deviceId').length;

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
    await waitFor(
      () => connections('a') >= 1 || bloc.state.phase == SharePhase.error,
    );
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
      service.preparedPath = '/tmp/share_second.bin';

      bloc.add(const ShareRecordsEvent.peerSelected('a'));
      await waitFor(() => connections('a') == 2);

      expect(service.cleanedFiles, [_payloadPath]);
    });

    test('closing the screen while the payload is written deletes it and '
        'starts no key exchange', () async {
      final gate = Completer<void>();
      service.prepareGate = gate;
      bloc
        ..add(const ShareRecordsEvent.sendModeSelected())
        ..add(
          ShareRecordsEvent.recordToggled(record(observationJson(), id: 'o1')),
        )
        ..add(const ShareRecordsEvent.peerSelected('a'));
      // Sealed, and the file is being written.
      await waitFor(() => service.calls.contains('payloadSealed'));

      // Closing waits for the running handler, which waits for the write:
      // start closing, then let the write finish.
      final closing = closeBloc();
      await settle();
      gate.complete();
      await closing;
      await waitFor(() => service.cleanedFiles.isNotEmpty);

      // Nothing else would delete it: the bloc's own cleanup already ran.
      expect(service.cleanedFiles, [_payloadPath]);
      expect(connections('a'), 0);
    });

    test('two quick peer selections run one after the other', () async {
      var prepared = 0;
      service.preparedPathFor = () => '/tmp/share_${++prepared}.bin';
      bloc
        ..add(const ShareRecordsEvent.sendModeSelected())
        ..add(
          ShareRecordsEvent.recordToggled(record(observationJson(), id: 'o1')),
        )
        ..add(const ShareRecordsEvent.peerSelected('a'))
        ..add(const ShareRecordsEvent.peerSelected('a'));
      await waitFor(() => connections('a') == 2);

      await closeBloc();
      await waitFor(() => service.cleanedFiles.length == 2);

      // Concurrent handlers would both write before either deletes, leaking
      // the first payload.
      expect(service.cleanedFiles, ['/tmp/share_1.bin', '/tmp/share_2.bin']);
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
    test('an unencrypted share from an older version shows an error', () async {
      bloc.add(ShareRecordsEvent.dataReceived(_data()));
      final state = await settle();

      expect(state.phase, SharePhase.error);
      expect(state.receivedData, isNull);
      expect(service.calls, isNot(contains('sendViewingStarted')));
    });

    test('an unencrypted received file shows an error', () async {
      service.receivedFileBytes = Uint8List.fromList(utf8.encode('{}'));

      bloc.add(const ShareRecordsEvent.filesReceived(['/tmp/a.bin']));
      final state = await settle();

      expect(state.phase, SharePhase.error);
      expect(state.receivedData, isNull);
    });

    test('a received file that cannot be read shows an error', () async {
      bloc.add(const ShareRecordsEvent.filesReceived(['/tmp/a.bin']));
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

    test('destroying without received data deletes no directory', () async {
      bloc.add(const ShareRecordsEvent.dataDestroyed());
      await settle();

      expect(service.cleanedSessions, isEmpty);
    });
  });
}
