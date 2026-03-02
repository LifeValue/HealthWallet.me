import 'package:flutter/material.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';

enum AppButtonVariant {
  primary,
  secondary,
  transparent,
  outlined,
  tinted,
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
  final double? height;
  final double? fontSize;
  final bool pillShaped;

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
    this.height,
    this.fontSize,
    this.pillShaped = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = context.isDarkMode;
    final colorScheme = context.colorScheme;

    Widget button;

    final effectivePadding = padding ??
        const EdgeInsets.symmetric(
          horizontal: Insets.medium,
          vertical: Insets.smallNormal,
        );
    final fixedSize = height != null ? Size.fromHeight(height!) : null;
    final effectiveShape = pillShaped
        ? const StadiumBorder()
        : RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Insets.small),
          );

    if (variant == AppButtonVariant.tinted) {
      final tintColor = backgroundColor ?? colorScheme.primary;
      final labelWidget = Text(
        label,
        style: AppTextStyle.buttonMedium.copyWith(
          color: tintColor,
          fontSize: fontSize,
        ),
      );
      final style = TextButton.styleFrom(
        backgroundColor: tintColor.withValues(alpha: 0.08),
        foregroundColor: tintColor,
        disabledForegroundColor: tintColor.withValues(alpha: 0.5),
        disabledBackgroundColor: tintColor.withValues(alpha: 0.04),
        padding: effectivePadding,
        fixedSize: fixedSize,
        shape: effectiveShape,
      );

      button = icon != null
          ? TextButton.icon(
              onPressed: enabled ? onPressed : null,
              icon: _buildIconWithColorFilter(icon!, tintColor),
              label: labelWidget,
              style: style,
            )
          : TextButton(
              onPressed: enabled ? onPressed : null,
              style: style,
              child: labelWidget,
            );
    } else if (variant == AppButtonVariant.transparent) {
      final isDisabled = !enabled || onPressed == null;
      final activeColor = isDarkMode ? Colors.white : colorScheme.primary;
      final textColor = isDisabled
          ? colorScheme.onSurface.withValues(alpha: 0.4)
          : activeColor;
      final iconColor = textColor;
      final labelWidget = Text(
        label,
        style: AppTextStyle.buttonMedium.copyWith(
          color: textColor,
          fontSize: fontSize,
        ),
      );
      final style = TextButton.styleFrom(
        padding: effectivePadding,
        fixedSize: fixedSize,
      );

      button = icon != null
          ? TextButton.icon(
              onPressed: enabled ? onPressed : null,
              icon: _buildIconWithColorFilter(icon!, iconColor),
              label: labelWidget,
              style: style,
            )
          : TextButton(
              onPressed: enabled ? onPressed : null,
              style: style,
              child: labelWidget,
            );
    } else if (variant == AppButtonVariant.outlined) {
      final borderColor = backgroundColor ?? colorScheme.primary;
      final textColor = backgroundColor ?? colorScheme.primary;
      final iconColor = backgroundColor ?? colorScheme.primary;
      final labelWidget = Text(
        label,
        style: AppTextStyle.buttonMedium.copyWith(
          color: textColor,
          fontSize: fontSize,
        ),
      );
      final style = OutlinedButton.styleFrom(
        backgroundColor: Colors.transparent,
        foregroundColor: textColor,
        side: BorderSide(color: borderColor, width: 1),
        disabledForegroundColor: textColor.withOpacity(0.5),
        disabledBackgroundColor: Colors.transparent,
        padding: effectivePadding,
        fixedSize: fixedSize,
        shape: effectiveShape,
      );

      button = icon != null
          ? OutlinedButton.icon(
              onPressed: enabled ? onPressed : null,
              icon: _buildIconWithColorFilter(icon!, iconColor),
              label: labelWidget,
              style: style,
            )
          : OutlinedButton(
              onPressed: enabled ? onPressed : null,
              style: style,
              child: labelWidget,
            );
    } else {
      final bgColor = backgroundColor ??
          (variant == AppButtonVariant.primary
              ? colorScheme.primary
              : colorScheme.secondary);
      final fgColor = backgroundColor != null
          ? Colors.white
          : (isDarkMode
              ? Colors.white
              : (variant == AppButtonVariant.primary
                  ? colorScheme.onPrimary
                  : colorScheme.onSecondary));
      final labelWidget = Text(
        label,
        style: AppTextStyle.buttonMedium.copyWith(
          color: fgColor,
          fontSize: fontSize,
        ),
      );
      final style = ElevatedButton.styleFrom(
        backgroundColor: bgColor,
        foregroundColor: fgColor,
        disabledBackgroundColor: bgColor.withOpacity(0.5),
        disabledForegroundColor: fgColor.withOpacity(0.5),
        padding: effectivePadding,
        fixedSize: fixedSize,
        shape: effectiveShape,
        elevation: 0,
      );

      button = icon != null
          ? ElevatedButton.icon(
              onPressed: enabled ? onPressed : null,
              icon: _buildIconWithColorFilter(icon!, fgColor),
              label: labelWidget,
              style: style,
            )
          : ElevatedButton(
              onPressed: enabled ? onPressed : null,
              style: style,
              child: labelWidget,
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
    if (icon is Icon) {
      return Icon(
        icon.icon,
        size: iconSize,
        color: color,
      );
    }

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
