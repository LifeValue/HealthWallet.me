import 'package:flutter/material.dart';
import 'package:health_wallet/core/l10n/l10n.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/widgets/dialogs/app_simple_dialog.dart';

/// Asks before stopping an AI model download, which then starts over from
/// the beginning; [onConfirm] runs only when the user confirms.
Future<bool?> confirmCancelDownload(
  BuildContext context, {
  required VoidCallback onConfirm,
}) => AppSimpleDialog.showConfirmation(
  context: context,
  title: context.l10n.cancelDownloadTitle,
  message: context.l10n.cancelDownloadMessage,
  confirmText: context.l10n.cancelDownloadTitle,
  cancelText: context.l10n.continueButton,
  confirmColor: AppColors.error,
  onConfirm: onConfirm,
);

/// The red "Cancel" next to a download's progress. It asks first, then runs
/// [onCancelConfirmed].
class CancelDownloadButton extends StatelessWidget {
  const CancelDownloadButton({super.key, required this.onCancelConfirmed});

  final VoidCallback onCancelConfirmed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => confirmCancelDownload(
          context,
          onConfirm: onCancelConfirmed,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Insets.small,
            vertical: Insets.extraSmall,
          ),
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(Insets.extraSmall),
          ),
          child: Text(
            context.l10n.cancel,
            style: AppTextStyle.labelSmall.copyWith(color: AppColors.error),
          ),
        ),
      ),
    );
  }
}
