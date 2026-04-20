import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/core/widgets/app_button.dart';
import 'package:health_wallet/features/desktop/communication/presentation/bloc/communication_bloc.dart';
import 'package:health_wallet/features/desktop/presentation/widgets/desktop_card.dart';
import 'package:health_wallet/features/desktop/presentation/widgets/info_row.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:health_wallet/core/l10n/l10n.dart';

class ConnectionCard extends StatelessWidget {
  final DesktopSyncState state;

  const ConnectionCard({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return DesktopCard(
      title: context.l10n.desktopConnection,
      child: Column(
        children: [
          if (state.pairedDevice == null) ...[
            AppButton(
              label: context.l10n.desktopGeneratePairingQr,
              onPressed: () {
                context
                    .read<CommunicationBloc>()
                    .add(const CommunicationPairingRequested());
              },
            ),
          ] else if (state.connectionStatus !=
              ConnectionStatus.connected) ...[
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
              context.l10n.desktopScanFromMobile,
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
            InfoRow(label: context.l10n.desktopDevice, value: state.pairedDevice!.deviceName),
            InfoRow(label: context.l10n.desktopTransport, value: _transportLabel(context, state)),
            if (state.connectedIp != null)
              InfoRow(label: context.l10n.desktopIp, value: state.connectedIp!),
            if (state.connectedPort != null)
              InfoRow(label: context.l10n.desktopPort, value: '${state.connectedPort}'),
            const SizedBox(height: Insets.small),
            AppButton(
              label: context.l10n.desktopNewPairing,
              onPressed: () {
                context
                    .read<CommunicationBloc>()
                    .add(const CommunicationPairingRequested());
              },
              fullWidth: false,
              height: 36,
            ),
          ],
        ],
      ),
    );
  }

  String _transportLabel(BuildContext context, DesktopSyncState state) {
    return switch (state.connectionTransport) {
      ConnectionTransport.tcp => context.l10n.desktopTransportTcp,
      ConnectionTransport.multipeerConnectivity =>
        context.l10n.desktopTransportMpc,
      ConnectionTransport.unknown => '-',
    };
  }
}
