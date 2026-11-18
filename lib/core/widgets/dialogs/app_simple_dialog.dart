import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:health_wallet/core/l10n/l10n.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/core/utils/responsive.dart';
import 'package:health_wallet/core/widgets/app_button.dart';

class AppSimpleDialog {
  AppSimpleDialog._();

  static Future<bool?> showConfirmation({
    required BuildContext context,
    required String title,
    String? message,
    String? subtitle,
    Widget? subtitleWidget,
    required String confirmText,
    required String cancelText,
    required VoidCallback onConfirm,
    VoidCallback? onCancel,
    Color? confirmColor,
    bool barrierDismissible = false,
    bool showCloseButton = true,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (dialogContext) {
        final textColor = context.isDarkMode
            ? AppColors.textPrimaryDark
            : AppColors.textPrimary;

        return _DialogShell(
          useResponsiveWidth: true,
          child: Padding(
            padding: const EdgeInsets.all(Insets.normal),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: AppTextStyle.bodyLarge.copyWith(
                          color: textColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    // Closes without choosing: unlike Cancel, it doesn't run
                    // onCancel, which some dialogs use as a second action.
                    if (showCloseButton) ...[
                      const SizedBox(width: Insets.small),
                      IconButton(
                        key: const Key('confirmation_dialog_close'),
                        tooltip: dialogContext.l10n.close,
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        icon: Icon(
                          Icons.close,
                          size: 18,
                          color: textColor.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ],
                ),
                if (message != null) ...[
                  const SizedBox(height: Insets.normal),
                  Text(
                    message,
                    style: AppTextStyle.labelLarge.copyWith(color: textColor),
                  ),
                ],
                if (subtitleWidget != null) ...[
                  const SizedBox(height: Insets.normal),
                  subtitleWidget,
                ] else if (subtitle != null) ...[
                  const SizedBox(height: Insets.normal),
                  Text(
                    subtitle,
                    style: AppTextStyle.bodyMedium.copyWith(
                      color: textColor.withValues(alpha: 0.6),
                    ),
                  ),
                ],
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
                        style: AppTextStyle.bodyMedium.copyWith(
                          color: textColor,
                        ),
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
                          color: context.colorScheme.error.withValues(
                            alpha: 0.1,
                          ),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: context.colorScheme.error.withValues(
                              alpha: 0.3,
                            ),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              message,
                              style: AppTextStyle.bodyMedium.copyWith(
                                color: textColor,
                              ),
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

  /// A small, centred confirmation: a check mark, the title, a short message
  /// and one OK button.
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
        return _DialogShell(
          width: successDialogWidth,
          child: Padding(
            padding: const EdgeInsets.all(Insets.medium),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    key: const Key('success_dialog_icon'),
                    padding: const EdgeInsets.all(Insets.smallNormal),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: AppColors.success,
                      size: Insets.large,
                    ),
                  ),
                ),
                const SizedBox(height: Insets.normal),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: AppTextStyle.titleSmall.copyWith(
                    color: dialogContext.primaryTextColor,
                  ),
                ),
                const SizedBox(height: Insets.small),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: AppTextStyle.bodyMedium.copyWith(
                    color: dialogContext.secondaryTextColor,
                  ),
                ),
                const SizedBox(height: Insets.medium),
                AppButton(
                  label: dialogContext.l10n.ok,
                  height: 40,
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    onOkPressed?.call();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Width of [showSuccess]: a short message reads best in a narrow card.
  /// A question with one button per answer. It can't be dismissed: the
  /// user picks one, and the future completes with its value.
  static Future<T?> showChoice<T>({
    required BuildContext context,
    required String title,
    required String message,
    required List<(String label, T value)> choices,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final textColor = context.isDarkMode
            ? AppColors.textPrimaryDark
            : AppColors.textPrimary;

        return PopScope(
          canPop: false,
          child: _DialogShell(
            useResponsiveWidth: true,
            child: Padding(
              padding: const EdgeInsets.all(Insets.normal),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    title,
                    style: AppTextStyle.bodyLarge.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: Insets.normal),
                  Text(
                    message,
                    style: AppTextStyle.labelLarge.copyWith(color: textColor),
                  ),
                  const SizedBox(height: Insets.normal),
                  for (final (i, (label, value)) in choices.indexed) ...[
                    if (i > 0) const SizedBox(height: Insets.small),
                    AppButton(
                      label: label,
                      variant: i == choices.length - 1
                          ? AppButtonVariant.outlined
                          : AppButtonVariant.primary,
                      fullWidth: true,
                      onPressed: () => Navigator.of(dialogContext).pop(value),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @visibleForTesting
  static const double successDialogWidth = 360;
}

class _DialogShell extends StatelessWidget {
  final Widget child;
  final bool useResponsiveWidth;

  /// A fixed width; overrides [useResponsiveWidth].
  final double? width;

  const _DialogShell({
    required this.child,
    this.useResponsiveWidth = false,
    this.width,
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
          width: width ?? (useResponsiveWidth ? context.dialogWidth : null),
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
    final showCancel = cancelText.isNotEmpty;

    return Row(
      mainAxisAlignment: showCancel
          ? MainAxisAlignment.start
          : MainAxisAlignment.center,
      children: [
        if (showCancel) ...[
          Expanded(
            // An outlined button, so Cancel reads as a button next to the
            // filled action, not as plain text.
            child: OutlinedButton(
              onPressed: onCancel,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                padding: useCancelTextButton
                    ? const EdgeInsets.symmetric(vertical: Insets.small)
                    : const EdgeInsets.all(8),
                fixedSize: useCancelTextButton
                    ? null
                    : const Size.fromHeight(36),
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
        ],
        Expanded(
          child: ElevatedButton(
            onPressed: onConfirm,
            style: ElevatedButton.styleFrom(
              backgroundColor: confirmColor,
              foregroundColor: Colors.white,
              padding: useCancelTextButton
                  ? const EdgeInsets.symmetric(vertical: Insets.small)
                  : const EdgeInsets.all(8),
              fixedSize: useCancelTextButton ? null : const Size.fromHeight(36),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
              elevation: 0,
            ),
            child: Text(
              confirmText,
              style: AppTextStyle.buttonSmall.copyWith(color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}
