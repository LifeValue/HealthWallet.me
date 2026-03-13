import 'package:health_wallet/core/config/constants/region_preset.dart';
import 'package:health_wallet/features/home/domain/entities/patient_vitals.dart';

class UnitConverter {
  UnitConverter._();

  static ({double value, String unit}) convertForDisplay({
    required double value,
    required String fromUnit,
    required PatientVitalType type,
    required RegionPreset region,
  }) {
    final targetUnit = _targetUnit(type, region);
    if (targetUnit == null) return (value: value, unit: fromUnit);

    final normalizedFrom = _normalizeUnit(fromUnit);
    final normalizedTarget = _normalizeUnit(targetUnit);

    if (normalizedFrom == normalizedTarget) {
      return (value: value, unit: targetUnit);
    }

    switch (type) {
      case PatientVitalType.weight:
        return _convertWeight(value, normalizedFrom, targetUnit);
      case PatientVitalType.height:
        return _convertHeight(value, normalizedFrom, targetUnit);
      case PatientVitalType.temperature:
        return _convertTemperature(value, normalizedFrom, targetUnit);
      case PatientVitalType.bloodGlucose:
        return _convertGlucose(value, normalizedFrom, targetUnit);
      default:
        return (value: value, unit: fromUnit);
    }
  }

  static String? _targetUnit(PatientVitalType type, RegionPreset region) {
    switch (type) {
      case PatientVitalType.weight:
        return region.weightUnit;
      case PatientVitalType.height:
        return region.heightUnit;
      case PatientVitalType.temperature:
        return region.temperatureUnit;
      case PatientVitalType.bloodGlucose:
        return region.glucoseUnit;
      default:
        return null;
    }
  }

  static String _normalizeUnit(String unit) {
    final u = unit.trim().toLowerCase();
    if (u == 'kg' || u == 'kilograms') return 'kg';
    if (u == 'lbs' || u == 'lb' || u == 'pounds' || u == '[lb_av]') {
      return 'lbs';
    }
    if (u == 'cm' || u == 'centimeters') return 'cm';
    if (u == 'ft/in' || u == 'ft' || u == 'in' || u == '[in_i]') return 'ft/in';
    if (u == '°c' || u == 'cel' || u == 'celsius') return '°c';
    if (u == '°f' || u == 'degf' || u == '[degf]' || u == 'fahrenheit') {
      return '°f';
    }
    if (u == 'mg/dl') return 'mg/dl';
    if (u == 'mmol/l') return 'mmol/l';
    return u;
  }

  static ({double value, String unit}) _convertWeight(
    double value,
    String normalizedFrom,
    String targetUnit,
  ) {
    if (normalizedFrom == 'kg' && _normalizeUnit(targetUnit) == 'lbs') {
      return (value: kgToLbs(value), unit: targetUnit);
    }
    if (normalizedFrom == 'lbs' && _normalizeUnit(targetUnit) == 'kg') {
      return (value: lbsToKg(value), unit: targetUnit);
    }
    return (value: value, unit: targetUnit);
  }

  static ({double value, String unit}) _convertHeight(
    double value,
    String normalizedFrom,
    String targetUnit,
  ) {
    if (normalizedFrom == 'cm' && _normalizeUnit(targetUnit) == 'ft/in') {
      return (value: value, unit: targetUnit);
    }
    if (normalizedFrom == 'ft/in' && _normalizeUnit(targetUnit) == 'cm') {
      return (value: value, unit: targetUnit);
    }
    return (value: value, unit: targetUnit);
  }

  static ({double value, String unit}) _convertTemperature(
    double value,
    String normalizedFrom,
    String targetUnit,
  ) {
    if (normalizedFrom == '°c' && _normalizeUnit(targetUnit) == '°f') {
      return (value: celsiusToFahrenheit(value), unit: targetUnit);
    }
    if (normalizedFrom == '°f' && _normalizeUnit(targetUnit) == '°c') {
      return (value: fahrenheitToCelsius(value), unit: targetUnit);
    }
    return (value: value, unit: targetUnit);
  }

  static ({double value, String unit}) _convertGlucose(
    double value,
    String normalizedFrom,
    String targetUnit,
  ) {
    if (normalizedFrom == 'mg/dl' && _normalizeUnit(targetUnit) == 'mmol/l') {
      return (value: mgDlToMmolL(value), unit: targetUnit);
    }
    if (normalizedFrom == 'mmol/l' && _normalizeUnit(targetUnit) == 'mg/dl') {
      return (value: mmolLToMgDl(value), unit: targetUnit);
    }
    return (value: value, unit: targetUnit);
  }

  static double kgToLbs(double kg) => kg * 2.20462;
  static double lbsToKg(double lbs) => lbs / 2.20462;

  static double celsiusToFahrenheit(double c) => c * 9 / 5 + 32;
  static double fahrenheitToCelsius(double f) => (f - 32) * 5 / 9;

  static double mgDlToMmolL(double mgDl) => mgDl / 18.0182;
  static double mmolLToMgDl(double mmolL) => mmolL * 18.0182;

  static String cmToFeetInchesString(double cm) {
    final totalInches = cm / 2.54;
    final feet = totalInches ~/ 12;
    final inches = (totalInches % 12).round();
    if (inches == 12) return "${feet + 1}'0\"";
    return "$feet'$inches\"";
  }

  static String formatValue(double value, PatientVitalType type) {
    switch (type) {
      case PatientVitalType.weight:
        return value.toStringAsFixed(1);
      case PatientVitalType.height:
        return value.toStringAsFixed(1);
      case PatientVitalType.temperature:
        return value.toStringAsFixed(1);
      case PatientVitalType.bloodGlucose:
        return value.toStringAsFixed(1);
      case PatientVitalType.bmi:
        return value.toStringAsFixed(1);
      case PatientVitalType.heartRate:
      case PatientVitalType.respiratoryRate:
        return value.round().toString();
      case PatientVitalType.bloodPressure:
      case PatientVitalType.systolicBloodPressure:
      case PatientVitalType.diastolicBloodPressure:
        return value.round().toString();
      case PatientVitalType.bloodOxygen:
        return value.round().toString();
    }
  }

  static double? normalizeToBaseUnit(
      double value, String unit, PatientVitalType type) {
    final normalized = _normalizeUnit(unit);
    switch (type) {
      case PatientVitalType.temperature:
        if (normalized == '°f') return fahrenheitToCelsius(value);
        return value;
      case PatientVitalType.bloodGlucose:
        if (normalized == 'mmol/l') return mmolLToMgDl(value);
        return value;
      case PatientVitalType.weight:
        if (normalized == 'lbs') return lbsToKg(value);
        return value;
      case PatientVitalType.height:
        return value;
      default:
        return value;
    }
  }
}
