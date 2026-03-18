import 'package:health_wallet/core/config/constants/region_preset.dart';
import 'package:health_wallet/features/records/domain/entity/observation/observation.dart';
import 'package:fhir_r4/fhir_r4.dart' as fhir_r4;
import 'package:health_wallet/features/records/domain/utils/vital_codes.dart';
import 'package:health_wallet/core/constants/blood_types.dart';
import 'package:health_wallet/features/records/domain/utils/extractors/fhir_common_extractor.dart';

class FhirObservationExtractor {
  static String? extractObservationValue(dynamic valueX) {
    final valueQuantity = valueX?.isAs<fhir_r4.Quantity>();
    if (valueQuantity != null) {
      return "${valueQuantity.value?.valueDouble?.toStringAsFixed(2)} ${valueQuantity.unit}";
    }

    final valueCodeableConcept = valueX?.isAs<fhir_r4.CodeableConcept>();
    if (valueCodeableConcept != null) {
      return FhirCommonExtractor.extractCodeableConceptText(
          valueCodeableConcept);
    }

    final valueString = valueX?.isAs<fhir_r4.FhirString>();
    if (valueString != null) {
      return valueString.valueString;
    }

    final valueBoolean = valueX?.isAs<fhir_r4.FhirBoolean>();
    if (valueBoolean != null) {
      return valueBoolean.valueString;
    }

    final valueInteger = valueX?.isAs<fhir_r4.FhirInteger>();
    if (valueInteger != null) {
      return valueInteger.valueString;
    }

    final valueRange = valueX?.isAs<fhir_r4.Range>();
    if (valueRange != null) {
      return "${valueRange.low?.value?.valueDouble?.toStringAsFixed(2)} - ${valueRange.high?.value?.valueDouble?.toStringAsFixed(2)}";
    }

    final valueRatio = valueX?.isAs<fhir_r4.Ratio>();
    if (valueRatio != null) {
      return "${valueRatio.numerator?.value?.valueDouble?.toStringAsFixed(2)} / ${valueRatio.denominator?.value?.valueDouble?.toStringAsFixed(2)}";
    }

    final valueTime = valueX?.isAs<fhir_r4.FhirTime>();
    if (valueTime != null) {
      return valueTime.valueString;
    }

    final valueDateTime = valueX?.isAs<fhir_r4.FhirDateTime>();
    if (valueDateTime != null) {
      return valueDateTime.valueString;
    }

    final valuePeriod = valueX?.isAs<fhir_r4.Period>();
    if (valuePeriod != null) {
      return "${valuePeriod.start} - ${valuePeriod.end}";
    }

    return null;
  }

  static String? extractObservationValueForRegion(
    dynamic valueX,
    RegionPreset region,
  ) {
    final valueQuantity = valueX?.isAs<fhir_r4.Quantity>();
    if (valueQuantity != null) {
      final rawValue = valueQuantity.value?.valueDouble;
      final rawUnit = valueQuantity.unit?.toString() ?? '';
      if (rawValue != null) {
        final u = rawUnit.trim().toLowerCase();
        if ((u == 'cm' || u == 'centimeters') &&
            region.heightUnit == 'ft/in') {
          final converted = convertQuantityForRegion(rawValue, rawUnit, region);
          return converted.unit;
        }
        final converted = convertQuantityForRegion(rawValue, rawUnit, region);
        return "${converted.value.toStringAsFixed(2)} ${converted.unit}";
      }
      return "${rawValue?.toStringAsFixed(2)} $rawUnit";
    }

    return extractObservationValue(valueX);
  }

  static ({double value, String unit}) convertQuantityForRegion(
    double value,
    String unit,
    RegionPreset region,
  ) {
    final u = unit.trim().toLowerCase();

    if ((u == 'kg' || u == 'kilograms') && region.weightUnit == 'lbs') {
      return (value: value * 2.20462, unit: region.weightUnit);
    }
    if ((u == 'lbs' || u == 'lb' || u == '[lb_av]') &&
        region.weightUnit == 'kg') {
      return (value: value / 2.20462, unit: region.weightUnit);
    }

    if ((u == '°c' || u == 'cel') && region.temperatureUnit == '°F') {
      return (value: value * 9 / 5 + 32, unit: region.temperatureUnit);
    }
    if ((u == '°f' || u == 'degf' || u == '[degf]') &&
        region.temperatureUnit == '°C') {
      return (value: (value - 32) * 5 / 9, unit: region.temperatureUnit);
    }

    if (u == 'mg/dl' && region.glucoseUnit == 'mmol/L') {
      return (value: value / 18.0182, unit: region.glucoseUnit);
    }
    if (u == 'mmol/l' && region.glucoseUnit == 'mg/dL') {
      return (value: value * 18.0182, unit: region.glucoseUnit);
    }

    if ((u == 'cm' || u == 'centimeters') && region.heightUnit == 'ft/in') {
      final totalInches = value / 2.54;
      final feet = totalInches ~/ 12;
      final inches = (totalInches % 12).round();
      final display = inches == 12 ? "${feet + 1}'0\"" : "$feet'$inches\"";
      return (value: value, unit: display);
    }

    return (value: value, unit: unit);
  }

  static bool isVitalSign(Observation observation) {
    final primaryCoding = observation.code?.coding;
    if (primaryCoding != null && primaryCoding.isNotEmpty) {
      for (final coding in primaryCoding) {
        if (coding.code != null && isVitalLoinc(coding.code.toString())) {
          return true;
        }
      }
    }

    if (observation.component != null) {
      for (final component in observation.component!) {
        final compCoding = component.code.coding;
        if (compCoding != null) {
          for (final coding in compCoding) {
            if (coding.code != null && isVitalLoinc(coding.code.toString())) {
              return true;
            }
          }
        }
      }
    }

    return false;
  }

  static String extractVitalSignTitle(Observation observation) {
    if (observation.code?.text != null) {
      return observation.code!.text.toString();
    }

    if (observation.code?.coding != null &&
        observation.code!.coding!.isNotEmpty) {
      final coding = observation.code!.coding!.first;
      if (coding.display != null) {
        return coding.display.toString();
      }
      if (coding.code != null) {
        return _mapLoincCodeToTitle(coding.code.toString());
      }
    }

    return 'Vital Sign';
  }

  static String extractVitalSignValue(Observation observation) {
    final valueX = observation.valueX;

    if (valueX is fhir_r4.Quantity) {
      final code = observation.code?.coding?.isNotEmpty == true
          ? observation.code!.coding!.first.code?.toString()
          : null;
      return _formatQuantityValueByCode(code, valueX);
    } else if (valueX is fhir_r4.FhirString) {
      return valueX.toString();
    } else if (valueX is fhir_r4.FhirInteger) {
      return valueX.toString();
    } else if (valueX is fhir_r4.FhirDecimal) {
      return _formatDecimal(valueX.toString());
    } else if (valueX is fhir_r4.CodeableConcept) {
      return valueX.text?.toString() ?? 'N/A';
    }

    return 'N/A';
  }

  static String extractVitalSignUnit(Observation observation) {
    final valueX = observation.valueX;

    if (valueX is fhir_r4.Quantity) {
      return valueX.unit?.toString() ?? '';
    }

    if (observation.code?.coding != null &&
        observation.code!.coding!.isNotEmpty) {
      final coding = observation.code!.coding!.first;
      if (coding.code != null) {
        return _mapLoincCodeToUnit(coding.code.toString());
      }
    }

    return '';
  }

  static String? extractVitalSignStatus(Observation observation) {
    if (observation.interpretation != null &&
        observation.interpretation!.isNotEmpty) {
      final interpretation = observation.interpretation!.first;
      if (interpretation.coding != null && interpretation.coding!.isNotEmpty) {
        final coding = interpretation.coding!.first;
        if (coding.code != null) {
          return _mapInterpretationCodeToStatus(coding.code.toString());
        }
      }
    }

    return null;
  }

  static String? extractInterpretation(List<dynamic>? interpretations) {
    if (interpretations == null || interpretations.isEmpty) return null;

    final texts = <String>[];
    for (final interp in interpretations) {
      if (interp is fhir_r4.CodeableConcept) {
        final text = FhirCommonExtractor.extractCodeableConceptText(interp);
        if (text != null) texts.add(text);
      }
    }

    return texts.isEmpty ? null : texts.join(', ');
  }

  static String? extractBloodTypeFromObservations(List<dynamic> observations) {
    if (observations.isEmpty) return null;

    final sortedObservations =
        observations.where((obs) => obs.code?.coding != null).toList()
          ..sort((a, b) {
            DateTime aDate = a.date ?? DateTime.now();
            DateTime bDate = b.date ?? DateTime.now();
            return bDate.compareTo(aDate);
          });

    for (final observation in sortedObservations) {
      final coding = observation.code?.coding;
      if (coding == null) continue;

      for (final code in coding) {
        if (code.code == null) continue;

        final loincCode = code.code.toString();

        if (loincCode == BloodTypes.combinedLoincCode ||
            loincCode == BloodTypes.aboLoincCode ||
            loincCode == BloodTypes.rhLoincCode) {
          final value = observation.valueX;

          if (value is fhir_r4.CodeableConcept) {
            if (value.text != null && value.text.toString().isNotEmpty) {
              final directText = value.text.toString();
              if (_isValidBloodType(directText)) {
                return directText;
              }
            }

            final display = code.display?.toString();
            if (display != null && _isValidBloodType(display)) {
              return display;
            }
          } else {
            final extractedValue = extractObservationValue(value);
            if (extractedValue != null && _isValidBloodType(extractedValue)) {
              return extractedValue;
            }
          }
        }
      }
    }

    return null;
  }

  static String _mapLoincCodeToTitle(String code) {
    switch (code) {
      case kLoincHeartRate:
        return 'Heart Rate';
      case kLoincBloodPressurePanel:
        return 'Blood Pressure';
      case kLoincTemperature:
        return 'Temperature';
      case kLoincBloodOxygen:
        return 'Blood Oxygen';
      case kLoincWeight:
        return 'Weight';
      case kLoincHeight:
        return 'Height';
      case kLoincBmi:
        return 'BMI';
      case kLoincSystolic:
        return 'Systolic Blood Pressure';
      case kLoincDiastolic:
        return 'Diastolic Blood Pressure';
      case kLoincRespiratoryRate:
        return 'Respiratory Rate';
      case kLoincBloodGlucose:
        return 'Blood Glucose';
      default:
        return 'Vital Sign';
    }
  }

  static String _mapLoincCodeToUnit(String code, {RegionPreset? region}) {
    final isUS = region == RegionPreset.us;
    switch (code) {
      case kLoincHeartRate:
        return 'BPM';
      case kLoincBloodPressurePanel:
        return 'mmHg';
      case kLoincTemperature:
        return isUS || region == null ? '°F' : '°C';
      case kLoincBloodOxygen:
        return '%';
      case kLoincWeight:
        return isUS ? 'lbs' : 'kg';
      case kLoincHeight:
        return isUS ? 'ft/in' : 'cm';
      case kLoincBmi:
        return 'kg/m\u00B2';
      case kLoincSystolic:
        return 'mmHg';
      case kLoincDiastolic:
        return 'mmHg';
      case kLoincRespiratoryRate:
        return '/min';
      case kLoincBloodGlucose:
        return isUS || region == null ? 'mg/dL' : 'mmol/L';
      default:
        return '';
    }
  }

  static String _mapInterpretationCodeToStatus(String code) {
    switch (code) {
      case 'H':
        return 'High';
      case 'L':
        return 'Low';
      case 'N':
        return 'Normal';
      case 'A':
        return 'Abnormal';
      case 'AA':
        return 'Critically Abnormal';
      case 'HH':
        return 'Critically High';
      case 'LL':
        return 'Critically Low';
      case 'U':
        return 'Uncertain';
      case 'R':
        return 'Resistant';
      case 'I':
        return 'Intermediate';
      case 'S':
        return 'Susceptible';
      case 'MS':
        return 'Moderately Susceptible';
      case 'VS':
        return 'Very Susceptible';
      default:
        return 'Unknown';
    }
  }

  static String _formatQuantityValueByCode(
      String? code, fhir_r4.Quantity quantity) {
    final String? raw = quantity.value?.toString();
    if (raw == null) return 'N/A';
    final double? num = double.tryParse(raw);
    if (num == null) return raw;

    int decimals = 1;
    switch (code) {
      case '8867-4':
      case '8480-6':
      case '8462-4':
      case '2708-6':
        decimals = 0;
        break;
      case '8310-5':
      case '29463-7':
      case '39156-5':
        decimals = 1;
        break;
      case '8302-2':
        decimals = 0;
        break;
      default:
        decimals = num.abs() >= 100 ? 0 : 1;
    }
    return decimals == 0
        ? num.round().toString()
        : num.toStringAsFixed(decimals);
  }

  static String _formatDecimal(String s) {
    final d = double.tryParse(s);
    if (d == null) return s;
    return d.abs() >= 100 ? d.round().toString() : d.toStringAsFixed(1);
  }

  static bool _isValidBloodType(String bloodType) {
    return BloodTypes.isValidBloodType(bloodType);
  }
}
