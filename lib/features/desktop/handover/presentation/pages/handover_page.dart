import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/l10n/display_names.dart';
import 'package:health_wallet/core/l10n/l10n.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/core/utils/responsive.dart';
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
              final transferSessions = handoverState.transfers.values.toList();
              final processingSessions = processingState.sessions
                  .where((s) => s.origin == ProcessingOrigin.handover)
                  .toList();
              final hasContent =
                  transferSessions.isNotEmpty || processingSessions.isNotEmpty;

              return Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: context.contentMaxWidth,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(Insets.medium),
                    child: hasContent
                        ? SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (transferSessions.isNotEmpty) ...[
                                  Text(
                                    context.l10n.desktopHandoverTransfer,
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
                                        bottom: Insets.small,
                                      ),
                                      child: _HandoverTransferCard(session: s),
                                    ),
                                  ),
                                ],
                                if (processingSessions.isNotEmpty) ...[
                                  if (transferSessions.isNotEmpty)
                                    const SizedBox(height: Insets.normal),
                                  Text(
                                    context.l10n.processing,
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
                  ),
                ),
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
            context.l10n.desktopHandoverNoActive,
            style: AppTextStyle.titleSmall.copyWith(
              color: context.primaryTextColor,
            ),
          ),
          const SizedBox(height: Insets.small),
          Text(
            context.l10n.desktopHandoverSendFromPhone,
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
        borderRadius: BorderRadius.circular(Insets.smallNormal),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(
                width: Insets.medium,
                height: Insets.medium,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),
              const SizedBox(width: Insets.smallNormal),
              Expanded(
                child: Text(
                  session.status.localizedLabel(context.l10n),
                  style: AppTextStyle.bodyMedium.copyWith(
                    color: context.primaryTextColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Text(
                context.l10n.desktopHandoverFilesProgress(
                  '${session.receivedCount}',
                  '${session.fileCount}',
                ),
                style: AppTextStyle.labelSmall.copyWith(
                  color: context.secondaryTextColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: Insets.smallNormal),
          ClipRRect(
            borderRadius: BorderRadius.circular(Insets.extraSmall),
            child: LinearProgressIndicator(
              value: session.progress,
              minHeight: Insets.extraSmall,
              backgroundColor: context.borderColor,
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
