import 'dart:convert';

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
import 'package:health_wallet/features/desktop/communication/data/models/device_pairing.dart';
import 'package:health_wallet/features/desktop/communication/data/services/pairing_storage_service.dart';
import 'package:health_wallet/features/desktop/communication/presentation/bloc/communication_bloc.dart';
import 'package:health_wallet/features/desktop/lww_sync/presentation/bloc/lww_sync_bloc.dart';
import 'package:health_wallet/features/desktop/presentation/widgets/info_row.dart';
import 'package:health_wallet/features/sync/presentation/widgets/qr_scanner_widget.dart';
import 'package:qr_flutter/qr_flutter.dart';

class SyncDialog extends StatefulWidget {
  static void show(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
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
                            child: SyncDialog(
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
    );
  }

  final DesktopSyncState commState;
  final LwwSyncState syncState;

  const SyncDialog({
    super.key,
    required this.commState,
    required this.syncState,
  });

  @override
  State<SyncDialog> createState() => _SyncDialogState();
}

class _SyncDialogState extends State<SyncDialog> {

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(Insets.medium),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildConnectionSection(context),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Insets.normal),
              child: Divider(
                color: context.colorScheme.onSurface.withValues(alpha: 0.06),
                height: 1,
              ),
            ),
            _buildDesktopSyncSection(context),
            if (widget.commState.connectionStatus != ConnectionStatus.connected) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: Insets.normal),
                child: Divider(
                  color: context.colorScheme.onSurface.withValues(alpha: 0.06),
                  height: 1,
                ),
              ),
              _buildPairingSection(context),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionSection(BuildContext context) {
    final isConnected =
        widget.commState.connectionStatus == ConnectionStatus.connected;
    final isDiscovering =
        widget.commState.connectionStatus == ConnectionStatus.discovering;

    final Color dotColor;
    final String statusLabel;

    final isDesktop = getIt<AppPlatform>().isDesktop;
    final remoteName = widget.commState.connectedDeviceName
        ?? (isDesktop ? null : widget.commState.pairedDevice?.deviceName);

    if (isConnected) {
      dotColor = AppColors.success;
      statusLabel = remoteName != null
          ? 'Connected to $remoteName'
          : 'Connected';
    } else if (isDiscovering) {
      dotColor = AppColors.warning;
      statusLabel = remoteName != null
          ? 'Reconnecting to $remoteName...'
          : 'Reconnecting...';
    } else {
      dotColor = AppColors.error;
      statusLabel = remoteName != null
          ? 'Disconnected from $remoteName'
          : 'Disconnected';
    }

    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: dotColor,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: Insets.small),
        Expanded(
          child: Text(
            statusLabel,
            style: AppTextStyle.bodyMedium.copyWith(color: dotColor),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (isConnected) ...[
          _TransportBadge(transport: widget.commState.connectionTransport),
          const SizedBox(width: Insets.small),
          GestureDetector(
            onTap: () {
              try {
                context.read<CommunicationBloc>().add(const CommunicationManualDisconnect());
              } catch (_) {
                getIt<CommunicationBloc>().add(const CommunicationManualDisconnect());
              }
            },
            child: Icon(
              Icons.link_off,
              size: 18,
              color: context.colorScheme.onSurface.withValues(alpha: 0.3),
            ),
          ),
        ],
        if (!isConnected && widget.commState.pairedDevice != null && !isDiscovering)
          GestureDetector(
            onTap: () {
              try {
                context.read<CommunicationBloc>().add(const CommunicationConnectionRequested());
              } catch (_) {
                getIt<CommunicationBloc>().add(const CommunicationConnectionRequested());
              }
            },
            child: Text(
              'Reconnect',
              style: AppTextStyle.labelSmall.copyWith(
                color: context.colorScheme.primary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDesktopSyncSection(BuildContext context) {
    final isSyncing = widget.syncState.syncStatus == LwwSyncStatus.syncing;
    final isConnected =
        widget.commState.connectionStatus == ConnectionStatus.connected;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InfoRow(
          label: 'Last synced',
          value: widget.syncState.lastSyncTime != null
              ? DateFormatUtils.getSincePretty(widget.syncState.lastSyncTime!)
              : 'Not yet',
        ),
        if (widget.syncState.sentRows > 0 || widget.syncState.receivedRows > 0)
          InfoRow(
            label: 'Transfer',
            value:
                '${widget.syncState.sentRows} sent, ${widget.syncState.receivedRows} received',
          ),
        if (widget.syncState.pendingChangeCount > 0)
          InfoRow(
            label: 'Pending',
            value: '${widget.syncState.pendingChangeCount} changes',
          ),
        if (widget.syncState.error != null) ...[
          const SizedBox(height: Insets.small),
          Text(
            widget.syncState.error!,
            style: AppTextStyle.labelSmall.copyWith(color: AppColors.error),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        if (isSyncing) ...[
          const SizedBox(height: Insets.small),
          if (widget.syncState.currentTable != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                'Syncing ${_formatTableName(widget.syncState.currentTable!)}...',
                style: AppTextStyle.labelSmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          LinearProgressIndicator(
            value: widget.syncState.totalTables > 0
                ? widget.syncState.completedTables / widget.syncState.totalTables
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
                      try {
                        context.read<LwwSyncBloc>().add(const SyncTriggered());
                      } catch (_) {
                        getIt<LwwSyncBloc>().add(const SyncTriggered());
                      }
                    }
                  : null,
              height: 36,
            ),
          ),
        ),
        if (widget.syncState.lastSyncTime != null) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: Insets.normal),
            child: Divider(
              color: context.colorScheme.onSurface.withValues(alpha: 0.06),
              height: 1,
            ),
          ),
          Text(
            'Recent',
            style: AppTextStyle.labelSmall.copyWith(
              color: context.colorScheme.onSurface.withValues(alpha: 0.35),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: Insets.small),
          _SyncHistoryEntry(
            time: widget.syncState.lastSyncTime!,
            deviceName: widget.commState.connectedDeviceName
                ?? (getIt<AppPlatform>().isDesktop ? null : widget.commState.pairedDevice?.deviceName),
            sentRows: widget.syncState.sentRows,
            receivedRows: widget.syncState.receivedRows,
            isSynced: widget.syncState.isSynced,
          ),
        ],
      ],
    );
  }

  Widget _buildPairingSection(BuildContext context) {
    final hasPairing = widget.commState.pairedDevice != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pairing',
          style: AppTextStyle.bodyMedium.copyWith(
            color: context.colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (hasPairing && getIt<AppPlatform>().isMobile) ...[
          const SizedBox(height: Insets.small),
          InfoRow(
            label: 'Desktop',
            value: widget.commState.pairedDevice!.deviceName,
          ),
        ],
        if (hasPairing && getIt<AppPlatform>().isDesktop) ...[
          const SizedBox(height: Insets.normal),
          Center(
            child: Container(
              padding: const EdgeInsets.all(Insets.normal),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: QrImageView(
                data: jsonEncode({
                  'device_id': widget.commState.pairedDevice!.deviceId,
                  'ip': widget.commState.pairedDevice!.lastIp,
                  'port': widget.commState.pairedDevice!.lastPort,
                  'pairing_key': widget.commState.pairedDevice!.pairingKey,
                  'device_name': widget.commState.pairedDevice!.deviceName,
                  'os': widget.commState.pairedDevice!.os,
                }),
                version: QrVersions.auto,
                size: 200,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              'Scan from your phone to pair',
              style: AppTextStyle.labelSmall.copyWith(
                color: context.colorScheme.onSurface.withValues(alpha: 0.3),
                fontSize: 11,
              ),
            ),
          ),
        ],
        const SizedBox(height: Insets.normal),
        if (getIt<AppPlatform>().isDesktop)
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: hasPairing ? 'New QR Code' : 'Generate QR Code',
                  onPressed: () {
                    getIt<CommunicationBloc>()
                        .add(const CommunicationPairingRequested());
                  },
                  variant: AppButtonVariant.outlined,
                  height: 36,
                ),
              ),
              const SizedBox(width: Insets.small),
              Expanded(
                child: AppButton(
                  label: 'Scan Network',
                  onPressed: hasPairing
                      ? () => context
                          .read<CommunicationBloc>()
                          .add(const CommunicationConnectionRequested())
                      : null,
                  variant: AppButtonVariant.outlined,
                  height: 36,
                ),
              ),
            ],
          ),
        if (getIt<AppPlatform>().isMobile)
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Scan QR Code',
                  onPressed: () => _openMobileQRScanner(context),
                  height: 36,
                ),
              ),
              const SizedBox(width: Insets.small),
              Expanded(
                child: AppButton(
                  label: 'Scan Network',
                  onPressed: hasPairing
                      ? () {
                          try {
                            context.read<CommunicationBloc>().add(const CommunicationConnectionRequested());
                          } catch (_) {
                            getIt<CommunicationBloc>().add(const CommunicationConnectionRequested());
                          }
                        }
                      : null,
                  variant: AppButtonVariant.outlined,
                  height: 36,
                ),
              ),
            ],
          ),
      ],
    );
  }

  void _openMobileQRScanner(BuildContext context) {
    final rootNavigator = Navigator.of(context, rootNavigator: true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    rootNavigator.pop();

    rootNavigator.push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => _FullScreenQRScanner(
          onQRCodeDetected: (qrData) => _handleQRCodeDetected(
            rootNavigator,
            scaffoldMessenger,
            qrData,
          ),
        ),
      ),
    );
  }

  void _handleQRCodeDetected(
    NavigatorState navigator,
    ScaffoldMessengerState messenger,
    String qrData,
  ) {
    try {
      final json = jsonDecode(qrData) as Map<String, dynamic>;
      if (json.containsKey('pairing_key') && json.containsKey('device_id')) {
        final pairing = DevicePairing(
          deviceId: json['device_id'] as String,
          deviceName: json['device_name'] as String,
          pairingKey: json['pairing_key'] as String,
          lastIp: json['ip'] as String,
          lastPort: json['port'] as int,
          pairedAt: DateTime.now(),
          os: json['os'] as String?,
        );

        _handlePairing(navigator, messenger, pairing);
        return;
      }
    } catch (_) {}

    navigator.pop();
    messenger.showSnackBar(
      const SnackBar(content: Text('Unrecognized QR code format')),
    );
  }

  Future<void> _handlePairing(
    NavigatorState navigator,
    ScaffoldMessengerState messenger,
    DevicePairing pairing,
  ) async {
    final pairingStorage = getIt<PairingStorageService>();
    await pairingStorage.savePairing(pairing);

    navigator.pop();

    messenger.showSnackBar(
      SnackBar(content: Text('Paired with ${pairing.deviceName}')),
    );

    getIt<CommunicationBloc>()
        .add(CommunicationPairingCompleted(pairing: pairing));
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

class _FullScreenQRScanner extends StatelessWidget {
  final Function(String) onQRCodeDetected;

  const _FullScreenQRScanner({required this.onQRCodeDetected});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Scan QR Code',
          style: AppTextStyle.titleMedium.copyWith(color: Colors.white),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Insets.medium),
          child: QRScannerWidget(
            onQRCodeDetected: onQRCodeDetected,
            onCancel: () => Navigator.of(context).pop(),
          ),
        ),
      ),
    );
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
                  color: context.colorScheme.onSurface.withValues(alpha: 0.6),
                  fontSize: 12,
                ),
              ),
              if (hasTransfer)
                Text(
                  '$sentRows sent · $receivedRows received',
                  style: AppTextStyle.labelSmall.copyWith(
                    color: context.colorScheme.onSurface.withValues(alpha: 0.3),
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

class _TransportBadge extends StatelessWidget {
  final ConnectionTransport transport;

  const _TransportBadge({required this.transport});

  @override
  Widget build(BuildContext context) {
    final (label, icon) = switch (transport) {
      ConnectionTransport.tcp => ('WiFi', Icons.wifi),
      ConnectionTransport.multipeerConnectivity => ('Direct', Icons.devices),
      ConnectionTransport.unknown => ('Unknown', Icons.help_outline),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.small,
        vertical: Insets.extraSmall,
      ),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.success),
          const SizedBox(width: Insets.extraSmall),
          Text(
            label,
            style: AppTextStyle.labelSmall.copyWith(color: AppColors.success),
          ),
        ],
      ),
    );
  }
}
