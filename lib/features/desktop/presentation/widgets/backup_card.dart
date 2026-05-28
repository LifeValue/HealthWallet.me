import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:health_wallet/features/desktop/lww_sync/presentation/bloc/lww_sync_bloc.dart';
import 'package:health_wallet/features/desktop/presentation/widgets/info_row.dart';
import 'package:health_wallet/core/l10n/l10n.dart';

class BackupCard extends StatefulWidget {
  final DesktopSyncState syncState;
  final BackupState backupState;

  const BackupCard({
    super.key,
    required this.syncState,
    required this.backupState,
  });

  @override
  State<BackupCard> createState() => _BackupCardState();
}

class _BackupCardState extends State<BackupCard> {
  final _nameController = TextEditingController();
  bool _syncFirst = true;
  bool _showForm = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _create() {
    final name = _nameController.text.trim();
    final effectiveName = name.isNotEmpty
        ? name
        : '${context.l10n.desktopBackup} ${DateFormat('MMM d, yyyy – HH:mm').format(DateTime.now())}';

    if (_syncFirst && widget.syncState.connectionStatus == ConnectionStatus.connected) {
      try { context.read<LwwSyncBloc>().add(const SyncTriggered()); } catch (_) {}
    }

    try { context.read<BackupBloc>().add(BackupRequested(name: effectiveName)); } catch (_) {}
    _nameController.clear();
    setState(() => _showForm = false);
  }

  @override
  Widget build(BuildContext context) {
    final isConnected =
        widget.syncState.connectionStatus == ConnectionStatus.connected;
    final isWorking = widget.backupState.isBackingUp || widget.backupState.isRestoring;
    final selected = widget.backupState.selectedBackup;
    final defaultName = '${context.l10n.desktopBackup} ${DateFormat('MMM d, yyyy').format(DateTime.now())}';

    if (!widget.backupState.hasUserSelectedPath) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(Insets.medium),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.folder_open,
                size: 40,
                color: context.colorScheme.onSurface.withValues(alpha: 0.15),
              ),
              const SizedBox(height: Insets.normal),
              Text(
                context.l10n.desktopChooseWhereToSave,
                style: AppTextStyle.bodyMedium.copyWith(
                  color: context.colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: Insets.small),
              Text(
                context.l10n.desktopSelectBackupFolder,
                style: AppTextStyle.labelSmall.copyWith(
                  color: context.colorScheme.onSurface.withValues(alpha: 0.4),
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: Insets.normal),
              SizedBox(
                width: 200,
                child: AppButton(
                  label: context.l10n.desktopChooseLocation,
                  onPressed: () => _BackupLocationRow.pickAndSetDirectory(context),
                  height: 36,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isWorking)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Insets.medium),
            child: LinearProgressIndicator(
              value: widget.backupState.progress > 0 ? widget.backupState.progress : null,
              minHeight: 3,
            ),
          ),
        if (widget.backupState.error != null)
          Padding(
            padding: const EdgeInsets.only(left: Insets.medium, right: Insets.medium, bottom: Insets.small),
            child: Text(
              widget.backupState.error!,
              style: TextStyle(color: context.colorScheme.error, fontSize: 12),
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(left: Insets.medium, right: Insets.medium, top: Insets.normal),
          child: Text(
            'Location',
            style: AppTextStyle.labelSmall.copyWith(
              color: context.colorScheme.onSurface.withValues(alpha: 0.5),
              fontSize: 11,
            ),
          ),
        ),
        const SizedBox(height: Insets.extraSmall),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Insets.medium),
          child: _BackupLocationRow(
            path: widget.backupState.backupPath,
            isWorking: isWorking,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: Insets.medium, right: Insets.medium, top: Insets.normal, bottom: Insets.small),
          child: Text(
            'History',
            style: AppTextStyle.labelSmall.copyWith(
              color: context.colorScheme.onSurface.withValues(alpha: 0.5),
              fontSize: 11,
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Insets.medium),
            child: selected != null
                ? SingleChildScrollView(
                    child: _BackupPreview(
                      backup: selected,
                      isWorking: isWorking,
                      isConnected: isConnected,
                    ),
                  )
                : _BackupList(
                    backups: widget.backupState.backupHistory,
                    isWorking: isWorking,
                  ),
          ),
        ),
        if (selected == null) ...[
          Divider(height: 1, color: context.theme.dividerColor),
          Padding(
            padding: const EdgeInsets.all(Insets.medium),
            child: Column(
              children: [
          if (!_showForm) ...[
            Center(
              child: SizedBox(
                width: 200,
                child: AppButton(
                  label: isWorking ? context.l10n.desktopBackingUp : context.l10n.desktopCreateBackup,
                  onPressed: !isWorking
                      ? () => setState(() => _showForm = true)
                      : null,
                  height: 36,
                ),
              ),
            ),
          ] else ...[
            TextField(
              controller: _nameController,
              autofocus: true,
              style: AppTextStyle.bodyMedium.copyWith(
                color: context.colorScheme.onSurface,
                fontSize: 13,
              ),
              decoration: InputDecoration(
                hintText: defaultName,
                hintStyle: AppTextStyle.bodyMedium.copyWith(
                  color: context.colorScheme.onSurface.withValues(alpha: 0.2),
                  fontSize: 13,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: context.colorScheme.onSurface.withValues(alpha: 0.08),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: context.colorScheme.onSurface.withValues(alpha: 0.08),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: context.colorScheme.primary),
                ),
              ),
              onSubmitted: (_) => _create(),
            ),
            const SizedBox(height: Insets.normal),
            GestureDetector(
              onTap: isConnected
                  ? () => setState(() => _syncFirst = !_syncFirst)
                  : null,
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: Checkbox(
                      value: isConnected ? _syncFirst : false,
                      onChanged: isConnected
                          ? (v) => setState(() => _syncFirst = v ?? false)
                          : null,
                      activeColor: context.colorScheme.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    context.l10n.desktopSyncWithPhoneFirst,
                    style: AppTextStyle.labelSmall.copyWith(
                      color: isConnected
                          ? context.colorScheme.onSurface.withValues(alpha: 0.5)
                          : context.colorScheme.onSurface.withValues(alpha: 0.2),
                      fontSize: 11,
                    ),
                  ),
                  if (!isConnected) ...[
                      const SizedBox(width: 6),
                      Text(
                        context.l10n.desktopNotConnected,
                        style: AppTextStyle.labelSmall.copyWith(
                          color: context.colorScheme.onSurface.withValues(alpha: 0.15),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            const SizedBox(height: Insets.normal),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                    onPressed: () => setState(() {
                      _showForm = false;
                      _nameController.clear();
                    }),
                    child: Text(
                      context.l10n.cancel,
                      style: TextStyle(
                        color: context.colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 160,
                    child: AppButton(
                      label: context.l10n.desktopStartBackup,
                      onPressed: _create,
                      height: 36,
                    ),
                  ),
                ],
              ),
            ],
            ],
          ),
        ),
        ],
      ],
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
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
              Icon(
                Icons.shield_outlined,
                size: 32,
                color: context.colorScheme.onSurface.withValues(alpha: 0.15),
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.desktopNoBackupsYet,
                style: AppTextStyle.bodySmall.copyWith(
                  color: context.colorScheme.onSurface.withValues(alpha: 0.4),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                context.l10n.desktopCreateFirstBackup,
                style: AppTextStyle.labelSmall.copyWith(
                  color: context.colorScheme.onSurface.withValues(alpha: 0.25),
                  fontSize: 11,
                ),
                textAlign: TextAlign.center,
              ),
            ],
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
          color: context.theme.dividerColor,
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
    final displayName = backup.name.isNotEmpty
        ? backup.name
        : DateFormat.yMMMd().add_Hm().format(backup.timestamp);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: Insets.smallNormal,
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
                    displayName,
                    style: AppTextStyle.labelSmall.copyWith(
                      color: context.colorScheme.onSurface,
                      fontWeight: isLatest ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  Text(
                    [
                      if (backup.name.isNotEmpty)
                        DateFormat.yMMMd().add_Hm().format(backup.timestamp),
                      '${backup.recordCount} ${context.l10n.records.toLowerCase()}',
                      _formatBytes(backup.sizeBytes),
                    ].join('  \u2022  '),
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
    final displayName = backup.name.isNotEmpty
        ? backup.name
        : '${context.l10n.desktopBackupFrom} ${DateFormat.yMMMd().format(backup.timestamp)}';

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
                  Icon(Icons.arrow_back, size: 16, color: context.colorScheme.primary),
                  const SizedBox(width: 4),
                  Text(
                    context.l10n.desktopAllBackups,
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
        Text(
          displayName,
          style: AppTextStyle.bodyMedium.copyWith(
            color: context.colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: Insets.small),
        InfoRow(
          label: context.l10n.desktopDate,
          value: DateFormat.yMMMd().add_Hm().format(backup.timestamp),
        ),
        InfoRow(
          label: context.l10n.records,
          value: backup.recordCount.toString(),
        ),
        InfoRow(
          label: context.l10n.desktopSize,
          value: _formatBytes(backup.sizeBytes),
        ),
        InfoRow(
          label: context.l10n.desktopChecksum,
          value: backup.checksum.length > 16
              ? '${backup.checksum.substring(0, 16)}\u2026'
              : backup.checksum,
        ),
        const SizedBox(height: Insets.normal),
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: context.l10n.desktopRestoreThisBackup,
                onPressed: !isWorking
                    ? () => _confirmRestore(context, backup)
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
            ),
          ],
        ),
      ],
    );
  }

  void _confirmRestore(BuildContext context, BackupEntry backup) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.desktopRestoreBackupTitle),
        content: Text(
          context.l10n.desktopRestoreBackupMessage(
            backup.name.isNotEmpty ? backup.name : '${context.l10n.desktopBackupFrom} ${DateFormat.yMMMd().format(backup.timestamp)}',
            backup.recordCount,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(context.l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context
                  .read<BackupBloc>()
                  .add(RestoreRequested(backupId: backup.id));
            },
            child: Text(
              context.l10n.desktopRestore,
              style: TextStyle(
                color: AppColors.warning,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, BackupEntry backup) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.desktopDeleteBackupTitle),
        content: Text(
          context.l10n.desktopDeleteBackupMessage(
            backup.name.isNotEmpty ? backup.name : '${context.l10n.desktopBackupFrom} ${DateFormat.yMMMd().format(backup.timestamp)}',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(context.l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context
                  .read<BackupBloc>()
                  .add(BackupDeleted(backupId: backup.id));
            },
            child: Text(
              context.l10n.desktopDelete,
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
              context.l10n.desktopChange,
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

  static const _fsChannel = MethodChannel('dev.lifevalue.healthwallet/fs');

  static Future<void> pickAndSetDirectory(BuildContext context, {String? initialPath}) async {
    String? result;
    if (Platform.isMacOS) {
      result = await _fsChannel.invokeMethod<String>('pickDirectory', {
        if (initialPath != null) 'initialDirectory': initialPath,
        'title': context.l10n.desktopChooseBackupLocation,
      });
    } else {
      result = await FilePicker.platform.getDirectoryPath(
        dialogTitle: context.l10n.desktopChooseBackupLocation,
        initialDirectory: initialPath,
      );
    }

    if (result != null && context.mounted) {
      context.read<BackupBloc>().add(BackupLocationChanged(result));
    }
  }

  Future<void> _pickDirectory(BuildContext context) async {
    final initialPath = path != null && await Directory(path!).exists()
        ? path!
        : null;
    await pickAndSetDirectory(context, initialPath: initialPath);
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
