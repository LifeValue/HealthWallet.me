import 'package:airdrop/airdrop.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/l10n/app_strings_provider.dart';
import 'package:health_wallet/features/records/domain/repository/records_repository.dart';
import 'package:health_wallet/features/share_records/data/service/share_preferences_service.dart';
import 'package:health_wallet/features/share_records/data/service/share_records_service.dart';
import 'package:health_wallet/features/share_records/domain/entity/entity.dart';
import 'package:health_wallet/features/share_records/domain/services/receive_mode_service.dart';
import 'package:health_wallet/features/share_records/presentation/bloc/share_records_bloc.dart';
import 'package:health_wallet/features/share_records/presentation/bloc/share_records_event.dart';
import 'package:health_wallet/features/share_records/presentation/bloc/share_records_state.dart';

class _FakeShareRecordsService extends Fake implements ShareRecordsService {
  @override
  Future<void> disconnect() async {}

  @override
  Future<void> selectPeer(String deviceId) async {}

  @override
  Future<void> startDiscovery({bool useBluetooth = true}) async {}

  @override
  Future<void> startSymmetricDiscovery() async {}

  @override
  Future<void> startReceivingInMemory() async {}

  @override
  Future<void> sendKillSignal() async {}
}

class _FakeRecordsRepository extends Fake implements RecordsRepository {}

class _FakeSharePreferencesService extends Fake
    implements SharePreferencesService {}

class _FakeReceiveModeService extends Fake implements ReceiveModeService {
  @override
  bool get isListening => false;
}

/// Status and error messages the share BLoC builds follow the app language
/// held by [AppStringsProvider].
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ShareRecordsBloc bloc;

  setUp(() {
    getIt.registerSingleton<ReceiveModeService>(_FakeReceiveModeService());
    bloc = ShareRecordsBloc(
      _FakeShareRecordsService(),
      _FakeRecordsRepository(),
      _FakeSharePreferencesService(),
      AppStringsProvider.forLocale(const Locale('ro')),
    );
  });

  tearDown(() async {
    await bloc.close();
    await getIt.reset();
  });

  Future<ShareRecordsState> settle() async {
    await pumpEventQueue();
    return bloc.state;
  }

  PeerDevice peer(String id, [String? name]) =>
      PeerDevice(deviceId: id, deviceName: name);

  group('in Romanian', () {
    test('the device count uses Romanian plural forms', () async {
      bloc.add(ShareRecordsEvent.peerDiscovered(peer('a', 'Pixel 8')));
      expect((await settle()).statusMessage, 'S-a găsit un dispozitiv');

      bloc
        ..add(ShareRecordsEvent.peerDiscovered(peer('b', 'iPad')))
        ..add(ShareRecordsEvent.peerDiscovered(peer('c', 'Galaxy')));
      expect((await settle()).statusMessage, 'S-au găsit 3 dispozitive');

      // Names that prefix one another are merged as the same device, so
      // each name ends with a separator.
      for (var i = 0; i < 17; i++) {
        bloc.add(ShareRecordsEvent.peerDiscovered(peer('d$i', 'Phone $i.')));
      }
      expect((await settle()).statusMessage, 'S-au găsit 20 de dispozitive');
    });

    test('connecting, retrying and transfer progress', () async {
      bloc.add(ShareRecordsEvent.peerDiscovered(peer('a', 'Pixel 8')));
      bloc.add(const ShareRecordsEvent.peerSelected('a'));
      expect((await settle()).statusMessage, 'Se conectează la Pixel 8...');

      bloc.add(
        const ShareRecordsEvent.transferProgressUpdated(
          TransferProgress(
            bytesTransferred: 50,
            totalBytes: 100,
            filesTransferred: 0,
            totalFiles: 1,
          ),
        ),
      );
      expect((await settle()).statusMessage, 'Se transferă 50%');

      // The retry status is followed at once by the rediscovery status, so
      // look at every emitted state.
      final statuses = <String?>[];
      final sub = bloc.stream.listen((s) => statuses.add(s.statusMessage));
      bloc.add(const ShareRecordsEvent.transferFailed('lost'));
      await settle();
      await sub.cancel();
      expect(statuses, contains('Se reîncearcă (1/3)...'));
      expect(statuses.last, 'Se așteaptă expeditorul...');
    });

    test('an unnamed peer is shown as an unknown device', () async {
      bloc.add(const ShareRecordsEvent.peerSelected('missing'));
      expect(
        (await settle()).statusMessage,
        'Se conectează la Dispozitiv Necunoscut...',
      );
    });

    test('selecting no records reports a Romanian error', () async {
      bloc.add(const ShareRecordsEvent.selectionConfirmed());
      expect(
        (await settle()).errorMessage,
        'Selectează cel puțin o înregistrare',
      );
    });

    test(
      'a declined invitation ends the session with a typed reason',
      () async {
        bloc.add(const ShareRecordsEvent.sendModeSelected());
        expect(
          (await settle()).statusMessage,
          'Selectează înregistrări de partajat',
        );

        bloc.add(const ShareRecordsEvent.remoteInvitationRejected());
        final state = await settle();

        expect(state.phase, SharePhase.sessionEnded);
        expect(
          state.sessionEndReason,
          ShareSessionEndReason.invitationDeclined,
        );
        expect(state.statusMessage, 'Destinatarul a refuzat invitația');
      },
    );

    test('a terminated session is not reported as declined', () async {
      bloc.add(const ShareRecordsEvent.killSessionRequested());
      await Future<void>.delayed(const Duration(milliseconds: 600));
      final state = await settle();

      expect(state.phase, SharePhase.sessionEnded);
      expect(state.sessionEndReason, ShareSessionEndReason.terminated);
      expect(state.statusMessage, 'Sesiune încheiată');
    });
  });
}
