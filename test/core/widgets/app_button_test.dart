import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/theme/theme.dart';
import 'package:health_wallet/core/widgets/app_button.dart';

void main() {
  Future<void> pumpOutlined(
    WidgetTester tester, {
    VoidCallback? onPressed,
    Widget? icon,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: Center(
            child: AppButton(
              label: 'Cancel',
              onPressed: onPressed,
              icon: icon,
              variant: AppButtonVariant.outlined,
              fullWidth: false,
            ),
          ),
        ),
      ),
    );
  }

  ButtonStyle styleOf(WidgetTester tester) =>
      tester.widget<OutlinedButton>(find.byType(OutlinedButton)).style!;

  Color? materialColor(WidgetTester tester) => tester
      .widget<Material>(
        find.descendant(
          of: find.byType(OutlinedButton),
          matching: find.byType(Material),
        ),
      )
      .color;

  testWidgets('an outlined button fills with its border colour under the '
      'mouse, with a white label', (tester) async {
    await pumpOutlined(tester, onPressed: () {});
    final primary = AppTheme.darkTheme.colorScheme.primary;

    expect(materialColor(tester), Colors.transparent);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.byType(OutlinedButton)));
    await tester.pumpAndSettle();

    expect(materialColor(tester), primary);
    // White in the dark theme, like a filled button's label.
    expect(
      styleOf(tester).foregroundColor!.resolve({WidgetState.hovered}),
      Colors.white,
    );

    await mouse.moveTo(Offset.zero);
    await tester.pumpAndSettle();
    expect(materialColor(tester), Colors.transparent);
  });

  testWidgets('pressing fills it too; a disabled one never fills', (
    tester,
  ) async {
    await pumpOutlined(tester, onPressed: () {});
    final style = styleOf(tester);
    final primary = AppTheme.darkTheme.colorScheme.primary;

    expect(style.backgroundColor!.resolve({WidgetState.pressed}), primary);
    expect(
      style.backgroundColor!.resolve({
        WidgetState.hovered,
        WidgetState.disabled,
      }),
      Colors.transparent,
    );
    expect(
      style.foregroundColor!.resolve({WidgetState.disabled}),
      primary.withValues(alpha: 0.5),
    );
    expect(style.foregroundColor!.resolve({}), primary);
    expect(style.overlayColor!.resolve({WidgetState.hovered}), isNot(primary));
  });

  testWidgets('with an icon it keeps the plain outlined look, so the icon '
      'stays visible', (tester) async {
    await pumpOutlined(
      tester,
      onPressed: () {},
      icon: const Icon(Icons.close),
    );

    final background = styleOf(tester).backgroundColor!;
    expect(background.resolve({WidgetState.hovered}), Colors.transparent);
  });
}
