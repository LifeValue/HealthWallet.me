import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/theme/theme.dart';
import 'package:health_wallet/core/widgets/app_dropdown_field.dart';

const _fruits = ['Apple', 'Banana', 'Cherry'];

void main() {
  late List<String> chosen;

  setUp(() => chosen = []);

  Future<void> pumpField(
    WidgetTester tester, {
    String value = 'Apple',
    List<String> items = _fruits,
    bool enabled = true,
    bool hasError = false,
    bool dark = false,
    Widget Function(BuildContext, String, bool)? itemBuilder,
    Widget Function(BuildContext, String)? valueBuilder,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                AppDropdownField<String>(
                  value: value,
                  items: items,
                  getDisplayText: (item) => item,
                  onChanged: enabled ? chosen.add : null,
                  hasError: hasError,
                  itemBuilder: itemBuilder,
                  valueBuilder: valueBuilder,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The colour of the field's border.
  Color borderColor(WidgetTester tester) {
    final container = tester.widget<Container>(
      find
          .descendant(
            of: find.byType(AppDropdownField<String>),
            matching: find.byType(Container),
          )
          .first,
    );
    final border = (container.decoration! as BoxDecoration).border! as Border;
    return border.top.color;
  }

  testWidgets('shows the value and opens a menu of every item', (
    tester,
  ) async {
    await pumpField(tester);
    expect(find.text('Apple'), findsOne);
    expect(find.byIcon(Icons.expand_more), findsOne);

    await tester.tap(find.text('Apple'));
    await tester.pumpAndSettle();

    expect(find.text('Banana'), findsOne);
    expect(find.text('Cherry'), findsOne);
    expect(find.byIcon(Icons.expand_less), findsOne);
  });

  testWidgets('choosing an item reports it and closes the menu', (
    tester,
  ) async {
    await pumpField(tester);
    await tester.tap(find.text('Apple'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cherry'));
    await tester.pumpAndSettle();

    expect(chosen, ['Cherry']);
    expect(find.text('Banana'), findsNothing);
    expect(find.byIcon(Icons.expand_more), findsOne);
  });

  testWidgets('a tap outside the menu closes it without a choice', (
    tester,
  ) async {
    await pumpField(tester);
    await tester.tap(find.text('Apple'));
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(390, 590));
    await tester.pumpAndSettle();

    expect(chosen, isEmpty);
    expect(find.text('Banana'), findsNothing);
  });

  testWidgets('from the keyboard, activating the field opens the menu and '
      'activating it again closes it', (tester) async {
    await pumpField(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('Banana'), findsOne);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('Banana'), findsNothing);
    expect(find.byIcon(Icons.expand_more), findsOne);
    expect(chosen, isEmpty);
  });

  testWidgets('without onChanged it does not open', (tester) async {
    await pumpField(tester, enabled: false);

    await tester.tap(find.text('Apple'));
    await tester.pumpAndSettle();

    expect(find.text('Banana'), findsNothing);
  });

  testWidgets('the border shows an error, the open menu, or the theme', (
    tester,
  ) async {
    await pumpField(tester);
    expect(borderColor(tester), AppColors.border);

    await tester.tap(find.text('Apple'));
    await tester.pumpAndSettle();
    final theme = Theme.of(tester.element(find.byType(Scaffold)));
    expect(borderColor(tester), theme.colorScheme.primary);

    await pumpField(tester, hasError: true);
    expect(borderColor(tester), theme.colorScheme.error);

    await tester.tapAt(const Offset(390, 590));
    await tester.pumpAndSettle();
    await pumpField(tester, dark: true);
    // Lets the theme change finish its animation.
    await tester.pumpAndSettle();
    expect(borderColor(tester), AppColors.borderDark);
  });

  testWidgets('custom builders draw the value and the items', (tester) async {
    await pumpField(
      tester,
      value: 'Banana',
      valueBuilder: (context, value) => Text('value: $value'),
      itemBuilder: (context, item, isSelected) =>
          Text(isSelected ? '[$item]' : item),
    );
    expect(find.text('value: Banana'), findsOne);

    await tester.tap(find.text('value: Banana'));
    await tester.pumpAndSettle();

    expect(find.text('[Banana]'), findsOne);
    expect(find.text('Apple'), findsOne);

    await tester.tap(find.text('Apple'));
    await tester.pumpAndSettle();
    expect(chosen, ['Apple']);
  });

  testWidgets('a long list scrolls to the chosen item', (tester) async {
    final items = [for (var i = 0; i < 30; i++) 'Item $i'];
    await pumpField(tester, value: 'Item 20', items: items);

    await tester.tap(find.text('Item 20'));
    await tester.pumpAndSettle();

    // Scrolled away from the top: the first item is out of view. (It is
    // scrolled by 52 px rows, which overshoots shorter rows.)
    expect(
      tester.widget<ListView>(find.byType(ListView)).controller!.offset,
      greaterThan(0),
    );
    expect(
      find.descendant(of: find.byType(ListView), matching: find.text('Item 0')),
      findsNothing,
    );
  });
}
