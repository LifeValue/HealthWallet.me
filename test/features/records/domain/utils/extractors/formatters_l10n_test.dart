import 'package:fhir_r4/fhir_r4.dart' as fhir;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/core/utils/date_format_utils.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/records/domain/utils/extractors/fhir_patient_extractor.dart';
import 'package:health_wallet/features/records/domain/utils/extractors/fhir_temporal_extractor.dart';

import '../../../../../fixtures/fhir/fhir_fixtures.dart';

void main() {
  final en = lookupAppLocalizations(const Locale('en'));
  final ro = lookupAppLocalizations(const Locale('ro'));

  group('FhirPatientExtractor in Romanian', () {
    test('extractPatientAge counts years', () {
      final now = DateTime.now();
      String birthDateYearsAgo(int years) =>
          '${now.year - years}-01-01'.padLeft(10, '0');
      Patient patientAged(int years) =>
          entityFromJson(patientJson(birthDate: birthDateYearsAgo(years)))
              as Patient;

      expect(
        FhirPatientExtractor.extractPatientAge(patientAged(1), l10n: ro),
        '1 an',
      );
      expect(
        FhirPatientExtractor.extractPatientAge(patientAged(5), l10n: ro),
        '5 ani',
      );
      expect(
        FhirPatientExtractor.extractPatientAge(patientAged(40), l10n: ro),
        '40 de ani',
      );
      expect(
        FhirPatientExtractor.extractPatientAge(patientAged(40), l10n: en),
        '40 years',
      );
    });

    test('extractPatientIdentifierLabel translates the passport label', () {
      final patient = entityFromJson(
        patientJson(
          identifiers: [identifier(value: '1', typeCode: 'PPN')],
        ),
      ) as Patient;

      expect(
        FhirPatientExtractor.extractPatientIdentifierLabel(patient, l10n: ro),
        'Pașaport',
      );
      expect(
        FhirPatientExtractor.extractPatientIdentifierLabel(patient),
        'Passport',
      );
    });

    test('extractMultipleBirth answers in Romanian', () {
      expect(
        FhirPatientExtractor.extractMultipleBirth(
          fhir.FhirBoolean(true),
          l10n: ro,
        ),
        'Da',
      );
      expect(
        FhirPatientExtractor.extractMultipleBirth(
          fhir.FhirBoolean(false),
          l10n: ro,
        ),
        'Nu',
      );
      expect(
        FhirPatientExtractor.extractMultipleBirth(
          fhir.FhirInteger(2),
          l10n: ro,
        ),
        'Da (ordinea nașterii: 2)',
      );
    });
  });

  group('FhirTemporalExtractor in Romanian', () {
    test('extractPeriod words open periods', () {
      expect(
        FhirTemporalExtractor.extractPeriod(
          fhir.Period(start: fhir.FhirDateTime.fromString('2020-01-01')),
          l10n: ro,
        ),
        'Din 2020-01-01',
      );
      expect(
        FhirTemporalExtractor.extractPeriod(
          fhir.Period(end: fhir.FhirDateTime.fromString('2020-01-01')),
          l10n: ro,
        ),
        'Până la 2020-01-01',
      );
    });

    test('extractPeriodFormatted words open periods', () {
      final formatted = FhirTemporalExtractor.extractPeriodFormatted(
        fhir.Period(start: fhir.FhirDateTime.fromString('2020-01-01T10:00')),
        l10n: ro,
      );
      expect(formatted, startsWith('Din '));
    });

    test('extractAbatementXFormatted answers in Romanian', () {
      expect(
        FhirTemporalExtractor.extractAbatementXFormatted(
          fhir.FhirBoolean(true),
          l10n: ro,
        ),
        'Da',
      );
    });
  });

  group('DateFormatUtils.getSincePretty', () {
    final now = DateTime.now();

    test('speaks Romanian', () {
      expect(
        DateFormatUtils.getSincePretty(
          now.subtract(const Duration(days: 2, minutes: 1)),
          ro,
        ),
        'acum 2 zile',
      );
      expect(
        DateFormatUtils.getSincePretty(
          now.subtract(const Duration(hours: 1, minutes: 1)),
          ro,
        ),
        'acum o oră',
      );
      expect(DateFormatUtils.getSincePretty(now, ro), 'Chiar acum');
    });

    test('keeps the English text', () {
      expect(
        DateFormatUtils.getSincePretty(
          now.subtract(const Duration(days: 1, minutes: 1)),
          en,
        ),
        '1 day ago',
      );
      expect(
        DateFormatUtils.getSincePretty(
          now.subtract(const Duration(minutes: 5, seconds: 1)),
          en,
        ),
        '5 minutes ago',
      );
      expect(DateFormatUtils.getSincePretty(now, en), 'Just now');
    });
  });
}
