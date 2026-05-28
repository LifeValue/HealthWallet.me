import 'package:flutter/material.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/features/home/presentation/bloc/home_bloc.dart';

class HomeOverviewToggle extends StatelessWidget {
  final OverviewViewMode mode;
  final ValueChanged<OverviewViewMode> onChanged;

  const HomeOverviewToggle({
    super.key,
    required this.mode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final outerColor =
        isDark ? const Color(0xFF060606) : const Color(0xFFF2F2F2);
    final borderColor =
        isDark ? const Color(0xFF3C3C3C) : const Color(0xFFE0E0E0);
    final inactiveTextColor = context.colorScheme.onSurface;

    final isSpecialties = mode == OverviewViewMode.specialties;

    return GestureDetector(
      onTap: () => onChanged(
        isSpecialties ? OverviewViewMode.resources : OverviewViewMode.specialties,
      ),
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: outerColor,
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(222),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isSpecialties ? AppColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(222),
              ),
              child: Text(
                'Specialties',
                style: AppTextStyle.labelSmall.copyWith(
                  color: isSpecialties ? Colors.white : inactiveTextColor,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: !isSpecialties ? AppColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(222),
              ),
              child: Text(
                'Resources',
                style: AppTextStyle.labelSmall.copyWith(
                  color: !isSpecialties ? Colors.white : inactiveTextColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
