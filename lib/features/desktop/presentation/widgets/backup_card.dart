import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/core/widgets/app_button.dart';
import 'package:health_wallet/features/desktop/backup/domain/entity/backup_entry.dart';
import 'package:health_wallet/features/desktop/backup/presentation/bloc/backup_bloc.dart';
import 'package:health_wallet/features/desktop/communication/presentation/bloc/communication_bloc.dart';
import 'package:health_wallet/features/desktop/presentation/widgets/desktop_card.dart';
import 'package:health_wallet/features/desktop/presentation/widgets/info_row.dart';

class BackupCard extends StatelessWidget {
  final DesktopSyncState syncState;
  final BackupState backupState;

  const BackupCard({
    super.key,
    required this.syncState,
    required this.backupState,
  });

  @override
  Widget build(BuildContext context) {
    final isConnected =
        syncState.connectionStatus == ConnectionStatus.connected;
    final isWorking = backupState.isBackingUp || backupState.isRestoring;
    final selected = backupState.selectedBackup;

    return DesktopCard(
      title: 'Backup',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isWorking)
            Padding(
              padding: const EdgeInsets.only(bottom: Insets.small),
              child: LinearProgressIndicator(
                value: backupState.progress > 0 ? backupState.progress : null,
                minHeight: 3,
              ),
            ),
          if (backupState.error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: Insets.small),
              child: Text(
                backupState.error!,
                style: TextStyle(
                  color: context.colorScheme.error,
                  fontSize: 12,
                ),
              ),
            ),
          _BackupLocationRow(
            path: backupState.backupPath,
            isWorking: isWorking,
          ),
          const SizedBox(height: Insets.small),
          if (selected != null) ...[
            _BackupPreview(
              backup: selected,
              isWorking: isWorking,
              isConnected: isConnected,
            ),
          ] else ...[
            _BackupList(
              backups: backupState.backupHistory,
              isWorking: isWorking,
            ),
          ],
          const SizedBox(height: Insets.normal),
          AppButton(
            label: backupState.isBackingUp ? 'Backing up...' : 'Backup Now',
            onPressed: isConnected && !isWorking
                ? () => context
                    .read<BackupBloc>()
                    .add(const BackupRequested())
                : null,
            height: 36,
          ),
        ],
      ),
    );
  }
}

class _BackupList extends StatelessWidget {
  final List<BackupEntry> backups;
  final bool isWorking;

  const _BackupList({required this.backups, required this.isWorking});

  @override
  Widget build(BuildContext context) {
    if (backups.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: Insets.normal),
        child: Text(
          'No backups yet',
          style: AppTextStyle.bodySmall.copyWith(
            color: context.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 240),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: backups.length,
        separatorBuilder: (_, __) => Divider(
          height: 1,
          color: context.colorScheme.outlineVariant,
        ),
        itemBuilder: (context, index) {
          final backup = backups[index];
          return _BackupTile(
            backup: backup,
            isLatest: index == 0,
            onTap: isWorking
                ? null
                : () => context
                    .read<BackupBloc>()
                    .add(BackupSelected(backup)),
          );
        },
      ),
    );
  }
}

class _BackupTile extends StatelessWidget {
  final BackupEntry backup;
  final bool isLatest;
  final VoidCallback? onTap;

  const _BackupTile({
    required this.backup,
    required this.isLatest,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: Insets.small,
          horizontal: Insets.extraSmall,
        ),
        child: Row(
          children: [
            Icon(
              Icons.archive_outlined,
              size: 20,
              color: isLatest
                  ? context.colorScheme.primary
                  : context.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
            const SizedBox(width: Insets.small),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat.yMMMd().add_Hm().format(backup.timestamp),
                    style: AppTextStyle.labelSmall.copyWith(
                      color: context.colorScheme.onSurface,
                      fontWeight: isLatest ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  Text(
                    '${backup.recordCount} records \u2022 ${_formatBytes(backup.sizeBytes)}',
                    style: AppTextStyle.labelSmall.copyWith(
                      color: context.colorScheme.onSurface.withValues(alpha: 0.5),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 18,
              color: context.colorScheme.onSurface.withValues(alpha: 0.3),
            ),
          ],
        ),
      ),
    );
  }
}

class _BackupPreview extends StatelessWidget {
  final BackupEntry backup;
  final bool isWorking;
  final bool isConnected;

  const _BackupPreview({
    required this.backup,
    required this.isWorking,
    required this.isConnected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            InkWell(
              onTap: () => context
                  .read<BackupBloc>()
                  .add(const BackupSelected(null)),
              borderRadius: BorderRadius.circular(4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.arrow_back,
                    size: 16,
                    color: context.colorScheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'All backups',
                    style: AppTextStyle.labelSmall.copyWith(
                      color: context.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: Insets.normal),
        InfoRow(
          label: 'Date',
          value: DateFormat.yMMMd().add_Hm().format(backup.timestamp),
        ),
        InfoRow(
          label: 'Records',
          value: backup.recordCount.toString(),
        ),
        InfoRow(
          label: 'Size',
          value: _formatBytes(backup.sizeBytes),
        ),
        InfoRow(
          label: 'Checksum',
          value: backup.checksum.length > 16
              ? '${backup.checksum.substring(0, 16)}\u2026'
              : backup.checksum,
        ),
        const SizedBox(height: Insets.normal),
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: 'Restore',
                onPressed: isConnected && !isWorking
                    ? () => context
                        .read<BackupBloc>()
                        .add(RestoreRequested(backupId: backup.id))
                    : null,
                height: 36,
              ),
            ),
            const SizedBox(width: Insets.small),
            IconButton(
              onPressed: isWorking
                  ? null
                  : () => _confirmDelete(context, backup),
              icon: Icon(
                Icons.delete_outline,
                size: 20,
                color: isWorking
                    ? context.colorScheme.onSurface.withValues(alpha: 0.3)
                    : AppColors.error,
              ),
              tooltip: 'Delete backup',
            ),
          ],
        ),
      ],
    );
  }

  void _confirmDelete(BuildContext context, BackupEntry backup) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Backup'),
        content: Text(
          'Delete backup from ${DateFormat.yMMMd().add_Hm().format(backup.timestamp)}?\n\nThis cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context
                  .read<BackupBloc>()
                  .add(BackupDeleted(backupId: backup.id));
            },
            child: Text(
              'Delete',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}

class _BackupLocationRow extends StatelessWidget {
  final String? path;
  final bool isWorking;

  const _BackupLocationRow({required this.path, required this.isWorking});

  @override
  Widget build(BuildContext context) {
    final displayPath = path ?? '...';
    final shortened = displayPath.length > 40
        ? '\u2026${displayPath.substring(displayPath.length - 40)}'
        : displayPath;

    return Row(
      children: [
        Icon(
          Icons.folder_outlined,
          size: 16,
          color: context.colorScheme.onSurface.withValues(alpha: 0.5),
        ),
        const SizedBox(width: Insets.extraSmall),
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
        const SizedBox(width: Insets.extraSmall),
        InkWell(
          onTap: isWorking ? null : () => _pickDirectory(context),
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Text(
              'Change',
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
    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Choose Backup Location',
      initialDirectory: path,
    );
    if (result != null && context.mounted) {
      context.read<BackupBloc>().add(BackupLocationChanged(result));
    }
  }
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}
