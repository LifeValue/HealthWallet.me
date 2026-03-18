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
import 'package:health_wallet/features/backup/presentation/bloc/backup_bloc.dart';
import 'package:qr_flutter/qr_flutter.dart';

@RoutePage()
class BackupPage extends StatelessWidget {
  const BackupPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          getIt<BackupBloc>()..add(const BackupInitialised()),
      child: BlocBuilder<BackupBloc, BackupState>(
        builder: (context, state) {
          return Padding(
            padding: const EdgeInsets.all(Insets.medium),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildConnectionIndicator(context, state),
                const SizedBox(height: Insets.medium),
                if (getIt<AppPlatform>().isDesktop)
                  _buildDesktopContent(context, state)
                else
                  _buildMobileContent(context, state),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildConnectionIndicator(BuildContext context, BackupState state) {
    final (color, label) = switch (state.connectionStatus) {
      BackupConnectionStatus.connected => (AppColors.success, 'Connected'),
      BackupConnectionStatus.discovering => (AppColors.warning, 'Discovering...'),
      BackupConnectionStatus.disconnected => (AppColors.error, 'Disconnected'),
    };

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: Insets.small),
        Text(
          label,
          style: AppTextStyle.bodyMedium.copyWith(
            color: context.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopContent(BuildContext context, BackupState state) {
    if (state.pairedDevice == null) {
      return Column(
        children: [
          Text(
            'Pair with Mobile Device',
            style: AppTextStyle.titleMedium.copyWith(
              color: context.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: Insets.normal),
          AppButton(
            label: 'Generate Pairing QR',
            onPressed: () {
              context.read<BackupBloc>().add(const BackupPairingRequested());
            },
          ),
        ],
      );
    }

    final qrData = jsonEncode({
      'device_id': state.pairedDevice!.deviceId,
      'ip': state.pairedDevice!.lastIp,
      'port': state.pairedDevice!.lastPort,
      'pairing_key': state.pairedDevice!.pairingKey,
      'device_name': state.pairedDevice!.deviceName,
      'os': state.pairedDevice!.os,
    });

    return Column(
      children: [
        if (state.connectionStatus != BackupConnectionStatus.connected) ...[
          Text(
            'Scan this QR code from your mobile app',
            style: AppTextStyle.titleSmall.copyWith(
              color: context.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: Insets.normal),
          Container(
            padding: const EdgeInsets.all(Insets.normal),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: QrImageView(
              data: qrData,
              version: QrVersions.auto,
              size: 250,
            ),
          ),
          const SizedBox(height: Insets.normal),
          Text(
            'Waiting for mobile device...',
            style: AppTextStyle.bodyMedium.copyWith(
              color: context.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ] else ...[
          Icon(
            Icons.check_circle_outline,
            size: 64,
            color: AppColors.success,
          ),
          const SizedBox(height: Insets.normal),
          Text(
            'Mobile device connected',
            style: AppTextStyle.titleMedium.copyWith(
              color: context.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: Insets.small),
          Text(
            '${state.connectedIp}:${state.connectedPort}',
            style: AppTextStyle.bodySmall.copyWith(
              color: context.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMobileContent(BuildContext context, BackupState state) {
    return Column(
      children: [
        Icon(
          Icons.backup_outlined,
          size: 64,
          color: context.colorScheme.primary,
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
        if (state.pairedDevice != null &&
            state.connectionStatus == BackupConnectionStatus.disconnected) ...[
          const SizedBox(height: Insets.normal),
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
    );
  }
}
