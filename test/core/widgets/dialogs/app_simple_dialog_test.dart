import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/widgets/app_button.dart';
import 'package:health_wallet/core/widgets/dialogs/app_simple_dialog.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  /// Shows a screen with an 'open' button that runs [open], then taps it.
  Future<void> openWith(
    WidgetTester tester,
    void Function(BuildContext context) open, {
    Size screen = const Size(1900, 1000),
    Brightness brightness = Brightness.light,
  }) async {
    tester.view.physicalSize = screen;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: brightness),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => open(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  double cardWidth(WidgetTester tester) => tester
      .getSize(
        find
            .descendant(
              of: find.byType(Dialog),
              matching: find.byType(Container),
            )
            .first,
      )
      .width;

  Color? textColor(WidgetTester tester, String text) =>
      tester.widget<Text>(find.text(text)).style?.color;

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
      Widget? subtitleWidget,
      String cancelText = 'Cancel',
      bool showCloseButton = true,
      Size screen = const Size(1900, 1000),
      Brightness brightness = Brightness.light,
    }) async {
      calls = [];
      result = null;
      await openWith(
        tester,
        (context) async {
          result = await AppSimpleDialog.showConfirmation(
            context: context,
            title: 'Disable the lock?',
            message: message,
            subtitle: subtitle,
            subtitleWidget: subtitleWidget,
            confirmText: 'Disable',
            cancelText: cancelText,
            onConfirm: () => calls.add('confirm'),
            onCancel: () => calls.add('cancel'),
            showCloseButton: showCloseButton,
          );
        },
        screen: screen,
        brightness: brightness,
      );
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

    testWidgets('a custom subtitle widget is shown instead of the subtitle', (
      tester,
    ) async {
      await openConfirmation(
        tester,
        subtitle: 'Plain subtitle',
        subtitleWidget: const Text('Rich subtitle'),
      );

      expect(find.text('Rich subtitle'), findsOne);
      expect(find.text('Plain subtitle'), findsNothing);
    });

    testWidgets('without cancel text only the centred action is shown', (
      tester,
    ) async {
      await openConfirmation(tester, cancelText: '');

      expect(find.byType(OutlinedButton), findsNothing);
      expect(find.text('Disable'), findsOne);
      expect(
        tester.getCenter(find.text('Disable')).dx,
        closeTo(tester.getCenter(find.byType(Dialog)).dx, 1),
      );
    });

    for (final (brightness, colour) in [
      (Brightness.light, AppColors.textPrimary),
      (Brightness.dark, AppColors.textPrimaryDark),
    ]) {
      testWidgets('the text follows the ${brightness.name} theme', (
        tester,
      ) async {
        await openConfirmation(
          tester,
          message: 'You can turn it on again.',
          brightness: brightness,
        );

        expect(textColor(tester, 'Disable the lock?'), colour);
        expect(textColor(tester, 'You can turn it on again.'), colour);
      });
    }

    for (final (screen, width) in [
      (const Size(1900, 1000), 480.0),
      (const Size(800, 1000), 450.0),
      (const Size(400, 800), 350.0),
    ]) {
      testWidgets('is ${width.toInt()} wide on a ${screen.width.toInt()} px '
          'screen', (tester) async {
        await openConfirmation(tester, screen: screen);

        expect(cardWidth(tester), width);
      });
    }
  });

  group('destructive confirmation', () {
    late List<String> calls;
    late bool? result;

    Future<void> openDestructive(
      WidgetTester tester, {
      String? warningText,
      Color? confirmButtonColor,
      Brightness brightness = Brightness.light,
    }) async {
      calls = [];
      result = null;
      await openWith(tester, (context) async {
        result = await AppSimpleDialog.showDestructiveConfirmation(
          context: context,
          title: 'Delete record',
          message: 'The record is removed from this device.',
          confirmText: 'Delete',
          cancelText: 'Cancel',
          warningText: warningText,
          confirmButtonColor: confirmButtonColor,
          onConfirm: () => calls.add('confirm'),
          onCancel: () => calls.add('cancel'),
        );
      }, brightness: brightness);
    }

    Color? deleteColor(WidgetTester tester) => tester
        .widget<ElevatedButton>(find.byType(ElevatedButton))
        .style
        ?.backgroundColor
        ?.resolve({});

    testWidgets('shows the title, the message, Cancel and the red action', (
      tester,
    ) async {
      await openDestructive(tester);

      expect(find.text('Delete record'), findsOne);
      expect(find.text('The record is removed from this device.'), findsOne);
      expect(find.text('Cancel'), findsOne);
      expect(find.text('Delete'), findsOne);
      expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
      final theme = Theme.of(tester.element(find.byType(Dialog)));
      expect(deleteColor(tester), theme.colorScheme.error);
    });

    testWidgets('a warning is shown in red with a warning icon', (
      tester,
    ) async {
      await openDestructive(tester, warningText: 'This cannot be undone.');

      expect(find.byIcon(Icons.warning_amber_rounded), findsOne);
      final theme = Theme.of(tester.element(find.byType(Dialog)));
      expect(
        textColor(tester, 'This cannot be undone.'),
        theme.colorScheme.error,
      );
    });

    testWidgets('the action can take another colour', (tester) async {
      await openDestructive(tester, confirmButtonColor: AppColors.primary);

      expect(deleteColor(tester), AppColors.primary);
    });

    testWidgets('the text follows the dark theme', (tester) async {
      await openDestructive(tester, brightness: Brightness.dark);

      expect(textColor(tester, 'Delete record'), AppColors.textPrimaryDark);
      expect(
        textColor(tester, 'The record is removed from this device.'),
        AppColors.textPrimaryDark,
      );
    });

    testWidgets('the X cancels', (tester) async {
      await openDestructive(tester);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsNothing);
      expect(result, isFalse);
      expect(calls, ['cancel']);
    });

    testWidgets('Cancel cancels', (tester) async {
      await openDestructive(tester);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsNothing);
      expect(result, isFalse);
      expect(calls, ['cancel']);
    });

    testWidgets('the action runs on the frame after the dialog closes', (
      tester,
    ) async {
      await openDestructive(tester);

      await tester.tap(find.text('Delete'));
      expect(calls, isEmpty);
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsNothing);
      expect(result, isTrue);
      expect(calls, ['confirm']);
    });

    testWidgets('back does not close it', (tester) async {
      await openDestructive(tester);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsOne);
      expect(calls, isEmpty);
    });
  });

  group('choice dialog', () {
    late String? picked;

    Future<void> openChoice(
      WidgetTester tester, {
      Brightness brightness = Brightness.light,
    }) async {
      picked = 'not picked';
      await openWith(tester, (context) async {
        picked = await AppSimpleDialog.showChoice<String>(
          context: context,
          title: 'Where to save?',
          message: 'Pick where the document goes.',
          choices: const [
            ('New record', 'new'),
            ('Existing record', 'existing'),
            ('Not now', 'later'),
          ],
        );
      }, brightness: brightness);
    }

    testWidgets('shows the question and one button per answer', (
      tester,
    ) async {
      await openChoice(tester);

      expect(find.text('Where to save?'), findsOne);
      expect(find.text('Pick where the document goes.'), findsOne);
      final buttons = tester
          .widgetList<AppButton>(find.byType(AppButton))
          .toList();
      expect(buttons.map((b) => b.label), [
        'New record',
        'Existing record',
        'Not now',
      ]);
      expect(buttons.map((b) => b.variant), [
        AppButtonVariant.primary,
        AppButtonVariant.primary,
        AppButtonVariant.outlined,
      ]);
      expect(buttons.every((b) => b.fullWidth), isTrue);
    });

    for (final (label, value) in [
      ('New record', 'new'),
      ('Existing record', 'existing'),
      ('Not now', 'later'),
    ]) {
      testWidgets('tapping $label closes it with its answer', (tester) async {
        await openChoice(tester);

        await tester.tap(find.text(label));
        await tester.pumpAndSettle();

        expect(find.byType(Dialog), findsNothing);
        expect(picked, value);
      });
    }

    testWidgets('back and a tap outside do not close it', (tester) async {
      await openChoice(tester);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsOne);
      expect(picked, 'not picked');
    });

    testWidgets('the text follows the dark theme', (tester) async {
      await openChoice(tester, brightness: Brightness.dark);

      expect(textColor(tester, 'Where to save?'), AppColors.textPrimaryDark);
      expect(
        textColor(tester, 'Pick where the document goes.'),
        AppColors.textPrimaryDark,
      );
    });
  });
}
