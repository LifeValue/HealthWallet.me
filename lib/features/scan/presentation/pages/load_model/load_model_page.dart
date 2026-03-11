import 'dart:ui';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/core/services/device_capability_service.dart';
import 'package:health_wallet/features/scan/presentation/pages/load_model/bloc/load_model_bloc.dart';
import 'package:health_wallet/features/scan/presentation/widgets/custom_progress_indicator.dart';
import 'package:health_wallet/features/scan/presentation/widgets/dialog_helper.dart';
import 'package:health_wallet/features/scan/presentation/widgets/model_management_dialog.dart';
import 'package:health_wallet/gen/assets.gen.dart';

@RoutePage<bool>()
class LoadModelPage extends StatefulWidget {
  const LoadModelPage({this.canAttachToEncounter = false, super.key});

  final bool canAttachToEncounter;

  @override
  State<LoadModelPage> createState() => _LoadModelPageState();
}

class _LoadModelPageState extends State<LoadModelPage> {
  late final LoadModelBloc _bloc;

  @override
  void initState() {
    super.initState();
    _bloc = getIt.get<LoadModelBloc>();
    _bloc.add(const LoadModelInitialized());
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
      child: BlocConsumer<LoadModelBloc, LoadModelState>(
        listenWhen: (previous, current) => previous.status != current.status,
        listener: (context, state) {
          if (state.status == LoadModelStatus.modelLoaded) {
            context.router.maybePop(true);
          }
          if (state.status == LoadModelStatus.error &&
              state.errorMessage != null) {
            if (state.errorMessage == kNoInternetErrorKey) {
              _showNoInternetDialog(context);
            } else {
              DialogHelper.showErrorDialog(context, state.errorMessage!);
            }
          }
        },
        builder: (context, state) {
          return Scaffold(
            appBar: AppBar(
              title: Text(
                context.l10n.aiModelTitle,
                style: AppTextStyle.titleMedium,
              ),
              automaticallyImplyLeading: true,
            ),
            body: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildView(context, state),
            ),
          );
        },
      ),
    );
  }

  void _showNoInternetDialog(BuildContext context) {
    final textColor =
        context.isDarkMode ? AppColors.textPrimaryDark : AppColors.textPrimary;
    final borderColor =
        context.isDarkMode ? AppColors.borderDark : AppColors.border;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(Insets.normal),
          child: Container(
            width: 350,
            decoration: BoxDecoration(
              color: context.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor, width: 1),
            ),
            child: Padding(
              padding: const EdgeInsets.all(Insets.normal),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.wifi_off,
                    size: 40,
                    color: context.colorScheme.error,
                  ),
                  const SizedBox(height: Insets.smallNormal),
                  Text(
                    context.l10n.noInternetConnectionTitle,
                    style: AppTextStyle.bodyMedium.copyWith(color: textColor),
                  ),
                  const SizedBox(height: Insets.small),
                  Text(
                    context.l10n.noInternetConnectionDescription,
                    textAlign: TextAlign.center,
                    style: AppTextStyle.labelLarge.copyWith(color: textColor),
                  ),
                  const SizedBox(height: Insets.normal),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(8),
                        fixedSize: const Size.fromHeight(36),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        context.l10n.ok,
                        style: AppTextStyle.buttonSmall.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildView(BuildContext context, LoadModelState state) {
    if (state.status == LoadModelStatus.loading &&
        state.downloadProgress == null &&
        !state.isBackgroundDownload) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        const SizedBox(height: 20),
        Assets.onboarding.onboarding3.svg(height: 250),
        Text(
          context.l10n.aiModelUnlockTitle,
          textAlign: TextAlign.center,
          style: AppTextStyle.titleLarge.copyWith(
            color: context.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 32),
        Text(
          context.l10n.aiModelUnlockDescription,
          textAlign: TextAlign.center,
          style: AppTextStyle.bodySmall.copyWith(
            color: context.colorScheme.onSurface.withOpacity(0.7),
            height: 1.5,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 32),
        Text(
          context.l10n.aiModelDownloadInfo,
          textAlign: TextAlign.center,
          style: AppTextStyle.bodySmall.copyWith(
            color: context.colorScheme.onSurface.withOpacity(0.7),
            height: 1.5,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 24),
        if (state.status == LoadModelStatus.loading) ...[
          CustomProgressIndicator(
            progress: (state.downloadProgress ?? 0) / 100,
            text: context.l10n.aiModelDownloading,
          ),
          const SizedBox(height: 16),
          Text(
            'You can navigate away - download will continue in background.\nCheck notifications for progress.',
            textAlign: TextAlign.center,
            style: AppTextStyle.bodySmall.copyWith(
              color: context.colorScheme.primary,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => context.router.maybePop(),
              child: Text(
                widget.canAttachToEncounter
                    ? 'Continue without AI (download in background)'
                    : 'Continue using app',
              ),
            ),
          ),
        ] else ...[
          if (state.deviceCapability == DeviceAiCapability.unsupported) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: context.colorScheme.errorContainer.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: context.colorScheme.error.withOpacity(0.5),
                ),
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
                      Flexible(
                        child: Text(
                          context.l10n.aiModelNotAvailableForDevice,
                          style: AppTextStyle.bodySmall.copyWith(
                            color: context.colorScheme.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.only(left: 28),
                    child: Text(
                      context.l10n.aiModelNotAvailableForDeviceDescription,
                      style: AppTextStyle.labelSmall.copyWith(
                        color: context.colorScheme.error.withOpacity(0.8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.colorScheme.primary,
                  foregroundColor: context.isDarkMode
                      ? Colors.white
                      : context.colorScheme.onPrimary,
                  padding: const EdgeInsets.all(8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadiusGeometry.circular(8)),
                ),
                onPressed: () => ModelManagementDialog.show(context),
                child: Text(context.l10n.aiModelEnableDownload),
              ),
            ),
          ],
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => context.router.maybePop(false),
              child: Text(widget.canAttachToEncounter
                  ? 'I want to attach the document without processing'
                  : context.l10n.cancel),
            ),
          ),
        ],
      ],
    );
  }
}
