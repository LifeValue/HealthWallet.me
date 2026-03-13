import 'package:flutter/material.dart';
import 'package:health_wallet/core/services/biometric_auth_service.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/logger.dart';

class BiometricsSetupDialog extends StatelessWidget {
  const BiometricsSetupDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final BiometricAuthService biometricService = getIt<BiometricAuthService>();

    final borderColor = context.theme.dividerColor;
    final textColor = context.primaryTextColor;
    final iconColor = context.secondaryTextColor;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(Insets.medium),
      child: Container(
        width: 400,
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
                    context.l10n.setupDeviceSecurity,
                    style: AppTextStyle.bodyMedium.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.w600,
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
                        color: iconColor,
                        size: 20,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      padding: EdgeInsets.zero,
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
                  Text(
                    context.l10n.deviceSecurityMessage,
                    style: AppTextStyle.bodySmall.copyWith(
                      color: textColor,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: Insets.medium),
                  _buildSetupStep(
                      context, '1', context.l10n.deviceSettingsStep1),
                  _buildSetupStep(
                      context, '2', context.l10n.deviceSettingsStep2),
                  _buildSetupStep(
                      context, '3', context.l10n.deviceSettingsStep3),
                  _buildSetupStep(
                      context, '4', context.l10n.deviceSettingsStep4),
                  const SizedBox(height: Insets.medium),
                  Text(
                    context.l10n.deviceSecurityReturnMessage,
                    style: AppTextStyle.labelLarge.copyWith(
                      color: iconColor,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(Insets.normal),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        foregroundColor: context.colorScheme.primary,
                      ),
                      child: Text(
                        context.l10n.cancel,
                        style: AppTextStyle.buttonMedium,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.of(context).pop();

                        try {
                          final opened =
                              await biometricService.openDeviceSettings();
                          if (!opened) {
                            if (context.mounted) {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title:
                                      Text(context.l10n.settingsNotAvailable),
                                  content: Text(
                                    context.l10n.settingsNotAvailableMessage,
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(),
                                      child: Text(context.l10n.ok),
                                    ),
                                  ],
                                ),
                              );
                            }
                          }
                        } catch (e) {
                          logger.w('Failed to open device settings: $e');
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        context.l10n.openSettings,
                        style: AppTextStyle.buttonMedium.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSetupStep(BuildContext context, String number, String text) {
    final textColor = context.primaryTextColor;

    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.small),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: context.colorScheme.primary,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Center(
              child: Text(
                number,
                style: AppTextStyle.labelSmall.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: Insets.small),
          Expanded(
            child: Text(
              text,
              style: AppTextStyle.bodySmall.copyWith(
                color: textColor,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
