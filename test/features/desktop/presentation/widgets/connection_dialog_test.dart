import 'dart:async';
import 'dart:convert';

import 'package:bloc_test/bloc_test.dart' show MockBloc, whenListen;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/config/app_platform.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/core/widgets/app_snack_bar.dart';
import 'package:health_wallet/features/desktop/communication/data/services/pairing_storage_service.dart';
import 'package:health_wallet/features/desktop/communication/presentation/bloc/communication_bloc.dart';
import 'package:health_wallet/features/desktop/presentation/widgets/connection_dialog.dart';
import 'package:health_wallet/features/desktop/presentation/widgets/vpn_notice.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Records the events the dialog sends instead of running them.
class _MockCommunicationBloc
    extends MockBloc<CommunicationEvent, DesktopSyncState>
    implements CommunicationBloc {
  final events = <CommunicationEvent>[];

  @override
  void add(CommunicationEvent event) => events.add(event);
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

void main() {
  late _MockCommunicationBloc commBloc;

  Future<void> register(AppPlatform platform, DesktopSyncState state) async {
    SharedPreferences.setMockInitialValues({});
    commBloc = _MockCommunicationBloc();
    whenListen(
      commBloc,
      const Stream<DesktopSyncState>.empty(),
      initialState: state,
    );
    getIt
      ..registerSingleton<AppPlatform>(platform)
      ..registerSingleton<CommunicationBloc>(commBloc)
      ..registerSingleton<PairingStorageService>(
        PairingStorageService(await SharedPreferences.getInstance()),
      );
  }

  tearDown(getIt.reset);

  Widget app(Widget home) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  );

  group('the VPN notice', () {
    Future<void> pumpSection(
      WidgetTester tester, {
      required AppPlatform platform,
      required DesktopSyncState state,
    }) async {
      await register(platform, state);
      await tester.pumpWidget(
        app(const Scaffold(body: ConnectionSection())),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('on the desktop, says the VPN can block the phone', (
      tester,
    ) async {
      await pumpSection(
        tester,
        platform: AppPlatform.desktop,
        state: const DesktopSyncState(vpnDetected: true),
      );

      expect(find.byType(VpnNotice), findsOne);
      expect(find.text(_en.desktopVpnBlocksPhone), findsOne);
      expect(find.text(_en.desktopVpnDetected), findsNothing);
    });

    testWidgets('on the phone, asks to turn the VPN off', (tester) async {
      await pumpSection(
        tester,
        platform: AppPlatform.mobile,
        state: const DesktopSyncState(vpnDetected: true),
      );

      expect(find.text(_en.desktopVpnDetected), findsOne);
      expect(find.text(_en.desktopVpnBlocksPhone), findsNothing);
    });

    testWidgets('is not shown once connected', (tester) async {
      await pumpSection(
        tester,
        platform: AppPlatform.desktop,
        state: const DesktopSyncState(
          vpnDetected: true,
          connectionStatus: ConnectionStatus.connected,
        ),
      );

      expect(find.byType(VpnNotice), findsNothing);
    });

    testWidgets('is not shown without a VPN', (tester) async {
      await pumpSection(
        tester,
        platform: AppPlatform.desktop,
        state: const DesktopSyncState(),
      );

      expect(find.byType(VpnNotice), findsNothing);
    });
  });

  group('scanning a desktop pairing code', () {
    late _FakeScannerPlatform scanner;
    late MobileScannerPlatform realScanner;

    setUp(() {
      realScanner = MobileScannerPlatform.instance;
      scanner = _FakeScannerPlatform();
      MobileScannerPlatform.instance = scanner;
    });

    tearDown(() async {
      MobileScannerPlatform.instance = realScanner;
      await scanner.close();
    });

    testWidgets('pairs, closes the scanner and confirms with a snackbar', (
      tester,
    ) async {
      await register(AppPlatform.mobile, const DesktopSyncState());
      // A phone screen, tall enough for the scanner.
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        app(
          Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => ConnectionDialog.openQRScanner(context),
                child: const Text('scan'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('scan'));
      await tester.pumpAndSettle();
      expect(find.text(_en.desktopScanQrCode), findsOne);

      scanner.barcodes.add(
        BarcodeCapture(
          barcodes: [
            Barcode(
              rawValue: jsonEncode({
                'device_id': 'desktop-1',
                'device_name': 'Office Mac',
                'pairing_key': 'key',
                'ip': '192.168.1.20',
                'port': 49152,
                'os': 'macos',
              }),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(_en.desktopScanQrCode), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(AppSnackBar.cardKey),
          matching: find.text(_en.desktopPairedWith('Office Mac')),
        ),
        findsOne,
      );
      final saved = getIt<PairingStorageService>().loadPairing();
      expect(saved?.deviceId, 'desktop-1');
      expect(
        commBloc.events.single,
        isA<CommunicationPairingCompleted>().having(
          (e) => e.pairing.deviceName,
          'device name',
          'Office Mac',
        ),
      );

      // Let the snackbar time out so no timer is left pending.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });
  });
}
