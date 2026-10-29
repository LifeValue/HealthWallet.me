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

IFhirResource _weight(num value, String unit) => entityFromJson(
  observationJson(
    code: '29463-7',
    codeDisplay: 'Body Weight',
    value: {'valueQuantity': quantity(value, unit: unit)},
  ),
);

void main() {
  setUpAll(initializeDateFormatting);

  final en = lookupAppLocalizations(const Locale('en'));

  group('additionalInfoIn', () {
    test('shows a weight recorded in pounds in kilograms for Europe', () {
      final infos = _infos(
        _weight(200, 'lbs').additionalInfoIn(
          RegionPreset.europe,
          en,
        ),
      );

      expect(infos, contains('Value: 90.72 kg'));
      expect(infos.join(), isNot(contains('lbs')));
    });

    test('shows a weight recorded in kilograms in pounds for the US', () {
      final infos = _infos(
        _weight(70, 'kg').additionalInfoIn(
          RegionPreset.us,
          en,
        ),
      );

      expect(infos, contains('Value: 154.32 lbs'));
    });

    test('matches what the record details show for an observation', () {
      final weight = _weight(200, 'lbs') as Observation;

      expect(
        _infos(weight.additionalInfoIn(RegionPreset.europe, en)),
        _infos(weight.additionalInfoForRegion(RegionPreset.europe, en)),
      );
    });

    test('keeps the plain lines for records without region units', () {
      final condition = entityFromJson(conditionJson());

      expect(
        _infos(condition.additionalInfoIn(RegionPreset.us, en)),
        _infos(condition.additionalInfo(en)),
      );
    });
  });
}
