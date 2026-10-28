import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';

/// Records every `logger` call made while a test runs, so a test can check
/// that a caught failure was logged instead of swallowed.
///
/// Call it from `main()` or a `group()`: it registers the listener in
/// `setUp` and removes it in `tearDown`.
List<LogEvent> captureLogs() {
  final events = <LogEvent>[];
  void listener(LogEvent event) => events.add(event);
  setUp(() {
    events.clear();
    Logger.addLogListener(listener);
  });
  tearDown(() => Logger.removeLogListener(listener));
  return events;
}

/// Matches a warning-or-worse log whose message contains [message].
Matcher loggedWarning(String message) => contains(
  isA<LogEvent>()
      .having(
        (e) => e.level.value,
        'level',
        greaterThanOrEqualTo(Level.warning.value),
      )
      .having((e) => '${e.message}', 'message', contains(message)),
);
