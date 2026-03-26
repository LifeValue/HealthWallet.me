import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/core/widgets/app_button.dart';
import 'package:health_wallet/features/share_records/domain/entity/peer_device.dart';
import 'package:health_wallet/features/share_records/presentation/bloc/share_records_bloc.dart';
import 'package:health_wallet/features/share_records/presentation/bloc/share_records_event.dart';
import 'package:health_wallet/features/share_records/presentation/bloc/share_records_state.dart';
import 'package:health_wallet/features/share_records/presentation/widgets/peer_invitation_view.dart';
import 'package:health_wallet/features/share_records/presentation/widgets/peer_search_status_view.dart';
import 'package:health_wallet/gen/assets.gen.dart';

class PeerDiscoveryView extends StatefulWidget {
  final ShareRecordsState state;

  const PeerDiscoveryView({super.key, required this.state});

  @override
  State<PeerDiscoveryView> createState() => _PeerDiscoveryViewState();
}

class _PeerDiscoveryViewState extends State<PeerDiscoveryView> {
  Timer? _searchTimer;
  bool _hasTimedOut = false;

  @override
  void initState() {
    super.initState();
    _startSearchTimer();
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    super.dispose();
  }

  void _startSearchTimer() {
    _searchTimer?.cancel();
    setState(() => _hasTimedOut = false);
    _searchTimer = Timer(const Duration(seconds: 30), () {
      if (mounted && widget.state.discoveredPeers.isEmpty) {
        setState(() => _hasTimedOut = true);
      }
    });
  }

  void _handleRetry() {
    _startSearchTimer();
    context.read<ShareRecordsBloc>().add(
          const ShareRecordsEvent.selectionConfirmed(),
        );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.state.isReceiving && widget.state.hasPendingInvitation) {
      return PeerInvitationView(state: widget.state);
    }

    if (widget.state.discoveredPeers.isEmpty) {
      return PeerSearchStatusView(
        hasTimedOut: _hasTimedOut,
        wifiToggleNeeded: widget.state.wifiToggleNeeded,
        onRetry: _handleRetry,
        bottomBar: _buildBottomBar(context),
      );
    }

    return Column(
      children: [
        _buildHeader(context),
        Expanded(child: _buildDeviceList(context)),
        _buildBottomBar(context),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(Insets.normal),
          child: Text(
            context.l10n.shareFoundDevices(widget.state.discoveredPeers.length),
            style: AppTextStyle.titleSmall.copyWith(
              color: context.colorScheme.onSurface,
            ),
          ),
        ),
        Divider(
          height: 1,
          thickness: 1,
          color: context.theme.dividerColor,
        ),
      ],
    );
  }

  Widget _buildDeviceList(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(Insets.normal),
      itemCount: widget.state.discoveredPeers.length,
      itemBuilder: (context, index) {
        final peer = widget.state.discoveredPeers[index];
        return _PeerDeviceTile(
          peer: peer,
          onTap: () {
            context.read<ShareRecordsBloc>().add(
                  ShareRecordsEvent.peerSelected(peer.deviceId),
                );
          },
        );
      },
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Insets.normal,
          Insets.normal,
          Insets.normal,
          Insets.normal,
        ),
        child: AppButton(
          onPressed: () {
            context.read<ShareRecordsBloc>().add(
                  const ShareRecordsEvent.sendModeSelected(),
                );
          },
          label: context.l10n.cancel,
          variant: AppButtonVariant.outlined,
        ),
      ),
    );
  }
}

class _PeerDeviceTile extends StatelessWidget {
  final PeerDevice peer;
  final VoidCallback onTap;

  const _PeerDeviceTile({required this.peer, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: Insets.small),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: context.theme.dividerColor),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(Insets.normal),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(12),
                child: Assets.icons.deviceFound.svg(
                  colorFilter: const ColorFilter.mode(
                    Colors.white,
                    BlendMode.srcIn,
                  ),
                ),
              ),
              const SizedBox(width: Insets.normal),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      peer.displayName,
                      style: AppTextStyle.titleSmall.copyWith(
                        color: context.colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.l10n.shareHealthWalletDevice,
                      style: AppTextStyle.labelMedium.copyWith(
                        color: context.colorScheme.onSurface
                            .withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: context.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
