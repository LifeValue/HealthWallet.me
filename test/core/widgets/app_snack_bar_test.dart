import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/widgets/app_snack_bar.dart';

/// A screen with one button that shows [message] as [type].
Widget _app({
  required AppSnackBarType type,
  String message = 'Something happened',
  Size size = const Size(390, 844),
  Brightness brightness = Brightness.dark,
}) => MediaQuery(
  data: MediaQueryData(size: size),
  child: MaterialApp(
    theme: ThemeData(brightness: brightness),
    home: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: TextButton(
            onPressed: () =>
                AppSnackBar.show(context, message: message, type: type),
            child: const Text('show'),
          ),
        ),
      ),
    ),
  ),
);

Future<void> _show(WidgetTester tester, Widget app) async {
  await tester.pumpWidget(app);
  await tester.tap(find.text('show'));
  await tester.pumpAndSettle();
}

BoxDecoration _card(WidgetTester tester) =>
    tester.widget<Container>(find.byKey(AppSnackBar.cardKey)).decoration!
        as BoxDecoration;

void main() {
  for (final (type, accent) in [
    (AppSnackBarType.error, AppColors.error),
    (AppSnackBarType.warning, AppColors.warning),
    (AppSnackBarType.success, AppColors.success),
    (AppSnackBarType.info, AppColors.primary),
  ]) {
    testWidgets('a ${type.name} message shows its text in the app style', (
      tester,
    ) async {
      await _show(tester, _app(type: type));

      expect(find.widgetWithText(SnackBar, 'Something happened'), findsOne);
      final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(snackBar.behavior, SnackBarBehavior.floating);
      expect(snackBar.backgroundColor, Colors.transparent);

      final border = _card(tester).border! as Border;
      expect(border.top.color.withValues(alpha: 1), accent);
    });
  }

  testWidgets('floats above the bottom navigation on a phone', (tester) async {
    await _show(tester, _app(type: AppSnackBarType.error));

    final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(
      (snackBar.margin! as EdgeInsets).bottom,
      AppSnackBar.mobileBottomMargin,
    );
    expect(snackBar.width, isNull);
  });

  testWidgets('is a centred card of fixed width on a wide desktop screen', (
    tester,
  ) async {
    await _show(
      tester,
      _app(type: AppSnackBarType.info, size: const Size(1440, 900)),
    );

    final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(snackBar.width, AppSnackBar.desktopWidth);
  });

  testWidgets('the close button dismisses it', (tester) async {
    await _show(tester, _app(type: AppSnackBarType.success));

    await tester.tap(find.byKey(AppSnackBar.closeKey));
    await tester.pumpAndSettle();

    expect(find.text('Something happened'), findsNothing);
  });

  testWidgets('uses an opaque surface in light and dark mode', (tester) async {
    for (final brightness in Brightness.values) {
      await _show(
        tester,
        _app(type: AppSnackBarType.error, brightness: brightness),
      );
      expect(_card(tester).color!.a, 1, reason: brightness.name);
      ScaffoldMessenger.of(
        tester.element(find.text('show')),
      ).removeCurrentSnackBar();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('does nothing without a ScaffoldMessenger', (tester) async {
    late BuildContext context;
    await tester.pumpWidget(
      Builder(
        builder: (c) {
          context = c;
          return const SizedBox();
        },
      ),
    );

    expect(
      AppSnackBar.show(context, message: 'x', type: AppSnackBarType.error),
      isNull,
    );
  });
}
