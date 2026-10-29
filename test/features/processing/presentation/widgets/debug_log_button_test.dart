import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/features/processing/domain/services/processing_log_buffer.dart';
import 'package:health_wallet/features/processing/presentation/widgets/debug_log_button.dart';

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('debug_log_button_test');
  });

  tearDown(() async {
    ProcessingLogBuffer.debugOverrideInstance(null);
    await dir.delete(recursive: true);
  });

  Future<void> pumpButton(WidgetTester tester, {required bool enabled}) async {
    ProcessingLogBuffer.debugOverrideInstance(
      ProcessingLogBuffer.forTesting(enabled: enabled, directory: dir),
    );
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: DebugLogButton())),
    );
  }

  testWidgets('shows the terminal icon while the scan log is kept', (
    tester,
  ) async {
    await pumpButton(tester, enabled: true);

    expect(find.byIcon(Icons.terminal), findsOne);
  });

  testWidgets('shows nothing when the scan log is off, as in release builds', (
    tester,
  ) async {
    await pumpButton(tester, enabled: false);

    expect(find.byIcon(Icons.terminal), findsNothing);
    expect(find.byType(IconButton), findsNothing);
  });

  testWidgets('the release-mode buffer has the icon hidden', (tester) async {
    expect(ProcessingLogBuffer.enabledFor(releaseMode: true), isFalse);
  });
}
