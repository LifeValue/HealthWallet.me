import 'package:flutter/material.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/features/desktop/communication/presentation/bloc/communication_bloc.dart';
import 'package:health_wallet/features/desktop/presentation/widgets/desktop_card.dart';
import 'package:health_wallet/features/desktop/presentation/widgets/info_row.dart';

class SyncStatusCard extends StatelessWidget {
  final DesktopSyncState state;

  const SyncStatusCard({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final isConnected =
        state.connectionStatus == ConnectionStatus.connected;

    return DesktopCard(
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
          const InfoRow(label: 'Last synced', value: 'Not yet'),
          const InfoRow(label: 'Pending', value: '0 changes'),
        ],
      ),
    );
  }
}
