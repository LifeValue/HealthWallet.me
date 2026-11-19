import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/features/app_lock/domain/services/app_lock_clock.dart';

void main() {
  test('reads the wall clock', () {
    final before = DateTime.now();
    final now = const AppLockClock().now();

    expect(now.isBefore(before), isFalse);
    expect(now.difference(before), lessThan(const Duration(seconds: 1)));
  });
}
