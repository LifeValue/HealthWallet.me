import 'package:flutter/material.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/gen/assets.gen.dart';

enum RecordsViewMode { recordsList, attachments }

class RecordsViewToggle extends StatelessWidget {
  final RecordsViewMode mode;
  final ValueChanged<RecordsViewMode> onChanged;

  const RecordsViewToggle({
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
    final inactiveIconColor = isDark ? Colors.white : Colors.black54;

    final isRecords = mode == RecordsViewMode.recordsList;

    return GestureDetector(
      onTap: () => onChanged(
        isRecords ? RecordsViewMode.attachments : RecordsViewMode.recordsList,
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
            _buildTab(
              svgIcon: Assets.icons.list,
              label: 'Records',
              isActive: isRecords,
              inactiveIconColor: inactiveIconColor,
            ),
            _buildTab(
              svgIcon: Assets.icons.attachmentsView,
              label: 'Attachments',
              isActive: !isRecords,
              inactiveIconColor: inactiveIconColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTab({
    required SvgGenImage svgIcon,
    required String label,
    required bool isActive,
    required Color inactiveIconColor,
  }) {
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(222),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            svgIcon.svg(
              width: 16,
              height: 16,
              colorFilter: ColorFilter.mode(
                isActive ? Colors.white : inactiveIconColor,
                BlendMode.srcIn,
              ),
            ),
            if (isActive) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: AppTextStyle.labelSmall.copyWith(color: Colors.white),
              ),
            ],
          ],
        ),
      );
  }
}
