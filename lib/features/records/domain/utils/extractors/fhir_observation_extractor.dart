import 'package:fhir_r4/fhir_r4.dart' as fhir_r4;
import 'package:health_wallet/core/config/constants/region_preset.dart';
import 'package:health_wallet/core/constants/blood_types.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/core/l10n/display_names.dart';
import 'package:health_wallet/core/utils/unit_converter.dart';
import 'package:health_wallet/features/home/domain/entities/patient_vitals.dart';
import 'package:health_wallet/features/records/domain/entity/observation/observation.dart';
import 'package:health_wallet/features/records/domain/utils/extractors/fhir_common_extractor.dart';
import 'package:health_wallet/features/records/domain/utils/extractors/fhir_temporal_extractor.dart';
import 'package:health_wallet/features/records/domain/utils/vital_codes.dart';

class FhirObservationExtractor {
  /// With [l10n], a unit spelled out in English is shown in the app language
  /// (see [localizedUnit]).
  static String? extractObservationValue(
    dynamic valueX, {
    AppLocalizations? l10n,
  }) {
    final valueQuantity = valueX?.isAs<fhir_r4.Quantity>();
    if (valueQuantity != null) return _quantityText(valueQuantity, l10n);

    final valueCodeableConcept = valueX?.isAs<fhir_r4.CodeableConcept>();
    if (valueCodeableConcept != null) {
      return FhirCommonExtractor.extractCodeableConceptText(
        valueCodeableConcept,
      );
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
      return FhirCommonExtractor.formatRange(
        _quantityText(valueRange.low, l10n),
        _quantityText(valueRange.high, l10n),
      );
    }

    final valueRatio = valueX?.isAs<fhir_r4.Ratio>();
    if (valueRatio != null) {
      // One term alone is not a ratio; show nothing rather than a bare number.
      final numerator = FhirCommonExtractor.quantityValue(valueRatio.numerator);
      final denominator = FhirCommonExtractor.quantityValue(
        valueRatio.denominator,
      );
      if (numerator == null || denominator == null) return null;
      return '$numerator / $denominator';
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
      return FhirTemporalExtractor.extractPeriod(valuePeriod, l10n: l10n);
    }

    return null;
  }

  /// [valueX] in the units of [region] when it is the [measured] value of a
  /// weight, height, temperature or glucose observation (see
  /// [regionUnitVitalOf]); any other value is shown as recorded.
  static String? extractObservationValueForRegion(
    dynamic valueX,
    RegionPreset region, {
    AppLocalizations? l10n,
    required PatientVitalType? measured,
  }) {
    final valueQuantity = valueX?.isAs<fhir_r4.Quantity>();
    if (valueQuantity != null) {
      final rawValue = valueQuantity.value?.valueDouble;
      if (rawValue == null) return null;
      final rawUnit = FhirCommonExtractor.quantityUnit(valueQuantity) ?? '';
      final ucumCode = valueQuantity.code?.valueString;
      final converted = convertQuantityForRegion(
        rawValue,
        rawUnit,
        region,
        measured: measured,
        ucumCode: ucumCode,
      );
      if (_inFeetAndInches(rawUnit, ucumCode, region, measured)) {
        return converted.unit;
      }
      final comparator = FhirCommonExtractor.comparatorOf(valueQuantity);
      return _withUnit(
        '$comparator${FhirCommonExtractor.formatQuantityValue(converted.value, source: rawValue)}',
        converted.unit,
        l10n,
      );
    }

    return extractObservationValue(valueX, l10n: l10n);
  }

  /// What [code] measures when its unit follows the region: the first LOINC
  /// coding (or coding without a system) that [regionUnitVital] knows.
  static PatientVitalType? regionUnitVitalOf(fhir_r4.CodeableConcept? code) {
    for (final coding in code?.coding ?? const <fhir_r4.Coding>[]) {
      final system = coding.system?.valueString;
      final value = coding.code?.valueString;
      if (value == null) continue;
      if (system != null && system != 'http://loinc.org') continue;
      final vital = regionUnitVital(value);
      if (vital != null) return vital;
    }
    return null;
  }

  /// The unit of a quantity: its UCUM [ucumCode] when it is one the region
  /// changes, otherwise the written [unit].
  static String? _knownUnit(String unit, String? ucumCode) =>
      UnitConverter.knownUnit(ucumCode) ?? UnitConverter.knownUnit(unit);

  static bool _inFeetAndInches(
    String unit,
    String? ucumCode,
    RegionPreset region,
    PatientVitalType? measured,
  ) =>
      measured == PatientVitalType.height &&
      region.heightUnit == 'ft/in' &&
      const {'cm', 'in'}.contains(_knownUnit(unit, ucumCode));

  static String _unit(String unit, AppLocalizations? l10n) =>
      l10n == null ? unit : localizedUnit(unit, l10n);

  /// "[value] [unit]" of [quantity]; null when it has no value.
  static String? _quantityText(
    fhir_r4.Quantity? quantity,
    AppLocalizations? l10n,
  ) {
    final value = FhirCommonExtractor.quantityValue(quantity);
    if (value == null) return null;
    return _withUnit(value, FhirCommonExtractor.quantityUnit(quantity), l10n);
  }

  /// "[value] [unit]", or the bare value when there is no unit.
  static String _withUnit(String value, String? unit, AppLocalizations? l10n) {
    if (unit == null || unit.trim().isEmpty) return value;
    return '$value ${_unit(unit, l10n)}';
  }

  /// [value] in [unit] converted to the unit of [region], when [measured]
  /// says it is a weight, height, temperature or glucose and the unit is one
  /// of its units, recognised by its [ucumCode] first. Anything else, a
  /// cholesterol in mg/dL for example, comes back unchanged with its written
  /// unit. A height in the US comes back with its feet and inches in `unit`.
  static ({double value, String unit}) convertQuantityForRegion(
    double value,
    String unit,
    RegionPreset region, {
    required PatientVitalType? measured,
    String? ucumCode,
  }) {
    final from = _knownUnit(unit, ucumCode);
    switch (measured) {
      case PatientVitalType.weight:
        if (from == 'kg' && region.weightUnit == 'lbs') {
          return (value: UnitConverter.kgToLbs(value), unit: region.weightUnit);
        }
        if (from == 'lbs' && region.weightUnit == 'kg') {
          return (value: UnitConverter.lbsToKg(value), unit: region.weightUnit);
        }
      case PatientVitalType.temperature:
        if (from == '°c' && region.temperatureUnit == '°F') {
          return (
            value: UnitConverter.celsiusToFahrenheit(value),
            unit: region.temperatureUnit,
          );
        }
        if (from == '°f' && region.temperatureUnit == '°C') {
          return (
            value: UnitConverter.fahrenheitToCelsius(value),
            unit: region.temperatureUnit,
          );
        }
      case PatientVitalType.bloodGlucose:
        if (from == 'mg/dl' && region.glucoseUnit == 'mmol/L') {
          return (
            value: UnitConverter.mgDlToMmolL(value),
            unit: region.glucoseUnit,
          );
        }
        if (from == 'mmol/l' && region.glucoseUnit == 'mg/dL') {
          return (
            value: UnitConverter.mmolLToMgDl(value),
            unit: region.glucoseUnit,
          );
        }
      case PatientVitalType.height:
        final cm = switch (from) {
          'cm' => value,
          'in' => UnitConverter.inchesToCm(value),
          _ => null,
        };
        if (cm != null && region.heightUnit == 'ft/in') {
          return (value: value, unit: UnitConverter.cmToFeetInchesString(cm));
        }
        if (cm != null && region.heightUnit == 'cm') {
          return (value: cm, unit: region.heightUnit);
        }
      default:
        break;
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
            final DateTime aDate = a.date ?? DateTime.now();
            final DateTime bDate = b.date ?? DateTime.now();
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
            final fromText = _normalizeBloodType(value.text?.toString());
            if (fromText != null) return fromText;

            final fromCoding = _bloodTypeFromCodings(value.coding);
            if (fromCoding != null) return fromCoding;

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
    String? code,
    fhir_r4.Quantity quantity,
  ) {
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

  /// [text] as a short blood type ("A+"), accepting the standard SNOMED
  /// displays ("Blood group A Rh(D) positive"); null when it is neither.
  static String? _normalizeBloodType(String? text) {
    final trimmed = text?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    if (_isValidBloodType(trimmed)) return trimmed;
    return BloodTypes.fhirDisplayMapping[trimmed];
  }

  /// The blood type coded in a value's codings: a known SNOMED code first
  /// (only in SNOMED codings or codings without a system), then a
  /// recognisable display.
  static String? _bloodTypeFromCodings(List<fhir_r4.Coding>? codings) {
    if (codings == null) return null;
    for (final coding in codings) {
      final system = coding.system?.toString();
      if (system == null || system.contains('snomed.info/sct')) {
        final code = coding.code?.toString();
        for (final entry in BloodTypes.snomedCodes.entries) {
          if (entry.value == code) return entry.key;
        }
      }
      final display = _normalizeBloodType(coding.display?.toString());
      if (display != null) return display;
    }
    return null;
  }
}
