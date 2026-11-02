import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:health_wallet/core/config/app_platform.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/l10n/l10n.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/core/utils/responsive.dart';
import 'package:health_wallet/core/widgets/app_button.dart';
import 'package:health_wallet/core/widgets/app_snack_bar.dart';
import 'package:health_wallet/features/desktop/communication/data/models/device_pairing.dart';
import 'package:health_wallet/features/desktop/communication/presentation/bloc/communication_bloc.dart';
import 'package:health_wallet/features/desktop/presentation/widgets/info_row.dart';
import 'package:health_wallet/features/desktop/presentation/widgets/vpn_notice.dart';
import 'package:health_wallet/features/sync/presentation/bloc/sync_bloc.dart';
import 'package:health_wallet/features/sync/presentation/widgets/qr_scanner_widget.dart';
import 'package:qr_flutter/qr_flutter.dart';

class ConnectionDialog extends StatefulWidget {
  static void openQRScanner(BuildContext context) {
    final rootNavigator = Navigator.of(context, rootNavigator: true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;

    rootNavigator.push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => _FullScreenQRScanner(
          onQRCodeDetected: (qrData) => handleScannedCode(
            navigator: rootNavigator,
            messenger: scaffoldMessenger,
            l10n: l10n,
            qrData: qrData,
          ),
        ),
      ),
    );
  }

  /// A code from the scanner: a desktop's pairing code is checked and handed
  /// to the [CommunicationBloc]; anything else goes to the Fasten sync.
  static void handleScannedCode({
    required NavigatorState navigator,
    required ScaffoldMessengerState messenger,
    required AppLocalizations l10n,
    required String qrData,
  }) {
    void tell(String message, {AppSnackBarType type = AppSnackBarType.error}) =>
        AppSnackBar.showOn(messenger, message: message, type: type);

    switch (DevicePairing.parseQr(qrData)) {
      case ValidPairingQr(:final pairing):
        navigator.pop();
        tell(
          l10n.desktopPairedWith(pairing.deviceName),
          type: AppSnackBarType.success,
        );
        getIt<CommunicationBloc>().add(
          CommunicationPairingCompleted(pairing: pairing),
        );
      case OutdatedPairingQr():
        navigator.pop();
        tell(l10n.desktopQrOutdated);
      case InvalidPairingQr():
        navigator.pop();
        tell(l10n.desktopQrInvalid);
      case NotPairingQr():
        navigator.pop();
        getIt<SyncBloc>().add(SyncData(qrData: qrData));
    }
  }

  /// The message for why the phone isn't connected, if there is one.
  static String? issueMessage(AppLocalizations l10n, DesktopSyncState state) {
    return switch (state.issue) {
      LinkIssue.notFound => l10n.desktopNotFound,
      LinkIssue.keyRejected => l10n.desktopPairingRejected,
      LinkIssue.declined => l10n.desktopPairingDeclined,
      LinkIssue.desktopOutdated => l10n.desktopUpdateDesktopApp,
      null => null,
    };
  }

  static void show(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Dialog(
          backgroundColor: Colors.transparent,
          child: SizedBox(
            width: context.dialogWidth,
            child: Container(
              decoration: BoxDecoration(
                color: context.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(
                      left: Insets.medium,
                      right: Insets.medium,
                      top: Insets.normal,
                    ),
                    child: Row(
                      children: [
                        Text(
                          context.l10n.desktopConnection,
                          style: AppTextStyle.bodyMedium.copyWith(
                            color: context.colorScheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: Icon(
                            Icons.close,
                            size: 20,
                            color: context.colorScheme.onSurface.withValues(
                              alpha: 0.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Flexible(
                    child: ConnectionDialog._(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  const ConnectionDialog._();

  @override
  State<ConnectionDialog> createState() => _ConnectionDialogState();
}

class _ConnectionDialogState extends State<ConnectionDialog> {
  late DesktopSyncState _commState;
  StreamSubscription<DesktopSyncState>? _sub;

  @override
  void initState() {
    super.initState();
    final bloc = getIt<CommunicationBloc>();
    _commState = bloc.state;
    _sub = bloc.stream.listen((state) {
      if (mounted) {
        setState(() => _commState = state);
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final commState = _commState;
    return Padding(
      padding: const EdgeInsets.all(Insets.medium),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatusSection(context, commState),
            if (commState.connectionStatus != ConnectionStatus.connected) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: Insets.normal),
                child: Divider(
                  color: context.colorScheme.onSurface.withValues(alpha: 0.06),
                  height: 1,
                ),
              ),
              _buildPairingSection(context, commState),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusSection(BuildContext context, DesktopSyncState commState) {
    final isConnected =
        commState.connectionStatus == ConnectionStatus.connected;
    final isDiscovering =
        commState.connectionStatus == ConnectionStatus.discovering;
    final isAwaitingApproval =
        commState.connectionStatus == ConnectionStatus.awaitingApproval;
    final isDesktop = getIt<AppPlatform>().isDesktop;
    final remoteName =
        commState.connectedDeviceName ??
        (isDesktop ? null : commState.pairedDevice?.deviceName);

    final Color dotColor;
    final String statusLabel;

    if (isConnected) {
      dotColor = AppColors.success;
      statusLabel = remoteName != null
          ? context.l10n.desktopConnectedTo(remoteName)
          : context.l10n.desktopConnected;
    } else if (isAwaitingApproval) {
      dotColor = AppColors.warning;
      statusLabel = context.l10n.desktopWaitingForApproval;
    } else if (isDiscovering) {
      dotColor = AppColors.warning;
      statusLabel = remoteName != null
          ? context.l10n.desktopReconnectingTo(remoteName)
          : context.l10n.desktopReconnecting;
    } else {
      dotColor = AppColors.error;
      statusLabel = remoteName != null
          ? context.l10n.desktopDisconnectedFrom(remoteName)
          : context.l10n.desktopDisconnected;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: Insets.small),
            Expanded(
              child: Text(
                statusLabel,
                style: AppTextStyle.bodyMedium.copyWith(color: dotColor),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isConnected)
              GestureDetector(
                onTap: () {
                  getIt<CommunicationBloc>().add(
                    const CommunicationManualDisconnect(),
                  );
                },
                child: Text(
                  context.l10n.desktopDisconnect,
                  style: AppTextStyle.labelSmall.copyWith(
                    color: AppColors.error,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            // The desktop listens all the time; only the phone reconnects.
            if (!isDesktop &&
                !isConnected &&
                commState.pairedDevice != null &&
                !isDiscovering &&
                !isAwaitingApproval)
              GestureDetector(
                onTap: () {
                  getIt<CommunicationBloc>().add(
                    const CommunicationConnectionRequested(),
                  );
                },
                child: Text(
                  context.l10n.desktopReconnect,
                  style: AppTextStyle.labelSmall.copyWith(
                    color: context.colorScheme.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            if (isDiscovering)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.warning,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    context.l10n.connectionStatusConnecting,
                    style: AppTextStyle.labelSmall.copyWith(
                      color: AppColors.warning,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
          ],
        ),
        if (!isDesktop &&
            ConnectionDialog.issueMessage(context.l10n, commState) != null) ...[
          const SizedBox(height: Insets.small),
          Text(
            ConnectionDialog.issueMessage(context.l10n, commState)!,
            style: AppTextStyle.labelSmall.copyWith(color: AppColors.error),
          ),
        ],
        if (isDesktop && commState.outdatedPhoneSeen && !isConnected) ...[
          const SizedBox(height: Insets.small),
          Text(
            context.l10n.desktopUpdatePhoneApp,
            style: AppTextStyle.labelSmall.copyWith(color: AppColors.warning),
          ),
        ],
        if (commState.vpnDetected && !isConnected) ...[
          const SizedBox(height: Insets.small),
          VpnNotice(
            message: isDesktop
                ? context.l10n.desktopVpnBlocksPhone
                : context.l10n.desktopVpnDetected,
          ),
        ],
      ],
    );
  }

  Widget _buildPairingSection(
    BuildContext context,
    DesktopSyncState commState,
  ) {
    final hasPairing = commState.pairedDevice != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.desktopPairing,
          style: AppTextStyle.bodyMedium.copyWith(
            color: context.colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (hasPairing && getIt<AppPlatform>().isMobile) ...[
          const SizedBox(height: Insets.small),
          InfoRow(
            label: context.l10n.desktopLabel,
            value: commState.pairedDevice!.deviceName,
          ),
        ],
        if (hasPairing &&
            getIt<AppPlatform>().isDesktop &&
            commState.pairedDevice!.peerDeviceId != null) ...[
          // Paired: the QR code is not shown again, so nobody can pair from
          // a glance at the screen or a screenshot.
          const SizedBox(height: Insets.small),
          InfoRow(
            label: context.l10n.desktopPairedPhone,
            value:
                commState.pairedDevice!.peerDeviceName ??
                context.l10n.desktopMobileDevice,
          ),
          const SizedBox(height: Insets.small),
          Text(
            context.l10n.desktopNewQrUnpairsHint,
            style: AppTextStyle.labelSmall.copyWith(
              color: context.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ] else if (hasPairing &&
            getIt<AppPlatform>().isDesktop &&
            commState.networkUnavailable) ...[
          const SizedBox(height: Insets.small),
          Text(
            context.l10n.desktopNoNetwork,
            style: AppTextStyle.labelSmall.copyWith(color: AppColors.warning),
          ),
        ] else if (hasPairing && getIt<AppPlatform>().isDesktop) ...[
          const SizedBox(height: Insets.normal),
          Center(
            child: GestureDetector(
              onTap: () => _showFullScreenQr(context, commState.pairedDevice!),
              child: Container(
                padding: const EdgeInsets.all(Insets.normal),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: QrImageView(
                  data: commState.pairedDevice!.toQrPayload(),
                  version: QrVersions.auto,
                  size: 200,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              context.l10n.desktopScanFromPhoneToPair,
              style: AppTextStyle.labelSmall.copyWith(
                color: context.colorScheme.onSurface.withValues(alpha: 0.3),
                fontSize: 11,
              ),
            ),
          ),
          if (Platform.isWindows) ...[
            const SizedBox(height: Insets.small),
            Text(
              context.l10n.desktopFirewallHint,
              textAlign: TextAlign.center,
              style: AppTextStyle.labelSmall.copyWith(
                color: context.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ],
        const SizedBox(height: Insets.normal),
        if (getIt<AppPlatform>().isDesktop)
          AppButton(
            label: hasPairing
                ? context.l10n.desktopNewQrCode
                : context.l10n.desktopGenerateQrCode,
            onPressed: () {
              getIt<CommunicationBloc>().add(
                const CommunicationPairingRequested(),
              );
            },
            variant: AppButtonVariant.outlined,
            height: 36,
          ),
        if (getIt<AppPlatform>().isMobile)
          AppButton(
            label: context.l10n.desktopScanQrCode,
            onPressed: () => _openMobileQRScanner(context),
            height: 36,
          ),
      ],
    );
  }

  void _showFullScreenQr(BuildContext context, DevicePairing pairing) {
    showDialog(
      context: context,
      builder: (_) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(Insets.large),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  QrImageView(
                    data: pairing.toQrPayload(),
                    version: QrVersions.auto,
                    size: 400,
                  ),
                  const SizedBox(height: Insets.normal),
                  Text(
                    context.l10n.desktopScanFromPhoneToPair,
                    style: AppTextStyle.bodyMedium.copyWith(
                      color: Colors.black54,
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

  void _openMobileQRScanner(BuildContext context) {
    final rootNavigator = Navigator.of(context, rootNavigator: true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;

    rootNavigator.pop();

    rootNavigator.push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => _FullScreenQRScanner(
          onQRCodeDetected: (qrData) => ConnectionDialog.handleScannedCode(
            navigator: rootNavigator,
            messenger: scaffoldMessenger,
            l10n: l10n,
            qrData: qrData,
          ),
        ),
      ),
    );
  }
}

class ConnectionSection extends StatelessWidget {
  const ConnectionSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const ConnectionDialog._();
  }
}

class _FullScreenQRScanner extends StatelessWidget {
  final Function(String) onQRCodeDetected;

  const _FullScreenQRScanner({required this.onQRCodeDetected});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          context.l10n.desktopScanQrCode,
          style: AppTextStyle.titleMedium,
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Insets.medium),
          child: QRScannerWidget(
            onQRCodeDetected: onQRCodeDetected,
            onCancel: () => Navigator.of(context).pop(),
          ),
        ),
      ),
    );
  }
}
