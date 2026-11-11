import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/core/widgets/dialogs/app_simple_dialog.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  Future<void> openSuccess(
    WidgetTester tester, {
    Size screen = const Size(1900, 1000),
    VoidCallback? onOk,
  }) async {
    tester.view.physicalSize = screen;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => AppSimpleDialog.showSuccess(
                context: context,
                title: 'Backup restored',
                message: '27 records are now on this device.',
                onOkPressed: onOk,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  group('success dialog', () {
    testWidgets('is a compact card on a wide desktop screen', (tester) async {
      await openSuccess(tester);

      final card = find.descendant(
        of: find.byType(Dialog),
        matching: find.byType(Container),
      );
      expect(
        tester.getSize(card.first).width,
        AppSimpleDialog.successDialogWidth,
      );
    });

    testWidgets('shows a check mark, a centred title and message', (
      tester,
    ) async {
      await openSuccess(tester);

      expect(find.byKey(const Key('success_dialog_icon')), findsOne);
      expect(find.byIcon(Icons.check_rounded), findsOne);
      for (final text in [
        'Backup restored',
        '27 records are now on this device.',
      ]) {
        expect(
          tester.widget<Text>(find.text(text)).textAlign,
          TextAlign.center,
        );
        expect(
          tester.getCenter(find.text(text)).dx,
          closeTo(tester.getCenter(find.byType(Dialog)).dx, 1),
        );
      }
    });

    testWidgets('OK closes it and runs the callback', (tester) async {
      var oks = 0;
      await openSuccess(tester, onOk: () => oks++);

      await tester.tap(find.text(l10n.ok));
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsNothing);
      expect(oks, 1);
    });

    testWidgets('fits a phone screen', (tester) async {
      await openSuccess(tester, screen: const Size(320, 640));

      expect(tester.takeException(), isNull);
      expect(find.text(l10n.ok), findsOne);
    });
  });

  group('confirmation dialog', () {
    late List<String> calls;
    late bool? result;

    Future<void> openConfirmation(
      WidgetTester tester, {
      String? message,
      String? subtitle,
      bool showCloseButton = true,
    }) async {
      calls = [];
      result = null;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await AppSimpleDialog.showConfirmation(
                    context: context,
                    title: 'Disable the lock?',
                    message: message,
                    subtitle: subtitle,
                    confirmText: 'Disable',
                    cancelText: 'Cancel',
                    onConfirm: () => calls.add('confirm'),
                    onCancel: () => calls.add('cancel'),
                    showCloseButton: showCloseButton,
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    final close = find.byKey(const Key('confirmation_dialog_close'));

    for (final variant in <String, ({String? message, String? subtitle})>{
      'title only': (message: null, subtitle: null),
      'with a message': (message: 'You can turn it on again.', subtitle: null),
      'with a subtitle': (message: null, subtitle: 'You can turn it on again.'),
    }.entries) {
      testWidgets('${variant.key}: shows the title and an X', (tester) async {
        await openConfirmation(
          tester,
          message: variant.value.message,
          subtitle: variant.value.subtitle,
        );

        expect(find.text('Disable the lock?'), findsOne);
        expect(close, findsOne);
        expect(find.byTooltip(l10n.close), findsOne);
        if (variant.value.message != null || variant.value.subtitle != null) {
          expect(find.text('You can turn it on again.'), findsOne);
        }
      });
    }

    testWidgets('the X closes without confirming or cancelling', (
      tester,
    ) async {
      await openConfirmation(tester, message: 'You can turn it on again.');

      await tester.tap(close);
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsNothing);
      expect(result, isNull);
      expect(calls, isEmpty);
    });

    testWidgets('a dialog that only informs can leave out the X', (
      tester,
    ) async {
      await openConfirmation(tester, showCloseButton: false);

      expect(find.text('Disable the lock?'), findsOne);
      expect(close, findsNothing);
      expect(find.text('Disable'), findsOne);
    });

    testWidgets('Cancel and the action still work', (tester) async {
      await openConfirmation(tester);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(result, isFalse);
      expect(calls, ['cancel']);

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      calls.clear();
      await tester.tap(find.text('Disable'));
      await tester.pumpAndSettle();
      expect(result, isTrue);
      expect(calls, ['confirm']);
    });
  });
}
