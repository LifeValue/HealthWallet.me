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

  static List<DateDropdownItem> getMonths() {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return [
      DateDropdownItem(value: null, displayText: '-'),
      ...List.generate(
        12,
        (index) =>
            DateDropdownItem(value: index + 1, displayText: months[index]),
      ),
    ];
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
            value: index + 1, displayText: (index + 1).toString()),
      ),
    ];
  }
}
