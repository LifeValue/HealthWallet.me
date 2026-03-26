import 'package:flutter/material.dart';

import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/features/share_records/presentation/bloc/share_records_state.dart';
import 'package:health_wallet/gen/assets.gen.dart';

class ConnectingView extends StatelessWidget {
  final ShareRecordsState state;

  const ConnectingView({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final retryCount = state.connectionRetryCount;
    final isRetrying = retryCount > 0;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 140,
            height: 140,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 140,
                  height: 140,
                  child: CircularProgressIndicator(
                    strokeWidth: 4,
                    color: AppColors.primary.withValues(alpha: 0.3),
                    strokeCap: StrokeCap.round,
                  ),
                ),
                SizedBox(
                  width: 80,
                  height: 80,
                  child: Assets.images.device.svg(
                    colorFilter: const ColorFilter.mode(
                      AppColors.primary,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 48),
          Text(
            isRetrying ? context.l10n.shareRetryingCount(retryCount) : context.l10n.shareConnecting,
            style: AppTextStyle.bodyLarge.copyWith(
              color: context.colorScheme.onSurface,
            ),
          ),
          if (isRetrying) ...[
            const SizedBox(height: 8),
            Text(
              context.l10n.shareConnectionInterrupted,
              style: AppTextStyle.bodySmall.copyWith(
                color: context.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class TransferProgressView extends StatelessWidget {
  final ShareRecordsState state;

  const TransferProgressView({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final progress = state.progressPercentage;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 120,
              height: 120,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 8,
                    ),
                  ),
                  Text(
                    '${(progress * 100).toInt()}%',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Text(
              state.isSending ? context.l10n.shareSendingRecords : context.l10n.shareReceivingRecords,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (state.statusMessage != null) ...[
              const SizedBox(height: 8),
              Text(state.statusMessage!),
            ],
          ],
        ),
      ),
    );
  }
}
