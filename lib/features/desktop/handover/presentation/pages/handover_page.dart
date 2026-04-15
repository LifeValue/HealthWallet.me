import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/features/desktop/handover/domain/entity/handover_session.dart';
import 'package:health_wallet/features/desktop/handover/presentation/bloc/handover_bloc.dart';
import 'package:health_wallet/features/processing/domain/entity/processing_session.dart';
import 'package:health_wallet/features/processing/presentation/bloc/processing_bloc.dart';
import 'package:health_wallet/features/processing/presentation/widgets/session_list.dart';
import 'package:health_wallet/gen/assets.gen.dart';

class HandoverPage extends StatelessWidget {
  const HandoverPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: getIt<HandoverBloc>()),
        BlocProvider.value(value: getIt<ProcessingBloc>()),
      ],
      child: BlocBuilder<HandoverBloc, HandoverState>(
        builder: (context, handoverState) {
          return BlocBuilder<ProcessingBloc, ProcessingState>(
            builder: (context, processingState) {
              final transferSessions = handoverState.activeSessions.values
                  .where((s) =>
                      s.status == HandoverStatus.receiving)
                  .toList();
              final processingSessions = processingState.sessions
                  .where((s) => s.origin == ProcessingOrigin.handover)
                  .toList();
              final hasContent =
                  transferSessions.isNotEmpty || processingSessions.isNotEmpty;

              return Padding(
                padding: const EdgeInsets.all(Insets.medium),
                child: hasContent
                    ? SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (transferSessions.isNotEmpty) ...[
                              Text(
                                'Transfer',
                                style: AppTextStyle.labelSmall.copyWith(
                                  color: context.colorScheme.onSurface
                                      .withValues(alpha: 0.4),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: Insets.small),
                              ...transferSessions.map(
                                (s) => Padding(
                                  padding: const EdgeInsets.only(
                                      bottom: Insets.small),
                                  child:
                                      _HandoverTransferCard(session: s),
                                ),
                              ),
                            ],
                            if (processingSessions.isNotEmpty) ...[
                              if (transferSessions.isNotEmpty)
                                const SizedBox(height: Insets.normal),
                              Text(
                                'Processing',
                                style: AppTextStyle.labelSmall.copyWith(
                                  color: context.colorScheme.onSurface
                                      .withValues(alpha: 0.4),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: Insets.small),
                              SessionList(sessions: processingSessions),
                            ],
                          ],
                        ),
                      )
                    : _HandoverEmptyState(),
              );
            },
          );
        },
      ),
    );
  }
}

class _HandoverEmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Assets.images.syncIlustration.svg(
            width: 120,
            height: 120,
          ),
          const SizedBox(height: Insets.medium),
          Text(
            'No active handovers',
            style: AppTextStyle.titleSmall.copyWith(
              color: context.primaryTextColor,
            ),
          ),
          const SizedBox(height: Insets.small),
          Text(
            'Send documents from your phone.',
            style: AppTextStyle.bodyMedium.copyWith(
              color: context.secondaryTextColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _HandoverTransferCard extends StatelessWidget {
  final HandoverSession session;

  const _HandoverTransferCard({required this.session});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Insets.normal),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _StatusIcon(status: session.status),
              const SizedBox(width: Insets.smallNormal),
              Expanded(
                child: Text(
                  _statusLabel(session.status),
                  style: AppTextStyle.bodyMedium.copyWith(
                    color: context.primaryTextColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (session.fileCount > 0)
                Text(
                  '${session.receivedCount}/${session.fileCount} files',
                  style: AppTextStyle.labelSmall.copyWith(
                    color: context.secondaryTextColor,
                  ),
                ),
            ],
          ),
          if (session.status != HandoverStatus.complete) ...[
            const SizedBox(height: Insets.smallNormal),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: session.progress,
                minHeight: 4,
                backgroundColor: context.borderColor,
                valueColor: AlwaysStoppedAnimation<Color>(
                  session.status == HandoverStatus.error
                      ? AppColors.error
                      : AppColors.primary,
                ),
              ),
            ),
          ],
          if (session.status == HandoverStatus.complete) ...[
            const SizedBox(height: Insets.small),
            Row(
              children: [
                Icon(Icons.check_circle, size: 16, color: AppColors.success),
                const SizedBox(width: Insets.extraSmall),
                Text(
                  'Transfer complete',
                  style:
                      AppTextStyle.labelSmall.copyWith(color: AppColors.success),
                ),
              ],
            ),
          ],
          if (session.error != null) ...[
            const SizedBox(height: Insets.small),
            Text(
              session.error!,
              style: AppTextStyle.labelSmall.copyWith(color: AppColors.error),
            ),
          ],
        ],
      ),
    );
  }

  String _statusLabel(HandoverStatus status) {
    switch (status) {
      case HandoverStatus.receiving:
        return 'Receiving files...';
      case HandoverStatus.processing:
        return 'Processing...';
      case HandoverStatus.sendingResults:
        return 'Sending results...';
      case HandoverStatus.complete:
        return 'Complete';
      case HandoverStatus.error:
        return 'Error';
      case HandoverStatus.sending:
        return 'Sending...';
      case HandoverStatus.waitingForResults:
        return 'Waiting for results...';
    }
  }
}

class _StatusIcon extends StatelessWidget {
  final HandoverStatus status;

  const _StatusIcon({required this.status});

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case HandoverStatus.complete:
        return Icon(Icons.check_circle, size: 24, color: AppColors.success);
      case HandoverStatus.error:
        return Icon(Icons.error, size: 24, color: AppColors.error);
      default:
        return SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        );
    }
  }
}
