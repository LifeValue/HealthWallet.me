import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_wallet/core/config/app_platform.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/utils/date_format_utils.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/core/widgets/app_button.dart';
import 'package:health_wallet/features/desktop/communication/presentation/bloc/communication_bloc.dart';
import 'package:health_wallet/features/desktop/lww_sync/presentation/bloc/lww_sync_bloc.dart';
import 'package:health_wallet/features/desktop/presentation/widgets/info_row.dart';

class SyncDialog extends StatelessWidget {
  static void show(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Dialog(
          backgroundColor: Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: MultiBlocProvider(
              providers: [
                BlocProvider.value(value: getIt<CommunicationBloc>()),
                BlocProvider.value(value: getIt<LwwSyncBloc>()),
              ],
              child: BlocBuilder<CommunicationBloc, DesktopSyncState>(
                builder: (context, commState) {
                  return BlocBuilder<LwwSyncBloc, LwwSyncState>(
                    builder: (context, syncState) {
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
                                    'Sync',
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
                              child: SyncSection(
                                commState: commState,
                                syncState: syncState,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  const SyncDialog({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class SyncSection extends StatelessWidget {
  final DesktopSyncState commState;
  final LwwSyncState syncState;

  const SyncSection({
    required this.commState,
    required this.syncState,
  });

  @override
  Widget build(BuildContext context) {
    final isSyncing = syncState.syncStatus == LwwSyncStatus.syncing;
    final isConnected =
        commState.connectionStatus == ConnectionStatus.connected;

    return Padding(
      padding: const EdgeInsets.all(Insets.medium),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InfoRow(
              label: 'Last synced',
              value: syncState.lastSyncTime != null
                  ? DateFormatUtils.getSincePretty(syncState.lastSyncTime!)
                  : 'Not yet',
            ),
            if (syncState.sentRows > 0 || syncState.receivedRows > 0)
              InfoRow(
                label: 'Transfer',
                value:
                    '${syncState.sentRows} sent, ${syncState.receivedRows} received',
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
            Center(
              child: SizedBox(
                width: 200,
                child: AppButton(
                  label: isSyncing ? 'Syncing...' : 'Sync Now',
                  onPressed: isConnected && !isSyncing
                      ? () {
                          getIt<LwwSyncBloc>().add(const SyncTriggered());
                        }
                      : null,
                  height: 36,
                ),
              ),
            ),
            if (syncState.lastSyncTime != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: Insets.normal),
                child: Divider(
                  color:
                      context.colorScheme.onSurface.withValues(alpha: 0.06),
                  height: 1,
                ),
              ),
              Text(
                'Recent',
                style: AppTextStyle.labelSmall.copyWith(
                  color:
                      context.colorScheme.onSurface.withValues(alpha: 0.35),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: Insets.small),
              _SyncHistoryEntry(
                time: syncState.lastSyncTime!,
                deviceName: commState.connectedDeviceName ??
                    (getIt<AppPlatform>().isDesktop
                        ? null
                        : commState.pairedDevice?.deviceName),
                sentRows: syncState.sentRows,
                receivedRows: syncState.receivedRows,
                isSynced: syncState.isSynced,
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatTableName(String tableName) {
    switch (tableName) {
      case 'fhir_resource':
        return 'Health Records';
      case 'sources':
        return 'Sources';
      case 'record_notes':
        return 'Notes';
      default:
        return tableName;
    }
  }
}

class _SyncHistoryEntry extends StatelessWidget {
  final DateTime time;
  final String? deviceName;
  final int sentRows;
  final int receivedRows;
  final bool isSynced;

  const _SyncHistoryEntry({
    required this.time,
    this.deviceName,
    required this.sentRows,
    required this.receivedRows,
    required this.isSynced,
  });

  @override
  Widget build(BuildContext context) {
    final timeStr = DateFormatUtils.getSincePretty(time);
    final device = deviceName ?? 'Unknown device';
    final hasTransfer = sentRows > 0 || receivedRows > 0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          isSynced ? Icons.check_circle_outline : Icons.sync,
          size: 16,
          color: isSynced
              ? AppColors.success
              : context.colorScheme.onSurface.withValues(alpha: 0.3),
        ),
        const SizedBox(width: Insets.small),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$timeStr · $device',
                style: AppTextStyle.labelSmall.copyWith(
                  color:
                      context.colorScheme.onSurface.withValues(alpha: 0.6),
                  fontSize: 12,
                ),
              ),
              if (hasTransfer)
                Text(
                  '$sentRows sent · $receivedRows received',
                  style: AppTextStyle.labelSmall.copyWith(
                    color:
                        context.colorScheme.onSurface.withValues(alpha: 0.3),
                    fontSize: 11,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
