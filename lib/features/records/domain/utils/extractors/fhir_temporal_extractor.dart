import 'package:fhir_r4/fhir_r4.dart' as fhir_r4;
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/features/records/domain/utils/extractors/fhir_common_extractor.dart';
import 'package:intl/intl.dart';

class FhirTemporalExtractor {
  /// Medium date plus time in the locale's own order and clock (en:
  /// "Oct 5, 2024 3:00 PM", de: "5. Okt. 2024 15:00"). A null [locale] uses
  /// `Intl.defaultLocale`, which the app keeps on the active language.
  static DateFormat _dateTimeFormat(
    String? locale, {
    String separator = ' ',
    bool withSeconds = false,
  }) => DateFormat.yMMMd(locale).addPattern(
    (withSeconds ? DateFormat.jms(locale) : DateFormat.jm(locale)).pattern,
    separator,
  );

  /// CLDR puts a narrow no-break space before AM/PM; keep the plain space
  /// the app has always shown.
  static String _format(DateFormat format, DateTime date) =>
      format.format(date).replaceAll('\u202f', ' ');

  static String? extractPeriod(
    fhir_r4.Period? period, {
    AppLocalizations? l10n,
  }) {
    if (period == null) return null;

    final start = period.start?.toString();
    final end = period.end?.toString();

    if (start != null && end != null) {
      return '$start - $end';
    } else if (start != null) {
      return l10n?.fromDate(start) ?? 'From $start';
    } else if (end != null) {
      return l10n?.untilDate(end) ?? 'Until $end';
    }
    return null;
  }

  static String? extractPeriodStart(fhir_r4.Period? period) {
    return period?.start?.toString();
  }

  static String? extractPeriodEnd(fhir_r4.Period? period) {
    return period?.end?.toString();
  }

  static String? extractPeriodFormatted(
    fhir_r4.Period? period, {
    AppLocalizations? l10n,
  }) {
    if (period == null) return null;

    final locale = l10n?.localeName;
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
        final formatter = _dateTimeFormat(locale);
        final startFormatted = _format(formatter, startDate);
        final endFormatted = _format(formatter, endDate);

        if (startDate.year == endDate.year &&
            startDate.month == endDate.month &&
            startDate.day == endDate.day) {
          final dateFormatter = DateFormat.yMMMd(locale);
          final timeFormatter = DateFormat.jm(locale);
          return '${_format(dateFormatter, startDate)}, ${_format(timeFormatter, startDate)} - ${_format(timeFormatter, endDate)}';
        }

        return '$startFormatted - $endFormatted';
      }

      // A partial FHIR date ("2024-03", "2024") doesn't parse; show it as
      // written rather than dropping it.
      final startFormatted = startDate != null
          ? _format(_dateTimeFormat(locale), startDate)
          : start;
      final endFormatted = endDate != null
          ? _format(_dateTimeFormat(locale), endDate)
          : end;
      if (startFormatted != null && endFormatted != null) {
        return '$startFormatted - $endFormatted';
      } else if (startFormatted != null) {
        return l10n?.fromDate(startFormatted) ?? 'From $startFormatted';
      } else if (endFormatted != null) {
        return l10n?.untilDate(endFormatted) ?? 'Until $endFormatted';
      }
    } catch (e) {
      return extractPeriod(period, l10n: l10n);
    }

    return null;
  }

  static String? extractOnsetX(dynamic onsetX, {AppLocalizations? l10n}) {
    if (onsetX == null) return null;

    final onsetDateTime = onsetX.isAs<fhir_r4.FhirDateTime>();
    if (onsetDateTime != null) return onsetDateTime.valueString;

    final onsetAge = onsetX.isAs<fhir_r4.Age>();
    if (onsetAge != null) {
      return '${onsetAge.value} ${onsetAge.unit ?? l10n?.years ?? 'years'}';
    }

    final onsetPeriod = onsetX.isAs<fhir_r4.Period>();
    if (onsetPeriod != null) return extractPeriod(onsetPeriod, l10n: l10n);

    final onsetRange = onsetX.isAs<fhir_r4.Range>();
    if (onsetRange != null) return FhirCommonExtractor.formatRange(onsetRange);

    final onsetString = onsetX.isAs<fhir_r4.FhirString>();
    if (onsetString != null) return onsetString.valueString;

    return null;
  }

  static String? extractAbatementX(
    dynamic abatementX, {
    AppLocalizations? l10n,
  }) {
    if (abatementX == null) return null;

    final abatementDateTime = abatementX.isAs<fhir_r4.FhirDateTime>();
    if (abatementDateTime != null) return abatementDateTime.valueString;

    final abatementAge = abatementX.isAs<fhir_r4.Age>();
    if (abatementAge != null) {
      return '${abatementAge.value} ${abatementAge.unit ?? l10n?.years ?? 'years'}';
    }

    final abatementPeriod = abatementX.isAs<fhir_r4.Period>();
    if (abatementPeriod != null) {
      return extractPeriod(abatementPeriod, l10n: l10n);
    }

    final abatementRange = abatementX.isAs<fhir_r4.Range>();
    if (abatementRange != null) {
      return FhirCommonExtractor.formatRange(abatementRange);
    }

    final abatementString = abatementX.isAs<fhir_r4.FhirString>();
    if (abatementString != null) return abatementString.valueString;

    return null;
  }

  static String? extractPerformedX(
    dynamic performedX, {
    AppLocalizations? l10n,
  }) {
    if (performedX == null) return null;

    final performedDateTime = performedX.isAs<fhir_r4.FhirDateTime>();
    if (performedDateTime != null) return performedDateTime.valueString;

    final performedPeriod = performedX.isAs<fhir_r4.Period>();
    if (performedPeriod != null) {
      return extractPeriod(performedPeriod, l10n: l10n);
    }

    return null;
  }

  static String? extractEffectiveX(
    dynamic effectiveX, {
    AppLocalizations? l10n,
  }) {
    if (effectiveX == null) return null;

    final effectiveDateTime = effectiveX.isAs<fhir_r4.FhirDateTime>();
    if (effectiveDateTime != null) return effectiveDateTime.valueString;

    final effectivePeriod = effectiveX.isAs<fhir_r4.Period>();
    if (effectivePeriod != null) {
      return extractPeriod(effectivePeriod, l10n: l10n);
    }

    final effectiveInstant = effectiveX.isAs<fhir_r4.FhirInstant>();
    if (effectiveInstant != null) return effectiveInstant.valueString;

    return null;
  }

  static String? extractOccurrenceX(
    dynamic occurrenceX, {
    AppLocalizations? l10n,
  }) {
    if (occurrenceX == null) return null;

    final occurrenceDateTime = occurrenceX.isAs<fhir_r4.FhirDateTime>();
    if (occurrenceDateTime != null) return occurrenceDateTime.valueString;

    final occurrencePeriod = occurrenceX.isAs<fhir_r4.Period>();
    if (occurrencePeriod != null) {
      return extractPeriod(occurrencePeriod, l10n: l10n);
    }

    final occurrenceString = occurrenceX.isAs<fhir_r4.FhirString>();
    if (occurrenceString != null) return occurrenceString.valueString;

    return null;
  }

  static String? extractDateTime(dynamic dateX, {AppLocalizations? l10n}) {
    if (dateX == null) return null;

    final dateTime = dateX.isAs<fhir_r4.FhirDateTime>();
    if (dateTime != null) return dateTime.valueString;

    final date = dateX.isAs<fhir_r4.FhirDate>();
    if (date != null) return date.valueString;

    final instant = dateX.isAs<fhir_r4.FhirInstant>();
    if (instant != null) return instant.valueString;

    final period = dateX.isAs<fhir_r4.Period>();
    if (period != null) return extractPeriod(period, l10n: l10n);

    return dateX.toString();
  }

  static String? formatFhirDateTime(fhir_r4.FhirDateTime? fhirDateTime) {
    if (fhirDateTime == null) return null;

    final dateTimeString = fhirDateTime.valueString;
    if (dateTimeString == null) return null;

    try {
      final dateTime = DateTime.parse(dateTimeString);
      return _format(_dateTimeFormat(null, separator: ', '), dateTime);
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
      return _format(DateFormat.yMMMd(), date);
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
      return _format(
        _dateTimeFormat(null, separator: ', ', withSeconds: true),
        dateTime,
      );
    } catch (e) {
      return instantString;
    }
  }

  static String? formatDateTimeString(String? dateTimeString) {
    if (dateTimeString == null || dateTimeString.isEmpty) return null;

    try {
      final dateTime = DateTime.parse(dateTimeString);

      final hasTime =
          dateTimeString.contains('T') || dateTimeString.contains(':');

      if (hasTime) {
        return _format(_dateTimeFormat(null, separator: ', '), dateTime);
      } else {
        return _format(DateFormat.yMMMd(), dateTime);
      }
    } catch (e) {
      return dateTimeString;
    }
  }

  static String? extractOnsetXFormatted(
    dynamic onsetX, {
    AppLocalizations? l10n,
  }) {
    if (onsetX == null) return null;

    final onsetDateTime = onsetX.isAs<fhir_r4.FhirDateTime>();
    if (onsetDateTime != null) {
      return formatFhirDateTime(onsetDateTime);
    }

    final onsetAge = onsetX.isAs<fhir_r4.Age>();
    if (onsetAge != null) {
      final value = onsetAge.value?.valueString;
      final unit = onsetAge.unit ?? l10n?.years ?? 'years';
      return value != null ? '$value $unit' : null;
    }

    final onsetPeriod = onsetX.isAs<fhir_r4.Period>();
    if (onsetPeriod != null) {
      return extractPeriodFormatted(onsetPeriod, l10n: l10n);
    }

    final onsetRange = onsetX.isAs<fhir_r4.Range>();
    if (onsetRange != null) return FhirCommonExtractor.formatRange(onsetRange);

    final onsetString = onsetX.isAs<fhir_r4.FhirString>();
    if (onsetString != null) return onsetString.valueString;

    return null;
  }

  static String? extractAbatementXFormatted(
    dynamic abatementX, {
    AppLocalizations? l10n,
  }) {
    if (abatementX == null) return null;

    final abatementDateTime = abatementX.isAs<fhir_r4.FhirDateTime>();
    if (abatementDateTime != null) {
      return formatFhirDateTime(abatementDateTime);
    }

    final abatementAge = abatementX.isAs<fhir_r4.Age>();
    if (abatementAge != null) {
      final value = abatementAge.value?.valueString;
      final unit = abatementAge.unit ?? l10n?.years ?? 'years';
      return value != null ? '$value $unit' : null;
    }

    final abatementPeriod = abatementX.isAs<fhir_r4.Period>();
    if (abatementPeriod != null) {
      return extractPeriodFormatted(abatementPeriod, l10n: l10n);
    }

    final abatementRange = abatementX.isAs<fhir_r4.Range>();
    if (abatementRange != null) {
      return FhirCommonExtractor.formatRange(abatementRange);
    }

    final abatementString = abatementX.isAs<fhir_r4.FhirString>();
    if (abatementString != null) return abatementString.valueString;

    final abatementBoolean = abatementX.isAs<fhir_r4.FhirBoolean>();
    if (abatementBoolean != null) {
      return abatementBoolean.valueBoolean == true
          ? (l10n?.yes ?? 'Yes')
          : (l10n?.no ?? 'No');
    }

    return null;
  }

  static String? extractPerformedXFormatted(
    dynamic performedX, {
    AppLocalizations? l10n,
  }) {
    if (performedX == null) return null;

    final performedDateTime = performedX.isAs<fhir_r4.FhirDateTime>();
    if (performedDateTime != null) {
      return formatFhirDateTime(performedDateTime);
    }

    final performedPeriod = performedX.isAs<fhir_r4.Period>();
    if (performedPeriod != null) {
      return extractPeriodFormatted(performedPeriod, l10n: l10n);
    }

    final performedString = performedX.isAs<fhir_r4.FhirString>();
    if (performedString != null) return performedString.valueString;

    final performedAge = performedX.isAs<fhir_r4.Age>();
    if (performedAge != null) {
      final value = performedAge.value?.valueString;
      final unit = performedAge.unit ?? l10n?.years ?? 'years';
      return value != null ? '$value $unit' : null;
    }

    final performedRange = performedX.isAs<fhir_r4.Range>();
    if (performedRange != null) {
      return FhirCommonExtractor.formatRange(performedRange);
    }

    return null;
  }

  static String? extractEffectiveXFormatted(
    dynamic effectiveX, {
    AppLocalizations? l10n,
  }) {
    if (effectiveX == null) return null;

    final effectiveDateTime = effectiveX.isAs<fhir_r4.FhirDateTime>();
    if (effectiveDateTime != null) {
      return formatFhirDateTime(effectiveDateTime);
    }

    final effectivePeriod = effectiveX.isAs<fhir_r4.Period>();
    if (effectivePeriod != null) {
      return extractPeriodFormatted(effectivePeriod, l10n: l10n);
    }

    final effectiveInstant = effectiveX.isAs<fhir_r4.FhirInstant>();
    if (effectiveInstant != null) {
      return formatFhirInstant(effectiveInstant);
    }

    final effectiveTiming = effectiveX.isAs<fhir_r4.Timing>();
    if (effectiveTiming != null && effectiveTiming.code != null) {
      return FhirCommonExtractor.extractCodeableConceptText(
        effectiveTiming.code,
      );
    }

    return null;
  }

  static String? extractOccurrenceXFormatted(
    dynamic occurrenceX, {
    AppLocalizations? l10n,
  }) {
    if (occurrenceX == null) return null;

    final occurrenceDateTime = occurrenceX.isAs<fhir_r4.FhirDateTime>();
    if (occurrenceDateTime != null) {
      return formatFhirDateTime(occurrenceDateTime);
    }

    final occurrencePeriod = occurrenceX.isAs<fhir_r4.Period>();
    if (occurrencePeriod != null) {
      return extractPeriodFormatted(occurrencePeriod, l10n: l10n);
    }

    final occurrenceString = occurrenceX.isAs<fhir_r4.FhirString>();
    if (occurrenceString != null) return occurrenceString.valueString;

    final occurrenceTiming = occurrenceX.isAs<fhir_r4.Timing>();
    if (occurrenceTiming != null && occurrenceTiming.code != null) {
      return FhirCommonExtractor.extractCodeableConceptText(
        occurrenceTiming.code,
      );
    }

    return null;
  }
}
