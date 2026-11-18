import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/records/presentation/widgets/delete_record_dialog.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  const related = <IFhirResource>[
    Encounter(id: 'enc-1', title: 'General examination'),
    Observation(id: 'obs-1', title: 'Blood Pressure'),
    Observation(id: 'obs-2', title: 'Blood Glucose'),
  ];

  /// Opens the dialog on a phone-sized screen; the result lands in the
  /// returned list once the dialog closes.
  Future<List<List<String>?>> open(
    WidgetTester tester, {
    List<IFhirResource> relatedResources = related,
    String recordTitle = 'Medical Report',
    Brightness brightness = Brightness.light,
    Size screen = const Size(390, 844),
  }) async {
    tester.view.physicalSize = screen;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final results = <List<String>?>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: brightness),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async => results.add(
                await DeleteRecordDialog.show(
                  context,
                  recordTitle: recordTitle,
                  relatedResources: relatedResources,
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return results;
  }

  String deleteLabel(WidgetTester tester) => tester
      .widget<Text>(
        find.descendant(
          of: find.byKey(DeleteRecordDialog.deleteKey),
          matching: find.byType(Text),
        ),
      )
      .data!;

  testWidgets('shows the record in the header with a close button, the '
      'related resources as an optional list, and Cancel and Delete', (
    tester,
  ) async {
    await open(tester);

    expect(find.text(l10n.deleteRecordOfType('Medical Report')), findsOne);
    expect(find.byKey(DeleteRecordDialog.closeKey), findsOne);
    expect(find.text(l10n.relatedResourcesKeptHint), findsOne);
    expect(find.text(l10n.relatedResourcesCount(3)), findsOne);
    expect(find.text('General examination'), findsOne);
    expect(find.text('Blood Pressure'), findsOne);
    expect(find.text('Encounter'), findsOne);
    expect(find.text('Observation'), findsNWidgets(2));
    expect(find.text(l10n.selectAll), findsOne);
    expect(find.byKey(DeleteRecordDialog.cancelKey), findsOne);
    expect(deleteLabel(tester), l10n.deletePage);
  });

  testWidgets('the buttons sit below the list', (tester) async {
    await open(tester);

    final lastItem = tester.getBottomLeft(find.text('Blood Glucose'));
    final delete = tester.getTopLeft(find.byKey(DeleteRecordDialog.deleteKey));
    final cancel = tester.getTopLeft(find.byKey(DeleteRecordDialog.cancelKey));
    expect(delete.dy, greaterThan(lastItem.dy));
    expect(cancel.dy, delete.dy);
    expect(cancel.dx, lessThan(delete.dx), reason: 'Cancel left, Delete right');
  });

  testWidgets('the close button closes without deleting', (tester) async {
    final results = await open(tester);

    await tester.tap(find.byKey(DeleteRecordDialog.closeKey));
    await tester.pumpAndSettle();

    expect(find.byType(DeleteRecordDialog), findsNothing);
    expect(results, [null]);
  });

  testWidgets('Cancel closes without deleting', (tester) async {
    final results = await open(tester);

    await tester.tap(find.byKey(DeleteRecordDialog.cancelKey));
    await tester.pumpAndSettle();

    expect(results, [null]);
  });

  testWidgets('Delete with nothing selected deletes only the record', (
    tester,
  ) async {
    final results = await open(tester);

    await tester.tap(find.byKey(DeleteRecordDialog.deleteKey));
    await tester.pumpAndSettle();

    expect(results, [<String>[]]);
  });

  testWidgets('tapping related resources selects them and Delete names how '
      'many go with the record', (tester) async {
    final results = await open(tester);

    await tester.tap(find.text('General examination'));
    await tester.tap(find.text('Blood Glucose'));
    await tester.pump();
    expect(deleteLabel(tester), l10n.deletePlusRelated(2));

    await tester.tap(find.text('General examination'));
    await tester.pump();
    expect(deleteLabel(tester), l10n.deletePlusRelated(1));

    await tester.tap(find.byKey(DeleteRecordDialog.deleteKey));
    await tester.pumpAndSettle();
    expect(results, [
      ['obs-2'],
    ]);
  });

  testWidgets('Select all selects every related resource, then turns into '
      'Deselect all', (tester) async {
    final results = await open(tester);

    await tester.tap(find.byKey(DeleteRecordDialog.toggleAllKey));
    await tester.pump();
    expect(deleteLabel(tester), l10n.deletePlusRelated(3));
    expect(find.text(l10n.deselectAll), findsOne);

    await tester.tap(find.byKey(DeleteRecordDialog.toggleAllKey));
    await tester.pump();
    expect(deleteLabel(tester), l10n.deletePage);
    expect(find.text(l10n.selectAll), findsOne);

    await tester.tap(find.byKey(DeleteRecordDialog.toggleAllKey));
    await tester.pump();
    await tester.tap(find.byKey(DeleteRecordDialog.deleteKey));
    await tester.pumpAndSettle();
    expect(results.single, unorderedEquals(['enc-1', 'obs-1', 'obs-2']));
  });

  testWidgets('a long list scrolls while Cancel and Delete stay on screen', (
    tester,
  ) async {
    final many = [
      for (var i = 0; i < 30; i++) Observation(id: 'o$i', title: 'Result $i'),
    ];
    final results = await open(
      tester,
      relatedResources: many,
      screen: const Size(375, 667),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Result 29'), findsNothing);
    final delete = tester.getRect(find.byKey(DeleteRecordDialog.deleteKey));
    expect(delete.bottom, lessThanOrEqualTo(667));

    await tester.scrollUntilVisible(find.text('Result 29'), 200);
    await tester.tap(find.text('Result 29'));
    await tester.pump();
    await tester.tap(find.byKey(DeleteRecordDialog.deleteKey));
    await tester.pumpAndSettle();
    expect(results, [
      ['o29'],
    ]);
  });

  testWidgets('a long record name wraps instead of hiding the close button', (
    tester,
  ) async {
    await open(
      tester,
      recordTitle: 'General examination of patient (procedure)',
    );

    expect(tester.takeException(), isNull);
    final title = tester.getRect(
      find.text(
        l10n.deleteRecordOfType('General examination of patient (procedure)'),
      ),
    );
    final close = tester.getRect(find.byKey(DeleteRecordDialog.closeKey));
    expect(title.right, lessThanOrEqualTo(close.left));
  });

  testWidgets('renders in the dark theme', (tester) async {
    await open(tester, brightness: Brightness.dark);

    expect(tester.takeException(), isNull);
    expect(find.byType(DeleteRecordDialog), findsOne);
  });
}
