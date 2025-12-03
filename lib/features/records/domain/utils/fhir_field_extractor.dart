import 'package:health_wallet/features/records/domain/entity/observation/observation.dart';
import 'package:health_wallet/features/records/domain/entity/patient/patient.dart';
import 'package:fhir_r4/fhir_r4.dart' as fhir_r4;
import 'package:health_wallet/features/records/domain/utils/vital_codes.dart';
import 'package:health_wallet/core/constants/blood_types.dart';

class FhirFieldExtractor {
  static String? extractStatus(dynamic status) {
    return status?.toString();
  }

  static String? extractCodeableConceptText(dynamic codeableConcept) {
    if (codeableConcept == null) return null;

    if (codeableConcept.toString().contains('.')) {
      return codeableConcept.toString().split('.').last;
    }

    try {
      final text = codeableConcept.text?.toString();
      if (text != null && text.isNotEmpty) return text;
    } catch (e) {}

    try {
      final coding = codeableConcept.coding;
      if (coding?.isNotEmpty == true) {
        final display = coding!.first.display?.toString();
        if (display != null && display.isNotEmpty) return display;
      }
    } catch (e) {}

    return null;
  }

  static String? extractReferenceDisplay(dynamic reference) {
    if (reference is fhir_r4.Reference) {
      return reference.display?.toString();
    }
    return null;
  }

  static String? extractDate(dynamic date) {
    return date?.toString();
  }

  static String? extractFirstCodeableConceptFromArray(
      List<dynamic>? codeableConceptArray) {
    if (codeableConceptArray == null || codeableConceptArray.isEmpty) {
      return null;
    }

    final firstConcept = codeableConceptArray.first;
    return extractCodeableConceptText(firstConcept);
  }

  static String? extractHumanName(dynamic name) {
    if (name == null) return null;

    final given = name.given?.map((g) => g.toString()).join(' ') ?? '';
    final family = name.family?.toString() ?? '';
    final prefix = name.prefix?.map((p) => p.toString()).join(' ') ?? '';

    final title = prefix.isNotEmpty ? '$prefix ' : '';

    if (given.isNotEmpty && family.isNotEmpty) {
      return '$title$given, $family';
    } else if (given.isNotEmpty) {
      return '$title$given';
    } else if (family.isNotEmpty) {
      return '$title$family';
    }

    return null;
  }

  static String? extractHumanNameForHome(dynamic name) {
    if (name == null) return null;

    final given = name.given?.map((g) => g.toString()).join(' ') ?? '';
    final family = name.family?.toString() ?? '';
    final prefix = name.prefix?.map((p) => p.toString()).join(' ') ?? '';

    final title = prefix.isNotEmpty ? '$prefix ' : '';

    if (given.isNotEmpty && family.isNotEmpty) {
      return '$title$given $family';
    } else if (given.isNotEmpty) {
      return '$title$given';
    } else if (family.isNotEmpty) {
      return '$title$family';
    }

    return null;
  }

  static String? extractHumanNameFamilyFirst(dynamic name) {
    if (name == null) return null;

    final family = name.family?.toString() ?? '';
    final given = name.given?.isNotEmpty == true
        ? name.given!.map((g) => g.toString()).join(' ')
        : '';

    if (family.isNotEmpty && given.isNotEmpty) {
      return '$family, $given';
    } else if (family.isNotEmpty) {
      return family;
    } else if (given.isNotEmpty) {
      return given;
    }

    return null;
  }

  static String? extractFirstHumanNameFromArray(List<dynamic>? nameArray) {
    if (nameArray != null &&
        nameArray.isNotEmpty &&
        nameArray.first is fhir_r4.HumanName) {
      return extractHumanName(nameArray.first);
    }
    return null;
  }

  static String? joinNullable(List<String?> values, String separator) {
    final nonNullStrings =
        values.where((s) => s != null && s.isNotEmpty).toList();
    return nonNullStrings.isEmpty ? null : nonNullStrings.join(separator);
  }

  static String? formatAddress(fhir_r4.Address? address) {
    if (address == null) return null;
    final city = address.city?.toString();
    final state = address.state?.toString();
    final country = address.country?.toString();
    return joinNullable([city, state, country], ', ');
  }

  static String? extractMultipleReferenceDisplays(List<dynamic>? references) {
    if (references == null || references.isEmpty) return null;

    final displays = references
        .where((r) => r is fhir_r4.Reference && r.display != null)
        .map((r) => r.display!)
        .join(', ');

    return displays.isNotEmpty ? displays : null;
  }

  static String? extractObservationValue(dynamic valueX) {
    final valueQuantity = valueX?.isAs<fhir_r4.Quantity>();
    if (valueQuantity != null) {
      return "${valueQuantity.value?.valueDouble?.toStringAsFixed(2)} ${valueQuantity.unit}";
    }

    final valueCodeableConcept = valueX?.isAs<fhir_r4.CodeableConcept>();
    if (valueCodeableConcept != null) {
      return extractCodeableConceptText(valueCodeableConcept);
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

  static String _mapLoincCodeToUnit(String code) {
    switch (code) {
      case kLoincHeartRate:
        return 'BPM';
      case kLoincBloodPressurePanel:
        return 'mmHg';
      case kLoincTemperature:
        return '°F';
      case kLoincBloodOxygen:
        return '%';
      case kLoincWeight:
        return 'kg';
      case kLoincHeight:
        return 'cm';
      case kLoincBmi:
        return 'kg/m²';
      case kLoincSystolic:
        return 'mmHg';
      case kLoincDiastolic:
        return 'mmHg';
      case kLoincRespiratoryRate:
        return '/min';
      case kLoincBloodGlucose:
        return 'mg/dL';
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
      case '8867-4': // Heart Rate
      case '8480-6': // Systolic BP
      case '8462-4': // Diastolic BP
      case '2708-6': // SpO2
        decimals = 0;
        break;
      case '8310-5': // Temperature
      case '29463-7': // Weight
      case '39156-5': // BMI
        decimals = 1;
        break;
      case '8302-2': // Height
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

  static String extractPatientGiven(Patient patient) {
    if (patient.name?.isNotEmpty == true) {
      final given = patient.name!.first.given;
      if (given != null && given.isNotEmpty) {
        return given.map((g) => g.toString()).join(' ');
      }
    }
    return '';
  }

  static String extractPatientFamily(Patient patient) {
    if (patient.name?.isNotEmpty == true) {
      final family = patient.name!.first.family;
      if (family != null) {
        return family.toString();
      }
    }
    return '';
  }

  static String extractPatientId(Patient patient) {
    if (patient.identifier?.isNotEmpty == true) {
      for (final identifier in patient.identifier!) {
        if (identifier.value != null) {
          return identifier.value!.toString();
        }
      }
    }
    return patient.id;
  }

  static String extractPatientAge(Patient patient) {
    if (patient.birthDate == null) return 'N/A';

    try {
      final birthDateStr = patient.birthDate!.toString();
      if (birthDateStr.isEmpty) return 'N/A';

      final birthDate = DateTime.parse(birthDateStr);
      final now = DateTime.now();
      final age = now.year - birthDate.year;

      if (now.month < birthDate.month ||
          (now.month == birthDate.month && now.day < birthDate.day)) {
        return '${age - 1} years';
      }

      return '$age years';
    } catch (e) {
      return 'N/A';
    }
  }

  static DateTime? extractPatientBirthDate(Patient patient) {
    if (patient.birthDate == null) return null;

    try {
      final birthDateStr = patient.birthDate!.toString();
      if (birthDateStr.isEmpty) return null;

      return DateTime.parse(birthDateStr);
    } catch (e) {
      return null;
    }
  }

  static String extractPatientGender(Patient patient) {
    final gender = FhirFieldExtractor.extractStatus(patient.gender);
    return gender ?? 'Unknown';
  }

  static String extractPatientMRN(Patient patient) {
    if (patient.identifier == null || patient.identifier!.isEmpty) {
      return '';
    }

    try {
      final mrnIdentifier = patient.identifier!.firstWhere(
        (id) =>
            id.type?.coding?.any(
              (coding) => coding.code?.toString() == 'MR',
            ) ??
            false,
      );

      if (mrnIdentifier.value != null) {
        return mrnIdentifier.value!.toString();
      }
    } catch (e) {
    }

    return '';
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

  static bool _isValidBloodType(String bloodType) {
    return BloodTypes.isValidBloodType(bloodType);
  }
}
