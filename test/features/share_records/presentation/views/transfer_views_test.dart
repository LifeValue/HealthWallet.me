import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/features/share_records/domain/services/share_log_buffer.dart';
import 'package:health_wallet/features/share_records/presentation/bloc/share_records_state.dart';
import 'package:health_wallet/features/share_records/presentation/views/transfer_views.dart';

final _en = lookupAppLocalizations(const Locale('en'));

Future<void> _pump(WidgetTester tester, Widget view) => tester.pumpWidget(
  MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: view),
  ),
);

void main() {
  late Directory logs;

  setUp(() => logs = Directory.systemTemp.createTempSync('hw_transfer_view_'));
  tearDown(() {
    ShareLogBuffer.debugOverrideInstance(null);
    logs.deleteSync(recursive: true);
  });

  void useLog({required bool enabled}) => ShareLogBuffer.debugOverrideInstance(
    ShareLogBuffer.forTesting(enabled: enabled, directory: logs),
  );

  final views = <String, Widget Function()>{
    'ConnectingView': () =>
        const ConnectingView(state: ShareRecordsState(mode: ShareMode.sending)),
    'TransferProgressView': () => const TransferProgressView(
      state: ShareRecordsState(
        mode: ShareMode.sending,
        statusMessage: 'Transferring 50%',
      ),
    ),
  };

  for (final MapEntry(key: name, value: build) in views.entries) {
    testWidgets('$name shows the debug log icon in debug builds', (
      tester,
    ) async {
      useLog(enabled: true);
      await _pump(tester, build());

      expect(find.byIcon(Icons.terminal), findsOneWidget);
    });

    testWidgets('$name opens the debug log from the icon', (tester) async {
      useLog(enabled: true);
      await _pump(tester, build());

      await tester.tap(find.byIcon(Icons.terminal));
      // The connecting spinner never settles; wait out the sheet animation.
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(BottomSheet), findsOneWidget);
    });

    testWidgets('$name hides the debug log icon in release builds', (
      tester,
    ) async {
      useLog(enabled: false);
      await _pump(tester, build());

      expect(find.byIcon(Icons.terminal), findsNothing);
    });
  }

  testWidgets('ConnectingView shows the retry count', (tester) async {
    useLog(enabled: false);
    await _pump(
      tester,
      const ConnectingView(
        state: ShareRecordsState(
          mode: ShareMode.sending,
          connectionRetryCount: 2,
        ),
      ),
    );

    expect(find.text(_en.shareRetryingCount(2)), findsOneWidget);
    expect(find.text(_en.shareConnectionInterrupted), findsOneWidget);
  });

  testWidgets('TransferProgressView shows the direction and status', (
    tester,
  ) async {
    useLog(enabled: false);
    await _pump(
      tester,
      const TransferProgressView(
        state: ShareRecordsState(
          mode: ShareMode.receiving,
          statusMessage: 'Receiving',
        ),
      ),
    );

    expect(find.text(_en.shareReceivingRecords), findsOneWidget);
    expect(find.text('Receiving'), findsOneWidget);
  });
}
