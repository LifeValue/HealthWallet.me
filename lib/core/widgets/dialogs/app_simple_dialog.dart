import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/core/utils/responsive.dart';

class AppSimpleDialog {
  AppSimpleDialog._();

  static Future<bool?> showConfirmation({
    required BuildContext context,
    required String title,
    String? message,
    required String confirmText,
    required String cancelText,
    required VoidCallback onConfirm,
    VoidCallback? onCancel,
    Color? confirmColor,
    bool barrierDismissible = false,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (dialogContext) {
        final textColor = context.isDarkMode
            ? AppColors.textPrimaryDark
            : AppColors.textPrimary;

        return _DialogShell(
          child: Padding(
            padding: const EdgeInsets.all(Insets.normal),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  message ?? title,
                  style: AppTextStyle.labelLarge.copyWith(color: textColor),
                ),
                const SizedBox(height: Insets.normal),
                _ActionButtons(
                  cancelText: cancelText,
                  confirmText: confirmText,
                  confirmColor: confirmColor ?? AppColors.primary,
                  onCancel: () {
                    Navigator.of(dialogContext).pop(false);
                    onCancel?.call();
                  },
                  onConfirm: () {
                    Navigator.of(dialogContext).pop(true);
                    onConfirm();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static Future<bool?> showDestructiveConfirmation({
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
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final textColor = context.primaryTextColor;
        final borderColor = context.borderColor;

        return PopScope(
          canPop: false,
          child: _DialogShell(
            useResponsiveWidth: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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
                        style:
                            AppTextStyle.bodyMedium.copyWith(color: textColor),
                      ),
                      SizedBox(
                        width: 36,
                        height: 36,
                        child: IconButton(
                          icon: Icon(Icons.close, color: textColor, size: 24),
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
                Container(height: 1, color: borderColor),
                Padding(
                  padding: const EdgeInsets.all(Insets.normal),
                  child: Column(
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
                            if (warningText != null) ...[
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
                                      warningText,
                                      style: AppTextStyle.regular.copyWith(
                                        color: context.colorScheme.error,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: Insets.normal),
                      _ActionButtons(
                        cancelText: cancelText,
                        confirmText: confirmText,
                        confirmColor:
                            confirmButtonColor ?? context.colorScheme.error,
                        onCancel: () {
                          Navigator.of(dialogContext).pop(false);
                          onCancel?.call();
                        },
                        onConfirm: () {
                          Navigator.of(dialogContext).pop(true);
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            onConfirm();
                          });
                        },
                        useCancelTextButton: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static Future<void> showSuccess({
    required BuildContext context,
    required String title,
    required String message,
    VoidCallback? onOkPressed,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final textColor = context.isDarkMode
            ? AppColors.textPrimaryDark
            : AppColors.textPrimary;

        return _DialogShell(
          child: Padding(
            padding: const EdgeInsets.all(Insets.normal),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title,
                  style: AppTextStyle.titleLarge
                      .copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: Insets.normal),
                Text(
                  message,
                  style: AppTextStyle.labelLarge.copyWith(color: textColor),
                ),
                const SizedBox(height: Insets.normal),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    onOkPressed?.call();
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
                    style: AppTextStyle.buttonSmall
                        .copyWith(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DialogShell extends StatelessWidget {
  final Widget child;
  final bool useResponsiveWidth;

  const _DialogShell({
    required this.child,
    this.useResponsiveWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = context.borderColor;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(Insets.normal),
        child: Container(
          width: useResponsiveWidth ? context.dialogWidth : null,
          decoration: BoxDecoration(
            color: context.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  final String cancelText;
  final String confirmText;
  final Color confirmColor;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;
  final bool useCancelTextButton;

  const _ActionButtons({
    required this.cancelText,
    required this.confirmText,
    required this.confirmColor,
    required this.onCancel,
    required this.onConfirm,
    this.useCancelTextButton = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: useCancelTextButton
              ? TextButton(
                  onPressed: onCancel,
                  style: TextButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(vertical: Insets.small),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: Text(
                    cancelText,
                    style: AppTextStyle.buttonSmall
                        .copyWith(color: AppColors.primary),
                  ),
                )
              : OutlinedButton(
                  onPressed: onCancel,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: BorderSide.none,
                    padding: const EdgeInsets.all(8),
                    fixedSize: const Size.fromHeight(36),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: Text(
                    cancelText,
                    style: AppTextStyle.buttonSmall
                        .copyWith(color: AppColors.primary),
                  ),
                ),
        ),
        const SizedBox(width: Insets.small),
        Expanded(
          child: ElevatedButton(
            onPressed: onConfirm,
            style: ElevatedButton.styleFrom(
              backgroundColor: confirmColor,
              foregroundColor: Colors.white,
              padding: useCancelTextButton
                  ? const EdgeInsets.symmetric(vertical: Insets.small)
                  : const EdgeInsets.all(8),
              fixedSize:
                  useCancelTextButton ? null : const Size.fromHeight(36),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
              elevation: 0,
            ),
            child: Text(
              confirmText,
              style:
                  AppTextStyle.buttonSmall.copyWith(color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}
