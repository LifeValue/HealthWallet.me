import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/features/home/domain/entities/patient_vitals.dart';
import 'package:health_wallet/features/records/domain/utils/vital_codes.dart';

void main() {
  test('isVitalLoinc', () {
    const vitals = [
      '8867-4',
      '85354-9',
      '55284-4',
      '8310-5',
      '2708-6',
      '29463-7',
      '8302-2',
      '39156-5',
      '8480-6',
      '8462-4',
      '9279-1',
      '2339-0',
    ];
    for (final code in vitals) {
      expect(isVitalLoinc(code), isTrue, reason: code);
    }
    for (final code in ['718-7', '883-9', '34530-6', '']) {
      expect(isVitalLoinc(code), isFalse, reason: code);
    }
  });

  group('regionUnitVital', () {
    final cases = <String, PatientVitalType>{
      '29463-7': PatientVitalType.weight,
      '3141-9': PatientVitalType.weight,
      '8302-2': PatientVitalType.height,
      '8306-3': PatientVitalType.height,
      '8310-5': PatientVitalType.temperature,
      '8331-1': PatientVitalType.temperature,
      '2339-0': PatientVitalType.bloodGlucose,
      '2345-7': PatientVitalType.bloodGlucose,
      '15074-8': PatientVitalType.bloodGlucose,
    };
    cases.forEach((code, vital) {
      test('$code is ${vital.name}', () {
        expect(regionUnitVital(code), vital);
      });
    });

    test('lab values measured in the same units are not region units', () {
      // Total cholesterol and creatinine are also reported in mg/dL, but the
      // glucose factor does not apply to them.
      for (final code in ['2093-3', '2160-0', '718-7', '8867-4', '']) {
        expect(regionUnitVital(code), isNull, reason: code);
      }
    });
  });
}
