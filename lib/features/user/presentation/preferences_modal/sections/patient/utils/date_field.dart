import 'package:flutter/material.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/gen/assets.gen.dart';

class DateField extends StatelessWidget {
  final String label;
  final DateTime? selectedDate;
  final ValueChanged<DateTime?>? onDateChanged;
  final Color iconColor;

  const DateField({
    super.key,
    required this.label,
    required this.selectedDate,
    this.onDateChanged,
    required this.iconColor,
  });

  String _calculateAge(DateTime birthDate) {
    final now = DateTime.now();
    int age = now.year - birthDate.year;
    if (now.month < birthDate.month ||
        (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }
    return age.toString();
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<void> _showDatePicker(BuildContext context) async {
    final now = DateTime.now();
    final firstDate = DateTime(1900);
    final lastDate = now;

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? now.subtract(const Duration(days: 365 * 25)),
      firstDate: firstDate,
      lastDate: lastDate,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: context.colorScheme,
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null && onDateChanged != null) {
      onDateChanged!(pickedDate);
    }
  }

  Widget _buildFieldLabel(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.smaller),
      child: Text(label,
          style: AppTextStyle.bodySmall.copyWith(
            color: context.isDarkMode
                ? AppColors.textPrimaryDark
                : AppColors.textPrimary,
          )),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ageText = selectedDate != null
        ? '${_calculateAge(selectedDate!)} ${context.l10n.years} (${_formatDate(selectedDate!)})'
        : context.l10n.selectBirthDate;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel(context),
        InkWell(
          onTap: onDateChanged != null ? () => _showDatePicker(context) : null,
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(
                horizontal: Insets.small, vertical: Insets.small),
            decoration: BoxDecoration(
              border: Border.all(
                color: context.isDarkMode
                    ? AppColors.borderDark
                    : AppColors.border,
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    ageText,
                    style: AppTextStyle.labelLarge.copyWith(
                      color: selectedDate != null
                          ? (context.isDarkMode
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimary)
                          : (context.isDarkMode
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondary),
                    ),
                  ),
                ),
                const SizedBox(width: Insets.smaller),
                Assets.icons.calendar.svg(
                    width: 16.0,
                    height: 16.0,
                    colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
