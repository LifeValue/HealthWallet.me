import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/config/constants/region_preset.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/records/presentation/models/record_info_line.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../../../fixtures/fhir/fhir_fixtures.dart';

List<String> _infos(List<RecordInfoLine> lines) =>
    lines.map((l) => l.info).toList();

Observation _troponin(Map<String, dynamic> range) => entityFromJson({
  ...observationJson(
    code: '6598-7',
    codeDisplay: 'Troponin T',
    value: {'valueQuantity': quantity(0.004, unit: 'ng/mL')},
  ),
  'referenceRange': [range],
}) as Observation;

void main() {
  setUpAll(initializeDateFormatting);

  final en = lookupAppLocalizations(const Locale('en'));

  final variants =
      <(String, List<RecordInfoLine> Function(Observation observation))>[
        ('additionalInfo', (o) => o.additionalInfo(en)),
        (
          'additionalInfoForRegion',
          (o) => o.additionalInfoForRegion(RegionPreset.us, en),
        ),
      ];

  for (final (name, info) in variants) {
    group('$name reference range', () {
      test('keeps the decimals of a small value and its high bound', () {
        final infos = _infos(
          info(_troponin({'high': quantity(0.014, unit: 'ng/mL')})),
        );
        expect(infos, contains('Value: 0.004 ng/mL'));
        expect(infos, contains('Reference Range: < 0.014 ng/mL'));
      });

      test('shows both bounds with at least 2 decimals', () {
        final infos = _infos(
          info(
            _troponin({
              'low': quantity(0, unit: 'ng/mL'),
              'high': quantity(0.014, unit: 'ng/mL'),
            }),
          ),
        );
        expect(infos, contains('Reference Range: 0.00 - 0.014 ng/mL'));
      });

      test('shows a low-only bound', () {
        final infos = _infos(
          info(_troponin({'low': quantity(1.5, unit: 'ng/mL')})),
        );
        expect(infos, contains('Reference Range: > 1.50 ng/mL'));
      });
    });
  }

  Observation weight(Map<String, dynamic> range) => entityFromJson({
    ...observationJson(
      code: '29463-7',
      codeDisplay: 'Body weight',
      value: {'valueQuantity': quantity(70, unit: 'kg')},
    ),
    'referenceRange': [range],
  }) as Observation;

  test('a converted bound keeps the decimals of the recorded one', () {
    final infos = _infos(
      weight({
        'low': quantity(50, unit: 'kg'),
      }).additionalInfoForRegion(RegionPreset.us, en),
    );
    expect(infos, contains('Value: 154.32 lbs'));
    expect(infos, contains('Reference Range: > 110.23 lbs'));
  });

  test(
    'converts both bounds of a range for the region',
    () {
      final infos = _infos(
        weight({
          'low': quantity(50, unit: 'kg'),
          'high': quantity(100, unit: 'kg'),
        }).additionalInfoForRegion(RegionPreset.us, en),
      );
      expect(infos, contains('Reference Range: 110.23 - 220.46 lbs'));
    },
  );

  test('converts a component with its own LOINC code for the region', () {
    final observation = entityFromJson(
      observationJson(
        code: '85353-1',
        codeDisplay: 'Vital signs panel',
        components: [
          {
            'code': codeableConcept(
              text: 'Body weight',
              codings: [loinc('29463-7', 'Body weight')],
            ),
            'valueQuantity': quantity(70, unit: 'kg'),
          },
        ],
      ),
    ) as Observation;

    final infos = _infos(
      observation.additionalInfoForRegion(RegionPreset.us, en),
    );

    expect(infos, contains('Body weight: 154.32 lbs'));
  });
}
