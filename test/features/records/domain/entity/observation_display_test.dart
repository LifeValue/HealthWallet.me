import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/config/constants/region_preset.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../../../fixtures/fhir/fhir_fixtures.dart';

List<String> _infos(Observation observation, RegionPreset region) => observation
    .additionalInfoForRegion(region, _en)
    .map((l) => l.info)
    .toList();

final _en = lookupAppLocalizations(const Locale('en'));

Observation _lab(
  String code,
  num value,
  String unit, {
  num? low,
  num? high,
}) => entityFromJson({
  ...observationJson(
    code: code,
    codeDisplay: null,
    value: {'valueQuantity': quantity(value, unit: unit)},
  ),
  if (low != null || high != null)
    'referenceRange': [
      {
        'low': ?(low == null ? null : quantity(low, unit: unit)),
        'high': ?(high == null ? null : quantity(high, unit: unit)),
      },
    ],
}) as Observation;

void main() {
  setUpAll(initializeDateFormatting);

  group('Observation.additionalInfoForRegion', () {
    test('shows a cholesterol in mg/dL as reported in Europe', () {
      final infos = _infos(
        _lab('2093-3', 200, 'mg/dL', low: 0, high: 200),
        RegionPreset.europe,
      );
      expect(infos, contains('Value: 200.00 mg/dL'));
      expect(infos, contains('Reference Range: 0.00 - 200.00 mg/dL'));
    });

    test('converts a blood glucose and its range in Europe', () {
      final infos = _infos(
        _lab('2339-0', 100, 'mg/dL', low: 70, high: 100),
        RegionPreset.europe,
      );
      expect(infos, contains('Value: 5.55 mmol/L'));
      expect(infos, contains('Reference Range: 3.88 - 5.55 mmol/L'));
    });

    test('keeps a sodium in mmol/L in the US', () {
      expect(
        _infos(_lab('2951-2', 140, 'mmol/L'), RegionPreset.us),
        contains('Value: 140.00 mmol/L'),
      );
    });

    test('keeps a lesion size in cm in the US', () {
      expect(
        _infos(_lab('21889-1', 2.3, 'cm'), RegionPreset.us),
        contains('Value: 2.30 cm'),
      );
    });

    test('converts a coded body height in the US', () {
      expect(
        _infos(_lab('8302-2', 175, 'cm'), RegionPreset.us),
        contains('Value: 5\'9"'),
      );
    });
  });
}
