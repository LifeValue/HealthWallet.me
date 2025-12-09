import 'package:flutter/material.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';

enum AppButtonVariant {
  primary,
  secondary,
  transparent,
  outlined,
}

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Widget? icon;
  final AppButtonVariant variant;
  final bool fullWidth;
  final EdgeInsets? padding;
  final Color? backgroundColor;
  final bool enabled;
  final double? iconSize;

  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = AppButtonVariant.primary,
    this.fullWidth = true,
    this.padding,
    this.backgroundColor,
    this.enabled = true,
    this.iconSize = 16,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = context.isDarkMode;
    final colorScheme = context.colorScheme;

    Widget button;

    if (variant == AppButtonVariant.transparent) {
      // Text button for transparent variant
      final textColor = isDarkMode ? Colors.white : colorScheme.primary;
      final iconColor = isDarkMode ? Colors.white : colorScheme.primary;

      button = TextButton.icon(
        onPressed: enabled ? onPressed : null,
        icon: icon != null
            ? _buildIconWithColorFilter(icon!, iconColor)
            : const SizedBox.shrink(),
        label: Text(
          label,
          style: AppTextStyle.buttonMedium.copyWith(
            color: textColor,
          ),
        ),
        style: TextButton.styleFrom(
          padding: padding ??
              const EdgeInsets.symmetric(
                horizontal: Insets.medium,
                vertical: Insets.smallNormal,
              ),
        ),
      );
    } else if (variant == AppButtonVariant.outlined) {
      // Outlined button variant
      final borderColor = backgroundColor ?? colorScheme.primary;
      final textColor = backgroundColor ?? colorScheme.primary;
      final iconColor = backgroundColor ?? colorScheme.primary;

      button = OutlinedButton.icon(
        onPressed: enabled ? onPressed : null,
        icon: icon != null
            ? _buildIconWithColorFilter(icon!, iconColor)
            : const SizedBox.shrink(),
        label: Text(
          label,
          style: AppTextStyle.buttonMedium.copyWith(
            color: textColor,
          ),
        ),
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: textColor,
          side: BorderSide(color: borderColor, width: 1),
          disabledForegroundColor: textColor.withOpacity(0.5),
          disabledBackgroundColor: Colors.transparent,
          padding: padding ??
              const EdgeInsets.symmetric(
                horizontal: Insets.medium,
                vertical: Insets.smallNormal,
              ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Insets.small),
          ),
        ),
      );
    } else {
      // Elevated button for primary and secondary variants
      final bgColor = backgroundColor ??
          (variant == AppButtonVariant.primary
              ? colorScheme.primary
              : colorScheme.secondary);
      // Always use white text when custom backgroundColor is provided
      // In dark mode, always use white text for buttons with background
      // Otherwise use the appropriate onColor for the variant
      final fgColor = backgroundColor != null
          ? Colors.white
          : (isDarkMode
              ? Colors.white
              : (variant == AppButtonVariant.primary
                  ? colorScheme.onPrimary
                  : colorScheme.onSecondary));

      button = ElevatedButton.icon(
        onPressed: enabled ? onPressed : null,
        icon: icon != null
            ? _buildIconWithColorFilter(icon!, fgColor)
            : const SizedBox.shrink(),
        label: Text(
          label,
          style: AppTextStyle.buttonMedium.copyWith(
            color: fgColor,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: bgColor,
          foregroundColor: fgColor,
          disabledBackgroundColor: bgColor.withOpacity(0.5),
          disabledForegroundColor: fgColor.withOpacity(0.5),
          padding: padding ??
              const EdgeInsets.symmetric(
                horizontal: Insets.medium,
                vertical: Insets.smallNormal,
              ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Insets.small),
          ),
          elevation: 0,
        ),
      );
    }

    if (fullWidth) {
      return SizedBox(
        width: double.infinity,
        child: button,
      );
    }

    return button;
  }

  Widget _buildIconWithColorFilter(Widget icon, Color color) {
    // If icon is a Material Icon, apply color directly
    if (icon is Icon) {
      return Icon(
        icon.icon,
        size: iconSize,
        color: color,
      );
    }

    // For SVG widgets, wrap with ColorFiltered to apply color
    // This works for SVG widgets that don't already have a colorFilter
    return SizedBox(
      width: iconSize,
      height: iconSize,
      child: ColorFiltered(
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
        child: icon,
      ),
    );
  }
}
