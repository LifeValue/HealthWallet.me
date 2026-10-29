import 'package:flutter/material.dart';
import 'package:health_wallet/core/l10n/l10n.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/features/desktop/communication/presentation/bloc/communication_bloc.dart';

class ConnectionChip extends StatelessWidget {
  final DesktopSyncState state;

  const ConnectionChip({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final (color, label, icon) = switch (state.connectionStatus) {
      ConnectionStatus.connected => (
        AppColors.success,
        _connectedLabel(context, state),
        Icons.link,
      ),
      ConnectionStatus.discovering => (
        AppColors.warning,
        context.l10n.desktopDiscovering,
        Icons.search,
      ),
      ConnectionStatus.disconnected => (
        AppColors.error,
        context.l10n.desktopDisconnected,
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

  String _connectedLabel(BuildContext context, DesktopSyncState state) {
    return switch (state.connectionTransport) {
      ConnectionTransport.tcp => context.l10n.desktopTransportWifi,
      ConnectionTransport.multipeerConnectivity =>
        context.l10n.desktopTransportDirect,
      ConnectionTransport.unknown => context.l10n.desktopConnected,
    };
  }
}
