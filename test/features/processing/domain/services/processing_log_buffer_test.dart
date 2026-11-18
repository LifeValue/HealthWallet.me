import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/features/processing/domain/services/processing_log_buffer.dart';

void main() {
  late Directory docs;

  setUp(() => docs = Directory.systemTemp.createTempSync('hw_scan_log_'));
  tearDown(() {
    if (docs.existsSync()) docs.deleteSync(recursive: true);
  });

  File logFile() => File('${docs.path}/${ProcessingLogBuffer.logFileName}');

  test('is enabled in debug and profile builds only', () {
    expect(ProcessingLogBuffer.enabledFor(releaseMode: true), isFalse);
    expect(ProcessingLogBuffer.enabledFor(releaseMode: false), isTrue);
    // `flutter test` runs in debug mode.
    expect(ProcessingLogBuffer.instance.isEnabled, isTrue);
  });

  group('when disabled (release builds)', () {
    test('keeps nothing in memory and writes no log file', () async {
      final buffer = ProcessingLogBuffer.forTesting(
        enabled: false,
        directory: docs,
      );
      var notified = false;
      buffer.addListener(() => notified = true);

      buffer.log('Patient: Jane Doe');

      expect(buffer.getAll(), isEmpty);
      expect(notified, isFalse);
      expect(await buffer.readPersistedLogs(), isEmpty);
      expect(logFile().existsSync(), isFalse);
    });

    test('does not read a log left by an older build', () async {
      logFile().writeAsStringSync('old patient data\n');
      final buffer = ProcessingLogBuffer.forTesting(
        enabled: false,
        directory: docs,
      );

      expect(await buffer.readPersistedLogs(), isEmpty);
      await buffer.clearPersistedLogs();
      expect(logFile().readAsStringSync(), 'old patient data\n');
    });
  });

  group('when enabled (debug and profile builds)', () {
    test('keeps entries in memory and appends them to the log file', () async {
      final buffer = ProcessingLogBuffer.forTesting(
        enabled: true,
        directory: docs,
      );

      buffer
        ..log('first')
        ..log('second');

      expect(buffer.getAll(), ['first', 'second']);
      expect(await buffer.readPersistedLogs(), 'first\nsecond\n');
    });

    test('keeps only the newest 500 entries in memory', () async {
      final buffer = ProcessingLogBuffer.forTesting(
        enabled: true,
        directory: docs,
      );

      for (var i = 0; i < 505; i++) {
        buffer.log('entry $i');
      }

      expect(buffer.length, 500);
      expect(buffer.getAll().first, 'entry 5');
      expect(buffer.getAll().last, 'entry 504');
      expect(
        () => buffer.getAll().add('x'),
        throwsUnsupportedError,
      );
      // The file keeps every entry.
      expect('\n'.allMatches(await buffer.readPersistedLogs()), hasLength(505));
    });

    test('lines logged during a write follow it in the file', () async {
      final buffer = ProcessingLogBuffer.forTesting(
        enabled: true,
        directory: docs,
      )..log('a');
      // The first write has started.
      await Future<void>.delayed(Duration.zero);

      buffer
        ..log('b')
        ..log('c');

      expect(await buffer.readPersistedLogs(), 'a\nb\nc\n');
    });

    test('log and clear notify listeners; clear keeps the file', () async {
      final buffer = ProcessingLogBuffer.forTesting(
        enabled: true,
        directory: docs,
      );
      var notifications = 0;
      buffer.addListener(() => notifications++);

      buffer.log('entry');
      buffer.clear();

      expect(notifications, 2);
      expect(buffer.getAll(), isEmpty);
      expect(buffer.length, 0);
      expect(await buffer.readPersistedLogs(), 'entry\n');
    });

    test('reads nothing before anything was logged', () async {
      final buffer = ProcessingLogBuffer.forTesting(
        enabled: true,
        directory: docs,
      );

      expect(await buffer.readPersistedLogs(), isEmpty);
      await expectLater(buffer.clearPersistedLogs(), completes);
      expect(logFile().existsSync(), isFalse);
    });

    test('a failed write is dropped without breaking logging', () async {
      final buffer = ProcessingLogBuffer.forTesting(
        enabled: true,
        directory: Directory('${docs.path}/missing'),
      );

      buffer.log('entry');

      expect(buffer.getAll(), ['entry']);
      expect(await buffer.readPersistedLogs(), isEmpty);
    });

    test('clearPersistedLogs empties the file', () async {
      final buffer = ProcessingLogBuffer.forTesting(
        enabled: true,
        directory: docs,
      )..log('entry');

      await buffer.clearPersistedLogs();

      expect(await buffer.readPersistedLogs(), isEmpty);
    });
  });

  test('a test override replaces the shared instance until reset', () {
    final disabled = ProcessingLogBuffer.forTesting(
      enabled: false,
      directory: docs,
    );
    final original = ProcessingLogBuffer.instance;

    ProcessingLogBuffer.debugOverrideInstance(disabled);
    addTearDown(() => ProcessingLogBuffer.debugOverrideInstance(null));

    expect(ProcessingLogBuffer.instance, same(disabled));
    ProcessingLogBuffer.debugOverrideInstance(null);
    expect(ProcessingLogBuffer.instance, same(original));
  });
}
