import 'package:flutter/material.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/gen/assets.gen.dart';

class HomeSectionHeader extends StatelessWidget {
  final String title;
  final Widget? titleWidget;
  final String? filterLabel;
  final VoidCallback? onFilterTap;
  final Widget? trailing;
  final ColorScheme colorScheme;
  final VoidCallback? onTap;
  final Widget? subtitle;
  final bool showDivider;
  final bool isEditMode;
  final VoidCallback? onInfoTap;
  final bool isFilterDisabled;

  const HomeSectionHeader({
    super.key,
    this.title = '',
    this.titleWidget,
    this.filterLabel,
    this.onFilterTap,
    this.trailing,
    required this.colorScheme,
    this.onTap,
    this.subtitle,
    this.showDivider = false,
    this.isEditMode = false,
    this.onInfoTap,
    this.isFilterDisabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = context.isDarkMode
        ? AppColors.textSecondaryDark
        : AppColors.textSecondary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  if (titleWidget != null)
                    titleWidget!
                  else
                    Text(
                      title,
                      style: AppTextStyle.bodyMedium.copyWith(
                        color: context.colorScheme.onSurface,
                      ),
                    ),
                  if (onInfoTap != null) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: onInfoTap,
                      child: Assets.icons.information.svg(
                        width: 16,
                        height: 16,
                        colorFilter: ColorFilter.mode(
                          iconColor,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (subtitle != null && !isEditMode) ...[
              const SizedBox(width: 16),
              subtitle!,
            ],
            if (isEditMode && filterLabel != null)
              InkWell(
                onTap: isFilterDisabled ? null : onFilterTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 4,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Assets.icons.filter.svg(
                        colorFilter: ColorFilter.mode(
                          isFilterDisabled
                              ? colorScheme.onSurface.withOpacity(0.38)
                              : colorScheme.primary,
                          BlendMode.srcIn,
                        ),
                        width: 16,
                        height: 16,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        filterLabel!,
                        style: AppTextStyle.bodySmall.copyWith(
                          color: isFilterDisabled
                              ? colorScheme.onSurface.withOpacity(0.38)
                              : colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else if (trailing != null)
              trailing!
            else
              const SizedBox.shrink(),
          ],
        ),
        if (showDivider)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Divider(
              color: colorScheme.outline.withValues(alpha: 0.2),
              height: 1,
            ),
          ),
      ],
    );
  }
}
