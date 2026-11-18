import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/core/utils/responsive.dart';
import 'package:health_wallet/features/home/domain/entities/medical_specialty.dart';
import 'package:health_wallet/features/home/domain/entities/overview_card.dart';
import 'package:health_wallet/features/home/domain/entities/patient_vitals.dart';
import 'package:health_wallet/features/home/domain/entities/specialty_card.dart';
import 'package:health_wallet/features/home/presentation/sections/medical_records_section.dart';
import 'package:health_wallet/features/home/presentation/sections/specialties_section.dart';
import 'package:health_wallet/features/home/presentation/sections/vitals_section.dart';

// The dashboard grids size their cells from a width/height ratio. On a narrow
// column of a tier (a 13" iPad in portrait, 1024 wide) or with a larger text
// size, the ratio alone left the cards too short and they overflowed.
void main() {
  const vitals = [
    PatientVital(
      title: 'Heart Rate',
      value: '72',
      unit: 'beats/min',
      status: 'Normal',
    ),
    PatientVital(
      title: 'Blood Pressure',
      value: '135/85',
      unit: 'mmHg',
      status: 'High',
    ),
    PatientVital(
      title: 'Temperature',
      value: '37.0',
      unit: '°C',
      status: 'Normal',
    ),
    PatientVital(
      title: 'Blood Oxygen',
      value: '98',
      unit: '%',
      status: 'Normal',
    ),
  ];
  final specialties = [
    for (final specialty in MedicalSpecialty.values.take(4))
      SpecialtyCard(specialty: specialty, count: 19),
  ];
  final overview = [
    for (final category in HomeRecordsCategory.values.take(4))
      OverviewCard(category: category, count: '12'),
  ];

  Future<void> pumpAt(
    WidgetTester tester, {
    required double width,
    required double textScale,
  }) async {
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = Size(width * 2, 1600 * 2);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: Scaffold(
              body: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: context.screenHorizontalPadding,
                ),
                child: Column(
                  children: [
                    const VitalsSection(
                      vitals: vitals,
                      allAvailableVitals: vitals,
                    ),
                    SpecialtiesSection(specialtyCards: specialties),
                    MedicalRecordsSection(overviewCards: overview),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final width in const [360.0, 412.0, 744.0, 834.0, 1024.0, 1366.0]) {
    for (final textScale in const [1.0, 1.3]) {
      testWidgets('cards fit their content at $width wide, text x$textScale', (
        tester,
      ) async {
        await pumpAt(tester, width: width, textScale: textScale);

        expect(tester.takeException(), isNull);
      });
    }
  }
}
