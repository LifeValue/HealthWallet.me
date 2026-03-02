import 'package:flutter/material.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/gen/assets.gen.dart';
import 'date_field_dropdown.dart';
import 'date_range_filter_model.dart';

class DateRangeSelector extends StatelessWidget {
  final String label;
  final SvgGenImage icon;
  final int? year;
  final int? month;
  final int? day;
  final ValueChanged<int?> onYearChanged;
  final ValueChanged<int?> onMonthChanged;
  final ValueChanged<int?> onDayChanged;
  final GlobalKey containerKey;
  final bool openUpward;

  const DateRangeSelector({
    super.key,
    required this.label,
    required this.icon,
    required this.year,
    required this.month,
    required this.day,
    required this.onYearChanged,
    required this.onMonthChanged,
    required this.onDayChanged,
    required this.containerKey,
    this.openUpward = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            icon.svg(
              width: 16,
              height: 16,
              colorFilter: ColorFilter.mode(
                context.colorScheme.primary,
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: AppTextStyle.labelLarge.copyWith(
                color: context.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Container(
                height: 1,
                color: context.colorScheme.onSurface.withValues(alpha: 0.2),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: DateFieldDropdown(
                label: 'Day',
                value: day,
                items: DateRangeDropdownService.getDays(year, month),
                containerKey: containerKey,
                selectedYear: year,
                selectedMonth: month,
                openUpward: openUpward,
                onChanged: onDayChanged,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DateFieldDropdown(
                label: 'Month',
                value: month,
                items: DateRangeDropdownService.getMonths(),
                containerKey: containerKey,
                openUpward: openUpward,
                onChanged: onMonthChanged,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DateFieldDropdown(
                label: 'Year',
                value: year,
                items: DateRangeDropdownService.getYears(),
                containerKey: containerKey,
                openUpward: openUpward,
                onChanged: onYearChanged,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
