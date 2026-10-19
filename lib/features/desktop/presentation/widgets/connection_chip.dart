import 'package:flutter/material.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/features/desktop/communication/presentation/bloc/communication_bloc.dart';

class ConnectionChip extends StatelessWidget {
  final DesktopSyncState state;

  const ConnectionChip({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final (color, label, icon) = switch (state.connectionStatus) {
      ConnectionStatus.connected => (
          AppColors.success,
          _connectedLabel(state),
          Icons.link,
        ),
      ConnectionStatus.discovering => (
          AppColors.warning,
          'Discovering...',
          Icons.search,
        ),
      ConnectionStatus.disconnected => (
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

  String _connectedLabel(DesktopSyncState state) {
    return switch (state.connectionTransport) {
      ConnectionTransport.tcp => 'WiFi',
      ConnectionTransport.multipeerConnectivity => 'Direct',
      ConnectionTransport.unknown => 'Connected',
    };
  }
}
