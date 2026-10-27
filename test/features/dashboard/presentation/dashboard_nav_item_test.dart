import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/features/dashboard/presentation/widgets/dashboard_nav_item.dart';

/// Builds the mobile tab bar as `DashboardPage` lays it out: a 60 px high
/// bar with 8 px side padding and 4 px inner padding, four equal items.
Widget _bar(Locale locale, double textScale) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Builder(
      builder: (context) {
        final l10n = AppLocalizations.of(context);
        final labels = [
          l10n.dashboardTitle,
          l10n.recordsTitle,
          l10n.documentScanTitle,
          l10n.importTitle,
        ];
        return MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: SizedBox(
                  height: 60,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      children: [
                        for (final (i, label) in labels.indexed)
                          Expanded(
                            child: DashboardNavItem(
                              icon: const SizedBox.square(dimension: 24),
                              label: label,
                              isSelected: i == 0,
                              onTap: () {},
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}

void main() {
  for (final code in ['de', 'ro', 'es', 'en']) {
    for (final scale in [1.0, 1.3]) {
      testWidgets(
        '$code tab labels fit on one line at 390 px, text scale $scale',
        (tester) async {
          tester.view.physicalSize = const Size(390, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);

          await tester.pumpWidget(_bar(Locale(code), scale));
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          final texts = tester.widgetList<Text>(find.byType(Text));
          expect(texts, hasLength(4));
          for (final text in texts) {
            expect(text.maxLines, 1);
            expect(text.overflow, isNot(TextOverflow.ellipsis));
          }
        },
      );
    }
  }

  testWidgets('the German dashboard tab is "Übersicht"', (tester) async {
    await tester.pumpWidget(_bar(const Locale('de'), 1));
    expect(find.text('Übersicht'), findsOneWidget);
  });
}
