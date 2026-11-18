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

  /// [date] in the phone's time zone. A FHIR time with `Z` or an offset
  /// parses as UTC and stays UTC in the record; it is shown in local time,
  /// while a time without an offset is already local.
  ///
  /// CLDR puts a narrow no-break space before AM/PM; keep the plain space
  /// the app has always shown.
  static String _format(DateFormat format, DateTime date) =>
      format.format(date.toLocal()).replaceAll('\u202f', ' ');

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

  /// "low - high" with the raw recorded values; an open range keeps its
  /// direction ("≥ low", "≤ high") and an empty range is null.
  static String? _rangeValues(fhir_r4.Range range) =>
      FhirCommonExtractor.formatRange(
        range.low?.value?.toString(),
        range.high?.value?.toString(),
      );

  /// "[value] [unit]" of an Age, the unit defaulting to years; null without
  /// a value.
  static String? _ageValue(fhir_r4.Age age, AppLocalizations? l10n) {
    final value = age.value?.toString();
    if (value == null) return null;
    final unit = age.unit?.toString().trim();
    return '$value ${unit == null || unit.isEmpty ? l10n?.years ?? 'years' : unit}';
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

    try {
      return _formatPeriod(period, l10n);
    } catch (e) {
      // Without date symbols for the locale, show the period as written.
      return extractPeriod(period, l10n: l10n);
    }
  }

  static String? _formatPeriod(fhir_r4.Period period, AppLocalizations? l10n) {
    final locale = l10n?.localeName;
    final start = period.start?.toString();
    final end = period.end?.toString();
    final startDate = start == null ? null : _parse(start);
    final endDate = end == null ? null : _parse(end);

    if (startDate != null &&
        endDate != null &&
        startDate.hasTime &&
        endDate.hasTime &&
        _isSameDay(startDate.value, endDate.value)) {
      final timeFormatter = DateFormat.jm(locale);
      return '${_format(DateFormat.yMMMd(locale), startDate.value)}, '
          '${_format(timeFormatter, startDate.value)} - '
          '${_format(timeFormatter, endDate.value)}';
    }

    // A partial FHIR date ("2024-03", "2024") doesn't parse; show it as
    // written rather than dropping it.
    final startFormatted = startDate != null
        ? _formatParsed(startDate, locale, separator: ' ')
        : start;
    final endFormatted = endDate != null
        ? _formatParsed(endDate, locale, separator: ' ')
        : end;
    if (startFormatted != null && endFormatted != null) {
      return '$startFormatted - $endFormatted';
    } else if (startFormatted != null) {
      return l10n?.fromDate(startFormatted) ?? 'From $startFormatted';
    } else if (endFormatted != null) {
      return l10n?.untilDate(endFormatted) ?? 'Until $endFormatted';
    }
    return null;
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static String? extractOnsetX(dynamic onsetX, {AppLocalizations? l10n}) {
    if (onsetX == null) return null;

    final onsetDateTime = onsetX.isAs<fhir_r4.FhirDateTime>();
    if (onsetDateTime != null) return onsetDateTime.valueString;

    final onsetAge = onsetX.isAs<fhir_r4.Age>();
    if (onsetAge != null) return _ageValue(onsetAge, l10n);

    final onsetPeriod = onsetX.isAs<fhir_r4.Period>();
    if (onsetPeriod != null) return extractPeriod(onsetPeriod, l10n: l10n);

    final onsetRange = onsetX.isAs<fhir_r4.Range>();
    if (onsetRange != null) return _rangeValues(onsetRange);

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
    if (abatementAge != null) return _ageValue(abatementAge, l10n);

    final abatementPeriod = abatementX.isAs<fhir_r4.Period>();
    if (abatementPeriod != null) {
      return extractPeriod(abatementPeriod, l10n: l10n);
    }

    final abatementRange = abatementX.isAs<fhir_r4.Range>();
    if (abatementRange != null) return _rangeValues(abatementRange);

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

  static String? formatFhirDateTime(fhir_r4.FhirDateTime? fhirDateTime) =>
      formatDateTimeString(fhirDateTime?.valueString);

  static String? formatFhirDate(fhir_r4.FhirDate? fhirDate) =>
      formatDateTimeString(fhirDate?.valueString);

  static String? formatFhirInstant(fhir_r4.FhirInstant? fhirInstant) =>
      formatDateTimeString(fhirInstant?.valueString, withSeconds: true);

  /// A FHIR date, dateTime or instant for display: a value with a time in
  /// the device's time zone, a date-only value as that calendar day. Partial
  /// dates ("2024-03") and anything unparseable are returned as written.
  static String? formatDateTimeString(
    String? dateTimeString, {
    String? locale,
    String separator = ', ',
    bool withSeconds = false,
  }) {
    if (dateTimeString == null || dateTimeString.isEmpty) return null;
    final parsed = _parse(dateTimeString);
    if (parsed == null) return dateTimeString;
    return _formatParsed(
      parsed,
      locale,
      separator: separator,
      withSeconds: withSeconds,
    );
  }

  /// Parses a FHIR date, dateTime or instant. A value with a time is moved
  /// to the device's time zone, so "21:30-04:00" is shown at the local time
  /// rather than in UTC; a date-only value stays local midnight of that day.
  static ({DateTime value, bool hasTime})? _parse(String raw) {
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return null;
    final hasTime = raw.contains('T') || raw.contains(':');
    return (value: hasTime ? parsed.toLocal() : parsed, hasTime: hasTime);
  }

  static String _formatParsed(
    ({DateTime value, bool hasTime}) parsed,
    String? locale, {
    String separator = ', ',
    bool withSeconds = false,
  }) => parsed.hasTime
      ? _format(
          _dateTimeFormat(
            locale,
            separator: separator,
            withSeconds: withSeconds,
          ),
          parsed.value,
        )
      : _format(DateFormat.yMMMd(locale), parsed.value);

  /// The calendar day a record's stored date stands for. A date-only FHIR
  /// value is stored as midnight UTC, which is the previous evening west of
  /// UTC; it is read back as that UTC day. Any other time is the local day.
  static DateTime recordDay(DateTime date) {
    final utc = date.toUtc();
    final isUtcMidnight =
        utc.hour == 0 &&
        utc.minute == 0 &&
        utc.second == 0 &&
        utc.millisecond == 0;
    if (isUtcMidnight) return DateTime(utc.year, utc.month, utc.day);
    final local = date.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  /// A record's stored date as a long date ("March 5, 2024"); see
  /// [recordDay].
  static String formatRecordDate(DateTime date, String? locale) =>
      DateFormat.yMMMMd(locale).format(recordDay(date));

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
    if (onsetRange != null) {
      return FhirCommonExtractor.formatRange(
        FhirCommonExtractor.extractQuantity(onsetRange.low),
        FhirCommonExtractor.extractQuantity(onsetRange.high),
      );
    }

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
      return FhirCommonExtractor.formatRange(
        FhirCommonExtractor.extractQuantity(abatementRange.low),
        FhirCommonExtractor.extractQuantity(abatementRange.high),
      );
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
      return FhirCommonExtractor.formatRange(
        FhirCommonExtractor.extractQuantity(performedRange.low),
        FhirCommonExtractor.extractQuantity(performedRange.high),
      );
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
