import 'package:flutter/material.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/core/widgets/dialogs/app_simple_dialog.dart';
import 'package:health_wallet/gen/assets.gen.dart';

class PatientModifiedBanner extends StatelessWidget {
  final String patientName;
  final VoidCallback? onRevert;

  const PatientModifiedBanner({
    super.key,
    required this.patientName,
    this.onRevert,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(
        left: Insets.smallNormal,
        top: Insets.extraSmall,
        bottom: Insets.extraSmall,
        right: Insets.extraSmall,
      ),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Assets.icons.edit.svg(
            width: 16,
            height: 16,
            colorFilter: ColorFilter.mode(
              AppColors.warning,
              BlendMode.srcIn,
            ),
          ),
          const SizedBox(width: Insets.small),
          Expanded(
            child: Text(
              context.l10n.patientModifiedUpdating(patientName),
              style: AppTextStyle.labelSmall.copyWith(
                color: AppColors.warning,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (onRevert != null)
            GestureDetector(
              onTap: () => _confirmRevert(context),
              child: Padding(
                padding: const EdgeInsets.all(Insets.extraSmall),
                child: Assets.icons.close.svg(
                  width: 14,
                  height: 14,
                  colorFilter: ColorFilter.mode(
                    AppColors.warning,
                    BlendMode.srcIn,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _confirmRevert(BuildContext context) {
    AppSimpleDialog.showDestructiveConfirmation(
      context: context,
      title: context.l10n.dropModificationsTitle,
      message: context.l10n.dropModificationsMessage,
      warningText: context.l10n.actionCannotBeUndone,
      confirmText: context.l10n.continueButton,
      cancelText: context.l10n.cancel,
      onConfirm: () => onRevert?.call(),
    );
  }
}
