import 'package:flutter/material.dart';
import 'package:health_wallet/core/l10n/l10n.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/core/widgets/dialogs/app_dialog.dart';

class DeleteConfirmationDialog {
  static void show({
    required BuildContext context,
    required String title,
    required VoidCallback onConfirm,
    VoidCallback? onCancel,
  }) {
    final textColor = context.primaryTextColor;

    showDialog(
      context: context,
      builder: (context) => AppDialog(
        title: title,
        description: '',
        mode: AppDialogMode.confirmation,
        items: const [],
        cancelText: context.l10n.cancel,
        confirmText: context.l10n.delete,
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
                  context.l10n.areYouSure,
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
                        context.l10n.actionCannotBeUndone,
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
