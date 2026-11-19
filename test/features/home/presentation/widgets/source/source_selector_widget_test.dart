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
  late List<Source> renamed;
  late List<Source> deleted;

  setUp(() {
    changes = [];
    renamed = [];
    deleted = [];
  });

  Widget app({
    List<String>? holderSourceIds = const ['clinic', 'lab'],
    List<Source> sources = _sources,
  }) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Center(
        child: SourceSelectorWidget(
          sources: sources,
          selectedSource: 'clinic',
          holderSourceIds: holderSourceIds,
          holderName: 'Jane Doe',
          onSourceChanged: changes.add,
          onSourceLabelEdit: renamed.add,
          onSourceDelete: deleted.add,
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

  testWidgets('renaming a source passes the new name', (tester) async {
    await tester.pumpWidget(app());
    await openList(tester);

    final labRow = find.ancestor(
      of: find.text('Lab Results').last,
      matching: find.byType(Row),
    );
    await tester.tap(
      find
          .descendant(of: labRow.first, matching: find.byType(GestureDetector))
          .first,
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Synevo');
    await tester.tap(find.byType(ElevatedButton).last);
    await tester.pumpAndSettle();

    expect(renamed.single.id, 'lab');
    expect(renamed.single.labelSource, 'Synevo');
  });

  testWidgets("a wallet source is shown under the person's name and can't be "
      'deleted', (tester) async {
    await tester.pumpWidget(
      app(
        holderSourceIds: const ['clinic', 'wallet-jane'],
        sources: const [
          Source(
            id: 'clinic',
            labelSource: 'City Clinic',
            platformType: 'fasten',
          ),
          Source(
            id: 'wallet-jane',
            labelSource: 'Wallet - Health Wallet Holder',
            platformType: 'wallet',
          ),
        ],
      ),
    );
    await openList(tester);

    expect(find.text('Jane Doe'), findsOneWidget);
    expect(find.text('Wallet - Health Wallet Holder'), findsNothing);
    final janeRow = find.ancestor(
      of: find.text('Jane Doe'),
      matching: find.byType(Row),
    );
    final clinicRow = find.ancestor(
      of: find.text('City Clinic').last,
      matching: find.byType(Row),
    );
    expect(
      find.descendant(
        of: janeRow.first,
        matching: find.byType(GestureDetector),
      ),
      findsOneWidget,
      reason: 'rename only',
    );
    expect(
      find.descendant(
        of: clinicRow.first,
        matching: find.byType(GestureDetector),
      ),
      findsNWidgets(2),
      reason: 'rename and delete',
    );
  });
}
