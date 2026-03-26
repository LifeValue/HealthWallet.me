import 'package:flutter/material.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';

class AiVisionToggleSection extends StatelessWidget {
  final bool useVision;
  final bool isMmprojDownloading;
  final double mmprojProgress;
  final VoidCallback onToggleOn;
  final VoidCallback onToggleOff;
  final Color textColor;
  final Color secondaryTextColor;
  final Color borderColor;

  const AiVisionToggleSection({
    required this.useVision,
    required this.isMmprojDownloading,
    required this.mmprojProgress,
    required this.onToggleOn,
    required this.onToggleOff,
    required this.textColor,
    required this.secondaryTextColor,
    required this.borderColor,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.smallNormal,
        vertical: Insets.small,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                context.l10n.useVisionLabel,
                style: AppTextStyle.bodyMedium.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: Insets.extraSmall),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 1,
                ),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Beta',
                  style: AppTextStyle.labelSmall.copyWith(
                    color: AppColors.warning,
                    fontWeight: FontWeight.w700,
                    fontSize: 9,
                  ),
                ),
              ),
              const Spacer(),
              _buildOnOffToggle(context),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            context.l10n.useVisionDescription,
            style: AppTextStyle.labelSmall.copyWith(
              color: secondaryTextColor,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOnOffToggle(BuildContext context) {
    if (isMmprojDownloading) {
      return _buildMmprojProgressIndicator();
    }

    final colorScheme = context.colorScheme;

    return GestureDetector(
      onTap: () {
        if (useVision) {
          onToggleOff();
        } else {
          onToggleOn();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 76,
        height: 36,
        padding: const EdgeInsets.all(Insets.extraSmall),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                decoration: BoxDecoration(
                  color: !useVision
                      ? colorScheme.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Text(
                    'OFF',
                    style: context.textTheme.bodySmall?.copyWith(
                      color: !useVision
                          ? (context.isDarkMode
                              ? Colors.white
                              : colorScheme.onPrimary)
                          : colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                decoration: BoxDecoration(
                  color: useVision
                      ? colorScheme.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Text(
                    'ON',
                    style: context.textTheme.bodySmall?.copyWith(
                      color: useVision
                          ? (context.isDarkMode
                              ? Colors.white
                              : colorScheme.onPrimary)
                          : colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMmprojProgressIndicator() {
    final percent = mmprojProgress.round();
    return SizedBox(
      width: 76,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$percent%',
            style: AppTextStyle.labelSmall.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 2),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: mmprojProgress / 100,
              minHeight: 4,
              backgroundColor: AppColors.primary.withValues(alpha: 0.15),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}
