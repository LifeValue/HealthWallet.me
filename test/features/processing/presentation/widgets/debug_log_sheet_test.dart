import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/core/widgets/app_snack_bar.dart';
import 'package:health_wallet/features/processing/domain/services/processing_log_buffer.dart';
import 'package:health_wallet/features/processing/presentation/widgets/debug_log_sheet.dart';

final _en = lookupAppLocalizations(const Locale('en'));

void main() {
  late Directory docs;
  late List<String> copied;

  setUp(() {
    docs = Directory.systemTemp.createTempSync('hw_debug_log_sheet_');
    ProcessingLogBuffer.debugOverrideInstance(
      ProcessingLogBuffer.forTesting(enabled: true, directory: docs),
    );
    copied = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            copied.add((call.arguments as Map)['text'] as String);
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
    ProcessingLogBuffer.debugOverrideInstance(null);
    if (docs.existsSync()) docs.deleteSync(recursive: true);
  });

  testWidgets('Copy puts the log on the clipboard and says so', (
    tester,
  ) async {
    ProcessingLogBuffer.instance
      ..log('OCR page 1 done')
      ..log('Mapping started');
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: DebugLogSheet()),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Copy'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(copied.single, contains('OCR page 1 done'));
    expect(copied.single, contains('Mapping started'));
    expect(
      find.descendant(
        of: find.byKey(AppSnackBar.cardKey),
        matching: find.text(_en.logsCopied),
      ),
      findsOne,
    );

    // Let the snackbar time out so no timer is left pending.
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  });
}
