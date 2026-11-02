import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/l10n/display_names.dart';
import 'package:health_wallet/core/l10n/l10n.dart';
import 'package:health_wallet/features/home/domain/entities/overview_card.dart';
import 'package:health_wallet/features/home/domain/entities/patient_vitals.dart';
import 'package:health_wallet/features/home/domain/factory/patient_vitals_factory.dart';
import 'package:health_wallet/features/home/domain/repository/home_preferences_repository.dart';
import 'package:health_wallet/features/home/domain/services/specialty_classifier.dart';
import 'package:health_wallet/features/home/presentation/bloc/handlers/home_data_handler.dart';
import 'package:health_wallet/features/home/presentation/bloc/home_bloc.dart';
import 'package:health_wallet/features/records/domain/repository/records_repository.dart';

/// Preferences saved by a build from before the translation: the order is
/// stored as the English titles and category names.
class _SavedEnglishLayout extends Fake implements HomePreferencesRepository {
  @override
  Future<List<String>?> getVitalsOrder() async => [
    PatientVitalType.bloodOxygen.title,
    PatientVitalType.heartRate.title,
  ];

  @override
  Future<List<String>?> getRecordsOrder() async => [
    HomeRecordsCategory.medications.display,
    HomeRecordsCategory.allergies.display,
  ];
}

class _LayoutBloc extends Bloc<HomeEvent, HomeState> with HomeDataHandler {
  _LayoutBloc() : super(const HomeState());

  @override
  final HomePreferencesRepository homePreferences = _SavedEnglishLayout();

  @override
  RecordsRepository get recordsRepository => throw UnimplementedError();

  @override
  PatientVitalFactory get patientVitalFactory => throw UnimplementedError();

  @override
  SpecialtyClassifier get specialtyClassifier => throw UnimplementedError();
}

PatientVital _vital(PatientVitalType type) =>
    PatientVital(title: type.title, value: '1', unit: type.defaultUnit);

void main() {
  group('saved dashboard layout from before the translation', () {
    late _LayoutBloc bloc;
    final ro = lookupAppLocalizations(const Locale('ro'));

    setUp(() => bloc = _LayoutBloc());
    tearDown(() => bloc.close());

    test('keeps the saved vitals order and shows localized names', () async {
      final ordered = await bloc.applyVitalSignsOrder([
        _vital(PatientVitalType.heartRate),
        _vital(PatientVitalType.temperature),
        _vital(PatientVitalType.bloodOxygen),
      ]);

      expect(ordered.map((v) => v.title), [
        PatientVitalType.bloodOxygen.title,
        PatientVitalType.heartRate.title,
        PatientVitalType.temperature.title,
      ]);
      expect(ordered.map((v) => localizedVitalTitle(v.title, ro)), [
        ro.vitalBloodOxygen,
        ro.vitalHeartRate,
        ro.vitalTemperature,
      ]);
    });

    test('keeps the saved records order', () async {
      final ordered = await bloc.applyOverviewCardsOrder([
        OverviewCard(category: HomeRecordsCategory.allergies, count: '1'),
        OverviewCard(category: HomeRecordsCategory.labResults, count: '2'),
        OverviewCard(category: HomeRecordsCategory.medications, count: '3'),
      ]);

      expect(ordered.map((c) => c.category), [
        HomeRecordsCategory.medications,
        HomeRecordsCategory.allergies,
        HomeRecordsCategory.labResults,
      ]);
    });
  });

  testWidgets('an unsupported device language falls back to English', (
    tester,
  ) async {
    tester.platformDispatcher.localesTestValue = const [Locale('fr', 'FR')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);

    late String localeName;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            localeName = context.l10n.localeName;
            return const SizedBox();
          },
        ),
      ),
    );

    expect(localeName, 'en');
  });
}
