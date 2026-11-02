import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/features/home/presentation/widgets/source/source_selector_widget.dart';
import 'package:health_wallet/features/sync/domain/entities/source.dart';

const _sources = [
  Source(id: 'clinic', labelSource: 'City Clinic'),
  Source(id: 'lab', labelSource: 'Lab Results'),
  Source(id: 'other', labelSource: "Tom's Clinic"),
];

final _en = lookupAppLocalizations(const Locale('en'));

void main() {
  late List<String> changes;

  setUp(() => changes = []);

  Widget app({List<String>? holderSourceIds = const ['clinic', 'lab']}) =>
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: SourceSelectorWidget(
              sources: _sources,
              selectedSource: 'clinic',
              holderSourceIds: holderSourceIds,
              onSourceChanged: changes.add,
            ),
          ),
        ),
      );

  Future<void> openList(WidgetTester tester) async {
    await tester.tap(find.text('City Clinic'));
    await tester.pumpAndSettle();
  }

  testWidgets("lists the selected person's sources only, All first", (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await openList(tester);

    expect(find.text(_en.all), findsOneWidget);
    expect(find.text('Lab Results'), findsOneWidget);
    expect(find.text("Tom's Clinic"), findsNothing);
  });

  testWidgets('picking All or one source passes its id', (tester) async {
    await tester.pumpWidget(app());
    await openList(tester);
    await tester.tap(find.text(_en.all));
    await tester.pumpAndSettle();

    await openList(tester);
    await tester.tap(find.text('Lab Results').last);
    await tester.pumpAndSettle();

    expect(changes, ['All', 'lab']);
  });

  testWidgets('with no one selected every source is listed', (tester) async {
    await tester.pumpWidget(app(holderSourceIds: null));
    await tester.tap(find.byType(InkWell).first);
    await tester.pumpAndSettle();

    expect(find.text("Tom's Clinic"), findsOneWidget);
  });
}
