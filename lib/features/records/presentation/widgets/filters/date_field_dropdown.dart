import 'package:flutter/material.dart';
import 'date_range_filter_model.dart';
import 'date_wide_dropdown.dart';

class DateFieldDropdown extends StatelessWidget {
  final String label;
  final int? value;
  final List<DateDropdownItem> items;
  final ValueChanged<int?>? onChanged;
  final bool enabled;
  final GlobalKey containerKey;
  final int? selectedYear;
  final int? selectedMonth;
  final bool openUpward;

  const DateFieldDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.containerKey,
    this.enabled = true,
    this.selectedYear,
    this.selectedMonth,
    this.openUpward = false,
  });

  @override
  Widget build(BuildContext context) {
    return DateWideDropdown(
      label: label,
      value: value,
      items: items,
      onChanged: enabled && onChanged != null ? onChanged : null,
      enabled: enabled,
      containerKey: containerKey,
      selectedYear: selectedYear,
      selectedMonth: selectedMonth,
      openUpward: openUpward,
    );
  }
}
