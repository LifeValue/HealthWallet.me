import 'package:health_wallet/features/records/domain/entity/observation/observation.dart';
import 'package:health_wallet/features/records/domain/entity/patient/patient.dart';
import 'package:fhir_r4/fhir_r4.dart' as fhir_r4;
import 'package:health_wallet/features/records/domain/utils/vital_codes.dart';
import 'package:health_wallet/core/constants/blood_types.dart';
import 'package:intl/intl.dart';

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
    } catch (e) {}

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

  // ============================================
  // Extended Field Extraction Methods
  // ============================================

  /// Extracts text from a list of Annotation objects
  static String? extractAnnotations(List<dynamic>? annotations) {
    if (annotations == null || annotations.isEmpty) return null;

    final texts = annotations
        .whereType<fhir_r4.Annotation>()
        .map((a) => a.text.toString())
        .where((text) => text.isNotEmpty)
        .toList();

    return texts.isEmpty ? null : texts.join('; ');
  }

  /// Extracts first annotation text
  static String? extractFirstAnnotation(List<dynamic>? annotations) {
    if (annotations == null || annotations.isEmpty) return null;

    for (final annotation in annotations) {
      if (annotation is fhir_r4.Annotation) {
        final text = annotation.text.toString();
        if (text.isNotEmpty) return text;
      }
    }
    return null;
  }

  /// Extracts a Period as a formatted string
  static String? extractPeriod(fhir_r4.Period? period) {
    if (period == null) return null;

    final start = period.start?.toString();
    final end = period.end?.toString();

    if (start != null && end != null) {
      return '$start - $end';
    } else if (start != null) {
      return 'From $start';
    } else if (end != null) {
      return 'Until $end';
    }
    return null;
  }

  /// Extracts period start date only
  static String? extractPeriodStart(fhir_r4.Period? period) {
    return period?.start?.toString();
  }

  /// Extracts period end date only
  static String? extractPeriodEnd(fhir_r4.Period? period) {
    return period?.end?.toString();
  }

  /// Extracts dosage instructions as a formatted string
  static String? extractDosageInstructions(List<dynamic>? dosages) {
    if (dosages == null || dosages.isEmpty) return null;

    final instructions = <String>[];
    for (final dosage in dosages) {
      if (dosage is fhir_r4.Dosage) {
        // Try to get text first
        if (dosage.text != null) {
          instructions.add(dosage.text.toString());
          continue;
        }

        // Build dosage from components
        final parts = <String>[];

        // Route
        final route = extractCodeableConceptText(dosage.route);
        if (route != null) parts.add(route);

        // Timing
        if (dosage.timing?.code != null) {
          final timingCode = extractCodeableConceptText(dosage.timing!.code);
          if (timingCode != null) parts.add(timingCode);
        }

        // Dose quantity
        if (dosage.doseAndRate != null && dosage.doseAndRate!.isNotEmpty) {
          final doseAndRate = dosage.doseAndRate!.first;
          final doseQuantity = doseAndRate.doseX?.isAs<fhir_r4.Quantity>();
          if (doseQuantity != null) {
            parts.add('${doseQuantity.value} ${doseQuantity.unit ?? ''}');
          }
        }

        if (parts.isNotEmpty) {
          instructions.add(parts.join(', '));
        }
      }
    }

    return instructions.isEmpty ? null : instructions.join('; ');
  }

  /// Extracts all CodeableConcepts from an array and joins them
  static String? extractAllCodeableConceptsFromArray(
      List<dynamic>? codeableConceptArray) {
    if (codeableConceptArray == null || codeableConceptArray.isEmpty) {
      return null;
    }

    final texts = codeableConceptArray
        .map((concept) => extractCodeableConceptText(concept))
        .where((text) => text != null && text.isNotEmpty)
        .toList();

    return texts.isEmpty ? null : texts.join(', ');
  }

  /// Extracts interpretation codes from observations
  static String? extractInterpretation(List<dynamic>? interpretations) {
    if (interpretations == null || interpretations.isEmpty) return null;

    final texts = <String>[];
    for (final interp in interpretations) {
      if (interp is fhir_r4.CodeableConcept) {
        final text = extractCodeableConceptText(interp);
        if (text != null) texts.add(text);
      }
    }

    return texts.isEmpty ? null : texts.join(', ');
  }

  /// Extracts onset[x] value (can be DateTime, Age, Period, Range, or String)
  static String? extractOnsetX(dynamic onsetX) {
    if (onsetX == null) return null;

    // Check for DateTime
    final onsetDateTime = onsetX.isAs<fhir_r4.FhirDateTime>();
    if (onsetDateTime != null) return onsetDateTime.valueString;

    // Check for Age
    final onsetAge = onsetX.isAs<fhir_r4.Age>();
    if (onsetAge != null) {
      return '${onsetAge.value} ${onsetAge.unit ?? 'years'}';
    }

    // Check for Period
    final onsetPeriod = onsetX.isAs<fhir_r4.Period>();
    if (onsetPeriod != null) return extractPeriod(onsetPeriod);

    // Check for Range
    final onsetRange = onsetX.isAs<fhir_r4.Range>();
    if (onsetRange != null) {
      return '${onsetRange.low?.value} - ${onsetRange.high?.value}';
    }

    // Check for String
    final onsetString = onsetX.isAs<fhir_r4.FhirString>();
    if (onsetString != null) return onsetString.valueString;

    return null;
  }

  /// Extracts abatement[x] value (similar to onset)
  static String? extractAbatementX(dynamic abatementX) {
    if (abatementX == null) return null;

    // Check for DateTime
    final abatementDateTime = abatementX.isAs<fhir_r4.FhirDateTime>();
    if (abatementDateTime != null) return abatementDateTime.valueString;

    // Check for Age
    final abatementAge = abatementX.isAs<fhir_r4.Age>();
    if (abatementAge != null) {
      return '${abatementAge.value} ${abatementAge.unit ?? 'years'}';
    }

    // Check for Period
    final abatementPeriod = abatementX.isAs<fhir_r4.Period>();
    if (abatementPeriod != null) return extractPeriod(abatementPeriod);

    // Check for Range
    final abatementRange = abatementX.isAs<fhir_r4.Range>();
    if (abatementRange != null) {
      return '${abatementRange.low?.value} - ${abatementRange.high?.value}';
    }

    // Check for String
    final abatementString = abatementX.isAs<fhir_r4.FhirString>();
    if (abatementString != null) return abatementString.valueString;

    return null;
  }

  /// Extracts performed[x] value (DateTime or Period)
  static String? extractPerformedX(dynamic performedX) {
    if (performedX == null) return null;

    // Check for DateTime
    final performedDateTime = performedX.isAs<fhir_r4.FhirDateTime>();
    if (performedDateTime != null) return performedDateTime.valueString;

    // Check for Period
    final performedPeriod = performedX.isAs<fhir_r4.Period>();
    if (performedPeriod != null) return extractPeriod(performedPeriod);

    return null;
  }

  /// Extracts effective[x] value (DateTime, Period, Timing, or Instant)
  static String? extractEffectiveX(dynamic effectiveX) {
    if (effectiveX == null) return null;

    // Check for DateTime
    final effectiveDateTime = effectiveX.isAs<fhir_r4.FhirDateTime>();
    if (effectiveDateTime != null) return effectiveDateTime.valueString;

    // Check for Period
    final effectivePeriod = effectiveX.isAs<fhir_r4.Period>();
    if (effectivePeriod != null) return extractPeriod(effectivePeriod);

    // Check for Instant
    final effectiveInstant = effectiveX.isAs<fhir_r4.FhirInstant>();
    if (effectiveInstant != null) return effectiveInstant.valueString;

    return null;
  }

  /// Extracts occurrence[x] value (DateTime, Period, or String)
  static String? extractOccurrenceX(dynamic occurrenceX) {
    if (occurrenceX == null) return null;

    // Check for DateTime
    final occurrenceDateTime = occurrenceX.isAs<fhir_r4.FhirDateTime>();
    if (occurrenceDateTime != null) return occurrenceDateTime.valueString;

    // Check for Period
    final occurrencePeriod = occurrenceX.isAs<fhir_r4.Period>();
    if (occurrencePeriod != null) return extractPeriod(occurrencePeriod);

    // Check for String
    final occurrenceString = occurrenceX.isAs<fhir_r4.FhirString>();
    if (occurrenceString != null) return occurrenceString.valueString;

    return null;
  }

  /// Extracts a Quantity value as formatted string
  static String? extractQuantity(fhir_r4.Quantity? quantity) {
    if (quantity == null) return null;
    if (quantity.value == null) return null;

    final value = quantity.value?.valueDouble?.toStringAsFixed(2);
    final unit = quantity.unit?.toString() ?? '';

    return '$value $unit'.trim();
  }

  /// Extracts performer references (usually practitioner names)
  static String? extractPerformers(List<dynamic>? performers) {
    if (performers == null || performers.isEmpty) return null;

    final names = <String>[];
    for (final performer in performers) {
      // Handle Reference directly
      if (performer is fhir_r4.Reference) {
        final display = performer.display?.toString();
        if (display != null && display.isNotEmpty) {
          names.add(display);
        }
      }
      // Handle ProcedurePerformer which has actor Reference
      else if (performer is fhir_r4.ProcedurePerformer) {
        final display = performer.actor.display?.toString();
        if (display != null && display.isNotEmpty) {
          names.add(display);
        }
      }
      // Handle DiagnosticReportPerformer
      else {
        try {
          // Try to access actor property
          final actor = (performer as dynamic).actor;
          if (actor is fhir_r4.Reference) {
            final display = actor.display?.toString();
            if (display != null && display.isNotEmpty) {
              names.add(display);
            }
          }
        } catch (_) {}
      }
    }

    return names.isEmpty ? null : names.join(', ');
  }

  /// Extracts participant references (for encounters, care teams, etc.)
  static String? extractParticipants(List<dynamic>? participants) {
    if (participants == null || participants.isEmpty) return null;

    final names = <String>[];
    for (final participant in participants) {
      try {
        // Try to access individual property (for EncounterParticipant)
        final individual = (participant as dynamic).individual;
        if (individual is fhir_r4.Reference) {
          final display = individual.display?.toString();
          if (display != null && display.isNotEmpty) {
            names.add(display);
          }
        }
      } catch (_) {}

      try {
        // Try to access member property (for CareTeamParticipant)
        final member = (participant as dynamic).member;
        if (member is fhir_r4.Reference) {
          final display = member.display?.toString();
          if (display != null && display.isNotEmpty) {
            names.add(display);
          }
        }
      } catch (_) {}
    }

    return names.isEmpty ? null : names.join(', ');
  }

  /// Extracts location references
  static String? extractLocations(List<dynamic>? locations) {
    if (locations == null || locations.isEmpty) return null;

    final names = <String>[];
    for (final location in locations) {
      try {
        // Try to access location property (for EncounterLocation)
        final loc = (location as dynamic).location;
        if (loc is fhir_r4.Reference) {
          final display = loc.display?.toString();
          if (display != null && display.isNotEmpty) {
            names.add(display);
          }
        }
      } catch (_) {}

      // Handle direct Reference
      if (location is fhir_r4.Reference) {
        final display = location.display?.toString();
        if (display != null && display.isNotEmpty) {
          names.add(display);
        }
      }
    }

    return names.isEmpty ? null : names.join(', ');
  }

  /// Extracts diagnosis references (for encounters)
  static String? extractDiagnoses(List<dynamic>? diagnoses) {
    if (diagnoses == null || diagnoses.isEmpty) return null;

    final names = <String>[];
    for (final diagnosis in diagnoses) {
      try {
        // Try to access condition property (for EncounterDiagnosis)
        final condition = (diagnosis as dynamic).condition;
        if (condition is fhir_r4.Reference) {
          final display = condition.display?.toString();
          if (display != null && display.isNotEmpty) {
            names.add(display);
          }
        }
      } catch (_) {}
    }

    return names.isEmpty ? null : names.join(', ');
  }

  /// Extracts coding class display (for Encounter.class)
  static String? extractCodingDisplay(dynamic coding) {
    if (coding == null) return null;

    if (coding is fhir_r4.Coding) {
      return coding.display?.toString() ?? coding.code?.toString();
    }

    return null;
  }

  /// Extracts reason codes from a list of CodeableConcepts
  static String? extractReasonCodes(List<dynamic>? reasonCodes) {
    return extractAllCodeableConceptsFromArray(reasonCodes);
  }

  /// Extracts reason references
  static String? extractReasonReferences(List<dynamic>? reasonReferences) {
    return extractMultipleReferenceDisplays(reasonReferences);
  }

  /// Extracts identifier value (first identifier)
  static String? extractFirstIdentifier(List<fhir_r4.Identifier>? identifiers) {
    if (identifiers == null || identifiers.isEmpty) return null;

    for (final identifier in identifiers) {
      if (identifier.value != null) {
        return identifier.value.toString();
      }
    }
    return null;
  }

  /// Extracts service type from ServiceRequest or similar
  static String? extractServiceType(List<dynamic>? serviceTypes) {
    return extractFirstCodeableConceptFromArray(serviceTypes);
  }

  /// Extracts priority as readable string
  static String? extractPriority(dynamic priority) {
    if (priority == null) return null;
    return priority.toString().split('.').last;
  }

  /// Extracts intent as readable string
  static String? extractIntent(dynamic intent) {
    if (intent == null) return null;
    return intent.toString().split('.').last;
  }

  // ============================================
  // Patient Extension Extraction Methods
  // ============================================

  /// Extracts a simple extension value from raw resource
  static String? extractExtensionValue(
      Map<String, dynamic> rawResource, String extensionUrl) {
    final extensions = rawResource['extension'] as List<dynamic>?;
    if (extensions == null) return null;

    for (final ext in extensions) {
      if (ext is Map<String, dynamic> && ext['url'] == extensionUrl) {
        return ext['valueCode']?.toString() ??
            ext['valueString']?.toString() ??
            ext['valueCodeableConcept']?['text']?.toString() ??
            ext['valueCodeableConcept']?['coding']?[0]?['display']?.toString();
      }
    }
    return null;
  }

  /// Extracts US Core race or ethnicity from complex extension
  static String? extractRaceOrEthnicity(
      Map<String, dynamic> rawResource, String extensionUrl) {
    final extensions = rawResource['extension'] as List<dynamic>?;
    if (extensions == null) return null;

    for (final ext in extensions) {
      if (ext is Map<String, dynamic> && ext['url'] == extensionUrl) {
        final nestedExtensions = ext['extension'] as List<dynamic>?;
        if (nestedExtensions != null) {
          // Look for 'text' extension first
          for (final nested in nestedExtensions) {
            if (nested is Map<String, dynamic> && nested['url'] == 'text') {
              return nested['valueString']?.toString();
            }
          }
          // Fallback to ombCategory display
          for (final nested in nestedExtensions) {
            if (nested is Map<String, dynamic> &&
                nested['url'] == 'ombCategory') {
              return nested['valueCoding']?['display']?.toString();
            }
          }
        }
      }
    }
    return null;
  }

  /// Extracts birth place from patient extension
  static String? extractBirthPlace(Map<String, dynamic> rawResource) {
    final extensions = rawResource['extension'] as List<dynamic>?;
    if (extensions == null) return null;

    for (final ext in extensions) {
      if (ext is Map<String, dynamic> &&
          ext['url'] ==
              'http://hl7.org/fhir/StructureDefinition/patient-birthPlace') {
        final address = ext['valueAddress'] as Map<String, dynamic>?;
        if (address != null) {
          final parts = <String>[];
          if (address['city'] != null) parts.add(address['city'].toString());
          if (address['state'] != null) parts.add(address['state'].toString());
          if (address['country'] != null) {
            parts.add(address['country'].toString());
          }
          return parts.isNotEmpty ? parts.join(', ') : null;
        }
      }
    }
    return null;
  }

  /// Extracts identifier by type code
  static String? extractIdentifierByType(
      List<fhir_r4.Identifier>? identifiers, String typeCode) {
    if (identifiers == null) return null;

    for (final id in identifiers) {
      final code = id.type?.coding?.firstOrNull?.code?.valueString;
      if (code == typeCode) {
        return id.value?.valueString;
      }
    }
    return null;
  }

  /// Extracts telecom value by system and optionally use
  static String? extractTelecomBySystem(
      List<fhir_r4.ContactPoint>? telecom, String system,
      {String? use}) {
    if (telecom == null) return null;

    for (final contact in telecom) {
      if (contact.system?.valueString == system) {
        if (use == null || contact.use?.valueString == use) {
          return contact.value?.valueString;
        }
      }
    }
    return null;
  }

  /// Extracts all telecom entries for a system with their use type
  static List<Map<String, String>> extractAllTelecomBySystem(
      List<fhir_r4.ContactPoint>? telecom, String system) {
    if (telecom == null) return [];

    final results = <Map<String, String>>[];
    for (final contact in telecom) {
      if (contact.system?.valueString == system) {
        final value = contact.value?.valueString;
        if (value != null) {
          results.add({
            'value': value,
            'use': contact.use?.valueString ?? '',
          });
        }
      }
    }
    return results;
  }

  /// Extracts full formatted address with all lines
  static String? formatFullAddress(fhir_r4.Address? address) {
    if (address == null) return null;

    final parts = <String>[];

    // Add address lines
    if (address.line != null) {
      for (final line in address.line!) {
        final lineStr = line.valueString;
        if (lineStr != null && lineStr.isNotEmpty) {
          parts.add(lineStr);
        }
      }
    }

    // Add city, state, postal code on one line
    final cityStateZip = <String>[];
    if (address.city?.valueString != null) {
      cityStateZip.add(address.city!.valueString!);
    }
    if (address.state?.valueString != null) {
      cityStateZip.add(address.state!.valueString!);
    }
    if (address.postalCode?.valueString != null) {
      cityStateZip.add(address.postalCode!.valueString!);
    }
    if (cityStateZip.isNotEmpty) {
      parts.add(cityStateZip.join(', '));
    }

    // Add country
    if (address.country?.valueString != null) {
      parts.add(address.country!.valueString!);
    }

    return parts.isNotEmpty ? parts.join('\n') : null;
  }

  /// Extracts communication languages
  static String? extractCommunicationLanguages(
      List<fhir_r4.PatientCommunication>? communication) {
    if (communication == null || communication.isEmpty) return null;

    final languages = communication
        .map((c) => extractCodeableConceptText(c.language))
        .where((l) => l != null && l.isNotEmpty)
        .toList();

    return languages.isEmpty ? null : languages.join(', ');
  }

  /// Calculate age from birth date
  static int? calculateAge(DateTime? birthDate) {
    if (birthDate == null) return null;

    final now = DateTime.now();
    int age = now.year - birthDate.year;
    if (now.month < birthDate.month ||
        (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  /// Extracts multiple birth information
  static String? extractMultipleBirth(dynamic multipleBirthX) {
    if (multipleBirthX == null) return null;

    final boolValue = multipleBirthX.isAs<fhir_r4.FhirBoolean>();
    if (boolValue != null) {
      return boolValue.valueBoolean == true ? 'Yes' : 'No';
    }

    final intValue = multipleBirthX.isAs<fhir_r4.FhirInteger>();
    if (intValue != null) {
      return 'Yes (Birth order: $intValue)';
    }

    return null;
  }

  /// Extracts telecom display with use type
  static String? extractTelecom(List<fhir_r4.ContactPoint>? telecom) {
    if (telecom == null || telecom.isEmpty) return null;

    for (final contact in telecom) {
      if (contact.value?.valueString != null) {
        final useType = contact.use?.valueString;
        final system = contact.system?.valueString;
        final value = contact.value!.valueString!;

        if (useType != null) {
          return '$value ($useType)';
        }
        if (system != null) {
          return '$system: $value';
        }
        return value;
      }
    }
    return null;
  }

  /// Extracts DateTime from various date types
  static String? extractDateTime(dynamic dateX) {
    if (dateX == null) return null;

    final dateTime = dateX.isAs<fhir_r4.FhirDateTime>();
    if (dateTime != null) return dateTime.valueString;

    final date = dateX.isAs<fhir_r4.FhirDate>();
    if (date != null) return date.valueString;

    final instant = dateX.isAs<fhir_r4.FhirInstant>();
    if (instant != null) return instant.valueString;

    final period = dateX.isAs<fhir_r4.Period>();
    if (period != null) return extractPeriod(period);

    return dateX.toString();
  }

  /// Extracts Dosage information
  static String? extractDosage(List<fhir_r4.Dosage>? dosages) {
    if (dosages == null || dosages.isEmpty) return null;

    final dosage = dosages.first;

    // Try text first
    if (dosage.text?.valueString != null) {
      return dosage.text!.valueString;
    }

    // Build from components
    final parts = <String>[];

    if (dosage.doseAndRate != null && dosage.doseAndRate!.isNotEmpty) {
      final doseAndRate = dosage.doseAndRate!.first;
      final doseQuantity = doseAndRate.doseX?.isAs<fhir_r4.Quantity>();
      if (doseQuantity != null) {
        final value = doseQuantity.value?.valueDouble?.toStringAsFixed(0);
        final unit = doseQuantity.unit?.valueString;
        if (value != null) {
          parts.add('$value${unit != null ? ' $unit' : ''}');
        }
      }
    }

    final route = extractCodeableConceptText(dosage.route);
    if (route != null) parts.add(route);

    if (dosage.timing?.code != null) {
      final timing = extractCodeableConceptText(dosage.timing!.code);
      if (timing != null) parts.add(timing);
    }

    return parts.isEmpty ? null : parts.join(', ');
  }

  /// Example output: "Jan 10, 2024, 10:00 AM - Jan 15, 2024, 10:00 AM"
  /// Or same day: "Jan 10, 2024, 10:00 AM - 2:00 PM"
  static String? extractPeriodFormatted(fhir_r4.Period? period) {
    if (period == null) return null;

    try {
      final start = period.start?.toString();
      final end = period.end?.toString();

      DateTime? startDate;
      DateTime? endDate;

      if (start != null) {
        startDate = DateTime.tryParse(start);
      }
      if (end != null) {
        endDate = DateTime.tryParse(end);
      }

      if (startDate != null && endDate != null) {
        final formatter = DateFormat('MMM d, yyyy h:mm a');
        final startFormatted = formatter.format(startDate);
        final endFormatted = formatter.format(endDate);
        
        if (startDate.year == endDate.year &&
            startDate.month == endDate.month &&
            startDate.day == endDate.day) {
          final dateFormatter = DateFormat('MMM d, yyyy');
          final timeFormatter = DateFormat('h:mm a');
          return '${dateFormatter.format(startDate)}, ${timeFormatter.format(startDate)} - ${timeFormatter.format(endDate)}';
        }
        
        return '$startFormatted - $endFormatted';
      } else if (startDate != null) {
        final formatter = DateFormat('MMM d, yyyy h:mm a');
        return 'From ${formatter.format(startDate)}';
      } else if (endDate != null) {
        final formatter = DateFormat('MMM d, yyyy h:mm a');
        return 'Until ${formatter.format(endDate)}';
      }
    } catch (e) {
      return extractPeriod(period);
    }

    return null;
  }

  /// Example: "Jan 10, 2024, 10:00 AM"
  static String? formatFhirDateTime(fhir_r4.FhirDateTime? fhirDateTime) {
    if (fhirDateTime == null) return null;
    
    final dateTimeString = fhirDateTime.valueString;
    if (dateTimeString == null) return null;
    
    try {
      final dateTime = DateTime.parse(dateTimeString);
      final formatter = DateFormat('MMM d, yyyy, h:mm a');
      return formatter.format(dateTime);
    } catch (e) {
      return dateTimeString;
    }
  }

  /// Example: "Jan 10, 2024"
  static String? formatFhirDate(fhir_r4.FhirDate? fhirDate) {
    if (fhirDate == null) return null;
    
    final dateString = fhirDate.valueString;
    if (dateString == null) return null;
    
    try {
      final date = DateTime.parse(dateString);
      final formatter = DateFormat('MMM d, yyyy');
      return formatter.format(date);
    } catch (e) {
      return dateString;
    }
  }

  /// Example: "Jan 10, 2024, 10:00:30 AM"
  static String? formatFhirInstant(fhir_r4.FhirInstant? fhirInstant) {
    if (fhirInstant == null) return null;
    
    final instantString = fhirInstant.valueString;
    if (instantString == null) return null;
    
    try {
      final dateTime = DateTime.parse(instantString);
      final formatter = DateFormat('MMM d, yyyy, h:mm:ss a');
      return formatter.format(dateTime);
    } catch (e) {
      return instantString;
    }
  }

  /// Automatically detects if it's a date or datetime
  /// Example: "2024-01-10T10:00:00-06:00" -> "Jan 10, 2024, 10:00 AM"
  /// Example: "2024-01-10" -> "Jan 10, 2024"
  static String? formatDateTimeString(String? dateTimeString) {
    if (dateTimeString == null || dateTimeString.isEmpty) return null;
    
    try {
      final dateTime = DateTime.parse(dateTimeString);
      
      final hasTime = dateTimeString.contains('T') || 
                     dateTimeString.contains(':');
      
      if (hasTime) {
        final formatter = DateFormat('MMM d, yyyy, h:mm a');
        return formatter.format(dateTime);
      } else {
        final formatter = DateFormat('MMM d, yyyy');
        return formatter.format(dateTime);
      }
    } catch (e) {
      return dateTimeString;
    }
  }

    static String? extractOnsetXFormatted(dynamic onsetX) {
    if (onsetX == null) return null;

    // Check for DateTime - FORMAT IT
    final onsetDateTime = onsetX.isAs<fhir_r4.FhirDateTime>();
    if (onsetDateTime != null) {
      return formatFhirDateTime(onsetDateTime);
    }

    // Check for Age
    final onsetAge = onsetX.isAs<fhir_r4.Age>();
    if (onsetAge != null) {
      final value = onsetAge.value?.valueString;
      final unit = onsetAge.unit ?? 'years';
      return value != null ? '$value $unit' : null;
    }

    // Check for Period - FORMAT IT
    final onsetPeriod = onsetX.isAs<fhir_r4.Period>();
    if (onsetPeriod != null) {
      return extractPeriodFormatted(onsetPeriod);
    }

    // Check for Range
    final onsetRange = onsetX.isAs<fhir_r4.Range>();
    if (onsetRange != null) {
      final low = extractQuantity(onsetRange.low);
      final high = extractQuantity(onsetRange.high);
      if (low != null && high != null) {
        return '$low - $high';
      }
      return low ?? high;
    }

    // Check for String
    final onsetString = onsetX.isAs<fhir_r4.FhirString>();
    if (onsetString != null) return onsetString.valueString;

    return null;
  }

  static String? extractAbatementXFormatted(dynamic abatementX) {
    if (abatementX == null) return null;

    // Check for DateTime - FORMAT IT
    final abatementDateTime = abatementX.isAs<fhir_r4.FhirDateTime>();
    if (abatementDateTime != null) {
      return formatFhirDateTime(abatementDateTime);
    }

    // Check for Age
    final abatementAge = abatementX.isAs<fhir_r4.Age>();
    if (abatementAge != null) {
      final value = abatementAge.value?.valueString;
      final unit = abatementAge.unit ?? 'years';
      return value != null ? '$value $unit' : null;
    }

    // Check for Period - FORMAT IT
    final abatementPeriod = abatementX.isAs<fhir_r4.Period>();
    if (abatementPeriod != null) {
      return extractPeriodFormatted(abatementPeriod);
    }

    // Check for Range
    final abatementRange = abatementX.isAs<fhir_r4.Range>();
    if (abatementRange != null) {
      final low = extractQuantity(abatementRange.low);
      final high = extractQuantity(abatementRange.high);
      if (low != null && high != null) {
        return '$low - $high';
      }
      return low ?? high;
    }

    // Check for String
    final abatementString = abatementX.isAs<fhir_r4.FhirString>();
    if (abatementString != null) return abatementString.valueString;

    // Check for Boolean
    final abatementBoolean = abatementX.isAs<fhir_r4.FhirBoolean>();
    if (abatementBoolean != null) {
      return abatementBoolean.valueBoolean == true ? 'Yes' : 'No';
    }

    return null;
  }

  static String? extractPerformedXFormatted(dynamic performedX) {
    if (performedX == null) return null;

    final performedDateTime = performedX.isAs<fhir_r4.FhirDateTime>();
    if (performedDateTime != null) {
      return formatFhirDateTime(performedDateTime);
    }

    final performedPeriod = performedX.isAs<fhir_r4.Period>();
    if (performedPeriod != null) {
      return extractPeriodFormatted(performedPeriod);
    }

    final performedString = performedX.isAs<fhir_r4.FhirString>();
    if (performedString != null) return performedString.valueString;

    final performedAge = performedX.isAs<fhir_r4.Age>();
    if (performedAge != null) {
      final value = performedAge.value?.valueString;
      final unit = performedAge.unit ?? 'years';
      return value != null ? '$value $unit' : null;
    }

    final performedRange = performedX.isAs<fhir_r4.Range>();
    if (performedRange != null) {
      final low = extractQuantity(performedRange.low);
      final high = extractQuantity(performedRange.high);
      if (low != null && high != null) {
        return '$low - $high';
      }
      return low ?? high;
    }

    return null;
  }

  static String? extractEffectiveXFormatted(dynamic effectiveX) {
    if (effectiveX == null) return null;

    final effectiveDateTime = effectiveX.isAs<fhir_r4.FhirDateTime>();
    if (effectiveDateTime != null) {
      return formatFhirDateTime(effectiveDateTime);
    }

    final effectivePeriod = effectiveX.isAs<fhir_r4.Period>();
    if (effectivePeriod != null) {
      return extractPeriodFormatted(effectivePeriod);
    }

    final effectiveInstant = effectiveX.isAs<fhir_r4.FhirInstant>();
    if (effectiveInstant != null) {
      return formatFhirInstant(effectiveInstant);
    }

    final effectiveTiming = effectiveX.isAs<fhir_r4.Timing>();
    if (effectiveTiming != null && effectiveTiming.code != null) {
      return extractCodeableConceptText(effectiveTiming.code);
    }

    return null;
  }

  static String? extractOccurrenceXFormatted(dynamic occurrenceX) {
    if (occurrenceX == null) return null;

    final occurrenceDateTime = occurrenceX.isAs<fhir_r4.FhirDateTime>();
    if (occurrenceDateTime != null) {
      return formatFhirDateTime(occurrenceDateTime);
    }

    final occurrencePeriod = occurrenceX.isAs<fhir_r4.Period>();
    if (occurrencePeriod != null) {
      return extractPeriodFormatted(occurrencePeriod);
    }

    final occurrenceString = occurrenceX.isAs<fhir_r4.FhirString>();
    if (occurrenceString != null) return occurrenceString.valueString;

    final occurrenceTiming = occurrenceX.isAs<fhir_r4.Timing>();
    if (occurrenceTiming != null && occurrenceTiming.code != null) {
      return extractCodeableConceptText(occurrenceTiming.code);
    }

    return null;
  }
}
