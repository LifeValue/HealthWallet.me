import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/features/desktop/communication/data/services/transport/communication_service.dart';
import 'package:health_wallet/features/desktop/communication/data/services/transport/transport_selector.dart';

void main() {
  final isApple = Platform.isIOS || Platform.isMacOS;

  test('MPC is primary and available only on Apple platforms', () {
    expect(
      TransportSelector.selectPrimary(),
      isApple ? TransportType.multipeerConnectivity : TransportType.tcp,
    );
    expect(TransportSelector.isMpcAvailable(), isApple);
  });

  test('TCP is always the fallback', () {
    expect(TransportSelector.selectFallback(), TransportType.tcp);
  });

  test('labels each transport', () {
    expect(TransportSelector.label(TransportType.tcp), 'TCP over WiFi');
    expect(
      TransportSelector.label(TransportType.multipeerConnectivity),
      'MultipeerConnectivity (Direct)',
    );
  });
}
