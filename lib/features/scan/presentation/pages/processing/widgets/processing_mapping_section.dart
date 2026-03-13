import 'package:flutter/material.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/core/widgets/app_button.dart';
import 'package:health_wallet/features/scan/domain/entity/processing_session.dart';
import 'package:health_wallet/features/scan/domain/repository/scan_repository.dart';
import 'package:health_wallet/features/scan/presentation/bloc/scan_bloc.dart';
import 'package:health_wallet/features/scan/presentation/widgets/custom_progress_indicator.dart';
import 'package:health_wallet/gen/assets.gen.dart';
import 'package:auto_route/auto_route.dart';
import 'package:health_wallet/core/navigation/app_router.dart';

class ProcessingMappingSection extends StatelessWidget {
  final ScanState state;
  final ProcessingSession displayedSession;
  final String sessionId;
  final VoidCallback onShowAiSettings;
  final VoidCallback onRetryStep1;
  final VoidCallback onRetryStep2;
  final VoidCallback onCancel;

  const ProcessingMappingSection({
    required this.state,
    required this.displayedSession,
    required this.sessionId,
    required this.onShowAiSettings,
    required this.onRetryStep1,
    required this.onRetryStep2,
    required this.onCancel,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (state.status is CapacityFailure) {
      return _buildCapacityFailure(context);
    }

    if (state.status is Failure) {
      final error = (state.status as Failure).error;
      return _buildFailure(context, error);
    }

    if (displayedSession.status == ProcessingStatus.cancelled) {
      return _buildCancelled(context);
    }

    if (displayedSession.isProcessing) {
      return _buildProcessing(context);
    }

    if (displayedSession.status == ProcessingStatus.pending) {
      return _QueuedMessage();
    }

    return const SizedBox.shrink();
  }

  Widget _buildFailure(BuildContext context, String error) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(Insets.normal),
          decoration: BoxDecoration(
            color: context.colorScheme.errorContainer.withOpacity(0.3),
            borderRadius: BorderRadius.circular(8),
            border:
                Border.all(color: context.colorScheme.error.withOpacity(0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: context.colorScheme.error,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    context.l10n.processingFailed,
                    style: AppTextStyle.bodyMedium.copyWith(
                      color: context.colorScheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                error,
                style: AppTextStyle.bodySmall.copyWith(
                  color: context.colorScheme.onErrorContainer,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Insets.normal),
        if (displayedSession.status != ProcessingStatus.patientExtracted)
          AppButton(
            label: context.l10n.retry,
            variant: AppButtonVariant.outlined,
            onPressed: onRetryStep1,
          ),
      ],
    );
  }

  Widget _buildCancelled(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(Insets.normal),
          decoration: BoxDecoration(
            color:
                context.colorScheme.surfaceContainerHighest.withOpacity(0.5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: context.colorScheme.outline.withOpacity(0.5)),
          ),
          child: Row(
            children: [
              Icon(
                Icons.cancel_outlined,
                color: context.colorScheme.onSurfaceVariant,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                context.l10n.processingCancelled,
                style: AppTextStyle.bodyMedium.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Insets.normal),
        AppButton(
          label: context.l10n.retry,
          variant: AppButtonVariant.outlined,
          onPressed: onRetryStep1,
        ),
      ],
    );
  }

  Widget _buildProcessing(BuildContext context) {
    return Column(
      children: [
        CustomProgressIndicator(
          progress: displayedSession.progress,
          text: displayedSession.status == ProcessingStatus.processingPatient
              ? context.l10n.processingBasicDetails
              : context.l10n.processingPages,
          secondaryText:
              displayedSession.status == ProcessingStatus.processingPatient
                  ? context.l10n.extractingPatientInfo
                  : context.l10n.pleaseWait,
          showProgressBar:
              displayedSession.status == ProcessingStatus.processing &&
                  state.useVision,
        ),
        const SizedBox(height: Insets.normal),
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: context.l10n.cancel,
                variant: AppButtonVariant.outlined,
                onPressed: onCancel,
              ),
            ),
            const SizedBox(width: Insets.smallNormal),
            Expanded(
              child: AppButton(
                label: context.l10n.focusMode,
                icon: Assets.icons.scan.svg(),
                variant: AppButtonVariant.primary,
                onPressed: () {
                  context.router.push(const FocusModeRoute());
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCapacityFailure(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(Insets.normal),
          decoration: BoxDecoration(
            color: context.colorScheme.errorContainer.withOpacity(0.3),
            borderRadius: BorderRadius.circular(8),
            border:
                Border.all(color: context.colorScheme.error.withOpacity(0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.memory,
                    color: context.colorScheme.error,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    context.l10n.processingFailed,
                    style: AppTextStyle.bodyMedium.copyWith(
                      color: context.colorScheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.processingFailedCapacity,
                style: AppTextStyle.bodySmall.copyWith(
                  color: context.colorScheme.onErrorContainer,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                context.l10n.processingFailedCapacitySuggestion,
                style: AppTextStyle.labelSmall.copyWith(
                  color: context.colorScheme.onErrorContainer.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Insets.normal),
        AppButton(
          label: context.l10n.increaseAiModelCapacity,
          variant: AppButtonVariant.primary,
          onPressed: onShowAiSettings,
        ),
        const SizedBox(height: Insets.small),
        AppButton(
          label: context.l10n.goBack,
          variant: AppButtonVariant.transparent,
          onPressed: () => context.router.maybePop(),
        ),
      ],
    );
  }
}

class _QueuedMessage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: getIt<ScanRepository>().checkModelExistence(),
      builder: (context, asyncSnapshot) {
        if (!asyncSnapshot.hasData) return const SizedBox();
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.hourglass_empty,
                color: context.colorScheme.primary, size: 20),
            const SizedBox(width: 8),
            Text(
              asyncSnapshot.data!
                  ? context.l10n.onlyOneSessionAtTime
                  : context.l10n.aiModelNotAvailable,
              style: AppTextStyle.bodyMedium.copyWith(
                color: context.colorScheme.primary,
              ),
            )
          ],
        );
      },
    );
  }
}
