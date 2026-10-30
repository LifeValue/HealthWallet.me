import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/features/user/presentation/preferences_modal/sections/patient/utils/phone_input_field.dart';

void main() {
  late List<String> changes;

  setUp(() => changes = []);

  Future<void> pumpField(
    WidgetTester tester, {
    required String value,
    String? defaultCountryCode = 'RO',
    bool editable = true,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: PhoneInputField(
            value: value,
            defaultCountryCode: defaultCountryCode,
            onChanged: editable ? changes.add : null,
          ),
        ),
      ),
    );
  }

  String fieldText(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField)).controller!.text;

  testWidgets('shows a saved number with its country', (tester) async {
    await pumpField(tester, value: '+4915123456789', defaultCountryCode: null);

    expect(find.text('DE'), findsOneWidget);
    expect(fieldText(tester).replaceAll(RegExp(r'\D'), ''), '15123456789');
  });

  testWidgets('a saved number that does not parse starts empty on the '
      'default country', (tester) async {
    await pumpField(tester, value: 'not a phone number');

    expect(find.text('RO'), findsOneWidget);
    expect(fieldText(tester), isEmpty);
    expect(changes, isEmpty);
  });

  testWidgets('a placeholder number of zeros starts empty', (tester) async {
    await pumpField(tester, value: '+40000000000');

    expect(find.text('RO'), findsOneWidget);
    expect(fieldText(tester), isEmpty);
  });

  testWidgets('typing reports the number with the dial code', (tester) async {
    await pumpField(tester, value: '');

    await tester.enterText(find.byType(TextField), '712345678');
    await tester.pump();

    expect(changes.last, '+40712345678');

    await tester.enterText(find.byType(TextField), '');
    await tester.pump();

    expect(changes.last, '');
  });

  testWidgets('a read-only field has no country picker arrow', (tester) async {
    await pumpField(tester, value: '', editable: false);

    expect(find.byIcon(Icons.expand_more), findsNothing);
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
  });
}
