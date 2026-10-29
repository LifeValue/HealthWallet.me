import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/config/constants/region_preset.dart';
import 'package:health_wallet/core/data/local/app_database.dart';
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

Map<String, dynamic> _lab(
  String code,
  String display,
  num value,
  String unit, {
  Map<String, dynamic>? range,
}) => {
  ...observationJson(
    code: code,
    codeDisplay: display,
    value: {'valueQuantity': quantity(value, unit: unit)},
  ),
  'referenceRange': ?(range == null ? null : [range]),
};

/// [json] saved in [sourceId], the way the app reads it back.
IFhirResource _fromSource(Map<String, dynamic> json, String sourceId) =>
    IFhirResource.fromLocalDto(
      FhirResourceLocalDto(
        id: json['id'] as String,
        resourceType: json['resourceType'] as String,
        resourceRaw: jsonEncode(json),
        sourceId: sourceId,
        resourceId: json['id'] as String,
        title: '',
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

    test('keeps a lab value in mg/dL that is not glucose as recorded', () {
      // The glucose factor would show 200 mg/dL of cholesterol as
      // 11.10 mmol/L; the correct value is 5.17 mmol/L.
      final infos = _infos(
        entityFromJson(
          _lab(
            '2093-3',
            'Cholesterol [Mass/volume] in Serum or Plasma',
            200,
            'mg/dL',
            range: {'high': quantity(200, unit: 'mg/dL')},
          ),
        ).additionalInfoIn(RegionPreset.europe, en),
      );

      expect(infos, contains('Value: 200.00 mg/dL'));
      expect(infos, contains('Reference Range: < 200.00 mg/dL'));
      expect(infos.join(), isNot(contains('mmol/L')));
    });

    test('converts a glucose value and its range for the region', () {
      final infos = _infos(
        entityFromJson(
          _lab(
            '2345-7',
            'Glucose [Mass/volume] in Serum or Plasma',
            99,
            'mg/dL',
            range: {
              'low': quantity(70, unit: 'mg/dL'),
              'high': quantity(99, unit: 'mg/dL'),
            },
          ),
        ).additionalInfoIn(RegionPreset.europe, en),
      );

      expect(infos, contains('Value: 5.49 mmol/L'));
      expect(infos, contains('Reference Range: 3.88 - 5.49 mmol/L'));
    });

    test('recognises the unit by its UCUM code before the written unit', () {
      final weight = entityFromJson(
        observationJson(
          code: '29463-7',
          codeDisplay: 'Body Weight',
          value: {
            'valueQuantity': quantity(70, unit: 'Kilogram', code: 'kg'),
          },
        ),
      );

      expect(
        _infos(weight.additionalInfoIn(RegionPreset.us, en)),
        contains('Value: 154.32 lbs'),
      );
    });

    test('shows a scanned record exactly as the document says', () {
      final scanned = _fromSource(
        _lab('29463-7', 'Body Weight', 200, 'lbs'),
        'wallet-pat-1',
      );

      final infos = _infos(scanned.additionalInfoIn(RegionPreset.europe, en));
      expect(infos, contains('Value: 200.00 lbs'));
      expect(infos, _infos(scanned.additionalInfo(en)));
    });

    test('converts the same record from a provider or the demo data', () {
      for (final source in ['demo_data', '3f2a9c1e-provider']) {
        expect(
          _infos(
            _fromSource(
              _lab('29463-7', 'Body Weight', 200, 'lbs'),
              source,
            ).additionalInfoIn(RegionPreset.europe, en),
          ),
          contains('Value: 90.72 kg'),
          reason: source,
        );
      }
    });
  });
}
