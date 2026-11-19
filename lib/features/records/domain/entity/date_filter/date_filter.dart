import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:intl/intl.dart';

part 'date_filter.freezed.dart';

@freezed
abstract class DateFilter with _$DateFilter {
  const DateFilter._();

  const factory DateFilter({
    int? fromYear,
    int? fromMonth,
    int? fromDay,
    int? toYear,
    int? toMonth,
    int? toDay,
  }) = _DateFilter;

  bool get hasValue =>
      fromYear != null ||
      fromMonth != null ||
      fromDay != null ||
      toYear != null ||
      toMonth != null ||
      toDay != null;

  /// Component-level matching.
  /// - One side only (from OR to): exact component match — each set field
  ///   must equal the date's corresponding component. Unset fields = "any".
  /// - Both sides set: range match — date must be >= from AND <= to.
  bool matches(DateTime date) {
    final hasFrom = fromYear != null || fromMonth != null || fromDay != null;
    final hasTo = toYear != null || toMonth != null || toDay != null;

    if (hasFrom && !hasTo) {
      // Only "from" side set → exact component match
      return _matchesComponents(date, fromYear, fromMonth, fromDay);
    } else if (!hasFrom && hasTo) {
      // Only "to" side set → exact component match
      return _matchesComponents(date, toYear, toMonth, toDay);
    } else if (hasFrom && hasTo) {
      // Both sides set → range match
      return _isOnOrAfterFrom(date) && _isOnOrBeforeTo(date);
    }
    return true;
  }

  /// Returns true if every non-null component equals the date's component.
  bool _matchesComponents(DateTime date, int? year, int? month, int? day) {
    if (year != null && date.year != year) return false;
    if (month != null && date.month != month) return false;
    if (day != null && date.day != day) return false;
    return true;
  }

  bool _isOnOrAfterFrom(DateTime date) {
    if (fromYear != null) {
      if (date.year < fromYear!) return false;
      if (date.year > fromYear!) return true;
    }
    if (fromMonth != null) {
      if (date.month < fromMonth!) return false;
      if (date.month > fromMonth!) return true;
    }
    if (fromDay != null) {
      if (date.day < fromDay!) return false;
    }
    return true;
  }

  bool _isOnOrBeforeTo(DateTime date) {
    if (toYear != null) {
      if (date.year > toYear!) return false;
      if (date.year < toYear!) return true;
    }
    if (toMonth != null) {
      if (date.month > toMonth!) return false;
      if (date.month < toMonth!) return true;
    }
    if (toDay != null) {
      if (date.day > toDay!) return false;
    }
    return true;
  }

  /// Whether the end side is before the start side. Only components set on
  /// both sides are compared.
  bool get hasInvalidRange {
    if (fromYear != null && toYear != null) {
      if (fromYear! > toYear!) return true;
      return fromYear! == toYear! && _monthAfterEnd();
    }
    if (fromYear == null && toYear == null) {
      if (_monthAfterEnd()) return true;
      if (fromMonth == null && toMonth == null) return _dayAfterEnd();
    }
    return false;
  }

  bool _monthAfterEnd() {
    if (fromMonth == null || toMonth == null) return false;
    if (fromMonth! > toMonth!) return true;
    return fromMonth! == toMonth! && _dayAfterEnd();
  }

  bool _dayAfterEnd() => fromDay != null && toDay != null && fromDay! > toDay!;

  /// Formats the set components of one side as "day month year" (for example
  /// "5 Mar 2024"), with the month abbreviated in [locale].
  static String formatDateParts(
    int? year,
    int? month,
    int? day,
    String locale,
  ) {
    final parts = <String>[];
    if (day != null) parts.add('$day');
    if (month != null) {
      parts.add(DateFormat.MMM(locale).format(DateTime(2000, month)));
    }
    if (year != null) parts.add('$year');
    return parts.join(' ');
  }

  String formatChipLabel(AppLocalizations l10n) {
    final locale = l10n.localeName;
    final from = formatDateParts(fromYear, fromMonth, fromDay, locale);
    final to = formatDateParts(toYear, toMonth, toDay, locale);

    final String dateText;
    if (from.isNotEmpty && to.isNotEmpty) {
      dateText = from == to ? from : '$from - $to';
    } else if (from.isNotEmpty) {
      dateText = l10n.fromDate(from);
    } else if (to.isNotEmpty) {
      dateText = l10n.untilDate(to);
    } else {
      return l10n.date;
    }

    return l10n.dateFilterChip(dateText);
  }
}
