import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_wallet/core/config/constants/ai_model_config.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/services/device_capability_service.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/core/utils/responsive.dart';
import 'package:health_wallet/features/scan/presentation/pages/load_model/bloc/load_model_bloc.dart';
import 'package:health_wallet/gen/assets.gen.dart';

class ModelManagementDialog extends StatefulWidget {
  const ModelManagementDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => const ModelManagementDialog(),
    );
  }

  @override
  State<ModelManagementDialog> createState() => _ModelManagementDialogState();
}

class _ModelManagementDialogState extends State<ModelManagementDialog> {
  late final LoadModelBloc _bloc;

  @override
  void initState() {
    super.initState();
    _bloc = getIt.get<LoadModelBloc>();
    _bloc.add(const LoadModelInitialized());
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = context.borderColor;
    final textColor = context.primaryTextColor;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(Insets.normal),
        child: BlocProvider.value(
          value: _bloc,
          child: BlocBuilder<LoadModelBloc, LoadModelState>(
            builder: (context, state) {
              return Container(
                width: context.dialogWidth,
                decoration: BoxDecoration(
                  color: context.colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor, width: 1),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(Insets.normal),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.memory, size: 22, color: AppColors.primary),
                          const SizedBox(width: Insets.small),
                          Expanded(
                            child: Text(
                              context.l10n.onboardingAiModelTitle,
                              style: AppTextStyle.bodyMedium
                                  .copyWith(color: textColor),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.of(context).pop(),
                            child: Icon(
                              Icons.close,
                              size: 20,
                              color: textColor.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                      if (state.deviceCapability ==
                          DeviceAiCapability.unsupported) ...[
                        const SizedBox(height: Insets.smallNormal),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: Insets.smallNormal,
                            vertical: Insets.small,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppColors.warning.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline,
                                  size: 18, color: AppColors.warning),
                              const SizedBox(width: Insets.small),
                              Flexible(
                                child: Text(
                                  context.l10n
                                      .aiModelNotAvailableForDeviceDescription,
                                  style: AppTextStyle.labelSmall.copyWith(
                                    color: textColor.withOpacity(0.8),
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: Insets.smallNormal),
                      _buildModelCard(
                        context: context,
                        config: AiModelConfig.medGemma,
                        isDownloaded: state.medGemmaDownloaded,
                        isActive:
                            state.selectedVariant == AiModelVariant.medGemma,
                        isDownloading: state.medGemmaDownloading,
                        progress: state.medGemmaProgress,
                        borderColor: borderColor,
                        textColor: textColor,
                        badge: null,
                        incompatible: state.deviceCapability !=
                            DeviceAiCapability.full,
                        incompatibleMessage: state.deviceCapability ==
                                DeviceAiCapability.basicOnly
                            ? context.l10n.medGemmaIncompatibleDevice
                            : null,
                      ),
                      const SizedBox(height: Insets.small),
                      _buildModelCard(
                        context: context,
                        config: AiModelConfig.qwen,
                        isDownloaded: state.qwenDownloaded,
                        isActive:
                            state.selectedVariant == AiModelVariant.qwen,
                        isDownloading: state.qwenDownloading,
                        progress: state.qwenProgress,
                        borderColor: borderColor,
                        textColor: textColor,
                        incompatible: state.deviceCapability ==
                            DeviceAiCapability.unsupported,
                      ),
                      if (state.status == LoadModelStatus.error &&
                          state.errorMessage != null &&
                          state.errorMessage != kNoInternetErrorKey) ...[
                        const SizedBox(height: Insets.small),
                        Text(
                          state.errorMessage!,
                          style: AppTextStyle.labelSmall
                              .copyWith(color: AppColors.error),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildModelCard({
    required BuildContext context,
    required AiModelConfig config,
    required bool isDownloaded,
    required bool isActive,
    required bool isDownloading,
    required double? progress,
    required Color borderColor,
    required Color textColor,
    String? badge,
    bool incompatible = false,
    String? incompatibleMessage,
  }) {
    final isActiveAndLoaded = isActive && isDownloaded;
    final cardBorderColor = incompatible
        ? AppColors.error.withOpacity(0.5)
        : isActiveAndLoaded
            ? AppColors.success
            : borderColor;
    final isTappable =
        isDownloaded && !isActive && !isDownloading && !incompatible;

    return GestureDetector(
      onTap: isTappable
          ? () => _bloc.add(LoadModelVariantSelected(config.variant))
          : null,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(Insets.smallNormal),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: cardBorderColor,
            width: isActiveAndLoaded ? 1.5 : 1,
          ),
        ),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Text(
                      config.displayName,
                      style: AppTextStyle.labelLarge.copyWith(
                        color: textColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (badge != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          badge,
                          style: AppTextStyle.labelSmall.copyWith(
                            color: AppColors.warning,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                    if (isActiveAndLoaded) ...[
                      const SizedBox(width: 8),
                      Icon(Icons.check_circle,
                          size: 16, color: AppColors.success),
                    ],
                  ],
                ),
              ),
              if (isDownloaded && !isDownloading)
                GestureDetector(
                  onTap: () =>
                      _bloc.add(LoadModelDeleteRequested(config.variant)),
                  child: Assets.icons.trashCan.svg(
                    width: 18,
                    height: 18,
                    colorFilter: ColorFilter.mode(
                      AppColors.error.withOpacity(0.7),
                      BlendMode.srcIn,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            config.description,
            style: AppTextStyle.labelSmall.copyWith(
              color: textColor.withOpacity(0.6),
            ),
          ),
          if (incompatible && incompatibleMessage != null) ...[
            const SizedBox(height: Insets.small),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: Insets.small,
                vertical: Insets.extraSmall,
              ),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      size: 14, color: AppColors.error),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      incompatibleMessage,
                      style: AppTextStyle.labelSmall.copyWith(
                        color: AppColors.error,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: Insets.small),
          if (isDownloading) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (progress ?? 0) / 100,
                minHeight: 6,
                backgroundColor: AppColors.primary.withOpacity(0.1),
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${context.l10n.aiModelDownloading} ${progress?.toStringAsFixed(0) ?? 0}%',
              style: AppTextStyle.labelSmall.copyWith(
                color: AppColors.primary,
              ),
            ),
          ] else if (!isDownloaded && !incompatible)
            SizedBox(
              height: 30,
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _bloc.add(LoadModelDownloadInitiated(
                    variant: config.variant)),
                icon: const Icon(Icons.download, size: 14),
                label: const Text('Download'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  textStyle: AppTextStyle.labelSmall,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  elevation: 0,
                ),
              ),
            )
          else if (isActive)
            Text(
              'Active',
              style: AppTextStyle.labelSmall.copyWith(
                color: AppColors.success,
                fontWeight: FontWeight.w600,
              ),
            )
          else if (isDownloaded)
            Text(
              'Tap to select',
              style: AppTextStyle.labelSmall.copyWith(
                color: AppColors.primary,
              ),
            ),
        ],
      ),
      ),
    );
  }
}
