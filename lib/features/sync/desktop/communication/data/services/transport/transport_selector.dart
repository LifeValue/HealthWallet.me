import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:health_wallet/features/sync/desktop/communication/data/services/transport/communication_service.dart';

class TransportSelector {
  static TransportType selectPrimary() {
    if (Platform.isIOS || Platform.isMacOS) {
      debugPrint('[Transport] Apple platform detected → MultipeerConnectivity primary');
      return TransportType.multipeerConnectivity;
    }
    debugPrint('[Transport] Non-Apple platform → TCP primary');
    return TransportType.tcp;
  }

  static TransportType selectFallback() {
    return TransportType.tcp;
  }

  static bool isMpcAvailable() {
    return Platform.isIOS || Platform.isMacOS;
  }

  static String label(TransportType type) {
    return switch (type) {
      TransportType.tcp => 'TCP over WiFi',
      TransportType.multipeerConnectivity => 'MultipeerConnectivity (Direct)',
    };
  }
}
