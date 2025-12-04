import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/core/widgets/dialogs/confirmation_dialog.dart';
import 'package:health_wallet/features/sync/presentation/bloc/sync_bloc.dart';
import 'package:health_wallet/gen/assets.gen.dart';

class SyncLoadingWidget extends StatelessWidget {
  final VoidCallback? onCancel;
  final String? cancelButtonText;

  const SyncLoadingWidget({
    super.key,
    this.onCancel,
    this.cancelButtonText,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(0),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 140,
            child: Center(
              child: Assets.images.syncScanIlustration.svg(width: 140),
            ),
          ),
          const SizedBox(height: Insets.medium),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Insets.normal),
            child: Column(
              children: [
                SizedBox(
                  width: 48,
                  height: 48,
                  child: CircularProgressIndicator(
                    strokeWidth: 8,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      context.isDarkMode ? Colors.white : Color(0xFF1E1E1E),
                    ),
                    strokeCap: StrokeCap.round,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  context.l10n.syncingData,
                  style: AppTextStyle.bodyMedium.copyWith(
                    fontWeight: FontWeight.w500,
                    letterSpacing: -0.14,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  context.l10n.syncingMessage,
                  style: AppTextStyle.labelLarge.copyWith(
                    fontWeight: FontWeight.w400,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.all(Insets.normal),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => _showCancelConfirmation(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: context.isDarkMode
                      ? Colors.white
                      : context.colorScheme.primary,
                  side: BorderSide(color: context.colorScheme.primary),
                  padding: const EdgeInsets.all(10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  cancelButtonText ?? context.l10n.cancel,
                  style: AppTextStyle.buttonSmall
                      .copyWith(color: context.colorScheme.primary),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCancelConfirmation(BuildContext context) {
    ConfirmationDialog.show(
      context: context,
      title: context.l10n.cancelSyncTitle,
      message: context.l10n.cancelSyncMessage,
      confirmText: context.l10n.yesCancel,
      cancelText: context.l10n.continueSync,
      onConfirm: () {
        // Cancel the sync operation
        context.read<SyncBloc>().add(const SyncCancel());
        onCancel?.call();
      },
    );
  }
}
