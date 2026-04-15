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
import 'package:health_wallet/core/widgets/app_button.dart';
import 'package:health_wallet/features/desktop/communication/data/models/device_pairing.dart';
import 'package:health_wallet/features/desktop/communication/data/services/pairing_storage_service.dart';
import 'package:health_wallet/features/desktop/communication/presentation/bloc/communication_bloc.dart';
import 'package:health_wallet/features/desktop/presentation/widgets/info_row.dart';
import 'package:health_wallet/features/sync/presentation/widgets/qr_scanner_widget.dart';
import 'package:qr_flutter/qr_flutter.dart';

class ConnectionDialog extends StatefulWidget {
  static void show(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Dialog(
          backgroundColor: Colors.transparent,
          child: SizedBox(
            width: 500,
            child: BlocProvider.value(
              value: getIt<CommunicationBloc>(),
              child: BlocBuilder<CommunicationBloc, DesktopSyncState>(
                builder: (context, commState) {
                  return Container(
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
                                'Connection',
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
                        Flexible(
                          child: ConnectionDialog._(commState: commState),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  final DesktopSyncState commState;

  const ConnectionDialog._({required this.commState});

  @override
  State<ConnectionDialog> createState() => _ConnectionDialogState();
}

class _ConnectionDialogState extends State<ConnectionDialog> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(Insets.medium),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatusSection(context),
            if (widget.commState.connectionStatus !=
                ConnectionStatus.connected) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: Insets.normal),
                child: Divider(
                  color:
                      context.colorScheme.onSurface.withValues(alpha: 0.06),
                  height: 1,
                ),
              ),
              _buildPairingSection(context),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusSection(BuildContext context) {
    final isConnected =
        widget.commState.connectionStatus == ConnectionStatus.connected;
    final isDiscovering =
        widget.commState.connectionStatus == ConnectionStatus.discovering;

    final isDesktop = getIt<AppPlatform>().isDesktop;
    final remoteName = widget.commState.connectedDeviceName ??
        (isDesktop ? null : widget.commState.pairedDevice?.deviceName);

    final Color dotColor;
    final String statusLabel;

    if (isConnected) {
      dotColor = AppColors.success;
      statusLabel =
          remoteName != null ? 'Connected to $remoteName' : 'Connected';
    } else if (isDiscovering) {
      dotColor = AppColors.warning;
      statusLabel = remoteName != null
          ? 'Reconnecting to $remoteName...'
          : 'Reconnecting...';
    } else {
      dotColor = AppColors.error;
      statusLabel = remoteName != null
          ? 'Disconnected from $remoteName'
          : 'Disconnected';
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
                  'Disconnect',
                  style: AppTextStyle.labelSmall.copyWith(
                    color: AppColors.error,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            if (!isConnected &&
                widget.commState.pairedDevice != null &&
                !isDiscovering)
              GestureDetector(
                onTap: () {
                  getIt<CommunicationBloc>()
                      .add(const CommunicationConnectionRequested());
                },
                child: Text(
                  'Reconnect',
                  style: AppTextStyle.labelSmall.copyWith(
                    color: context.colorScheme.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        if (widget.commState.vpnDetected && !isConnected) ...[
          const SizedBox(height: Insets.small),
          Row(
            children: [
              Icon(Icons.vpn_lock, size: 14, color: AppColors.warning),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'VPN detected. Disconnect VPN to sync with desktop.',
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

  Widget _buildPairingSection(BuildContext context) {
    final hasPairing = widget.commState.pairedDevice != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pairing',
          style: AppTextStyle.bodyMedium.copyWith(
            color: context.colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (hasPairing && getIt<AppPlatform>().isMobile) ...[
          const SizedBox(height: Insets.small),
          InfoRow(
            label: 'Desktop',
            value: widget.commState.pairedDevice!.deviceName,
          ),
        ],
        if (hasPairing && getIt<AppPlatform>().isDesktop) ...[
          const SizedBox(height: Insets.normal),
          Center(
            child: GestureDetector(
              onTap: () => _showFullScreenQr(context, widget.commState.pairedDevice!),
              child: Container(
                padding: const EdgeInsets.all(Insets.normal),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: QrImageView(
                  data: _qrData(widget.commState.pairedDevice!),
                  version: QrVersions.auto,
                  size: 200,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              'Scan from your phone to pair',
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
            label: hasPairing ? 'New QR Code' : 'Generate QR Code',
            onPressed: () {
              getIt<CommunicationBloc>()
                  .add(const CommunicationPairingRequested());
            },
            variant: AppButtonVariant.outlined,
            height: 36,
          ),
        if (getIt<AppPlatform>().isMobile)
          AppButton(
            label: 'Scan QR Code',
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
                    'Scan from your phone to pair',
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

    navigator.pop();
    messenger.showSnackBar(
      const SnackBar(content: Text('Unrecognized QR code format')),
    );
  }

  Future<void> _handlePairing(
    NavigatorState navigator,
    ScaffoldMessengerState messenger,
    DevicePairing pairing,
  ) async {
    final pairingStorage = getIt<PairingStorageService>();
    await pairingStorage.savePairing(pairing);

    navigator.pop();

    messenger.showSnackBar(
      SnackBar(content: Text('Paired with ${pairing.deviceName}')),
    );

    getIt<CommunicationBloc>()
        .add(CommunicationPairingCompleted(pairing: pairing));
  }
}

class ConnectionSection extends StatelessWidget {
  final DesktopSyncState commState;

  const ConnectionSection({super.key, required this.commState});

  @override
  Widget build(BuildContext context) {
    return ConnectionDialog._(commState: commState);
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
          'Scan QR Code',
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
