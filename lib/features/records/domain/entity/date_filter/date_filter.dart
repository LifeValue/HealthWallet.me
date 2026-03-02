import 'package:freezed_annotation/freezed_annotation.dart';

part 'date_filter.freezed.dart';

@freezed
class DateFilter with _$DateFilter {
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

  /// Returns a validation error message, or null if valid.
  String? validate() {
    // Only validate when both sides have comparable fields
    if (fromYear != null && toYear != null) {
      if (fromYear! > toYear!) return 'End date must be after start date';
      if (fromYear! == toYear!) {
        if (fromMonth != null && toMonth != null) {
          if (fromMonth! > toMonth!) return 'End date must be after start date';
          if (fromMonth! == toMonth!) {
            if (fromDay != null && toDay != null) {
              if (fromDay! > toDay!) {
                return 'End date must be after start date';
              }
            }
          }
        }
      }
    }

    if (fromYear == null && toYear == null) {
      if (fromMonth != null && toMonth != null) {
        if (fromMonth! > toMonth!) return 'End date must be after start date';
        if (fromMonth! == toMonth!) {
          if (fromDay != null && toDay != null) {
            if (fromDay! > toDay!) {
              return 'End date must be after start date';
            }
          }
        }
      }

      if (fromMonth == null && toMonth == null) {
        if (fromDay != null && toDay != null) {
          if (fromDay! > toDay!) return 'End date must be after start date';
        }
      }
    }

    return null;
  }

  String formatChipLabel() {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];

    String formatSide(int? year, int? month, int? day) {
      final parts = <String>[];
      if (day != null) parts.add('$day');
      if (month != null) parts.add(months[month - 1]);
      if (year != null) parts.add('$year');
      return parts.join(' ');
    }

    final from = formatSide(fromYear, fromMonth, fromDay);
    final to = formatSide(toYear, toMonth, toDay);

    String dateText;
    if (from.isNotEmpty && to.isNotEmpty) {
      if (from == to) {
        dateText = from;
      } else {
        dateText = '$from - $to';
      }
    } else if (from.isNotEmpty) {
      dateText = 'From $from';
    } else if (to.isNotEmpty) {
      dateText = 'Until $to';
    } else {
      return 'Date';
    }

    return 'Date: $dateText';
  }
}
