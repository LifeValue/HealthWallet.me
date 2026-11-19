import 'package:intl/intl.dart';

/// Which part of a date a dropdown edits.
enum DateField { day, month, year }

class DateRangeFilterModel {
  int? fromYear;
  int? fromMonth;
  int? fromDay;
  int? toYear;
  int? toMonth;
  int? toDay;

  DateRangeFilterModel({
    this.fromYear,
    this.fromMonth,
    this.fromDay,
    this.toYear,
    this.toMonth,
    this.toDay,
  });

  bool get hasValue =>
      fromYear != null ||
      fromMonth != null ||
      fromDay != null ||
      toYear != null ||
      toMonth != null ||
      toDay != null;

  void clear() {
    fromYear = null;
    fromMonth = null;
    fromDay = null;
    toYear = null;
    toMonth = null;
    toDay = null;
  }
}

class DateDropdownItem {
  final int? value;
  final String displayText;

  DateDropdownItem({required this.value, required this.displayText});
}

class DateRangeDropdownService {
  static List<DateDropdownItem> getYears() {
    final currentYear = DateTime.now().year;
    final minYear = currentYear - 200;
    final years = List.generate(
      currentYear - minYear + 1,
      (index) => currentYear - index,
    );

    return [
      DateDropdownItem(value: null, displayText: '-'),
      ...years.map(
        (year) => DateDropdownItem(value: year, displayText: year.toString()),
      ),
    ];
  }

  /// The twelve months abbreviated in [locale] (standalone form), after a
  /// "-" entry that clears the month.
  static List<DateDropdownItem> getMonths(String locale) {
    final format = DateFormat.LLL(locale);
    return [
      DateDropdownItem(value: null, displayText: '-'),
      ...List.generate(
        12,
        (index) => DateDropdownItem(
          value: index + 1,
          displayText: format.format(DateTime(2000, index + 1)),
        ),
      ),
    ];
  }

  /// One-letter weekday names in [locale], Sunday first.
  static List<String> getWeekdayInitials(String locale) {
    final format = DateFormat.EEEEE(locale);
    // 2 January 2000 was a Sunday.
    return List.generate(7, (i) => format.format(DateTime(2000, 1, 2 + i)));
  }

  static List<DateDropdownItem> getDays(int? year, int? month) {
    final daysInMonth = (year != null && month != null)
        ? DateTime(year, month + 1, 0).day
        : 31;

    return [
      DateDropdownItem(value: null, displayText: '-'),
      ...List.generate(
        daysInMonth,
        (index) => DateDropdownItem(
          value: index + 1,
          displayText: (index + 1).toString(),
        ),
      ),
    ];
  }
}
