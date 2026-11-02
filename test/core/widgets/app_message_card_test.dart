import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/widgets/app_message_card.dart';

Widget _app(Widget card, {Brightness brightness = Brightness.light}) =>
    MaterialApp(
      theme: ThemeData(brightness: brightness),
      home: Scaffold(body: Center(child: card)),
    );

BoxDecoration _decoration(WidgetTester tester) =>
    tester.widget<Container>(find.byKey(AppMessageCard.cardKey)).decoration!
        as BoxDecoration;

void main() {
  for (final (type, accent) in [
    (AppMessageType.error, AppColors.error),
    (AppMessageType.warning, AppColors.warning),
    (AppMessageType.success, AppColors.success),
    (AppMessageType.info, AppColors.primary),
  ]) {
    testWidgets('a ${type.name} card shows its text with a border in its '
        'colour', (tester) async {
      await tester.pumpWidget(
        _app(AppMessageCard(message: 'Something happened', type: type)),
      );

      expect(find.text('Something happened'), findsOne);
      final border = _decoration(tester).border! as Border;
      expect(border.top.color, accent.withValues(alpha: 0.4));
    });
  }

  testWidgets('inline it has no shadow; elevated it has one', (tester) async {
    await tester.pumpWidget(
      _app(const AppMessageCard(message: 'm', type: AppMessageType.error)),
    );
    expect(_decoration(tester).boxShadow, isNull);

    await tester.pumpWidget(
      _app(
        const AppMessageCard(
          message: 'm',
          type: AppMessageType.error,
          elevated: true,
        ),
      ),
    );
    expect(_decoration(tester).boxShadow, isNotEmpty);
  });

  testWidgets('shows a close button only with onClose, and calls it', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(const AppMessageCard(message: 'm', type: AppMessageType.error)),
    );
    expect(find.byKey(AppMessageCard.closeKey), findsNothing);

    var closed = 0;
    await tester.pumpWidget(
      _app(
        AppMessageCard(
          message: 'm',
          type: AppMessageType.error,
          onClose: () => closed++,
        ),
      ),
    );
    await tester.tap(find.byKey(AppMessageCard.closeKey));
    expect(closed, 1);
  });

  testWidgets('a long message wraps instead of overflowing', (tester) async {
    await tester.pumpWidget(
      _app(
        SizedBox(
          width: 300,
          child: AppMessageCard(
            message: 'Restaurarea a eșuat. Încearcă din nou. ' * 4,
            type: AppMessageType.error,
            onClose: () {},
          ),
        ),
        brightness: Brightness.dark,
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
