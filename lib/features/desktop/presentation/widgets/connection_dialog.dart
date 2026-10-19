import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_wallet/core/config/app_platform.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/core/utils/responsive.dart';
import 'package:health_wallet/core/widgets/app_button.dart';
import 'package:health_wallet/features/desktop/communication/data/models/device_pairing.dart';
import 'package:health_wallet/features/desktop/communication/data/services/pairing_storage_service.dart';
import 'package:health_wallet/features/desktop/communication/presentation/bloc/communication_bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:health_wallet/features/desktop/presentation/widgets/info_row.dart';
import 'package:health_wallet/features/sync/presentation/bloc/sync_bloc.dart';
import 'package:health_wallet/features/sync/presentation/widgets/qr_scanner_widget.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:health_wallet/core/l10n/l10n.dart';

class ConnectionDialog extends StatefulWidget {
  static void openQRScanner(BuildContext context) {
    final rootNavigator = Navigator.of(context, rootNavigator: true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    rootNavigator.push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => _FullScreenQRScanner(
          onQRCodeDetected: (qrData) {
            debugPrint('[QR_SCAN] QR detected from direct scanner');
            try {
              final json = jsonDecode(qrData) as Map<String, dynamic>;
              if (json.containsKey('pairing_key') && json.containsKey('device_id')) {
                debugPrint('[QR_SCAN] Detected: Desktop pairing QR');
                final pairing = DevicePairing(
                  deviceId: json['device_id'] as String,
                  deviceName: json['device_name'] as String,
                  pairingKey: json['pairing_key'] as String,
                  lastIp: json['ip'] as String,
                  lastPort: json['port'] as int,
                  pairedAt: DateTime.now(),
                  os: json['os'] as String?,
                );

                final pairingStorage = getIt<PairingStorageService>();
                pairingStorage.savePairing(pairing).then((_) {
                  rootNavigator.pop();
                  scaffoldMessenger.showSnackBar(
                    SnackBar(content: Text('Paired with ${pairing.deviceName}')),
                  );
                  getIt<CommunicationBloc>().add(
                    CommunicationPairingCompleted(pairing: pairing),
                  );
                });
                return;
              }
            } catch (_) {}

            debugPrint('[QR_SCAN] Forwarding to SyncBloc for Fasten Health sync');
            rootNavigator.pop();
            getIt<SyncBloc>().add(SyncData(qrData: qrData));
          },
        ),
      ),
    );
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
                    padding: EdgeInsets.only(
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
                            color: context.colorScheme.onSurface
                                .withValues(alpha: 0.4),
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
            if (commState.connectionStatus !=
                ConnectionStatus.connected) ...[
              Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: Insets.normal),
                child: Divider(
                  color: context.colorScheme.onSurface
                      .withValues(alpha: 0.06),
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
    final isDesktop = getIt<AppPlatform>().isDesktop;
    final remoteName = commState.connectedDeviceName ??
        (isDesktop ? null : commState.pairedDevice?.deviceName);

    final Color dotColor;
    final String statusLabel;

    if (isConnected) {
      dotColor = AppColors.success;
      statusLabel =
          remoteName != null ? context.l10n.desktopConnectedTo(remoteName) : context.l10n.desktopConnected;
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
                  getIt<CommunicationBloc>()
                      .add(const CommunicationManualDisconnect());
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
            if (!isConnected &&
                commState.pairedDevice != null &&
                !isDiscovering)
              GestureDetector(
                onTap: () {
                  getIt<CommunicationBloc>()
                      .add(const CommunicationConnectionRequested());
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
                  SizedBox(
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
        if (commState.vpnDetected && !isConnected) ...[
          const SizedBox(height: Insets.small),
          Row(
            children: [
              Icon(Icons.vpn_lock, size: 14, color: AppColors.warning),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  context.l10n.desktopVpnDetected,
                  style: AppTextStyle.labelSmall.copyWith(
                    color: AppColors.warning,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildPairingSection(BuildContext context, DesktopSyncState commState) {
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
        if (hasPairing && getIt<AppPlatform>().isDesktop) ...[
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
                  data: _qrData(commState.pairedDevice!),
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
        ],
        const SizedBox(height: Insets.normal),
        if (getIt<AppPlatform>().isDesktop)
          AppButton(
            label: hasPairing ? context.l10n.desktopNewQrCode : context.l10n.desktopGenerateQrCode,
            onPressed: () {
              getIt<CommunicationBloc>()
                  .add(const CommunicationPairingRequested());
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

  String _qrData(DevicePairing pairing) {
    return jsonEncode({
      'device_id': pairing.deviceId,
      'ip': pairing.lastIp,
      'port': pairing.lastPort,
      'pairing_key': pairing.pairingKey,
      'device_name': pairing.deviceName,
      'os': pairing.os,
    });
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
                    data: _qrData(pairing),
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

    rootNavigator.pop();

    rootNavigator.push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => _FullScreenQRScanner(
          onQRCodeDetected: (qrData) => _handleQRCodeDetected(
            rootNavigator,
            scaffoldMessenger,
            qrData,
          ),
        ),
      ),
    );
  }

  void _handleQRCodeDetected(
    NavigatorState navigator,
    ScaffoldMessengerState messenger,
    String qrData,
  ) {
    try {
      final json = jsonDecode(qrData) as Map<String, dynamic>;
      if (json.containsKey('pairing_key') && json.containsKey('device_id')) {
        final pairing = DevicePairing(
          deviceId: json['device_id'] as String,
          deviceName: json['device_name'] as String,
          pairingKey: json['pairing_key'] as String,
          lastIp: json['ip'] as String,
          lastPort: json['port'] as int,
          pairedAt: DateTime.now(),
          os: json['os'] as String?,
        );

        _handlePairing(navigator, messenger, pairing);
        return;
      }
    } catch (_) {}

    debugPrint('[QR_SCAN] Not a pairing QR, forwarding to SyncBloc for Fasten Health sync');
    navigator.pop();
    getIt<SyncBloc>().add(SyncData(qrData: qrData));
  }

  Future<void> _handlePairing(
    NavigatorState navigator,
    ScaffoldMessengerState messenger,
    DevicePairing pairing,
  ) async {
    final pairingStorage = getIt<PairingStorageService>();
    await pairingStorage.savePairing(pairing);

    navigator.pop();

    getIt<CommunicationBloc>()
        .add(CommunicationPairingCompleted(pairing: pairing));
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
