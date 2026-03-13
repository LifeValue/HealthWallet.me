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
  FixedExtentScrollController? _hoursController;
  FixedExtentScrollController? _minutesController;

  @override
  void dispose() {
    _hoursController?.dispose();
    _minutesController?.dispose();
    super.dispose();
  }

  FixedExtentScrollController _getHoursController(int hours) {
    final items = <int>[0, 1, 2, 3];
    final index = items.indexOf(hours);
    if (_hoursController == null) {
      _hoursController = FixedExtentScrollController(
        initialItem: index >= 0 ? index : 0,
      );
    }
    return _hoursController!;
  }

  FixedExtentScrollController _getMinutesController(int minutes) {
    final items = <int>[];
    for (int i = 0; i <= 59; i += 5) {
      items.add(i);
    }
    final index = items.indexOf(minutes);
    if (_minutesController == null) {
      _minutesController = FixedExtentScrollController(
        initialItem: index >= 0 ? index : 0,
      );
    }
    return _minutesController!;
  }

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
              _buildDurationPicker(context),
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
            durationText = '${hours}h ${minutes} min';
          } else {
            durationText = '${hours}h';
          }
        } else {
          durationText = '$minutes min';
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
                      'Session time',
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
                    label: 'Set as default',
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
        label: canContinue ? 'Share Records' : 'Select records to share',
      ),
    );
  }

  Widget _buildDurationPicker(BuildContext context) {
    return Container(
      height: 160,
      padding: const EdgeInsets.symmetric(vertical: Insets.extraSmall),
      child: BlocBuilder<ShareRecordsBloc, ShareRecordsState>(
        builder: (context, state) {
          final currentDuration = state.selectedViewingDuration;
          final hours = currentDuration.inHours;
          final minutes = currentDuration.inMinutes % 60;

          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 100,
                child: _buildScrollWheel(
                  context: context,
                  controller: _getHoursController(hours),
                  label: 'hours',
                  maxValue: 3,
                  currentValue: hours,
                  onChanged: (newHours) {
                    var newDuration = Duration(hours: newHours, minutes: minutes);
                    if (newDuration == Duration.zero) {
                      newDuration = const Duration(minutes: 5);
                      _minutesController?.animateToItem(
                        1,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      );
                    }
                    context.read<ShareRecordsBloc>().add(
                          ShareRecordsEvent.viewingDurationChanged(newDuration),
                        );
                  },
                ),
              ),
              const SizedBox(width: 20),
              SizedBox(
                width: 100,
                child: _buildScrollWheel(
                  context: context,
                  controller: _getMinutesController(minutes),
                  label: 'min',
                  maxValue: 59,
                  step: 5,
                  currentValue: minutes,
                  onChanged: (newMinutes) {
                    var newDuration = Duration(hours: hours, minutes: newMinutes);
                    if (newDuration == Duration.zero) {
                      newDuration = const Duration(minutes: 5);
                      _minutesController?.animateToItem(
                        1,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      );
                    }
                    context.read<ShareRecordsBloc>().add(
                          ShareRecordsEvent.viewingDurationChanged(newDuration),
                        );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildScrollWheel({
    required BuildContext context,
    required FixedExtentScrollController controller,
    required String label,
    required int maxValue,
    required int currentValue,
    required Function(int) onChanged,
    int step = 1,
  }) {
    final items = <int>[];
    for (int i = 0; i <= maxValue; i += step) {
      items.add(i);
    }

    return Column(
      children: [
        Expanded(
          child: ListWheelScrollView.useDelegate(
            controller: controller,
            itemExtent: 50,
            perspective: 0.005,
            diameterRatio: 1.2,
            physics: const FixedExtentScrollPhysics(),
            onSelectedItemChanged: (index) {
              onChanged(items[index]);
            },
            childDelegate: ListWheelChildBuilderDelegate(
              builder: (context, index) {
                if (index < 0 || index >= items.length) return null;
                final value = items[index];
                final isSelected = value == currentValue;
                return Center(
                  child: Text(
                    '$value $label',
                    style: AppTextStyle.titleMedium.copyWith(
                      color: isSelected
                          ? context.colorScheme.onSurface
                          : context.colorScheme.onSurface.withValues(alpha: 0.4),
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                );
              },
              childCount: items.length,
            ),
          ),
        ),
      ],
    );
  }
}
