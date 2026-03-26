import 'dart:convert';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_wallet/core/config/app_platform.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/core/widgets/app_button.dart';
import 'package:health_wallet/features/sync/desktop/communication/data/models/device_pairing.dart';
import 'package:health_wallet/features/sync/desktop/communication/presentation/bloc/backup_bloc.dart';
import 'package:health_wallet/features/sync/presentation/widgets/qr_scanner_widget.dart';
import 'package:qr_flutter/qr_flutter.dart';

@RoutePage()
class BackupPage extends StatefulWidget {
  const BackupPage({super.key});

  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  bool _isScanning = false;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<BackupBloc>()..add(const BackupInitialised()),
      child: BlocBuilder<BackupBloc, BackupState>(
        builder: (context, state) {
          if (getIt<AppPlatform>().isDesktop) {
            return _buildDesktopSyncHub(context, state);
          }
          return _buildMobileLayout(context, state);
        },
      ),
    );
  }

  Widget _buildDesktopSyncHub(BuildContext context, BackupState state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(Insets.medium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDesktopHeader(context, state),
          const SizedBox(height: Insets.medium),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildConnectionCard(context, state)),
              const SizedBox(width: Insets.medium),
              Expanded(
                child: Column(
                  children: [
                    _buildBackupCard(context, state),
                    const SizedBox(height: Insets.medium),
                    _buildSyncStatusCard(context, state),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Insets.medium),
          _buildProcessingCard(context, state),
        ],
      ),
    );
  }

  Widget _buildDesktopHeader(BuildContext context, BackupState state) {
    return Row(
      children: [
        Icon(Icons.sync, size: 28, color: context.colorScheme.primary),
        const SizedBox(width: Insets.small),
        Text(
          'Sync',
          style: AppTextStyle.titleMedium
              .copyWith(color: context.colorScheme.onSurface),
        ),
        const Spacer(),
        _buildConnectionChip(context, state),
      ],
    );
  }

  Widget _buildConnectionChip(BuildContext context, BackupState state) {
    final (color, label, icon) = switch (state.connectionStatus) {
      BackupConnectionStatus.connected => (
          AppColors.success,
          _connectedLabel(state),
          Icons.link,
        ),
      BackupConnectionStatus.discovering => (
          AppColors.warning,
          'Discovering...',
          Icons.search,
        ),
      BackupConnectionStatus.disconnected => (
          AppColors.error,
          'Disconnected',
          Icons.link_off,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.normal,
        vertical: Insets.extraSmall,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: Insets.extraSmall),
          Text(label, style: AppTextStyle.labelSmall.copyWith(color: color)),
        ],
      ),
    );
  }

  String _connectedLabel(BackupState state) {
    return switch (state.connectionTransport) {
      ConnectionTransport.tcp => 'WiFi',
      ConnectionTransport.multipeerConnectivity => 'Direct',
      ConnectionTransport.unknown => 'Connected',
    };
  }

  Widget _buildConnectionCard(BuildContext context, BackupState state) {
    return _card(
      context,
      title: 'Connection',
      child: Column(
        children: [
          if (state.pairedDevice == null) ...[
            AppButton(
              label: 'Generate Pairing QR',
              onPressed: () {
                context
                    .read<BackupBloc>()
                    .add(const BackupPairingRequested());
              },
            ),
          ] else if (state.connectionStatus !=
              BackupConnectionStatus.connected) ...[
            Container(
              padding: const EdgeInsets.all(Insets.normal),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: QrImageView(
                data: jsonEncode({
                  'device_id': state.pairedDevice!.deviceId,
                  'ip': state.pairedDevice!.lastIp,
                  'port': state.pairedDevice!.lastPort,
                  'pairing_key': state.pairedDevice!.pairingKey,
                  'device_name': state.pairedDevice!.deviceName,
                  'os': state.pairedDevice!.os,
                }),
                version: QrVersions.auto,
                size: 180,
              ),
            ),
            const SizedBox(height: Insets.small),
            Text(
              'Scan from mobile Sync page',
              style: AppTextStyle.labelSmall.copyWith(
                color: context.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ] else ...[
            Icon(Icons.check_circle, size: 40, color: AppColors.success),
            const SizedBox(height: Insets.small),
            Text(
              state.pairedDevice!.deviceName,
              style: AppTextStyle.bodyMedium
                  .copyWith(color: context.colorScheme.onSurface),
            ),
          ],
          if (state.pairedDevice != null) ...[
            const SizedBox(height: Insets.normal),
            _buildInfoRow(context, 'Device', state.pairedDevice!.deviceName),
            _buildInfoRow(context, 'Transport', _transportLabel(state)),
            if (state.connectedIp != null)
              _buildInfoRow(context, 'IP', state.connectedIp!),
            if (state.connectedPort != null)
              _buildInfoRow(context, 'Port', '${state.connectedPort}'),
            const SizedBox(height: Insets.small),
            AppButton(
              label: 'New Pairing',
              onPressed: () {
                context
                    .read<BackupBloc>()
                    .add(const BackupPairingRequested());
              },
              fullWidth: false,
              height: 36,
            ),
          ],
        ],
      ),
    );
  }

  String _transportLabel(BackupState state) {
    return switch (state.connectionTransport) {
      ConnectionTransport.tcp => 'TCP over WiFi',
      ConnectionTransport.multipeerConnectivity =>
        'MultipeerConnectivity (Direct)',
      ConnectionTransport.unknown => '-',
    };
  }

  Widget _buildBackupCard(BuildContext context, BackupState state) {
    final isConnected =
        state.connectionStatus == BackupConnectionStatus.connected;

    return _card(
      context,
      title: 'Backup',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow(context, 'Last backup', 'Not yet'),
          _buildInfoRow(context, 'Records', '-'),
          _buildInfoRow(context, 'Size', '-'),
          const SizedBox(height: Insets.normal),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Backup Now',
                  onPressed: isConnected ? () {} : null,
                  height: 36,
                ),
              ),
              const SizedBox(width: Insets.small),
              Expanded(
                child: AppButton(
                  label: 'Restore',
                  onPressed: isConnected ? () {} : null,
                  height: 36,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSyncStatusCard(BuildContext context, BackupState state) {
    final isConnected =
        state.connectionStatus == BackupConnectionStatus.connected;

    return _card(
      context,
      title: 'LWW Sync',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isConnected ? AppColors.success : AppColors.error,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: Insets.small),
              Text(
                isConnected ? 'Ready' : 'Offline',
                style: AppTextStyle.labelSmall.copyWith(
                  color: isConnected ? AppColors.success : AppColors.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: Insets.small),
          _buildInfoRow(context, 'Last synced', 'Not yet'),
          _buildInfoRow(context, 'Pending', '0 changes'),
        ],
      ),
    );
  }

  Widget _buildProcessingCard(BuildContext context, BackupState state) {
    return _card(
      context,
      title: 'Processing History',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProcessingRow(context,
              icon: Icons.phone_android,
              label: 'Scanned on Phone',
              count: '-'),
          _buildProcessingRow(context,
              icon: Icons.desktop_mac,
              label: 'Processed on Desktop',
              count: '-'),
          _buildProcessingRow(context,
              icon: Icons.file_upload_outlined,
              label: 'Imported on Desktop',
              count: '-'),
        ],
      ),
    );
  }

  Widget _buildProcessingRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String count,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.small),
      child: Row(
        children: [
          Icon(icon,
              size: 16,
              color: context.colorScheme.onSurface.withValues(alpha: 0.5)),
          const SizedBox(width: Insets.small),
          Text(label,
              style: AppTextStyle.labelSmall
                  .copyWith(color: context.colorScheme.onSurface)),
          const Spacer(),
          Text(count,
              style: AppTextStyle.labelSmall.copyWith(
                  color:
                      context.colorScheme.onSurface.withValues(alpha: 0.5))),
        ],
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.extraSmall),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: AppTextStyle.labelSmall.copyWith(
                color: context.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTextStyle.labelSmall
                  .copyWith(color: context.colorScheme.onSurface),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(
    BuildContext context, {
    required String title,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Insets.medium),
      decoration: BoxDecoration(
        color: context.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTextStyle.bodyMedium
                .copyWith(color: context.colorScheme.onSurface),
          ),
          const SizedBox(height: Insets.normal),
          child,
        ],
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context, BackupState state) {
    if (_isScanning) {
      return Padding(
        padding: const EdgeInsets.all(Insets.medium),
        child: QRScannerWidget(
          onQRCodeDetected: (code) => _onQRCodeDetected(context, code),
          onCancel: () => setState(() => _isScanning = false),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(Insets.medium),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildConnectionChip(context, state),
          const SizedBox(height: Insets.medium),
          Icon(
            state.connectionStatus == BackupConnectionStatus.connected
                ? Icons.cloud_done_outlined
                : Icons.sync,
            size: 64,
            color: state.connectionStatus == BackupConnectionStatus.connected
                ? AppColors.success
                : context.colorScheme.primary,
          ),
          const SizedBox(height: Insets.normal),
          Text(
            'Desktop Sync',
            style: AppTextStyle.titleMedium
                .copyWith(color: context.colorScheme.onSurface),
          ),
          const SizedBox(height: Insets.small),
          Text(
            state.pairedDevice != null
                ? 'Paired with ${state.pairedDevice!.deviceName}'
                : 'Scan QR code on your desktop to pair',
            style: AppTextStyle.bodyMedium.copyWith(
              color: context.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          if (state.connectionStatus == BackupConnectionStatus.connected)
            Padding(
              padding: const EdgeInsets.only(top: Insets.extraSmall),
              child: Text(
                _transportLabel(state),
                style: AppTextStyle.labelSmall.copyWith(
                  color: context.colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ),
            ),
          if (state.error != null) ...[
            const SizedBox(height: Insets.small),
            Text(
              state.error!,
              style: AppTextStyle.bodySmall.copyWith(color: AppColors.error),
            ),
          ],
          const SizedBox(height: Insets.normal),
          if (state.pairedDevice == null ||
              state.connectionStatus == BackupConnectionStatus.disconnected)
            AppButton(
              label:
                  state.pairedDevice != null ? 'Scan New QR' : 'Scan QR Code',
              onPressed: () => setState(() => _isScanning = true),
            ),
          if (state.pairedDevice != null &&
              state.connectionStatus ==
                  BackupConnectionStatus.disconnected) ...[
            const SizedBox(height: Insets.small),
            AppButton(
              label: 'Reconnect',
              onPressed: () {
                context
                    .read<BackupBloc>()
                    .add(const BackupConnectionRequested());
              },
            ),
          ],
        ],
      ),
    );
  }

  void _onQRCodeDetected(BuildContext context, String code) {
    setState(() => _isScanning = false);

    try {
      final json = jsonDecode(code) as Map<String, dynamic>;
      final pairing = DevicePairing(
        deviceId: json['device_id'] as String,
        deviceName: json['device_name'] as String,
        pairingKey: json['pairing_key'] as String,
        lastIp: json['ip'] as String,
        lastPort: json['port'] as int,
        pairedAt: DateTime.now(),
        os: json['os'] as String?,
      );

      context.read<BackupBloc>().add(BackupPairingCompleted(pairing: pairing));
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid pairing QR code')),
      );
    }
  }
}
