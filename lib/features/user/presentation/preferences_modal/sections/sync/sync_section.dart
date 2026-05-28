import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_wallet/core/config/app_platform.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/features/desktop/presentation/widgets/connection_dialog.dart';
import 'package:health_wallet/features/desktop/presentation/widgets/device_sync_dialog.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/widgets/app_button.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/l10n/l10n.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/core/utils/date_format_utils.dart';
import 'package:health_wallet/features/desktop/backup/presentation/bloc/backup_bloc.dart';
import 'package:health_wallet/features/desktop/communication/data/services/tcp_service.dart';
import 'package:health_wallet/features/desktop/communication/presentation/bloc/communication_bloc.dart';
import 'package:health_wallet/features/desktop/lww_sync/presentation/bloc/lww_sync_bloc.dart';
import 'package:health_wallet/features/sync/presentation/bloc/sync_bloc.dart';
import 'package:health_wallet/gen/assets.gen.dart' show Assets;

class SyncSection extends StatelessWidget {
  const SyncSection({super.key});

  @override
  Widget build(BuildContext context) {
    final borderColor = context.theme.dividerColor;
    final isDesktop = getIt<AppPlatform>().isDesktop;

    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: getIt<CommunicationBloc>()),
        BlocProvider.value(value: getIt<LwwSyncBloc>()),
        BlocProvider.value(value: getIt<BackupBloc>()),
      ],
      child: BlocBuilder<SyncBloc, SyncState>(
        builder: (context, ehrSyncState) {
          return BlocBuilder<CommunicationBloc, DesktopSyncState>(
            builder: (context, commState) {
              return BlocBuilder<LwwSyncBloc, LwwSyncState>(
                builder: (context, lwwState) {
                  return BlocBuilder<BackupBloc, BackupState>(
                    builder: (context, backupState) {
                      final hasEhrSync = ehrSyncState.hasSyncedData;
                      final hasDesktopPairing = commState.pairedDevice != null;
                      final showSetup = !isDesktop && !hasDesktopPairing && !hasEhrSync;

                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: Insets.normal),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.l10n.desktopSyncAndBackup,
                              style: AppTextStyle.bodySmall,
                            ),
                            const SizedBox(height: Insets.small),
                            if (hasEhrSync) ...[
                              Container(
                                padding: const EdgeInsets.all(Insets.smallNormal),
                                decoration: BoxDecoration(
                                  border: Border.all(color: borderColor),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _StatusRow(
                                      icon: Icons.check_circle_outline,
                                      label: 'EHR Sync',
                                      status: context.l10n.syncSuccessful,
                                      statusColor: AppColors.success,
                                    ),
                                    if (ehrSyncState.lastSyncTime != null) ...[
                                      const SizedBox(height: Insets.extraSmall),
                                      Padding(
                                        padding: const EdgeInsets.only(left: 28),
                                        child: Text(
                                          DateFormatUtils.humanReadable(
                                            DateTime.tryParse(ehrSyncState.lastSyncTime!),
                                          ),
                                          style: AppTextStyle.labelSmall.copyWith(
                                            color: context.colorScheme.onSurface.withValues(alpha: 0.5),
                                          ),
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: Insets.small),
                                    SizedBox(
                                      width: double.infinity,
                                      child: OutlinedButton.icon(
                                        onPressed: () => ConnectionDialog.openQRScanner(context),
                                        icon: const Icon(Icons.sync, size: 16),
                                        label: Text(
                                          context.l10n.syncTitle,
                                          style: AppTextStyle.buttonSmall,
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: context.colorScheme.primary,
                                          side: BorderSide(
                                            color: context.colorScheme.primary.withValues(alpha: 0.3),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: Insets.small,
                                            vertical: Insets.small,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: Insets.small),
                            ],
                            if (showSetup) ...[
                          Container(
                            padding: const EdgeInsets.all(Insets.smallNormal),
                            decoration: BoxDecoration(
                              border: Border.all(color: borderColor),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              children: [
                                Assets.images.syncScanIlustration.svg(
                                  width: 140,
                                  height: 140,
                                ),
                                const SizedBox(height: Insets.small),
                                Text(
                                  context.l10n.desktopSyncDescription,
                                  textAlign: TextAlign.center,
                                  style: AppTextStyle.labelLarge,
                                ),
                                const SizedBox(height: Insets.normal),
                                AppButton(
                                  label: context.l10n.syncTitle,
                                  icon: const Icon(Icons.sync),
                                  variant: AppButtonVariant.primary,
                                  onPressed: () => ConnectionDialog.openQRScanner(context),
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                        Container(
                          padding: const EdgeInsets.all(Insets.smallNormal),
                          decoration: BoxDecoration(
                            border: Border.all(color: borderColor),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _StatusRow(
                                icon: commState.connectionStatus == ConnectionStatus.connected
                                    ? Icons.link
                                    : Icons.link_off,
                                label: context.l10n.connectionLabel,
                                status: _getConnectionStatus(commState, context.l10n),
                                statusColor: _getConnectionColor(commState),
                              ),
                              const SizedBox(height: Insets.small),
                              _StatusRow(
                                icon: Icons.sync,
                                label: context.l10n.deviceSyncLabel,
                                status: _getSyncStatus(commState, lwwState, context.l10n),
                                statusColor: _getSyncColor(commState, lwwState),
                              ),
                              const SizedBox(height: Insets.small),
                              _StatusRow(
                                icon: Icons.shield_outlined,
                                label: context.l10n.backupLabel,
                                status: _getBackupStatus(commState, backupState, context.l10n),
                                statusColor: _getBackupColor(commState, backupState),
                              ),
                              const SizedBox(height: Insets.normal),
                              if (isDesktop)
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: () => DeviceSyncDialog.show(context),
                                    icon: Assets.icons.renewSync.svg(
                                      width: 16,
                                      height: 16,
                                      colorFilter: const ColorFilter.mode(
                                        Colors.white,
                                        BlendMode.srcIn,
                                      ),
                                    ),
                                    label: Text(
                                      context.l10n.syncMedicalRecords,
                                      style: AppTextStyle.buttonSmall,
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: Insets.small,
                                        vertical: Insets.small,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                    ),
                                  ),
                                ),
                              if (!isDesktop &&
                                  commState.connectionStatus == ConnectionStatus.connected) ...[
                                Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: () => DeviceSyncDialog.show(context),
                                        icon: Assets.icons.renewSync.svg(
                                          width: 16,
                                          height: 16,
                                          colorFilter: const ColorFilter.mode(
                                            Colors.white,
                                            BlendMode.srcIn,
                                          ),
                                        ),
                                        label: Text(
                                          context.l10n.syncLabel,
                                          style: AppTextStyle.buttonSmall,
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.primary,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: Insets.small,
                                            vertical: Insets.small,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: Insets.small),
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: _canBackup(commState, backupState)
                                            ? () => _requestRemoteBackup(context, commState)
                                            : null,
                                        icon: Icon(
                                          Icons.shield_outlined,
                                          size: 16,
                                          color: _canBackup(commState, backupState)
                                              ? Colors.white
                                              : null,
                                        ),
                                        label: Text(
                                          backupState.isBackingUp
                                              ? context.l10n.backupStatusBackingUp
                                              : context.l10n.backupLabel,
                                          style: AppTextStyle.buttonSmall,
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.primary,
                                          foregroundColor: Colors.white,
                                          disabledBackgroundColor:
                                              context.colorScheme.onSurface.withValues(alpha: 0.06),
                                          disabledForegroundColor:
                                              context.colorScheme.onSurface.withValues(alpha: 0.3),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: Insets.small,
                                            vertical: Insets.small,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (commState.connectionStatus == ConnectionStatus.connected)
                                  Padding(
                                    padding: const EdgeInsets.only(top: Insets.small),
                                    child: SizedBox(
                                      width: double.infinity,
                                      child: TextButton(
                                        onPressed: () {
                                          try {
                                            context.read<CommunicationBloc>()
                                                .add(const CommunicationManualDisconnect());
                                          } catch (_) {
                                            getIt<CommunicationBloc>()
                                                .add(const CommunicationManualDisconnect());
                                          }
                                        },
                                        style: TextButton.styleFrom(
                                          foregroundColor: AppColors.error,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: Insets.small,
                                          ),
                                        ),
                                        child: Text(
                                          context.l10n.disconnectLabel,
                                          style: AppTextStyle.buttonSmall.copyWith(
                                            color: AppColors.error,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                              if (!isDesktop &&
                                  commState.connectionStatus != ConnectionStatus.connected) ...[
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: () => DeviceSyncDialog.show(context),
                                    icon: const Icon(Icons.link, size: 16),
                                    label: Text(
                                      context.l10n.connect,
                                      style: AppTextStyle.buttonSmall,
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: Insets.small,
                                        vertical: Insets.small,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                              if (isDesktop) ...[
                                const SizedBox(height: Insets.normal),
                                Divider(height: 1, color: borderColor),
                                const SizedBox(height: Insets.normal),
                                _BackupLocationRow(
                                  path: backupState.backupPath,
                                  isWorking: backupState.isBackingUp ||
                                      backupState.isRestoring,
                                ),
                              ],
                            ],
                          ),
                        ),
                        ],
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      );
        },
      ),
    );
  }

  String _getConnectionStatus(DesktopSyncState comm, AppLocalizations l10n) {
    if (comm.connectionStatus == ConnectionStatus.connected) {
      return comm.connectedDeviceName ?? l10n.connectionStatusConnected;
    }
    if (comm.connectionStatus == ConnectionStatus.discovering) {
      return l10n.connectionStatusConnecting;
    }
    if (comm.pairedDevice != null) return l10n.connectionStatusDisconnected;
    return l10n.connectionStatusNotPaired;
  }

  Color _getConnectionColor(DesktopSyncState comm) {
    if (comm.connectionStatus == ConnectionStatus.connected) {
      return AppColors.success;
    }
    if (comm.connectionStatus == ConnectionStatus.discovering) {
      return AppColors.warning;
    }
    if (comm.pairedDevice != null) return AppColors.error;
    return AppColors.textSecondary;
  }

  String _getSyncStatus(DesktopSyncState comm, LwwSyncState lww, AppLocalizations l10n) {
    final isConnected =
        comm.connectionStatus == ConnectionStatus.connected;
    if (lww.syncStatus == LwwSyncStatus.syncing) return l10n.syncStatusSyncing;
    if (lww.isSynced && isConnected) return l10n.syncStatusInSync;
    if (isConnected) return l10n.connectionStatusConnected;
    if (lww.pendingChangeCount > 0) return l10n.syncStatusPending(lww.pendingChangeCount);
    if (lww.lastSyncTime != null) {
      return DateFormatUtils.getSincePretty(lww.lastSyncTime!);
    }
    return l10n.connectionStatusNotPaired;
  }

  Color _getSyncColor(DesktopSyncState comm, LwwSyncState lww) {
    if (lww.syncStatus == LwwSyncStatus.syncing) return AppColors.primary;
    if (lww.isSynced) return AppColors.success;
    if (comm.connectionStatus == ConnectionStatus.connected) {
      return AppColors.success;
    }
    if (lww.pendingChangeCount > 0) return AppColors.warning;
    return AppColors.textSecondary;
  }

  String _getBackupStatus(DesktopSyncState comm, BackupState state, AppLocalizations l10n) {
    if (state.isBackingUp) return l10n.backupStatusBackingUp;
    if (state.isRestoring) return l10n.backupStatusRestoring;
    if (state.backupHistory.isNotEmpty) {
      return DateFormatUtils.getSincePretty(state.backupHistory.first.timestamp);
    }
    if (state.desktopLastBackupTime != null) {
      return DateFormatUtils.getSincePretty(state.desktopLastBackupTime!);
    }
    if (comm.connectionStatus == ConnectionStatus.connected) {
      return l10n.backupStatusWaiting;
    }
    return l10n.backupStatusNotConnected;
  }

  Color _getBackupColor(DesktopSyncState comm, BackupState state) {
    if (state.isBackingUp || state.isRestoring) return AppColors.primary;
    if (state.backupHistory.isNotEmpty) return AppColors.success;
    if (state.desktopLastBackupTime != null) return AppColors.success;
    if (comm.connectionStatus == ConnectionStatus.connected) return AppColors.textSecondary;
    return AppColors.textSecondary;
  }

  bool _canBackup(DesktopSyncState commState, BackupState backupState) {
    return commState.connectionStatus == ConnectionStatus.connected &&
        !backupState.isBackingUp;
  }

  void _requestRemoteBackup(BuildContext context, DesktopSyncState commState) {
    try {
      context.read<LwwSyncBloc>().add(const SyncTriggered());
    } catch (_) {
      getIt<LwwSyncBloc>().add(const SyncTriggered());
    }

    getIt<BackupBloc>().add(
      const RemoteBackupStatusChanged(isBackingUp: true),
    );
    getIt<TcpService>().sendData('backup.request', {});
  }
}

class _StatusRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String status;
  final Color statusColor;

  const _StatusRow({
    required this.icon,
    required this.label,
    required this.status,
    required this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: context.colorScheme.onSurface.withValues(alpha: 0.4)),
        const SizedBox(width: Insets.small),
        Text(
          label,
          style: AppTextStyle.labelSmall.copyWith(
            color: context.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
        const Spacer(),
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: statusColor,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          status,
          style: AppTextStyle.labelSmall.copyWith(
            color: statusColor,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _BackupLocationRow extends StatelessWidget {
  final String? path;
  final bool isWorking;

  static const _fsChannel = MethodChannel('dev.lifevalue.healthwallet/fs');

  const _BackupLocationRow({required this.path, required this.isWorking});

  @override
  Widget build(BuildContext context) {
    final displayPath = path ?? '...';
    final shortened = displayPath.length > 35
        ? '\u2026${displayPath.substring(displayPath.length - 35)}'
        : displayPath;

    return Row(
      children: [
        Icon(Icons.folder_outlined, size: 14,
            color: context.colorScheme.onSurface.withValues(alpha: 0.4)),
        SizedBox(width: Insets.extraSmall),
        Expanded(
          child: Tooltip(
            message: displayPath,
            child: Text(
              shortened,
              style: AppTextStyle.labelSmall.copyWith(
                color: context.colorScheme.onSurface.withValues(alpha: 0.5),
                fontSize: 11,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        SizedBox(width: Insets.extraSmall),
        InkWell(
          onTap: isWorking ? null : () => _pickDirectory(context),
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Text(
              context.l10n.changeLabel,
              style: AppTextStyle.labelSmall.copyWith(
                color: isWorking
                    ? context.colorScheme.onSurface.withValues(alpha: 0.3)
                    : context.colorScheme.primary,
                fontSize: 11,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickDirectory(BuildContext context) async {
    final initialPath = path != null && await Directory(path!).exists()
        ? path!
        : null;

    String? result;
    if (Platform.isMacOS) {
      result = await _fsChannel.invokeMethod<String>('pickDirectory', {
        if (initialPath != null) 'initialDirectory': initialPath,
        'title': 'Choose Backup Location',
      });
    } else {
      result = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Choose Backup Location',
        initialDirectory: initialPath,
      );
    }

    if (result != null && context.mounted) {
      context.read<BackupBloc>().add(BackupLocationChanged(result));
    }
  }
}
