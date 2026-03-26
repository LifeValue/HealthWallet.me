import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/gen/assets.gen.dart';

class ExitConfirmationDialog extends StatelessWidget {
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  const ExitConfirmationDialog({
    super.key,
    required this.onCancel,
    required this.onConfirm,
  });

  static Future<bool?> show({
    required BuildContext context,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const ExitConfirmationDialog(
          onCancel: _defaultCallback,
          onConfirm: _defaultCallback,
        );
      },
    );
  }

  static void _defaultCallback() {}

  @override
  Widget build(BuildContext context) {
    final textColor = context.primaryTextColor;
    final borderColor = context.borderColor;

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
                      context.l10n.shareConfirmExit,
                      style: AppTextStyle.bodyMedium.copyWith(color: textColor),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        color: textColor,
                        size: 24,
                      ),
                      onPressed: () => Navigator.of(context).pop(false),
                      padding: const EdgeInsets.all(9),
                    ),
                  ],
                ),
              ),
              Container(height: 1, color: borderColor),
              Padding(
                padding: const EdgeInsets.all(Insets.normal),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(Insets.normal),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.error.withValues(alpha: 0.4),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.l10n.shareDeleteSharedRecords,
                            style: AppTextStyle.bodyMedium.copyWith(
                              color: context.colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: Insets.small),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Assets.icons.information.svg(
                                width: 16,
                                height: 16,
                                colorFilter: const ColorFilter.mode(
                                  AppColors.error,
                                  BlendMode.srcIn,
                                ),
                              ),
                              const SizedBox(width: Insets.small),
                              Expanded(
                                child: Text(
                                  context.l10n.shareDeleteWarning,
                                  style: AppTextStyle.labelLarge.copyWith(
                                    color: AppColors.error,
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
                            onPressed: () => Navigator.of(context).pop(false),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                vertical: Insets.small,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            child: Text(
                              context.l10n.cancel,
                              style: AppTextStyle.buttonSmall.copyWith(
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: Insets.small),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.error,
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
                              context.l10n.shareDeleteAndExit,
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
    );
  }
}
