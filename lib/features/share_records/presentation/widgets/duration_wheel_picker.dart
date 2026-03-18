import 'package:flutter/material.dart';

import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';

class DurationWheelPicker extends StatefulWidget {
  final Duration currentDuration;
  final ValueChanged<Duration> onChanged;

  const DurationWheelPicker({
    super.key,
    required this.currentDuration,
    required this.onChanged,
  });

  @override
  State<DurationWheelPicker> createState() => _DurationWheelPickerState();
}

class _DurationWheelPickerState extends State<DurationWheelPicker> {
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
    final hours = widget.currentDuration.inHours;
    final minutes = widget.currentDuration.inMinutes % 60;

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
              widget.onChanged(newDuration);
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
              widget.onChanged(newDuration);
            },
          ),
        ),
      ],
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
