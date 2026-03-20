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
import 'package:health_wallet/features/backup/data/models/device_pairing.dart';
import 'package:health_wallet/features/backup/presentation/bloc/backup_bloc.dart';
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
      create: (_) =>
          getIt<BackupBloc>()..add(const BackupInitialised()),
      child: BlocBuilder<BackupBloc, BackupState>(
        builder: (context, state) {
          if (getIt<AppPlatform>().isDesktop) {
            return _buildDesktopLayout(context, state);
          }
          return _buildMobileLayout(context, state);
        },
      ),
    );
  }

  Widget _buildDesktopLayout(BuildContext context, BackupState state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(Insets.medium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context, state),
          const SizedBox(height: Insets.medium),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildPairingCard(context, state)),
              const SizedBox(width: Insets.medium),
              Expanded(child: _buildStatusCard(context, state)),
            ],
          ),
          const SizedBox(height: Insets.medium),
          _buildPhaseProgress(context),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, BackupState state) {
    return Row(
      children: [
        Icon(
          Icons.backup_outlined,
          size: 32,
          color: context.colorScheme.primary,
        ),
        const SizedBox(width: Insets.small),
        Text(
          'Desktop Backup Hub',
          style: AppTextStyle.titleMedium.copyWith(
            color: context.colorScheme.onSurface,
          ),
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
          'Connected',
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
          Text(
            label,
            style: AppTextStyle.labelSmall.copyWith(color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildPairingCard(BuildContext context, BackupState state) {
    return Container(
      padding: const EdgeInsets.all(Insets.medium),
      decoration: BoxDecoration(
        color: context.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: context.colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'QR Pairing',
            style: AppTextStyle.bodyMedium.copyWith(
              color: context.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: Insets.normal),
          if (state.pairedDevice == null) ...[
            Center(
              child: AppButton(
                label: 'Generate Pairing QR',
                onPressed: () {
                  context
                      .read<BackupBloc>()
                      .add(const BackupPairingRequested());
                },
              ),
            ),
          ] else if (state.connectionStatus !=
              BackupConnectionStatus.connected) ...[
            Center(
              child: Container(
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
                  size: 200,
                ),
              ),
            ),
            const SizedBox(height: Insets.small),
            Center(
              child: Text(
                'Scan from mobile Sync page',
                style: AppTextStyle.labelSmall.copyWith(
                  color:
                      context.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ),
          ] else ...[
            Center(
              child: Column(
                children: [
                  Icon(
                    Icons.check_circle,
                    size: 48,
                    color: AppColors.success,
                  ),
                  const SizedBox(height: Insets.small),
                  Text(
                    'Paired with ${state.pairedDevice!.deviceName}',
                    style: AppTextStyle.bodySmall.copyWith(
                      color: context.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (state.pairedDevice != null) ...[
            const SizedBox(height: Insets.small),
            Center(
              child: AppButton(
                label: 'New Pairing',
                onPressed: () {
                  context
                      .read<BackupBloc>()
                      .add(const BackupPairingRequested());
                },
                fullWidth: false,
                height: 36,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusCard(BuildContext context, BackupState state) {
    return Container(
      padding: const EdgeInsets.all(Insets.medium),
      decoration: BoxDecoration(
        color: context.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: context.colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Connection Details',
            style: AppTextStyle.bodyMedium.copyWith(
              color: context.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: Insets.normal),
          _buildDetailRow(
            context,
            'Protocol',
            'TCP + AES-256-GCM (Isolate server)',
          ),
          _buildDetailRow(
            context,
            'Discovery',
            'mDNS + SSDP (parallel)',
          ),
          _buildDetailRow(
            context,
            'Pairing',
            state.pairedDevice != null ? 'Active' : 'Not paired',
          ),
          _buildDetailRow(
            context,
            'Device',
            state.pairedDevice?.deviceName ?? '-',
          ),
          _buildDetailRow(
            context,
            'IP',
            state.pairedDevice?.lastIp ?? '-',
          ),
          _buildDetailRow(
            context,
            'Port',
            state.pairedDevice?.lastPort.toString() ?? '-',
          ),
          if (state.error != null)
            _buildDetailRow(context, 'Error', state.error!, isError: true),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context,
    String label,
    String value, {
    bool isError = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.small),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: AppTextStyle.labelSmall.copyWith(
                color:
                    context.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTextStyle.labelSmall.copyWith(
                color: isError
                    ? AppColors.error
                    : context.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhaseProgress(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Insets.medium),
      decoration: BoxDecoration(
        color: context.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: context.colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'HM-2: Desktop App v1.0 Progress',
            style: AppTextStyle.bodyMedium.copyWith(
              color: context.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: Insets.normal),
          _buildPhaseItem(context, 'Phase 1: Desktop Shell', true,
              'HM-158 - Entry point, navigation, platform detection'),
          _buildPhaseItem(context, 'Phase 2: Communication', true,
              'HM-159 - QR pairing, mDNS+SSDP, encrypted TCP'),
          _buildPhaseItem(context, 'Phase 3a: Backup & Restore', false,
              'Snapshot, transfer, restore over TCP'),
          _buildPhaseItem(context, 'Phase 3b: Processing Handover', false,
              'Mobile offloads AI processing to desktop'),
          _buildPhaseItem(context, 'Phase 3c: LWW Sync', false,
              'Bidirectional last-write-wins sync'),
          _buildPhaseItem(context, 'Phase 3d: Desktop UI Polish', false,
              'Keyboard shortcuts, drag & drop, theme'),
        ],
      ),
    );
  }

  Widget _buildPhaseItem(
    BuildContext context,
    String phase,
    bool done,
    String description,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.small),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            done ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 18,
            color: done ? AppColors.success : context.colorScheme.outline,
          ),
          const SizedBox(width: Insets.small),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  phase,
                  style: AppTextStyle.labelSmall.copyWith(
                    color: context.colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  description,
                  style: AppTextStyle.labelSmall.copyWith(
                    color: context.colorScheme.onSurface
                        .withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
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
                : Icons.backup_outlined,
            size: 64,
            color: state.connectionStatus == BackupConnectionStatus.connected
                ? AppColors.success
                : context.colorScheme.primary,
          ),
          const SizedBox(height: Insets.normal),
          Text(
            'Desktop Backup',
            style: AppTextStyle.titleMedium.copyWith(
              color: context.colorScheme.onSurface,
            ),
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
          if (state.error != null) ...[
            const SizedBox(height: Insets.small),
            Text(
              state.error!,
              style: AppTextStyle.bodySmall.copyWith(
                color: AppColors.error,
              ),
            ),
          ],
          const SizedBox(height: Insets.normal),
          if (state.pairedDevice == null ||
              state.connectionStatus ==
                  BackupConnectionStatus.disconnected)
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
