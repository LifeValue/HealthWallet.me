import 'package:flutter_test/flutter_test.dart';

/// Waits until [condition] holds, failing after [timeout].
///
/// For outcomes that depend on real I/O (files, sockets): a fixed number of
/// event-loop turns (`pumpEventQueue`) or a fixed delay passes on an idle
/// machine and fails under the full suite's parallel load.
Future<void> eventually(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Condition not met within $timeout');
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}
