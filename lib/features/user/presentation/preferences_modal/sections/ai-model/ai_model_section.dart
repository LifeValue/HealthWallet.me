import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/core/widgets/app_button.dart';
import 'package:health_wallet/features/scan/presentation/pages/load_model/bloc/load_model_bloc.dart';
import 'package:health_wallet/features/scan/presentation/widgets/custom_progress_indicator.dart';
import 'package:health_wallet/gen/assets.gen.dart';

class AiModelSection extends StatefulWidget {
  const AiModelSection({super.key});

  @override
  State<AiModelSection> createState() => _AiModelSectionState();
}

class _AiModelSectionState extends State<AiModelSection> {
  late final LoadModelBloc _bloc;

  @override
  void initState() {
    super.initState();
    _bloc = getIt.get<LoadModelBloc>();
    _bloc.add(const LoadModelInitialized());
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = context.theme.dividerColor;

    return BlocProvider.value(
      value: _bloc,
      child: BlocConsumer<LoadModelBloc, LoadModelState>(
        listener: (context, state) {
          if (state.status == LoadModelStatus.error &&
              state.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.errorMessage!)),
            );
          }
        },
        builder: (context, state) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: Insets.normal),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.l10n.onboardingAiModelTitle,
                    style: AppTextStyle.bodySmall),
                const SizedBox(height: Insets.small),
                Container(
                  padding: const EdgeInsets.all(Insets.smallNormal),
                  decoration: BoxDecoration(
                    border: Border.all(color: borderColor),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: Insets.small,
                              vertical: Insets.extraSmall,
                            ),
                            decoration: BoxDecoration(
                              color: _getStatusColor(state.status)
                                  .withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _getStatusIcon(state.status),
                                const SizedBox(width: Insets.extraSmall),
                                Text(
                                  _getModelStatusText(context, state),
                                  style: AppTextStyle.labelSmall.copyWith(
                                    color: _getStatusColor(state.status),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: Insets.normal),
                      Assets.onboarding.onboarding3.svg(
                        width: 140,
                        height: 140,
                      ),
                      const SizedBox(height: Insets.small),
                      Text(
                        context.l10n.onboardingAiModelDescription,
                        textAlign: TextAlign.center,
                        style: AppTextStyle.labelLarge,
                      ),
                      const SizedBox(height: Insets.normal),
                      if (state.status == LoadModelStatus.modelAbsent ||
                          state.status == LoadModelStatus.error)
                        AppButton(
                          label: context.l10n.aiModelEnableDownload,
                          icon: const Icon(Icons.download),
                          variant: AppButtonVariant.primary,
                          onPressed: () =>
                              _bloc.add(const LoadModelDownloadInitiated()),
                        )
                      else if (state.status == LoadModelStatus.loading) ...[
                        CustomProgressIndicator(
                          progress: (state.downloadProgress ?? 0) / 100,
                          text: context.l10n.aiModelDownloading,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Download continues in background',
                          textAlign: TextAlign.center,
                          style: AppTextStyle.labelSmall.copyWith(
                            color: context.colorScheme.onSurface.withOpacity(0.6),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ] else if (state.status == LoadModelStatus.modelLoaded)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.check_circle,
                              size: 20,
                              color: AppColors.success,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              context.l10n.aiModelReady,
                              textAlign: TextAlign.center,
                              style: AppTextStyle.labelLarge.copyWith(
                                color: AppColors.success,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Color _getStatusColor(LoadModelStatus status) {
    switch (status) {
      case LoadModelStatus.modelLoaded:
        return AppColors.success;
      case LoadModelStatus.modelAbsent:
        return AppColors.primary;
      case LoadModelStatus.loading:
        return AppColors.primary;
      case LoadModelStatus.error:
        return AppColors.error;
    }
  }

  Widget _getStatusIcon(LoadModelStatus status) {
    switch (status) {
      case LoadModelStatus.modelLoaded:
        return Icon(
          Icons.check_circle,
          size: 14,
          color: AppColors.success,
        );
      case LoadModelStatus.modelAbsent:
        return Assets.icons.download.svg(
          width: 14,
          height: 14,
          colorFilter: const ColorFilter.mode(
            AppColors.primary,
            BlendMode.srcIn,
          ),
        );
      case LoadModelStatus.loading:
        return SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.primary,
          ),
        );
      case LoadModelStatus.error:
        return Icon(
          Icons.error_outline,
          size: 14,
          color: AppColors.error,
        );
    }
  }

  String _getModelStatusText(BuildContext context, LoadModelState state) {
    switch (state.status) {
      case LoadModelStatus.modelLoaded:
        return context.l10n.aiModelReady;
      case LoadModelStatus.modelAbsent:
        return context.l10n.aiModelMissing;
      case LoadModelStatus.loading:
        final progress = state.downloadProgress?.toStringAsFixed(0) ?? '0';
        return '${context.l10n.aiModelDownloading} $progress%';
      case LoadModelStatus.error:
        return context.l10n.aiModelError;
    }
  }
}
