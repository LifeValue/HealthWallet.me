import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/services/device_capability_service.dart';
import 'package:health_wallet/features/processing/domain/deep_scan_defaults.dart';

void main() {
  group('defaultDeepScan', () {
    test('is on for the desktop', () {
      expect(defaultDeepScan(true), isTrue);
    });

    test('is off for mobile', () {
      expect(defaultDeepScan(false), isFalse);
    });
  });

  group('deepScanRuns', () {
    test('reads the pages when Deep Scan is on and the device has the '
        'memory', () {
      expect(
        deepScanRuns(deepScanOn: true, capability: DeviceAiCapability.full),
        isTrue,
      );
    });

    test('reads the text on a device without the memory for Deep Scan', () {
      expect(
        deepScanRuns(
          deepScanOn: true,
          capability: DeviceAiCapability.basicOnly,
        ),
        isFalse,
      );
    });

    test('reads the text when Deep Scan is off', () {
      expect(
        deepScanRuns(deepScanOn: false, capability: DeviceAiCapability.full),
        isFalse,
      );
    });
  });
}
