import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/config/constants/region_preset.dart';
import 'package:health_wallet/core/utils/unit_converter.dart';
import 'package:health_wallet/features/home/domain/entities/patient_vitals.dart';

void main() {
  group('knownUnit', () {
    final cases = <String, String>{
      'kg': 'kg',
      'Kilograms': 'kg',
      '[lb_av]': 'lbs',
      'lb': 'lbs',
      'pounds': 'lbs',
      'cm': 'cm',
      '[in_i]': 'in',
      'inches': 'in',
      'Cel': '°c',
      '°C': '°c',
      '[degF]': '°f',
      'Fahrenheit': '°f',
      'mg/dL': 'mg/dl',
      'mmol/L': 'mmol/l',
    };
    cases.forEach((unit, known) {
      test('$unit -> $known', () {
        expect(UnitConverter.knownUnit(unit), known);
      });
    });

    test('units the region does not change are unknown', () {
      for (final unit in ['mmHg', 'ng/mL', '%', 'ft/in', 'Kilogram', '']) {
        expect(UnitConverter.knownUnit(unit), isNull, reason: unit);
      }
      expect(UnitConverter.knownUnit(null), isNull);
    });
  });

  group('convertForDisplay', () {
    ({double value, String unit}) convert(
      double value,
      String from,
      PatientVitalType type,
      RegionPreset region,
    ) => UnitConverter.convertForDisplay(
      value: value,
      fromUnit: from,
      type: type,
      region: region,
    );

    test('converts weight, temperature and glucose for the region', () {
      final lbs = convert(70, 'kg', PatientVitalType.weight, RegionPreset.us);
      expect(lbs.value, closeTo(154.32, 0.01));
      expect(lbs.unit, 'lbs');

      final kg = convert(
        154.32,
        '[lb_av]',
        PatientVitalType.weight,
        RegionPreset.europe,
      );
      expect(kg.value, closeTo(70, 0.01));
      expect(kg.unit, 'kg');

      final f = convert(
        37,
        'Cel',
        PatientVitalType.temperature,
        RegionPreset.us,
      );
      expect(f.value, closeTo(98.6, 0.01));
      expect(f.unit, '°F');

      final mmol = convert(
        99,
        'mg/dL',
        PatientVitalType.bloodGlucose,
        RegionPreset.europe,
      );
      expect(mmol.value, closeTo(5.49, 0.01));
      expect(mmol.unit, 'mmol/L');
    });

    test('converts inches to centimeters', () {
      final cm = convert(
        70,
        'in',
        PatientVitalType.height,
        RegionPreset.europe,
      );
      expect(cm.value, closeTo(177.8, 0.01));
      expect(cm.unit, 'cm');
    });

    test('keeps a value already in the regional unit', () {
      final kg = convert(
        70,
        'kilograms',
        PatientVitalType.weight,
        RegionPreset.europe,
      );
      expect(kg.value, 70);
      expect(kg.unit, 'kg');
    });

    test('leaves vitals without a regional unit unchanged', () {
      final rate = convert(
        72,
        '/min',
        PatientVitalType.heartRate,
        RegionPreset.us,
      );
      expect(rate.value, 72);
      expect(rate.unit, '/min');
    });
  });

  test('heightInCm', () {
    expect(UnitConverter.heightInCm(175, 'cm'), 175);
    expect(UnitConverter.heightInCm(70, '[in_i]'), closeTo(177.8, 0.01));
    expect(UnitConverter.heightInCm(70, 'kg'), isNull);
  });

  test('cmToFeetInchesString rolls 12 inches over to the next foot', () {
    expect(UnitConverter.cmToFeetInchesString(175), '5\'9"');
    expect(UnitConverter.cmToFeetInchesString(182.5), '6\'0"');
  });

  test('formatValue', () {
    expect(UnitConverter.formatValue(70.26, PatientVitalType.weight), '70.3');
    expect(UnitConverter.formatValue(72.6, PatientVitalType.heartRate), '73');
    expect(
      UnitConverter.formatValue(97.5, PatientVitalType.bloodOxygen),
      '98',
    );
  });

  test('normalizeToBaseUnit', () {
    expect(
      UnitConverter.normalizeToBaseUnit(
        98.6,
        '°F',
        PatientVitalType.temperature,
      ),
      closeTo(37, 0.01),
    );
    expect(
      UnitConverter.normalizeToBaseUnit(
        5.5,
        'mmol/L',
        PatientVitalType.bloodGlucose,
      ),
      closeTo(99.1, 0.01),
    );
    expect(
      UnitConverter.normalizeToBaseUnit(154.32, 'lbs', PatientVitalType.weight),
      closeTo(70, 0.01),
    );
    expect(
      UnitConverter.normalizeToBaseUnit(70, 'in', PatientVitalType.height),
      closeTo(177.8, 0.01),
    );
    expect(
      UnitConverter.normalizeToBaseUnit(72, '/min', PatientVitalType.heartRate),
      72,
    );
  });
}
