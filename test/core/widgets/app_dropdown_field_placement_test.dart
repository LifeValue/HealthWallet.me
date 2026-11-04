import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/widgets/app_dropdown_field.dart';

/// A phone-sized screen: 874 tall, a 62 top and 34 bottom safe area.
MediaQueryData _phone({double keyboard = 0}) => MediaQueryData(
  size: const Size(402, 874),
  padding: const EdgeInsets.only(top: 62, bottom: 34),
  viewInsets: EdgeInsets.only(bottom: keyboard),
);

void main() {
  group('menuPlacement', () {
    test('opens above when asked and the whole menu fits there', () {
      final p = menuPlacement(
        fieldTop: 600,
        fieldHeight: 48,
        media: _phone(),
        itemCount: 20,
        preferAbove: true,
      );
      expect(p.above, isTrue);
      expect(p.maxHeight, 52.0 * 7);
    });

    test('a field near the top asked to open above opens below instead', () {
      // The bug: the specialty field high in the create-encounter dialog
      // opened 7 rows upwards and its first options went off the screen.
      final p = menuPlacement(
        fieldTop: 180,
        fieldHeight: 48,
        media: _phone(),
        itemCount: 20,
        preferAbove: true,
      );
      expect(p.above, isFalse);
      expect(p.maxHeight, 52.0 * 7);
    });

    test('never taller than the room on the chosen side', () {
      // Little room either way: below wins and the menu scrolls.
      final p = menuPlacement(
        fieldTop: 300,
        fieldHeight: 48,
        media: _phone(keyboard: 336),
        itemCount: 20,
        preferAbove: true,
      );
      final spaceAbove = 300 - 62 - 8;
      expect(p.above, isTrue);
      expect(p.maxHeight, spaceAbove);
      expect(p.maxHeight, lessThan(52.0 * 7));
    });

    test('the keyboard counts as used space below', () {
      final p = menuPlacement(
        fieldTop: 400,
        fieldHeight: 48,
        media: _phone(keyboard: 336),
        itemCount: 20,
        preferAbove: false,
      );
      // Below: 874 - 336 - 34 - 8 - 448 = 48, above: 400 - 62 - 8 = 330.
      expect(p.above, isTrue);
      expect(p.maxHeight, 330);
    });

    test('a short list keeps its own height', () {
      final p = menuPlacement(
        fieldTop: 600,
        fieldHeight: 48,
        media: _phone(),
        itemCount: 3,
        preferAbove: true,
      );
      expect(p.maxHeight, 52.0 * 3);
    });

    test('always leaves room for at least one row', () {
      final p = menuPlacement(
        fieldTop: 70,
        fieldHeight: 48,
        media: const MediaQueryData(
          size: Size(402, 160),
          padding: EdgeInsets.only(top: 62, bottom: 34),
        ),
        itemCount: 20,
        preferAbove: true,
      );
      expect(p.maxHeight, 52);
    });
  });

  group('AppDropdownField on screen', () {
    Future<void> pumpAt(WidgetTester tester, double top) async {
      tester.view.physicalSize = const Size(402, 874);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                Positioned(
                  top: top,
                  left: 16,
                  right: 16,
                  child: AppDropdownField<int>(
                    value: 'Pick one',
                    items: List.generate(20, (i) => i),
                    getDisplayText: (i) => 'Option $i',
                    onChanged: (_) {},
                    openAbove: true,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.tap(find.text('Pick one'));
      await tester.pumpAndSettle();
    }

    testWidgets('near the top, the first option stays on screen', (
      tester,
    ) async {
      await pumpAt(tester, 120);

      final first = tester.getRect(find.text('Option 0'));
      expect(first.top, greaterThanOrEqualTo(0));
      expect(first.top, greaterThan(120), reason: 'opened below the field');
    });

    testWidgets('lower down, it still opens above as asked', (tester) async {
      await pumpAt(tester, 700);

      final first = tester.getRect(find.text('Option 0'));
      expect(first.bottom, lessThan(700));
      expect(first.top, greaterThanOrEqualTo(0));
    });
  });
}
