import 'package:flutter/material.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/widgets/app_button.dart';
import 'package:health_wallet/features/desktop/communication/presentation/bloc/communication_bloc.dart';
import 'package:health_wallet/features/desktop/presentation/widgets/desktop_card.dart';
import 'package:health_wallet/features/desktop/presentation/widgets/info_row.dart';

class BackupCard extends StatelessWidget {
  final DesktopSyncState state;

  const BackupCard({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final isConnected =
        state.connectionStatus == ConnectionStatus.connected;

    return DesktopCard(
      title: 'Backup',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const InfoRow(label: 'Last backup', value: 'Not yet'),
          const InfoRow(label: 'Records', value: '-'),
          const InfoRow(label: 'Size', value: '-'),
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
}
