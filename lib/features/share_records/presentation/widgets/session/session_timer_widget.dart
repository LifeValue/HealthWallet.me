import 'package:flutter/material.dart';

import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';

class SessionTimerWidget extends StatelessWidget {
  final Duration? timeRemaining;
  final bool isExpanded;
  final VoidCallback? onToggleExpanded;
  final String? statusText;

  const SessionTimerWidget({
    super.key,
    this.timeRemaining,
    this.isExpanded = false,
    this.onToggleExpanded,
    this.statusText,
  });

  @override
  Widget build(BuildContext context) {
    final remaining = timeRemaining ?? Duration.zero;
    final isWarning = remaining.inSeconds < 60;

    final hours = remaining.inHours;
    final minutes = remaining.inMinutes % 60;
    final seconds = remaining.inSeconds % 60;
    String timeText;
    if (hours > 0) {
      timeText = '${hours}h ${minutes}min ${seconds}s';
    } else if (minutes > 0) {
      timeText = '${minutes}min ${seconds}s';
    } else {
      timeText = '${seconds}s';
    }

    final timerColor = isWarning ? AppColors.error : context.colorScheme.onSurface;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onToggleExpanded,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Insets.normal,
          vertical: Insets.smallNormal,
        ),
        child: Row(
          children: [
            Icon(
              Icons.timer_outlined,
              size: 20,
              color: timerColor,
            ),
            const SizedBox(width: Insets.small),
            Text(
              'Session expires in',
              style: AppTextStyle.bodyMedium.copyWith(
                color: isWarning
                    ? AppColors.error
                    : context.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(width: Insets.smallNormal),
            Text(
              timeText,
              style: AppTextStyle.titleMedium.copyWith(
                fontWeight: FontWeight.bold,
                color: isWarning ? AppColors.error : AppColors.primary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const Spacer(),
            if (statusText != null)
              Text(
                statusText!,
                style: AppTextStyle.labelSmall.copyWith(
                  color: AppColors.warning,
                ),
              )
            else if (onToggleExpanded != null)
              Icon(
                isExpanded
                    ? Icons.keyboard_arrow_down
                    : Icons.keyboard_arrow_up,
                size: 22,
                color: context.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
          ],
        ),
      ),
    );
  }
}
