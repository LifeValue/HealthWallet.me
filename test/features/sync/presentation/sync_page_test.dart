import 'dart:async';

import 'package:bloc_test/bloc_test.dart' show MockBloc, whenListen;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/core/widgets/app_snack_bar.dart';
import 'package:health_wallet/features/desktop/communication/data/models/device_pairing.dart';
import 'package:health_wallet/features/desktop/communication/data/services/pairing_storage_service.dart';
import 'package:health_wallet/features/desktop/communication/data/services/secret_store.dart';
import 'package:health_wallet/features/desktop/communication/presentation/bloc/communication_bloc.dart';
import 'package:health_wallet/features/desktop/lww_sync/presentation/bloc/lww_sync_bloc.dart';
import 'package:health_wallet/features/sync/presentation/bloc/sync_bloc.dart';
import 'package:health_wallet/features/sync/presentation/sync_page.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Records the events sent to it instead of running them.
class _MockCommunicationBloc
    extends MockBloc<CommunicationEvent, DesktopSyncState>
    implements CommunicationBloc {
  final events = <CommunicationEvent>[];

  @override
  void add(CommunicationEvent event) => events.add(event);
}

class _MockLwwSyncBloc extends MockBloc<LwwSyncEvent, LwwSyncState>
    implements LwwSyncBloc {}

/// Records the events sent to it instead of running them.
class _MockSyncBloc extends MockBloc<SyncEvent, SyncState> implements SyncBloc {
  final events = <SyncEvent>[];

  @override
  void add(SyncEvent event) => events.add(event);
}

/// A camera that starts at once and reports the codes the test sends.
class _FakeScannerPlatform extends MobileScannerPlatform {
  final barcodes = StreamController<BarcodeCapture?>.broadcast();

  @override
  Stream<BarcodeCapture?> get barcodesStream => barcodes.stream;

  @override
  Stream<TorchState> get torchStateStream => const Stream.empty();

  @override
  Stream<double> get zoomScaleStateStream => const Stream.empty();

  @override
  Widget buildCameraView() => const SizedBox.expand();

  @override
  Future<MobileScannerViewAttributes> start(StartOptions startOptions) async =>
      const MobileScannerViewAttributes(
        cameraDirection: CameraFacing.back,
        currentTorchMode: TorchState.unavailable,
        size: Size(640, 480),
      );

  @override
  Future<void> stop() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> updateScanWindow(Rect? window) async {}

  @override
  Future<void> dispose() async {}

  Future<void> close() => barcodes.close();
}

final _en = lookupAppLocalizations(const Locale('en'));

/// Pairing keys are not read here.
class _NoSecrets extends Fake implements SecretStore {}

/// A desktop's pairing code, as its QR code shows it.
final _qrCode = DevicePairing(
  deviceId: 'desktop-1',
  deviceName: 'Office Mac',
  pairingKey: DevicePairing.newKey(),
  lastIp: '192.168.1.20',
  lastPort: 49152,
  pairedAt: DateTime(2024),
).toQrPayload();

void main() {
  late _MockCommunicationBloc commBloc;
  late _MockSyncBloc syncBloc;
  late _FakeScannerPlatform scanner;
  late MobileScannerPlatform realScanner;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    realScanner = MobileScannerPlatform.instance;
    scanner = _FakeScannerPlatform();
    MobileScannerPlatform.instance = scanner;

    commBloc = _MockCommunicationBloc();
    final lwwBloc = _MockLwwSyncBloc();
    syncBloc = _MockSyncBloc();
    whenListen(
      commBloc,
      const Stream<DesktopSyncState>.empty(),
      initialState: const DesktopSyncState(),
    );
    whenListen(
      lwwBloc,
      const Stream<LwwSyncState>.empty(),
      initialState: LwwSyncState.initial(),
    );
    whenListen(
      syncBloc,
      const Stream<SyncState>.empty(),
      initialState: const SyncState(isQRScanning: true),
    );
    getIt
      ..registerSingleton<CommunicationBloc>(commBloc)
      ..registerSingleton<LwwSyncBloc>(lwwBloc)
      ..registerSingleton<PairingStorageService>(
        PairingStorageService(
          await SharedPreferences.getInstance(),
          _NoSecrets(),
        ),
      );
  });

  tearDown(() async {
    MobileScannerPlatform.instance = realScanner;
    await scanner.close();
    await getIt.reset();
  });

  testWidgets('scanning a desktop pairing code pairs and confirms with a '
      'snackbar', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider<SyncBloc>.value(
          value: syncBloc,
          child: const SyncPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    scanner.barcodes.add(
      BarcodeCapture(
        barcodes: [
          Barcode(
            rawValue: _qrCode,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(AppSnackBar.cardKey),
        matching: find.text(_en.pairedWithDevice('Office Mac')),
      ),
      findsOne,
    );
    expect(syncBloc.events, [const SyncCancel()]);
    expect(
      commBloc.events.single,
      isA<CommunicationPairingCompleted>().having(
        (e) => (e.pairing.deviceId, e.pairing.deviceName),
        'desktop',
        ('desktop-1', 'Office Mac'),
      ),
    );

    // Let the snackbar time out so no timer is left pending.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });
}
