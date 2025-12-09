import 'dart:convert';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/core/utils/date_format_utils.dart';
import 'package:health_wallet/core/widgets/dialogs/success_dialog.dart';
import 'package:health_wallet/features/sync/domain/entities/sync_qr_data.dart';
import 'package:health_wallet/features/sync/presentation/bloc/sync_bloc.dart';
import 'package:health_wallet/features/sync/presentation/widgets/qr_scanner_widget.dart';
import 'package:health_wallet/features/sync/presentation/widgets/sync_loading_widget.dart';
import 'package:health_wallet/core/navigation/app_router.dart';
import 'package:health_wallet/gen/assets.gen.dart';
import 'package:shared_preferences/shared_preferences.dart';

@RoutePage()
class SyncPage extends StatefulWidget {
  const SyncPage({super.key});

  @override
  State<SyncPage> createState() => _SyncPageState();
}

class _SyncPageState extends State<SyncPage> {
  final TextEditingController _manualCodeController = TextEditingController();

  @override
  void initState() {
    context.read<SyncBloc>().add(const SyncInitialised());
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<SyncBloc, SyncState>(
      listenWhen: (previous, current) {
        return current.syncDialogShown && !previous.syncDialogShown;
      },
      listener: (context, state) {
        if (state.syncDialogShown) {
          _handleSyncCompletion(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Sync',
            style: AppTextStyle.titleMedium,
          ),
          backgroundColor: context.colorScheme.inversePrimary,
          centerTitle: false,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              context.router.pop();
            },
          ),
        ),
        body: GestureDetector(
          onTap: () {
            FocusScope.of(context).unfocus();
          },
          child: _buildQRCodeTab(context),
        ),
      ),
    );
  }

  Widget _buildQRCodeTab(BuildContext context) {
    return BlocBuilder<SyncBloc, SyncState>(
      builder: (context, state) {
        if (state.isQRScanning) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: QRScannerWidget(
              cancelButtonText: 'Cancel',
              onQRCodeDetected: (qrData) {
                context.read<SyncBloc>().add(SyncData(qrData: qrData));
              },
              onCancel: () {
                context.read<SyncBloc>().add(const SyncCancel());
              },
            ),
          );
        }

        if (state.syncStatus == SyncStatus.syncing && state.isLoading) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: SyncLoadingWidget(
              onCancel: () {
                context.read<SyncBloc>().add(const SyncCancel());
              },
              cancelButtonText: 'Cancel',
            ),
          );
        }

        if (state.syncStatus == SyncStatus.synced) {
          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Assets.images.syncScanIlustration.svg(width: 140),
                  const SizedBox(height: 12),
                  _buildQRConfigCard(context, state),
                  const SizedBox(height: 12),
                  if (state.errorMessage != null)
                    _buildResultCard(
                        context, state.errorMessage!, AppColors.error)
                  else if (state.successMessage != null)
                    _buildResultCard(
                        context, state.successMessage!, AppColors.success),
                  _buildQRActionButtons(context, state),
                ],
              ),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: _buildQRScannerSection(context, state),
        );
      },
    );
  }

  Widget _buildQRScannerSection(BuildContext context, SyncState state) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Assets.images.syncScanIlustration.svg(width: 140),
          const SizedBox(height: Insets.small),
          const Text(
            'Scan QR Code',
            style: AppTextStyle.buttonMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          const Text(
            'Scan a QR code from your Fasten server to establish a secure connection.',
            style: AppTextStyle.labelLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                context.read<SyncBloc>().add(const SyncScanQRCode());
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: context.colorScheme.primary,
                foregroundColor: context.isDarkMode
                    ? Colors.white
                    : context.colorScheme.onPrimary,
                padding: const EdgeInsets.all(12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Assets.icons.qrCode.svg(width: 16),
                  const SizedBox(width: 8),
                  Text(
                    context.l10n.scanCode,
                    style: AppTextStyle.buttonSmall,
                  )
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Text(context.l10n.or, style: AppTextStyle.labelLarge),
          ),
          Text(
            context.l10n.manualSyncMessage,
            style: AppTextStyle.labelLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          TextField(
            maxLines: 3,
            style: AppTextStyle.labelLarge,
            controller: _manualCodeController,
            decoration: InputDecoration(
              hintText: context.l10n.pasteSyncDataHint,
              hintStyle: AppTextStyle.labelLarge.copyWith(
                  color: context.isDarkMode
                      ? Colors.white
                      : AppColors.textPrimary.withValues(alpha: 0.6)),
              disabledBorder: OutlineInputBorder(
                borderSide: BorderSide(
                    color: context.isDarkMode
                        ? Colors.white
                        : AppColors.textPrimary.withValues(alpha: 0.2)),
                borderRadius: BorderRadius.circular(8),
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(
                    color: context.isDarkMode
                        ? Colors.white
                        : AppColors.textPrimary.withValues(alpha: 0.2)),
                borderRadius: BorderRadius.circular(8),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(
                    color: context.isDarkMode
                        ? Colors.white
                        : AppColors.textPrimary.withValues(alpha: 0.2)),
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 9, horizontal: 12),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: state.isLoading
                  ? null
                  : () => context
                      .read<SyncBloc>()
                      .add(SyncData(qrData: _manualCodeController.text)),
              style: OutlinedButton.styleFrom(
                foregroundColor: context.isDarkMode
                    ? Colors.white
                    : context.colorScheme.primary,
                side: BorderSide(color: context.colorScheme.primary),
                padding: const EdgeInsets.all(12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: state.isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : Text(context.l10n.connect,
                      style: AppTextStyle.buttonSmall
                          .copyWith(color: context.colorScheme.primary)),
            ),
          ),
          const SizedBox(height: 12),
          if (state.errorMessage != null)
            _buildResultCard(context, state.errorMessage!, AppColors.error)
        ],
      ),
    );
  }

  Widget _buildQRConfigCard(BuildContext context, SyncState state) {
    DateTime lastSyncTime = DateTime.parse(state.lastSyncTime!);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Server connection',
              style: AppTextStyle.bodyMedium,
            ),
            const SizedBox(height: 8),
            _buildDetailRow(
                context, 'Server', state.syncQrData!.serverBaseUrls.first),
            _buildDetailRow(context, 'Expires',
                state.syncQrData?.tokenMeta.formattedExpiration ?? ''),
            _buildDetailRow(context, 'Last synced',
                DateFormatUtils.getSincePretty(lastSyncTime))
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: AppTextStyle.labelLarge,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTextStyle.labelLarge,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard(BuildContext context, String message, Color color) {
    return Column(
      children: [
        Card(
          color: color.withValues(alpha: 0.1),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
            child: Row(
              children: [
                Icon(
                  Icons.error_outline,
                  color: color,
                  size: 16,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: AppTextStyle.buttonSmall.copyWith(color: color),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildQRActionButtons(BuildContext context, SyncState state) {
    return Column(
      children: [
        if (!(state.syncQrData?.tokenMeta.isExpired ?? true)) ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                String qrData = jsonEncode(state.syncQrData!.toJson());
                context.read<SyncBloc>().add(SyncData(qrData: qrData));
              },
              icon: state.isLoading
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          context.colorScheme.onPrimary,
                        ),
                      ),
                    )
                  : Assets.icons.renewSync.svg(width: 16),
              label: Text(
                state.isLoading ? 'Syncing...' : 'Sync Data',
                style: AppTextStyle.buttonSmall,
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 10),
                backgroundColor: context.colorScheme.primary,
                foregroundColor: context.isDarkMode
                    ? Colors.white
                    : context.colorScheme.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 4),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              context.read<SyncBloc>().add(const SyncScanNewPressed());
            },
            icon: Icon(Icons.refresh, color: context.colorScheme.primary),
            label: Text(context.l10n.scanNewQRCode,
                style: AppTextStyle.buttonSmall
                    .copyWith(color: context.colorScheme.primary)),
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
          ),
        ),
      ],
    );
  }

  Future<void> _handleSyncCompletion(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final onboardingShown = prefs.getBool('onboarding_shown') ?? false;

    await SuccessDialog.show(
      context: context,
      title: context.l10n.success,
      message: context.l10n.syncDataLoadedSuccessfully,
      onOkPressed: () {
        // Navigate to home first
        context.router.pushAndPopUntil(
          DashboardRoute(),
          predicate: (_) => false,
        );

        // Trigger tutorial if not shown before
        if (!onboardingShown) {
          Future.delayed(const Duration(milliseconds: 400), () {
            try {
              context.read<SyncBloc>().add(const TriggerTutorial());
            } catch (e) {
              // Handle any errors silently
            }
          });
        }
      },
    );
  }
}
