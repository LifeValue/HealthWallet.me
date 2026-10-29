import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/features/user/presentation/pages/privacy_policy_page.dart';

Widget _page(Locale locale) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: const PrivacyPolicyPage(),
);

/// Every piece of text the page renders, RichText spans included.
List<String> _renderedText(WidgetTester tester) => tester
    .widgetList<RichText>(find.byType(RichText))
    .map((r) => r.text.toPlainText())
    .toList();

void main() {
  testWidgets('renders the policy in Romanian', (tester) async {
    await tester.pumpWidget(_page(const Locale('ro')));
    await tester.pumpAndSettle();

    final text = _renderedText(tester).join('\n');
    expect(text, contains('nu colectăm, nu stocăm și nu avem acces'));
    expect(text, contains('Data intrării în vigoare: 1 septembrie 2025'));
    expect(text, isNot(contains('**')), reason: 'bold markers must not show');
    expect(text, isNot(contains('do not collect')));
    expect(text, isNot(contains('Our app operates entirely')));
    expect(text, isNot(contains('September')));
  });

  testWidgets('keeps the English policy and its bold parts', (tester) async {
    await tester.pumpWidget(_page(const Locale('en')));
    await tester.pumpAndSettle();

    final text = _renderedText(tester).join('\n');
    expect(text, contains('Effective Date: September 1, 2025'));
    expect(
      text,
      contains(
        'The most important thing to know is that we, the developers of '
        'HealthWallet.me, do not collect, store, or have access to any of '
        'your personal or health information.',
      ),
    );
    expect(text, isNot(contains('**')));

    final bold = tester
        .widgetList<RichText>(find.byType(RichText))
        .expand((r) {
          final spans = <InlineSpan>[];
          r.text.visitChildren((span) {
            spans.add(span);
            return true;
          });
          return spans;
        })
        .whereType<TextSpan>()
        .where((s) => s.style?.fontWeight == FontWeight.bold)
        .map((s) => s.text)
        .toSet();
    expect(bold, containsAll(['do not', 'does not', 'you choose to import']));
  });
}
