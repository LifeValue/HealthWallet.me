import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/l10n/l10n.dart';
import 'package:health_wallet/core/navigation/app_router.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/core/widgets/app_snack_bar.dart';
import 'package:health_wallet/core/widgets/dialogs/app_simple_dialog.dart';
import 'package:health_wallet/features/desktop/communication/data/models/device_pairing.dart';
import 'package:health_wallet/features/desktop/communication/presentation/bloc/communication_bloc.dart';
import 'package:health_wallet/features/desktop/lww_sync/presentation/bloc/lww_sync_bloc.dart';
import 'package:health_wallet/features/sync/presentation/bloc/sync_bloc.dart';
import 'package:health_wallet/features/sync/presentation/widgets/qr_scanner_widget.dart';
import 'package:health_wallet/features/sync/presentation/widgets/sync_loading_widget.dart';
import 'package:health_wallet/features/sync/presentation/widgets/sync_placeholder_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

@RoutePage()
class SyncPage extends StatefulWidget {
  const SyncPage({super.key});

  @override
  State<SyncPage> createState() => _SyncPageState();
}

class _SyncPageState extends State<SyncPage> {
  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: getIt<CommunicationBloc>()),
        BlocProvider.value(value: getIt<LwwSyncBloc>()),
      ],
      child: BlocListener<SyncBloc, SyncState>(
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
            title: Text(
              context.l10n.syncTitle,
              style: AppTextStyle.titleMedium,
            ),
            backgroundColor: context.colorScheme.surface,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
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
            child: _buildBody(context),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    return BlocBuilder<SyncBloc, SyncState>(
      builder: (context, syncState) {
        if (syncState.isQRScanning) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: QRScannerWidget(
              onQRCodeDetected: (qrData) {
                _handleQRCodeDetected(context, qrData);
              },
              onCancel: () {
                context.read<SyncBloc>().add(const SyncCancel());
              },
            ),
          );
        }

        if (syncState.syncStatus == SyncStatus.syncing && syncState.isLoading) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: SyncLoadingWidget(
              onCancel: () {
                context.read<SyncBloc>().add(const SyncCancel());
              },
            ),
          );
        }

        return const SyncPlaceholderWidget(
          onSyncPressed: null,
          recordTypeName: null,
        );
      },
    );
  }

  void _handleQRCodeDetected(BuildContext context, String qrData) {
    final messenger = ScaffoldMessenger.of(context);
    void tell(String message, {AppSnackBarType type = AppSnackBarType.error}) =>
        AppSnackBar.showOn(messenger, message: message, type: type);

    switch (DevicePairing.parseQr(qrData)) {
      case ValidPairingQr(:final pairing):
        context.read<SyncBloc>().add(const SyncCancel());
        tell(
          context.l10n.pairedWithDevice(pairing.deviceName),
          type: AppSnackBarType.success,
        );
        getIt<CommunicationBloc>().add(
          CommunicationPairingCompleted(pairing: pairing),
        );
      case OutdatedPairingQr():
        tell(context.l10n.desktopQrOutdated);
      case InvalidPairingQr():
        tell(context.l10n.desktopQrInvalid);
      case NotPairingQr():
        context.read<SyncBloc>().add(SyncData(qrData: qrData));
    }
  }

  Future<void> _handleSyncCompletion(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final onboardingShown = prefs.getBool('onboarding_shown') ?? false;
    if (!context.mounted) return;

    await AppSimpleDialog.showSuccess(
      context: context,
      title: context.l10n.success,
      message: context.l10n.syncDataLoadedSuccessfully,
      onOkPressed: () {
        context.router.pushAndPopUntil(
          const DashboardRoute(),
          predicate: (_) => false,
        );

        if (!onboardingShown) {
          Future.delayed(const Duration(milliseconds: 400), () {
            if (!context.mounted) return;
            try {
              context.read<SyncBloc>().add(const TriggerTutorial());
            } catch (_) {
              // The page was closed before the delay ended; skip the tutorial.
            }
          });
        }
      },
    );
  }
}
