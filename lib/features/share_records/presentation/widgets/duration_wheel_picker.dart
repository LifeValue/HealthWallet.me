import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/features/share_records/presentation/bloc/share_records_bloc.dart';
import 'package:health_wallet/features/share_records/presentation/bloc/share_records_event.dart';
import 'package:health_wallet/features/share_records/presentation/bloc/share_records_state.dart';

class DurationWheelPicker {
  static const durationOptions = [
    Duration(minutes: 1),
    Duration(minutes: 5),
    Duration(minutes: 10),
    Duration(minutes: 15),
    Duration(minutes: 30),
  ];
}

class DurationDropdown extends StatefulWidget {
  static const double dropdownWidth = 82.0;

  const DurationDropdown({super.key});

  @override
  State<DurationDropdown> createState() => _DurationDropdownState();
}

class _DurationDropdownState extends State<DurationDropdown> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  bool _isOpen = false;

  void _toggle() {
    if (_isOpen) {
      _dismiss();
      return;
    }
    _show();
  }

  void _dismiss() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (mounted) {
      setState(() => _isOpen = false);
    }
  }

  void _show() {
    final bloc = context.read<ShareRecordsBloc>();
    final current = bloc.state.selectedViewingDuration;
    var selectedIndex =
        DurationWheelPicker.durationOptions.indexOf(current);
    if (selectedIndex < 0) selectedIndex = 1;

    final overlay = Overlay.of(context);

    _overlayEntry = OverlayEntry(
      builder: (overlayContext) => _DropdownOverlay(
        link: _layerLink,
        initialIndex: selectedIndex,
        onChanged: (index) {
          bloc.add(
            ShareRecordsEvent.viewingDurationChanged(
                DurationWheelPicker.durationOptions[index]),
          );
        },
        onDismiss: _dismiss,
      ),
    );

    overlay.insert(_overlayEntry!);
    setState(() => _isOpen = true);
  }

  @override
  void dispose() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: InkWell(
        onTap: _toggle,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Insets.small,
            vertical: Insets.extraSmall,
          ),
          decoration: BoxDecoration(
            color: context.colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: context.colorScheme.primary.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.timer_outlined,
                size: 14,
                color: context.colorScheme.primary,
              ),
              const SizedBox(width: 4),
              BlocSelector<ShareRecordsBloc, ShareRecordsState, int>(
                selector: (state) =>
                    state.selectedViewingDuration.inMinutes,
                builder: (context, minutes) {
                  return _DurationLabel(
                    minutes: minutes,
                    style: AppTextStyle.labelMedium.copyWith(
                      color: context.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  );
                },
              ),
              const SizedBox(width: 4),
              Icon(
                _isOpen ? Icons.expand_less : Icons.expand_more,
                size: 16,
                color: context.colorScheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DurationLabel extends StatelessWidget {
  final int minutes;
  final TextStyle style;
  final double numberWidth;

  const _DurationLabel({
    required this.minutes,
    required this.style,
    this.numberWidth = 20,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: numberWidth,
          child: Text(
            '$minutes',
            textAlign: TextAlign.right,
            style: style.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text('min', style: style),
      ],
    );
  }
}

class _DropdownOverlay extends StatefulWidget {
  final LayerLink link;
  final int initialIndex;
  final ValueChanged<int> onChanged;
  final VoidCallback onDismiss;

  const _DropdownOverlay({
    required this.link,
    required this.initialIndex,
    required this.onChanged,
    required this.onDismiss,
  });

  @override
  State<_DropdownOverlay> createState() => _DropdownOverlayState();
}

class _DropdownOverlayState extends State<_DropdownOverlay> {
  late final FixedExtentScrollController _controller;
  late int _selectedIndex;

  static const double _dropdownHeight = 96.0;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _controller = FixedExtentScrollController(initialItem: _selectedIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GestureDetector(
          onTap: widget.onDismiss,
          behavior: HitTestBehavior.opaque,
          child: const SizedBox.expand(),
        ),
        Positioned(
          left: 0,
          top: 0,
          child: CompositedTransformFollower(
            link: widget.link,
            showWhenUnlinked: false,
            targetAnchor: Alignment.bottomCenter,
            followerAnchor: Alignment.topCenter,
            offset: const Offset(0, 8),
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(12),
              color: context.colorScheme.surface,
              child: Container(
                width: DurationDropdown.dropdownWidth,
                height: _dropdownHeight,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: context.theme.dividerColor,
                  ),
                ),
                child: ListWheelScrollView.useDelegate(
                  controller: _controller,
                  itemExtent: 30,
                  perspective: 0.003,
                  diameterRatio: 1.4,
                  physics: const FixedExtentScrollPhysics(),
                  onSelectedItemChanged: (index) {
                    setState(() => _selectedIndex = index);
                    widget.onChanged(index);
                  },
                  childDelegate: ListWheelChildBuilderDelegate(
                    childCount: DurationWheelPicker.durationOptions.length,
                    builder: (context, index) {
                      final isSelected = index == _selectedIndex;
                      final minutes = DurationWheelPicker
                          .durationOptions[index].inMinutes;
                      return Center(
                        child: _DurationLabel(
                          minutes: minutes,
                          numberWidth: 24,
                          style: isSelected
                              ? AppTextStyle.titleSmall.copyWith(
                                  color: context.colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                )
                              : AppTextStyle.bodySmall.copyWith(
                                  color: context.colorScheme.onSurface
                                      .withValues(alpha: 0.3),
                                ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
