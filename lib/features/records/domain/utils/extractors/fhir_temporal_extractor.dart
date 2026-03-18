import 'package:fhir_r4/fhir_r4.dart' as fhir_r4;
import 'package:intl/intl.dart';
import 'package:health_wallet/features/records/domain/utils/extractors/fhir_common_extractor.dart';

class FhirTemporalExtractor {
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

  static String? extractPeriodStart(fhir_r4.Period? period) {
    return period?.start?.toString();
  }

  static String? extractPeriodEnd(fhir_r4.Period? period) {
    return period?.end?.toString();
  }

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

  static String? extractOnsetX(dynamic onsetX) {
    if (onsetX == null) return null;

    final onsetDateTime = onsetX.isAs<fhir_r4.FhirDateTime>();
    if (onsetDateTime != null) return onsetDateTime.valueString;

    final onsetAge = onsetX.isAs<fhir_r4.Age>();
    if (onsetAge != null) {
      return '${onsetAge.value} ${onsetAge.unit ?? 'years'}';
    }

    final onsetPeriod = onsetX.isAs<fhir_r4.Period>();
    if (onsetPeriod != null) return extractPeriod(onsetPeriod);

    final onsetRange = onsetX.isAs<fhir_r4.Range>();
    if (onsetRange != null) {
      return '${onsetRange.low?.value} - ${onsetRange.high?.value}';
    }

    final onsetString = onsetX.isAs<fhir_r4.FhirString>();
    if (onsetString != null) return onsetString.valueString;

    return null;
  }

  static String? extractAbatementX(dynamic abatementX) {
    if (abatementX == null) return null;

    final abatementDateTime = abatementX.isAs<fhir_r4.FhirDateTime>();
    if (abatementDateTime != null) return abatementDateTime.valueString;

    final abatementAge = abatementX.isAs<fhir_r4.Age>();
    if (abatementAge != null) {
      return '${abatementAge.value} ${abatementAge.unit ?? 'years'}';
    }

    final abatementPeriod = abatementX.isAs<fhir_r4.Period>();
    if (abatementPeriod != null) return extractPeriod(abatementPeriod);

    final abatementRange = abatementX.isAs<fhir_r4.Range>();
    if (abatementRange != null) {
      return '${abatementRange.low?.value} - ${abatementRange.high?.value}';
    }

    final abatementString = abatementX.isAs<fhir_r4.FhirString>();
    if (abatementString != null) return abatementString.valueString;

    return null;
  }

  static String? extractPerformedX(dynamic performedX) {
    if (performedX == null) return null;

    final performedDateTime = performedX.isAs<fhir_r4.FhirDateTime>();
    if (performedDateTime != null) return performedDateTime.valueString;

    final performedPeriod = performedX.isAs<fhir_r4.Period>();
    if (performedPeriod != null) return extractPeriod(performedPeriod);

    return null;
  }

  static String? extractEffectiveX(dynamic effectiveX) {
    if (effectiveX == null) return null;

    final effectiveDateTime = effectiveX.isAs<fhir_r4.FhirDateTime>();
    if (effectiveDateTime != null) return effectiveDateTime.valueString;

    final effectivePeriod = effectiveX.isAs<fhir_r4.Period>();
    if (effectivePeriod != null) return extractPeriod(effectivePeriod);

    final effectiveInstant = effectiveX.isAs<fhir_r4.FhirInstant>();
    if (effectiveInstant != null) return effectiveInstant.valueString;

    return null;
  }

  static String? extractOccurrenceX(dynamic occurrenceX) {
    if (occurrenceX == null) return null;

    final occurrenceDateTime = occurrenceX.isAs<fhir_r4.FhirDateTime>();
    if (occurrenceDateTime != null) return occurrenceDateTime.valueString;

    final occurrencePeriod = occurrenceX.isAs<fhir_r4.Period>();
    if (occurrencePeriod != null) return extractPeriod(occurrencePeriod);

    final occurrenceString = occurrenceX.isAs<fhir_r4.FhirString>();
    if (occurrenceString != null) return occurrenceString.valueString;

    return null;
  }

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

    final onsetDateTime = onsetX.isAs<fhir_r4.FhirDateTime>();
    if (onsetDateTime != null) {
      return formatFhirDateTime(onsetDateTime);
    }

    final onsetAge = onsetX.isAs<fhir_r4.Age>();
    if (onsetAge != null) {
      final value = onsetAge.value?.valueString;
      final unit = onsetAge.unit ?? 'years';
      return value != null ? '$value $unit' : null;
    }

    final onsetPeriod = onsetX.isAs<fhir_r4.Period>();
    if (onsetPeriod != null) {
      return extractPeriodFormatted(onsetPeriod);
    }

    final onsetRange = onsetX.isAs<fhir_r4.Range>();
    if (onsetRange != null) {
      final low = FhirCommonExtractor.extractQuantity(onsetRange.low);
      final high = FhirCommonExtractor.extractQuantity(onsetRange.high);
      if (low != null && high != null) {
        return '$low - $high';
      }
      return low ?? high;
    }

    final onsetString = onsetX.isAs<fhir_r4.FhirString>();
    if (onsetString != null) return onsetString.valueString;

    return null;
  }

  static String? extractAbatementXFormatted(dynamic abatementX) {
    if (abatementX == null) return null;

    final abatementDateTime = abatementX.isAs<fhir_r4.FhirDateTime>();
    if (abatementDateTime != null) {
      return formatFhirDateTime(abatementDateTime);
    }

    final abatementAge = abatementX.isAs<fhir_r4.Age>();
    if (abatementAge != null) {
      final value = abatementAge.value?.valueString;
      final unit = abatementAge.unit ?? 'years';
      return value != null ? '$value $unit' : null;
    }

    final abatementPeriod = abatementX.isAs<fhir_r4.Period>();
    if (abatementPeriod != null) {
      return extractPeriodFormatted(abatementPeriod);
    }

    final abatementRange = abatementX.isAs<fhir_r4.Range>();
    if (abatementRange != null) {
      final low = FhirCommonExtractor.extractQuantity(abatementRange.low);
      final high = FhirCommonExtractor.extractQuantity(abatementRange.high);
      if (low != null && high != null) {
        return '$low - $high';
      }
      return low ?? high;
    }

    final abatementString = abatementX.isAs<fhir_r4.FhirString>();
    if (abatementString != null) return abatementString.valueString;

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
      final low = FhirCommonExtractor.extractQuantity(performedRange.low);
      final high = FhirCommonExtractor.extractQuantity(performedRange.high);
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
      return FhirCommonExtractor.extractCodeableConceptText(
          effectiveTiming.code);
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
      return FhirCommonExtractor.extractCodeableConceptText(
          occurrenceTiming.code);
    }

    return null;
  }
}
