import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/widgets/app_button.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/features/share_records/presentation/bloc/share_records_bloc.dart';
import 'package:health_wallet/features/share_records/presentation/bloc/share_records_event.dart';

class ExtendRequestCard extends StatelessWidget {
  final int durationSeconds;
  final String peerRole;

  const ExtendRequestCard({
    super.key,
    required this.durationSeconds,
    required this.peerRole,
  });

  @override
  Widget build(BuildContext context) {
    final minutes = durationSeconds ~/ 60;
    final label = minutes > 0
        ? context.l10n.shareMinuteCount(minutes)
        : context.l10n.shareSecondsCount(durationSeconds);

    const accentColor = AppColors.primary;

    return Container(
      padding: const EdgeInsets.all(Insets.normal),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.shareExtensionRequestedTitle,
            style: AppTextStyle.titleSmall.copyWith(
              color: context.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            context.l10n.shareExtensionRequestMessage(peerRole, label),
            style: AppTextStyle.bodySmall.copyWith(
              color: context.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: Insets.small),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: context.l10n.shareDecline,
                  onPressed: () {
                    context.read<ShareRecordsBloc>().add(
                          const ShareRecordsEvent.extendRejected(),
                        );
                  },
                  variant: AppButtonVariant.outlined,
                  pillShaped: false,
                  padding: const EdgeInsets.symmetric(
                    horizontal: Insets.normal,
                    vertical: Insets.extraSmall,
                  ),
                  fontSize: AppTextStyle.labelLarge.fontSize,
                ),
              ),
              const SizedBox(width: Insets.small),
              Expanded(
                child: AppButton(
                  label: context.l10n.shareAccept,
                  onPressed: () {
                    context.read<ShareRecordsBloc>().add(
                          ShareRecordsEvent.extendAccepted(durationSeconds),
                        );
                  },
                  variant: AppButtonVariant.primary,
                  backgroundColor: accentColor,
                  pillShaped: false,
                  padding: const EdgeInsets.symmetric(
                    horizontal: Insets.normal,
                    vertical: Insets.extraSmall,
                  ),
                  fontSize: AppTextStyle.labelLarge.fontSize,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
