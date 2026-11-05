import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/records/presentation/widgets/vision_prescription_table.dart';

import '../../../../fixtures/fhir/fhir_fixtures.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  Future<void> pump(WidgetTester tester, Map<String, dynamic> json) =>
      tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: VisionPrescriptionTable(
              rows: (entityFromJson(json) as VisionPrescription).eyeRows,
            ),
          ),
        ),
      );

  /// The cells of each table row, as text.
  List<List<String>> rows(WidgetTester tester) => [
    for (final row in tester.widget<Table>(find.byType(Table)).children)
      [
        for (final cell in row.children)
          tester
              .widgetList<Text>(
                find.descendant(
                  of: find.byWidget(cell),
                  matching: find.byType(Text),
                ),
              )
              .map((t) => t.data!)
              .join(),
      ],
  ];

  testWidgets('one row per eye, OD then OS, with the printed values', (
    tester,
  ) async {
    await pump(tester, visionPrescriptionJson());

    expect(rows(tester), [
      [
        '',
        l10n.visionSphere,
        l10n.visionCylinder,
        l10n.visionAxis,
        l10n.visionAdd,
      ],
      [l10n.visionEyeRight, '+0.75', '-', '-', '+1.75'],
      [l10n.visionEyeLeft, '+0.75', '+0.25', '160°', '+1.75'],
    ]);
  });

  testWidgets('the Add column is shown only when an eye has an add', (
    tester,
  ) async {
    final json = visionPrescriptionJson();
    for (final lens in json['lensSpecification'] as List) {
      (lens as Map).remove('add');
    }
    await pump(tester, json);

    expect(find.text(l10n.visionAdd), findsNothing);
    expect(rows(tester).first, [
      '',
      l10n.visionSphere,
      l10n.visionCylinder,
      l10n.visionAxis,
    ]);
  });
}
