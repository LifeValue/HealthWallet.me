import 'dart:io';

import 'package:fhir_r4/fhir_r4.dart' as fhir;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/config/constants/region_preset.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/records/presentation/models/record_info_line.dart';

import '../../../../fixtures/fhir/fhir_fixtures.dart';

List<String> _infos(List<RecordInfoLine> lines) =>
    lines.map((l) => l.info).toList();

List<String> _sections(List<RecordInfoLine> lines) =>
    lines.where((l) => l.isSection).map((l) => l.info).toList();

void main() {
  final en = lookupAppLocalizations(const Locale('en'));
  final ro = lookupAppLocalizations(const Locale('ro'));

  group('Condition.additionalInfo', () {
    final condition = entityFromJson({
      ...conditionJson(abatement: {'abatementDateTime': '2020-05-01'}),
      'clinicalStatus': codeableConcept(text: 'active'),
      'severity': codeableConcept(text: 'moderate'),
    });

    test('renders Romanian labels', () {
      final infos = _infos(condition.additionalInfo(ro));

      expect(infos, contains('Stare clinică: active'));
      expect(infos, contains('Severitate: moderate'));
      expect(infos, contains('Debut: 2019-02-01'));
      expect(infos, contains('Rezolvat: 2020-05-01'));
    });

    test('keeps the English labels', () {
      final infos = _infos(condition.additionalInfo(en));

      expect(infos, contains('Clinical Status: active'));
      expect(infos, contains('Onset: 2019-02-01'));
      expect(infos, contains('Resolved: 2020-05-01'));
    });
  });

  group('Observation.additionalInfo', () {
    final observation = entityFromJson(
      observationJson(
        value: {'valueQuantity': quantity(13.5, unit: 'g/dL')},
      ),
    ) as Observation;

    test('renders Romanian section headers and labels', () {
      final lines = observation.additionalInfo(ro);

      expect(
        _sections(lines),
        containsAllInOrder([
          'Rezultat',
          'Informații de bază',
          'Informații suplimentare',
        ]),
      );
      expect(_infos(lines), contains('Valoare: 13.50 g/dL'));
      expect(_infos(lines), contains('Categorie: Laboratory'));
    });

    test('renders Romanian labels for a region', () {
      final lines = observation.additionalInfoForRegion(
        RegionPreset.europe,
        ro,
      );

      expect(_sections(lines).first, 'Rezultat');
      expect(_infos(lines), contains('Stare: final'));
    });

    test('keeps the English labels', () {
      final lines = observation.additionalInfo(en);

      expect(
        _sections(lines),
        containsAllInOrder([
          'Result',
          'Basic Information',
          'Additional Information',
        ]),
      );
      expect(_infos(lines), contains('Value: 13.50 g/dL'));
    });
  });

  test('a diagnostic report counts its results in Romanian', () {
    final report = DiagnosticReport(
      result: [
        for (var i = 0; i < 3; i++)
          fhir.Reference(reference: fhir.FhirString('Observation/$i')),
      ],
    );

    expect(
      _infos(report.additionalInfo(ro)),
      contains('Rezultate: 3 rezultate'),
    );
    expect(_infos(report.additionalInfo(en)), contains('Results: 3 result(s)'));
  });

  test('every record type renders in every locale', () {
    for (final locale in AppLocalizations.supportedLocales) {
      final l10n = lookupAppLocalizations(locale);
      for (final json in minimalResources().values) {
        final resource = entityFromJson(json);
        expect(
          () => resource.additionalInfo(l10n),
          returnsNormally,
          reason: '${resource.fhirType} in $locale',
        );
      }
    }
  });

  test('record entities pass every label through the ARB files', () {
    final literal = RegExp(
      r'''(?:prefix:\s*|createSectionHeader\(\s*)(['"])[^A-Za-z'"$]*[A-Za-z]''',
    );
    final offenders = <String>[];
    final files = Directory('lib/features/records/domain/entity')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => !f.path.endsWith('.freezed.dart'));
    for (final file in files) {
      final source = file.readAsStringSync();
      for (final match in literal.allMatches(source)) {
        final line = '\n'.allMatches(source.substring(0, match.start)).length;
        offenders.add('${file.path}:${line + 1}');
      }
    }

    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });
}
