import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';

const double kInputFieldHeight = 44.0;
const double kInputBorderWidth = 1.5;
const double kInputBorderRadius = 8.0;

class AppInputField extends StatelessWidget {
  final TextEditingController? controller;
  final String? initialValue;
  final String? hintText;
  final bool enabled;
  final ValueChanged<String>? onChanged;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final Widget? suffixIcon;
  final double height;

  const AppInputField({
    super.key,
    this.controller,
    this.initialValue,
    this.hintText,
    this.enabled = true,
    this.onChanged,
    this.keyboardType,
    this.inputFormatters,
    this.suffixIcon,
    this.height = kInputFieldHeight,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = context.borderColor;
    final textColor = context.isDarkMode
        ? AppColors.textPrimaryDark
        : AppColors.textPrimary;
    final hintColor = context.isDarkMode
        ? AppColors.textSecondaryDark
        : AppColors.textSecondary;

    final effectiveController =
        controller ?? TextEditingController(text: initialValue ?? '');

    return Container(
      height: height,
      decoration: BoxDecoration(
        border: Border.all(color: borderColor, width: kInputBorderWidth),
        borderRadius: BorderRadius.circular(kInputBorderRadius),
      ),
      alignment: Alignment.center,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: effectiveController,
              enabled: enabled,
              onChanged: onChanged,
              keyboardType: keyboardType,
              inputFormatters: inputFormatters,
              style: AppTextStyle.labelLarge
                  .copyWith(color: textColor, height: 1.0),
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: Insets.smallNormal,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isCollapsed: true,
                hintText: hintText,
                hintStyle: AppTextStyle.labelLarge
                    .copyWith(color: hintColor, height: 1.0),
              ),
            ),
          ),
          if (suffixIcon != null)
            Padding(
              padding: const EdgeInsets.only(right: Insets.small),
              child: suffixIcon!,
            ),
        ],
      ),
    );
  }
}

TextStyle inputFieldTextStyle(BuildContext context) {
  return AppTextStyle.labelLarge.copyWith(
    color: context.isDarkMode
        ? AppColors.textPrimaryDark
        : AppColors.textPrimary,
    height: 1.0,
  );
}
