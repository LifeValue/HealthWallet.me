import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/widgets/app_button.dart';
import 'package:health_wallet/features/desktop/communication/presentation/bloc/communication_bloc.dart';
import 'package:health_wallet/features/desktop/lww_sync/presentation/bloc/lww_sync_bloc.dart';
import 'package:health_wallet/features/desktop/presentation/widgets/desktop_card.dart';
import 'package:health_wallet/features/desktop/presentation/widgets/info_row.dart';
import 'package:intl/intl.dart';

class SyncStatusCard extends StatelessWidget {
  final DesktopSyncState commState;
  final LwwSyncState syncState;

  const SyncStatusCard({
    super.key,
    required this.commState,
    required this.syncState,
  });

  @override
  Widget build(BuildContext context) {
    final isConnected =
        commState.connectionStatus == ConnectionStatus.connected;
    final isSyncing = syncState.syncStatus == LwwSyncStatus.syncing;
    final hasError = syncState.syncStatus == LwwSyncStatus.error;

    final (statusColor, statusLabel) =
        _getStatus(isConnected, isSyncing, hasError, syncState.isSynced);

    return DesktopCard(
      title: 'Sync',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: Insets.small),
              Text(
                statusLabel,
                style: AppTextStyle.labelSmall.copyWith(color: statusColor),
              ),
              if (syncState.isSynced && isConnected) ...[
                const SizedBox(width: Insets.small),
                Icon(Icons.check_circle, color: AppColors.success, size: 16),
              ],
            ],
          ),
          const SizedBox(height: Insets.small),
          InfoRow(
            label: 'Last synced',
            value: syncState.lastSyncTime != null
                ? DateFormat.yMMMd().add_Hm().format(syncState.lastSyncTime!)
                : 'Not yet',
          ),
          if (syncState.sentRows > 0 || syncState.receivedRows > 0)
            InfoRow(
              label: 'Transfer',
              value: '${syncState.sentRows} sent, ${syncState.receivedRows} received',
            ),
          if (syncState.pendingChangeCount > 0)
            InfoRow(
              label: 'Pending',
              value: '${syncState.pendingChangeCount} changes',
            ),
          if (syncState.error != null) ...[
            const SizedBox(height: Insets.small),
            Text(
              syncState.error!,
              style: AppTextStyle.labelSmall.copyWith(color: AppColors.error),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (isSyncing) ...[
            const SizedBox(height: Insets.small),
            if (syncState.currentTable != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  'Syncing ${_formatTableName(syncState.currentTable!)}...',
                  style: AppTextStyle.labelSmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            LinearProgressIndicator(
              value: syncState.totalTables > 0
                  ? syncState.completedTables / syncState.totalTables
                  : null,
            ),
          ],
          const SizedBox(height: Insets.normal),
          AppButton(
            label: isSyncing ? 'Syncing...' : 'Sync Now',
            onPressed: isConnected && !isSyncing
                ? () {
                    context
                        .read<LwwSyncBloc>()
                        .add(const SyncTriggered());
                  }
                : null,
            height: 36,
          ),
        ],
      ),
    );
  }

  (Color, String) _getStatus(
      bool connected, bool syncing, bool hasError, bool isSynced) {
    if (hasError) return (AppColors.error, 'Error');
    if (syncing) return (AppColors.warning, 'Syncing...');
    if (isSynced && connected) return (AppColors.success, 'In Sync');
    if (connected) return (AppColors.success, 'Ready');
    return (AppColors.error, 'Offline');
  }

  String _formatTableName(String tableName) {
    switch (tableName) {
      case 'fhir_resource':
        return 'Health Records';
      case 'sources':
        return 'Sources';
      case 'record_notes':
        return 'Notes';
      case 'processing_sessions':
        return 'Sessions';
      default:
        return tableName;
    }
  }
}
