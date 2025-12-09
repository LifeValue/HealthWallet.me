import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';

class SuccessDialog extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback? onOkPressed;

  const SuccessDialog({
    super.key,
    required this.title,
    required this.message,
    this.onOkPressed,
  });

  static Future<void> show({
    required BuildContext context,
    required String title,
    required String message,
    VoidCallback? onOkPressed,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return SuccessDialog(
          title: title,
          message: message,
          onOkPressed: onOkPressed,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final textColor =
        context.isDarkMode ? AppColors.textPrimaryDark : AppColors.textPrimary;
    final borderColor =
        context.isDarkMode ? AppColors.borderDark : AppColors.border;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(Insets.normal),
        child: Container(
          decoration: BoxDecoration(
            color: context.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.all(Insets.normal),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Success title
                Text(
                  title,
                  style: AppTextStyle.titleLarge.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: Insets.normal),
                // Content
                Text(
                  message,
                  style: AppTextStyle.labelLarge.copyWith(color: textColor),
                ),

                const SizedBox(height: Insets.normal),

                // Action button
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context)
                        .pop(); // Always close the dialog first
                    onOkPressed
                        ?.call(); // Then call the custom callback if provided
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.all(8),
                    fixedSize: const Size.fromHeight(36),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'OK',
                    style: AppTextStyle.buttonSmall.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
