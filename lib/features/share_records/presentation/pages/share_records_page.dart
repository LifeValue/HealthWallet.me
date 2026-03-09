import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/records/domain/entity/i_fhir_resource.dart';
import 'package:health_wallet/features/share_records/core/share_permissions_helper.dart';
import 'package:health_wallet/features/share_records/presentation/bloc/share_records_bloc.dart';
import 'package:health_wallet/features/share_records/presentation/bloc/share_records_event.dart';
import 'package:health_wallet/features/share_records/presentation/bloc/share_records_state.dart';
import 'package:health_wallet/features/share_records/presentation/views/ephemeral_viewer_view.dart';
import 'package:health_wallet/features/share_records/presentation/views/peer_discovery_view.dart';
import 'package:health_wallet/features/share_records/presentation/views/record_selection_view.dart';
import 'package:health_wallet/features/share_records/presentation/views/session_ended_view.dart';
import 'package:health_wallet/features/share_records/presentation/views/session_monitoring_view.dart';
import 'package:health_wallet/features/share_records/presentation/views/transfer_views.dart';
import 'package:health_wallet/features/share_records/presentation/widgets/exit_confirmation_dialog.dart';
import 'package:health_wallet/core/widgets/custom_app_bar.dart';
import 'package:health_wallet/gen/assets.gen.dart';
import 'package:health_wallet/core/widgets/custom_arrow_tooltip.dart';
import 'package:health_wallet/features/records/presentation/bloc/records_bloc.dart';

@RoutePage()
class ShareRecordsPage extends StatelessWidget {
  final bool autoSelectSendMode;
  final List<IFhirResource>? preSelectedResources;
  final List<FhirType>? appliedFilters;
  final String? pendingInvitationId;
  final String? pendingInvitationDeviceName;
  final bool invitationPreAccepted;
  final bool hasReceivedData;

  const ShareRecordsPage({
    super.key,
    this.autoSelectSendMode = false,
    this.preSelectedResources,
    this.appliedFilters,
    this.pendingInvitationId,
    this.pendingInvitationDeviceName,
    this.invitationPreAccepted = false,
    this.hasReceivedData = false,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        final bloc = getIt<ShareRecordsBloc>()
          ..add(const ShareRecordsEvent.initialized());

        if (autoSelectSendMode) {
          bloc.add(const ShareRecordsEvent.sendModeSelected());

          if (preSelectedResources != null &&
              preSelectedResources!.isNotEmpty) {
            bloc.add(
                ShareRecordsEvent.allRecordsSelected(preSelectedResources!));
          }
        } else if (hasReceivedData) {
          bloc.add(const ShareRecordsEvent.receiverInitializedWithData());
        } else if (pendingInvitationId != null) {
          bloc.add(ShareRecordsEvent.receiverInitializedWithInvitation(
            invitationId: pendingInvitationId!,
            deviceName: pendingInvitationDeviceName ?? 'Unknown Device',
            preAccepted: invitationPreAccepted,
          ));
        } else {
          bloc.add(const ShareRecordsEvent.symmetricDiscoveryStarted());
        }

        return bloc;
      },
      child: _ShareRecordsView(
        appliedFilters: appliedFilters,
        preSelectedResources: preSelectedResources,
      ),
    );
  }
}

class _ShareRecordsView extends StatefulWidget {
  final List<FhirType>? appliedFilters;
  final List<IFhirResource>? preSelectedResources;

  const _ShareRecordsView({
    this.appliedFilters,
    this.preSelectedResources,
  });

  @override
  State<_ShareRecordsView> createState() => _ShareRecordsViewState();
}

class _ShareRecordsViewState extends State<_ShareRecordsView> {
  bool _showInfo = false;
  final GlobalKey _appBarInfoIconKey = GlobalKey();
  final GlobalKey _viewingInfoIconKey = GlobalKey();

  @override
  void dispose() {
    CustomArrowTooltip.dismiss();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ShareRecordsBloc, ShareRecordsState>(
      listenWhen: (prev, curr) =>
          prev.mode != ShareMode.idle && curr.mode == ShareMode.idle,
      listener: (context, state) {
        context.maybePop();
      },
      child: BlocConsumer<ShareRecordsBloc, ShareRecordsState>(
        listenWhen: (previous, current) =>
            previous.showExitConfirmationDialog !=
                current.showExitConfirmationDialog ||
            previous.showSettingsDialog != current.showSettingsDialog ||
            previous.hasError != current.hasError,
        listener: (context, state) {
          if (state.hasError && state.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.errorMessage!),
                backgroundColor: AppColors.error,
              ),
            );
          }

          if (state.showSettingsDialog) {
            _showSettingsDialog(context);
          }

          if (state.showExitConfirmationDialog) {
            _showExitConfirmationDialog(context);
          }
        },
        builder: (context, state) {
          return PopScope(
            canPop: state.mode == ShareMode.idle ||
                state.phase == SharePhase.sessionEnded ||
                state.phase == SharePhase.selectingRecords ||
                state.showExitConfirmationDialog,
            onPopInvokedWithResult: (didPop, result) {
              if (!didPop) {
                _handleBackPress(context, state);
              }
            },
            child: Scaffold(
              appBar: state.phase == SharePhase.selectingRecords
                  ? CustomAppBar(
                      leading: IconButton(
                        icon: const Icon(Icons.arrow_back_ios, size: 18),
                        padding: const EdgeInsets.only(left: 12),
                        constraints: const BoxConstraints(),
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                      titleWidget: _buildSelectionAppBarContent(context, state),
                    )
                  : state.phase == SharePhase.viewingRecords
                      ? CustomAppBar(
                          automaticallyImplyLeading: false,
                          titleWidget: _buildViewingAppBarContent(context, state),
                        )
                      : state.phase == SharePhase.sessionEnded
                          ? null
                          : state.phase == SharePhase.monitoringSession
                              ? CustomAppBar(
                                  leading: IconButton(
                                    icon: const Icon(Icons.close, size: 22),
                                    onPressed: () async {
                                      final confirmed = await ExitConfirmationDialog.show(context: context);
                                      if (confirmed == true && context.mounted) {
                                        context.read<ShareRecordsBloc>().add(
                                              const ShareRecordsEvent.killSessionRequested(),
                                            );
                                      }
                                    },
                                  ),
                                  titleWidget: Text(
                                    _getTitle(state),
                                    style: AppTextStyle.bodyLarge,
                                  ),
                                )
                              : state.phase == SharePhase.connecting
                                  ? CustomAppBar(
                                      leading: IconButton(
                                        icon: const Icon(Icons.close, size: 22),
                                        onPressed: () {
                                          final bloc = context.read<ShareRecordsBloc>();
                                          if (state.isSending) {
                                            bloc.add(const ShareRecordsEvent.sendModeSelected());
                                          } else {
                                            bloc.add(const ShareRecordsEvent.modeCleared());
                                          }
                                        },
                                      ),
                                      titleWidget: Text(
                                        _getTitle(state),
                                        style: AppTextStyle.bodyLarge,
                                      ),
                                    )
                                  : CustomAppBar(
                                      titleWidget: Text(
                                        _getTitle(state),
                                        style: AppTextStyle.bodyLarge,
                                      ),
                                    ),
              body: Column(
                children: [
                  if (_showInfo &&
                      state.phase == SharePhase.selectingRecords)
                    _buildInfoBanner(context),
                  Expanded(child: _buildBody(context, state)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSelectionAppBarContent(
      BuildContext context, ShareRecordsState state) {
    final count = state.selection.totalCount;
    final hasSelection = state.selection.isNotEmpty;

    return Row(
      children: [
        Text(
          '$count selected',
          style: AppTextStyle.bodyLarge.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const Spacer(),
        GestureDetector(
          key: _appBarInfoIconKey,
          onTap: () {
            CustomArrowTooltip.show(
              context: context,
              buttonKey: _appBarInfoIconKey,
              message: 'VIEW ONLY - Data will be deleted when you close the session or leave proximity area',
              backgroundColor: const Color(0xFFE37A3C),
              alignment: TooltipAlignment.alignRight,
              width: 240,
            );
          },
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12),
                width: 1,
              ),
            ),
            child: Center(
              child: Assets.icons.information.svg(
                width: 16,
                height: 16,
                colorFilter: ColorFilter.mode(
                  Theme.of(context).colorScheme.onSurface,
                  BlendMode.srcIn,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        TextButton(
          onPressed: () {
            final recordsBloc = context.read<RecordsBloc>();
            final allRecords = recordsBloc.state.resources;
            context.read<ShareRecordsBloc>().add(
                  ShareRecordsEvent.allRecordsSelected(allRecords),
                );
          },
          style: TextButton.styleFrom(
            minimumSize: Size.zero,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text('Select All', style: TextStyle(fontSize: 12)),
        ),
        if (hasSelection)
          TextButton(
            onPressed: () {
              context.read<ShareRecordsBloc>().add(
                    const ShareRecordsEvent.allRecordsDeselected(),
                  );
            },
            style: TextButton.styleFrom(
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Clear', style: TextStyle(fontSize: 12)),
          ),
      ],
    );
  }

  Widget _buildViewingAppBarContent(
      BuildContext context, ShareRecordsState state) {
    final receivedData = state.receivedData;
    final recordCount = receivedData?.recordCount ?? 0;
    final deviceName = receivedData?.senderDeviceName ?? 'Unknown Device';

    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.phone_iphone,
            size: 16,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: AppTextStyle.bodyLarge.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
              children: [
                TextSpan(
                  text: '$recordCount record${recordCount == 1 ? '' : 's'}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const TextSpan(text: ' shared from '),
                TextSpan(
                  text: deviceName,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          key: _viewingInfoIconKey,
          onTap: () {
            CustomArrowTooltip.show(
              context: context,
              buttonKey: _viewingInfoIconKey,
              message: 'VIEW ONLY - Data will be deleted when you exit',
              backgroundColor: const Color(0xFFE37A3C),
              alignment: TooltipAlignment.alignRight,
              width: 240,
            );
          },
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12),
                width: 1,
              ),
            ),
            child: Center(
              child: Assets.icons.information.svg(
                width: 16,
                height: 16,
                colorFilter: ColorFilter.mode(
                  Theme.of(context).colorScheme.onSurface,
                  BlendMode.srcIn,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoBanner(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.warning.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Assets.icons.information.svg(
            width: 18,
            height: 18,
            colorFilter: const ColorFilter.mode(
              AppColors.warning,
              BlendMode.srcIn,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Shared records are view-only. All data is automatically deleted when the session ends or the time limit expires.',
              style: TextStyle(
                color: AppColors.warning,
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ),
          TextButton(
            onPressed: () => setState(() => _showInfo = false),
            style: TextButton.styleFrom(
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'OK',
              style: TextStyle(
                color: AppColors.warning,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getTitle(ShareRecordsState state) {
    switch (state.phase) {
      case SharePhase.selectingRecords:
        return 'Share';
      case SharePhase.discoveringPeers:
        return state.isSending ? 'Find Devices' : 'Waiting...';
      case SharePhase.connecting:
        return 'Connecting';
      case SharePhase.transferring:
        return state.isSending ? 'Sending' : 'Receiving';
      case SharePhase.monitoringSession:
        return 'Session Active';
      case SharePhase.viewingRecords:
        return 'Viewing Records';
      case SharePhase.sessionEnded:
        return 'Complete';
      case SharePhase.error:
        return 'Error';
    }
  }

  Widget _buildBody(BuildContext context, ShareRecordsState state) {
    switch (state.phase) {
      case SharePhase.selectingRecords:
        return RecordSelectionView(
          appliedFilters: widget.appliedFilters,
          preSelectedResources: widget.preSelectedResources,
        );
      case SharePhase.discoveringPeers:
        return PeerDiscoveryView(state: state);
      case SharePhase.connecting:
        return ConnectingView(state: state);
      case SharePhase.transferring:
        return TransferProgressView(state: state);
      case SharePhase.monitoringSession:
        return SessionMonitoringView(state: state);
      case SharePhase.viewingRecords:
        return EphemeralViewerView(state: state);
      case SharePhase.sessionEnded:
        return SessionEndedView(state: state);
      case SharePhase.error:
        return ErrorView(state: state);
    }
  }

  void _handleBackPress(BuildContext context, ShareRecordsState state) async {
    final bloc = context.read<ShareRecordsBloc>();

    if (state.phase == SharePhase.monitoringSession) {
      final confirmed = await ExitConfirmationDialog.show(context: context);
      if (confirmed == true && context.mounted) {
        bloc.add(const ShareRecordsEvent.killSessionRequested());
      }
    } else if (state.phase == SharePhase.discoveringPeers) {
      bloc.add(const ShareRecordsEvent.sendModeSelected());
    } else if (state.receivedData != null) {
      bloc.add(const ShareRecordsEvent.sessionEndRequested());
    } else if (state.mode != ShareMode.idle) {
      bloc.add(const ShareRecordsEvent.modeCleared());
    } else {
      context.maybePop();
    }
  }

  void _showSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Permissions Required'),
        content: Text(SharePermissionsHelper.getPermissionExplanation()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              SharePermissionsHelper.openSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  Future<void> _showExitConfirmationDialog(BuildContext context) async {
    final result = await ExitConfirmationDialog.show(
      context: context,
    );

    if (result == true) {
      if (context.mounted) {
        context.read<ShareRecordsBloc>().add(
              const ShareRecordsEvent.dataDestructionConfirmed(),
            );
      }
    } else {
      if (context.mounted) {
        context.read<ShareRecordsBloc>().add(
              const ShareRecordsEvent.continueViewing(),
            );
      }
    }
  }
}
