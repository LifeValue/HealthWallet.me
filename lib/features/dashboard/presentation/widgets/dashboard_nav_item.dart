import 'package:flutter/material.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';

/// One tab of the dashboard's bottom bar: an icon over a label.
///
/// The label always stays on one line: when the icon and label don't fit the
/// tab (long German or Romanian words, larger text scales), both are scaled
/// down together, never wrapped or cut.
class DashboardNavItem extends StatelessWidget {
  const DashboardNavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    super.key,
  });

  final Widget icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: double.infinity,
        decoration: BoxDecoration(
          color: isSelected ? context.colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Insets.extraSmall),
            // Scales icon and label together, so a long label or a large
            // text scale shrinks the content to fit the tab in both axes.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  icon,
                  const SizedBox(height: Insets.extraSmall),
                  Text(
                    label,
                    maxLines: 1,
                    softWrap: false,
                    style: AppTextStyle.labelSmall.copyWith(
                      color: isSelected
                          ? (context.isDarkMode
                                ? Colors.white
                                : context.colorScheme.surface)
                          : context.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
