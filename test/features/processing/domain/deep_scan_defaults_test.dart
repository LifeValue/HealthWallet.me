import 'package:flutter_test/flutter_test.dart';
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
}
