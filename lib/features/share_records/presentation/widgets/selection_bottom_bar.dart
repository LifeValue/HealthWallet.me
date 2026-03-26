import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/core/widgets/app_button.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/share_records/presentation/bloc/share_records_bloc.dart';
import 'package:health_wallet/features/share_records/presentation/bloc/share_records_event.dart';
import 'package:health_wallet/features/share_records/presentation/bloc/share_records_state.dart';
import 'package:health_wallet/features/share_records/presentation/widgets/duration_wheel_picker.dart';

class SelectionBottomBar extends StatefulWidget {
  final ShareRecordsState shareState;
  final Set<FhirType> filterTypes;
  final VoidCallback? onSharePressed;

  const SelectionBottomBar({
    super.key,
    required this.shareState,
    required this.filterTypes,
    this.onSharePressed,
  });

  @override
  State<SelectionBottomBar> createState() => _SelectionBottomBarState();
}

class _SelectionBottomBarState extends State<SelectionBottomBar> {
  bool _isDurationPickerExpanded = false;

  @override
  Widget build(BuildContext context) {
    final selectedCount = widget.shareState.selection.totalCount;
    final canContinue = selectedCount > 0;

    return Container(
      decoration: BoxDecoration(
        color: context.colorScheme.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, -4),
            blurRadius: 12,
            color: Colors.black.withValues(alpha: 0.15),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSessionTimeRow(context),
            if (_isDurationPickerExpanded)
              Container(
                height: 160,
                padding: const EdgeInsets.symmetric(vertical: Insets.extraSmall),
                child: BlocBuilder<ShareRecordsBloc, ShareRecordsState>(
                  builder: (context, state) {
                    return DurationWheelPicker(
                      currentDuration: state.selectedViewingDuration,
                      onChanged: (duration) {
                        context.read<ShareRecordsBloc>().add(
                              ShareRecordsEvent.viewingDurationChanged(duration),
                            );
                      },
                    );
                  },
                ),
              ),
            _buildShareButton(context, canContinue),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionTimeRow(BuildContext context) {
    return BlocBuilder<ShareRecordsBloc, ShareRecordsState>(
      builder: (context, state) {
        final duration = state.selectedViewingDuration;
        final hours = duration.inHours;
        final minutes = duration.inMinutes % 60;
        final isDefaultDuration = state.isDefaultDuration;
        final isZeroDuration = duration == Duration.zero;

        String durationText;
        if (hours > 0) {
          if (minutes > 0) {
            durationText = context.l10n.shareDurationHoursMinutes(hours, minutes);
          } else {
            durationText = context.l10n.shareDurationHours(hours);
          }
        } else {
          durationText = context.l10n.shareDurationMinutes(minutes);
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _isDurationPickerExpanded = !_isDurationPickerExpanded),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: Insets.normal,
              vertical: Insets.small,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      context.l10n.shareSessionTime,
                      style: AppTextStyle.bodyMedium.copyWith(
                        color: context.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
                Visibility(
                  visible: !isDefaultDuration,
                  maintainSize: true,
                  maintainAnimation: true,
                  maintainState: true,
                  child: AppButton(
                    onPressed: isZeroDuration
                        ? null
                        : () {
                            context.read<ShareRecordsBloc>().add(
                                  const ShareRecordsEvent.defaultViewingDurationSet(),
                                );
                            setState(() {
                              _isDurationPickerExpanded = false;
                            });
                          },
                    label: context.l10n.shareSetAsDefault,
                    variant: AppButtonVariant.transparent,
                    fullWidth: false,
                    fontSize: 14,
                    padding: const EdgeInsets.symmetric(
                      horizontal: Insets.extraSmall,
                      vertical: 0,
                    ),
                  ),
                ),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.timer_outlined,
                          size: 16,
                          color: context.colorScheme.onSurface,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          durationText,
                          style: AppTextStyle.bodyMedium.copyWith(
                            color: context.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          _isDurationPickerExpanded ? Icons.expand_less : Icons.expand_more,
                          size: 20,
                          color: context.colorScheme.onSurface,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildShareButton(BuildContext context, bool canContinue) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Insets.normal, Insets.small, Insets.normal, Insets.normal),
      child: AppButton(
        onPressed: canContinue
            ? () {
                if (widget.filterTypes.isNotEmpty) {
                  context.read<ShareRecordsBloc>().add(
                        ShareRecordsEvent.filtersApplied(
                          widget.filterTypes.toList(),
                        ),
                      );
                }
                context.read<ShareRecordsBloc>().add(
                      const ShareRecordsEvent.selectionConfirmed(),
                    );
              }
            : null,
        label: canContinue ? context.l10n.shareRecordsButton : context.l10n.shareSelectRecordsToShare,
      ),
    );
  }
}
