import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';

class AlertDialogs {
  static Future<bool?> showConfirmation({
    required BuildContext context,
    required String title,
    required String message,
    required String confirmText,
    required String cancelText,
    required VoidCallback onConfirm,
    VoidCallback? onCancel,
    String? warningText,
    Color? confirmButtonColor,
  }) {
    final textColor =
        context.isDarkMode ? AppColors.textPrimaryDark : AppColors.textPrimary;
    final borderColor =
        context.isDarkMode ? AppColors.borderDark : AppColors.border;

    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PopScope(
        canPop: false,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(Insets.normal),
            child: Container(
              width: 350,
              decoration: BoxDecoration(
                color: context.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor, width: 1),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Insets.normal,
                      vertical: Insets.small,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          title,
                          style: AppTextStyle.bodyMedium.copyWith(
                            color: textColor,
                          ),
                        ),
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: IconButton(
                            icon: Icon(
                              Icons.close,
                              color: textColor,
                              size: 24,
                            ),
                            onPressed: () {
                              Navigator.of(dialogContext).pop(false);
                              onCancel?.call();
                            },
                            padding: const EdgeInsets.all(9),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Divider
                  Container(height: 1, color: borderColor),

                  // Content
                  Padding(
                    padding: const EdgeInsets.all(Insets.normal),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(Insets.smallNormal),
                          decoration: BoxDecoration(
                            color: context.colorScheme.error
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: context.colorScheme.error
                                  .withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                message,
                                style: AppTextStyle.bodyMedium
                                    .copyWith(color: textColor),
                              ),
                              const SizedBox(height: Insets.smallNormal),
                              Row(
                                children: [
                                  Icon(
                                    Icons.warning_amber_rounded,
                                    color: context.colorScheme.error,
                                    size: 20,
                                  ),
                                  const SizedBox(width: Insets.small),
                                  Expanded(
                                    child: Text(
                                      warningText ?? '',
                                      style: AppTextStyle.regular.copyWith(
                                        color: context.colorScheme.error,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: Insets.normal),
                        Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                onPressed: () {
                                  Navigator.of(dialogContext).pop(false);
                                  onCancel?.call();
                                },
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: Insets.small,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                                child: Text(
                                  cancelText,
                                  style: AppTextStyle.buttonSmall.copyWith(
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: Insets.small),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.of(dialogContext).pop(true);
                                  // Dispatch callback after dialog is fully closed
                                  // This prevents blank screen issues with PageView navigation
                                  WidgetsBinding.instance
                                      .addPostFrameCallback((_) {
                                    onConfirm();
                                  });
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: confirmButtonColor ??
                                      context.colorScheme.error,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: Insets.small,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  elevation: 0,
                                ),
                                child: Text(
                                  confirmText,
                                  style: AppTextStyle.buttonSmall.copyWith(
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
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
