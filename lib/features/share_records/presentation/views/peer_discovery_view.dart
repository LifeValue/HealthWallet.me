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
      return _InvitationView(state: widget.state);
    }

    if (widget.state.discoveredPeers.isEmpty) {
      return _buildSearchingView(context);
    }

    return Column(
      children: [
        _buildHeader(context),
        Expanded(child: _buildDeviceList(context)),
        _buildBottomBar(context),
      ],
    );
  }

  Widget _buildSearchingView(BuildContext context) {
    if (widget.state.wifiToggleNeeded) {
      return _buildWifiToggleView(context);
    }

    if (_hasTimedOut) {
      return _buildNoDevicesFoundView(context);
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Insets.normal,
            Insets.small,
            Insets.normal,
            Insets.normal,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Searching for nearby devices...',
                style: AppTextStyle.titleMedium.copyWith(
                  color: context.colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              RichText(
                text: TextSpan(
                  style: AppTextStyle.bodyMedium.copyWith(
                    color: context.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  children: [
                    const TextSpan(text: 'Make sure the other device has the '),
                    TextSpan(
                      text: 'HealthWallet.me',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const TextSpan(text: ' opened'),
                  ],
                ),
              ),
              const SizedBox(height: Insets.small),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.warning.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Assets.icons.information.svg(
                        width: 20,
                        height: 20,
                        colorFilter: const ColorFilter.mode(
                          AppColors.warning,
                          BlendMode.srcIn,
                        ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: AppTextStyle.labelLarge.copyWith(
                            color: context.colorScheme.onSurface,
                          ),
                          children: [
                            const TextSpan(text: 'The '),
                            TextSpan(
                              text: 'receiving device',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: context.colorScheme.onSurface,
                              ),
                            ),
                            const TextSpan(text: ' must have '),
                            TextSpan(
                              text: 'Share Proximity',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: context.colorScheme.onSurface,
                              ),
                            ),
                            const TextSpan(text: ' '),
                            TextSpan(
                              text: 'ON',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: context.colorScheme.onSurface,
                              ),
                            ),
                            const TextSpan(
                                text:
                                    ' in Preferences to be discoverable.'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Divider(
          height: 1,
          thickness: 1,
          color: context.theme.dividerColor,
        ),
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 140,
                  height: 140,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 140,
                        height: 140,
                        child: CircularProgressIndicator(
                          strokeWidth: 4,
                          color: AppColors.primary.withValues(alpha: 0.3),
                          strokeCap: StrokeCap.round,
                        ),
                      ),
                      SizedBox(
                        width: 80,
                        height: 80,
                        child: Assets.images.device.svg(
                          colorFilter: ColorFilter.mode(
                            AppColors.primary,
                            BlendMode.srcIn,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 48),
                Text(
                  'Search for devices...',
                  style: AppTextStyle.bodyLarge.copyWith(
                    color: context.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
        _buildBottomBar(context),
      ],
    );
  }

  Widget _buildNoDevicesFoundView(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Insets.normal,
            Insets.small,
            Insets.normal,
            Insets.normal,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'No Devices Found',
                style: AppTextStyle.titleMedium.copyWith(
                  color: context.colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              RichText(
                text: TextSpan(
                  style: AppTextStyle.bodyMedium.copyWith(
                    color: context.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  children: [
                    const TextSpan(text: 'Make sure the other device has the '),
                    TextSpan(
                      text: 'HealthWallet.me',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const TextSpan(text: ' opened'),
                  ],
                ),
              ),
              const SizedBox(height: Insets.small),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.warning.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Assets.icons.information.svg(
                        width: 20,
                        height: 20,
                        colorFilter: const ColorFilter.mode(
                          AppColors.warning,
                          BlendMode.srcIn,
                        ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: AppTextStyle.labelLarge.copyWith(
                            color: context.colorScheme.onSurface,
                          ),
                          children: [
                            const TextSpan(text: 'The '),
                            TextSpan(
                              text: 'receiving device',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: context.colorScheme.onSurface,
                              ),
                            ),
                            const TextSpan(text: ' must have '),
                            TextSpan(
                              text: 'Share Proximity',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: context.colorScheme.onSurface,
                              ),
                            ),
                            const TextSpan(text: ' '),
                            TextSpan(
                              text: 'ON',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: context.colorScheme.onSurface,
                              ),
                            ),
                            const TextSpan(
                                text:
                                    ' in Preferences to be discoverable.'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Divider(
          height: 1,
          thickness: 1,
          color: context.theme.dividerColor,
        ),
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 200,
                  height: 200,
                  child: Assets.images.noDeviceFound.svg(),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Insets.normal),
                  child: AppButton(
                    onPressed: _handleRetry,
                    label: 'Retry',
                  ),
                ),
              ],
            ),
          ),
        ),
        _buildBottomBar(context),
      ],
    );
  }

  Widget _buildWifiToggleView(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Insets.normal,
            Insets.small,
            Insets.normal,
            Insets.normal,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Connection Issue',
                style: AppTextStyle.titleMedium.copyWith(
                  color: context.colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'WiFi Direct is unresponsive on this device.',
                style: AppTextStyle.bodyMedium.copyWith(
                  color: context.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
        Divider(
          height: 1,
          thickness: 1,
          color: context.theme.dividerColor,
        ),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Insets.normal),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(Insets.normal),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.warning.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.wifi_off, color: AppColors.warning),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'WiFi Direct unresponsive. Toggle WiFi off/on, then tap Retry.',
                            style: AppTextStyle.bodySmall.copyWith(
                              color: context.colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  AppButton(
                    onPressed: _handleRetry,
                    label: 'Retry',
                  ),
                ],
              ),
            ),
          ),
        ),
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
            'Found ${widget.state.discoveredPeers.length} device(s)',
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
          label: 'Cancel',
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
                      'HealthWallet Device',
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

class _InvitationView extends StatelessWidget {
  final ShareRecordsState state;

  const _InvitationView({required this.state});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.share,
                size: 40,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Incoming Transfer',
              style: AppTextStyle.titleLarge.copyWith(
                color: context.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${state.pendingInvitationDeviceName ?? "A device"} wants to share records with you',
              style: AppTextStyle.bodyMedium.copyWith(
                color: context.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(Insets.normal),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.visibility, color: AppColors.warning),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Records will be view-only and automatically deleted when you exit',
                      style: AppTextStyle.bodySmall.copyWith(
                        color: context.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      if (state.pendingInvitationId != null) {
                        context.read<ShareRecordsBloc>().add(
                              ShareRecordsEvent.invitationRejected(
                                state.pendingInvitationId!,
                              ),
                            );
                      }
                    },
                    child: const Text('Decline'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      if (state.pendingInvitationId != null) {
                        context.read<ShareRecordsBloc>().add(
                              ShareRecordsEvent.invitationAccepted(
                                state.pendingInvitationId!,
                              ),
                            );
                      }
                    },
                    child: const Text('Accept'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
