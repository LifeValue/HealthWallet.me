import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/config/constants/region_preset.dart';
import 'package:health_wallet/features/home/domain/entities/patient_vitals.dart';
import 'package:health_wallet/features/home/domain/factory/patient_vitals_factory.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/records/domain/utils/vital_codes.dart';

import '../../../../fixtures/fhir/fhir_fixtures.dart';

/// Vitals as the demo data writes them: 'Body …' titles and US units.
List<Observation> _demoVitals() => [
  for (final (id, code, text, value, unit, ucum) in [
    ('w', kLoincWeight, 'Body Weight', 200, 'pounds', '[lb_av]'),
    ('h', kLoincHeight, 'Body Height', 70, 'inches', '[in_i]'),
    ('t', kLoincTemperature, 'Body Temperature', 98.6, '°F', '[degF]'),
  ])
    entityFromJson(
      observationJson(
        id: id,
        code: code,
        codeText: text,
        value: {'valueQuantity': quantity(value, unit: unit, code: ucum)},
      ),
    ) as Observation,
];

PatientVital _vital(List<PatientVital> vitals, PatientVitalType type) =>
    vitals.singleWhere((v) => v.title == type.title);

void main() {
  final factory = PatientVitalFactory();

  test('the Europe region shows kg, cm and °C', () {
    final vitals = factory.buildFromResources(
      _demoVitals(),
      region: RegionPreset.europe,
    );

    final weight = _vital(vitals, PatientVitalType.weight);
    expect((weight.value, weight.unit), ('90.7', 'kg'));
    final height = _vital(vitals, PatientVitalType.height);
    expect((height.value, height.unit), ('177.8', 'cm'));
    final temperature = _vital(vitals, PatientVitalType.temperature);
    expect((temperature.value, temperature.unit), ('37.0', '°C'));
  });

  test('the US region shows lbs, feet and inches, and °F', () {
    final vitals = factory.buildFromResources(
      _demoVitals(),
      region: RegionPreset.us,
    );

    final weight = _vital(vitals, PatientVitalType.weight);
    expect((weight.value, weight.unit), ('200.0', 'lbs'));
    final height = _vital(vitals, PatientVitalType.height);
    expect((height.value, height.unit), ('5\'10"', ''));
    final temperature = _vital(vitals, PatientVitalType.temperature);
    expect((temperature.value, temperature.unit), ('98.6', '°F'));
  });
}
