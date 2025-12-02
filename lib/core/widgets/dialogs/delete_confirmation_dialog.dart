import 'package:flutter/material.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/core/widgets/dialogs/app_dialog.dart';

class DeleteConfirmationDialog {
  static void show({
    required BuildContext context,
    required String title,
    required VoidCallback onConfirm,
    VoidCallback? onCancel,
  }) {
    final textColor =
        context.isDarkMode ? AppColors.textPrimaryDark : AppColors.textPrimary;

    showDialog(
      context: context,
      builder: (context) => AppDialog(
        title: title,
        description: '',
        mode: AppDialogMode.confirmation,
        items: const [],
        cancelText: 'Cancel',
        confirmText: 'Delete',
        confirmButtonColor: context.colorScheme.error,
        customContent: Padding(
          padding: const EdgeInsets.only(bottom: Insets.medium),
          child: Container(
            padding: const EdgeInsets.all(Insets.smallNormal),
            decoration: BoxDecoration(
              color: context.colorScheme.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: context.colorScheme.error.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Are you sure?',
                  style: AppTextStyle.bodyMedium.copyWith(color: textColor),
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
                        'This action cannot be undone.',
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
        ),
        onConfirm: (_) {
          onConfirm();
        },
        onCancel: () {
          onCancel?.call();
        },
      ),
    );
  }
}
