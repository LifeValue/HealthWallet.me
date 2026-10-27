import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/core/l10n/display_names.dart';
import 'package:health_wallet/features/home/domain/entities/medical_specialty.dart';
import 'package:health_wallet/features/home/domain/entities/overview_card.dart';
import 'package:health_wallet/features/home/domain/entities/patient_vitals.dart';
import 'package:health_wallet/features/processing/domain/entity/processing_session.dart';
import 'package:health_wallet/features/records/domain/entity/i_fhir_resource.dart';

/// The localized name and the English key of every value that must be
/// translated at display time.
Map<String, (String, String)> _names(AppLocalizations l10n) => {
  for (final v in PatientVitalType.values)
    'vital.${v.name}': (v.localizedName(l10n), v.title),
  for (final s in MedicalSpecialty.values)
    'specialty.${s.name}': (s.localizedName(l10n), s.displayName),
  for (final c in HomeRecordsCategory.values)
    'category.${c.name}': (c.localizedName(l10n), c.display),
  for (final t in FhirType.values)
    'fhirType.${t.name}': (t.localizedName(l10n), t.display),
  for (final o in ProcessingOrigin.values)
    'origin.${o.name}': (o.localizedName(l10n), o.toString()),
  for (final s in ProcessingStatus.values)
    'status.${s.name}': (s.localizedName(l10n), s.toString()),
};

/// Names that are spelled the same as in English in that language.
const _sameAsEnglish = {
  'de': {
    'vital.bmi',
    'fhirType.Patient',
    'origin.scan',
    'origin.import',
  },
  'ro': {
    'fhirType.DocumentReference',
    'fhirType.Media',
    'origin.import',
  },
  'es': <String>{},
};

void main() {
  for (final code in ['en', 'es', 'de', 'ro']) {
    final l10n = lookupAppLocalizations(Locale(code));

    test('every display name is non-empty in $code', () {
      final empty = _names(
        l10n,
      ).entries.where((e) => e.value.$1.trim().isEmpty).map((e) => e.key);
      expect(empty, isEmpty);
    });
  }

  test('English names keep the English keys, except fixed typos', () {
    final l10n = lookupAppLocalizations(const Locale('en'));
    final differing = _names(l10n).entries
        .where((e) => e.value.$1 != e.value.$2)
        .map((e) => e.key)
        .toList();
    expect(differing, ['fhirType.MedicationStatement']);
    expect(
      FhirType.MedicationStatement.localizedName(l10n),
      'Medication Statement',
    );
  });

  for (final code in ['de', 'ro']) {
    test('$code names differ from the English key where the words differ', () {
      final l10n = lookupAppLocalizations(Locale(code));
      final untranslated = _names(l10n).entries
          .where(
            (e) =>
                e.value.$1 == e.value.$2 &&
                !_sameAsEnglish[code]!.contains(e.key),
          )
          .map((e) => e.key)
          .toList();
      expect(untranslated, isEmpty);
    });
  }

  group('localizedVitalTitle', () {
    final ro = lookupAppLocalizations(const Locale('ro'));

    test('localizes a known vital title', () {
      expect(localizedVitalTitle('Heart Rate', ro), ro.vitalHeartRate);
      expect(ro.vitalHeartRate, isNot('Heart Rate'));
    });

    test('returns an unmapped title unchanged', () {
      expect(localizedVitalTitle('Cholesterol HDL', ro), 'Cholesterol HDL');
    });
  });

  test('localizedSpecialtyName falls back to the stored name', () {
    final de = lookupAppLocalizations(const Locale('de'));
    expect(localizedSpecialtyName('Cardiology', de), 'Kardiologie');
    expect(localizedSpecialtyName('Podiatry', de), 'Podiatry');
  });

  test('localizedStatusDisplay translates Active/Inactive only', () {
    final ro = lookupAppLocalizations(const Locale('ro'));
    expect(localizedStatusDisplay('Active', ro), ro.active);
    expect(localizedStatusDisplay('Inactive', ro), ro.inactive);
    expect(ro.active, isNot('Active'));
    expect(localizedStatusDisplay('final', ro), 'final');
  });
}
