import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/core/widgets/app_button.dart';
import 'package:health_wallet/features/share_records/presentation/widgets/exit_confirmation_dialog.dart';
import 'package:health_wallet/features/share_records/presentation/bloc/share_records_bloc.dart';
import 'package:health_wallet/features/share_records/presentation/bloc/share_records_event.dart';
import 'package:health_wallet/features/share_records/presentation/bloc/share_records_state.dart';
import 'package:health_wallet/features/share_records/presentation/widgets/extend_request_card.dart';
import 'package:health_wallet/features/share_records/presentation/widgets/session_timer_widget.dart';

class SessionBottomBar extends StatefulWidget {
  final ShareRecordsState state;
  final String peerRole;
  final ShareRecordsEvent endSessionEvent;
  final bool isReceiver;

  const SessionBottomBar({
    super.key,
    required this.state,
    required this.peerRole,
    required this.endSessionEvent,
    this.isReceiver = false,
  });

  @override
  State<SessionBottomBar> createState() => _SessionBottomBarState();
}

class _SessionBottomBarState extends State<SessionBottomBar> {
  bool _isExpanded = false;
  int _extendHours = 0;
  int _extendMinutes = 15;
  int? _lastRequestedSeconds;
  late final FixedExtentScrollController _hoursController;
  late final FixedExtentScrollController _minutesController;

  @override
  void initState() {
    super.initState();
    _hoursController = FixedExtentScrollController(initialItem: 0);
    _minutesController = FixedExtentScrollController(initialItem: 3);
  }

  @override
  void dispose() {
    _hoursController.dispose();
    _minutesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;

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
        child: widget.isReceiver
            ? _buildReceiverLayout(context, state)
            : _buildSenderLayout(context, state),
      ),
    );
  }

  Widget _buildReceiverLayout(BuildContext context, ShareRecordsState state) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SessionTimerWidget(
          timeRemaining: state.viewingTimeRemaining,
          isExpanded: _isExpanded,
          statusText: state.extensionRequestPending
              ? '${_formatDuration(_lastRequestedSeconds)} requested'
              : null,
          onToggleExpanded: state.canRequestExtension &&
                  !state.extensionRequestPending
              ? () => setState(() => _isExpanded = !_isExpanded)
              : null,
        ),
        if (_isExpanded &&
            state.canRequestExtension &&
            !state.extensionRequestPending) ...[
          Divider(height: 1, color: context.theme.dividerColor),
          _buildDurationPicker(context),
          if (state.extensionsUsed > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: Insets.small),
              child: Text(
                '${state.extensionsUsed}/${state.maxExtensions} extensions used',
                style: AppTextStyle.labelSmall.copyWith(
                  color: context.colorScheme.onSurface
                      .withValues(alpha: 0.5),
                ),
              ),
            ),
        ],
        if (state.pendingExtendDurationSeconds != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Insets.normal,
              0,
              Insets.normal,
              Insets.small,
            ),
            child: ExtendRequestCard(
              durationSeconds: state.pendingExtendDurationSeconds!,
              peerRole: widget.peerRole,
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Insets.normal,
            Insets.small,
            Insets.normal,
            Insets.normal,
          ),
          child: Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Request +10 min',
                  onPressed: state.extensionRequestPending ||
                          !state.canRequestExtension
                      ? null
                      : () {
                          setState(() => _lastRequestedSeconds = 600);
                          context.read<ShareRecordsBloc>().add(
                                const ShareRecordsEvent.sessionExtendRequested(600),
                              );
                        },
                  variant: AppButtonVariant.outlined,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
              const SizedBox(width: Insets.small),
              Expanded(
                child: AppButton(
                  label: 'End Session',
                  onPressed: () => _confirmEndSession(context),
                  backgroundColor: AppColors.error,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSenderLayout(BuildContext context, ShareRecordsState state) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SessionTimerWidget(
          timeRemaining: state.viewingTimeRemaining,
          isExpanded: _isExpanded,
          onToggleExpanded: state.canRequestExtension
              ? () => setState(() => _isExpanded = !_isExpanded)
              : null,
        ),
        if (_isExpanded && state.canRequestExtension) ...[
          Divider(height: 1, color: context.theme.dividerColor),
          if (state.extensionRequestPending)
            _buildWaitingIndicator(context)
          else
            _buildDurationPicker(context),
          if (state.extensionsUsed > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: Insets.small),
              child: Text(
                '${state.extensionsUsed}/${state.maxExtensions} extensions used',
                style: AppTextStyle.labelSmall.copyWith(
                  color: context.colorScheme.onSurface
                      .withValues(alpha: 0.5),
                ),
              ),
            ),
        ],
        if (state.pendingExtendDurationSeconds != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Insets.normal,
              0,
              Insets.normal,
              Insets.small,
            ),
            child: ExtendRequestCard(
              durationSeconds: state.pendingExtendDurationSeconds!,
              peerRole: widget.peerRole,
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Insets.normal,
            Insets.small,
            Insets.normal,
            Insets.normal,
          ),
          child: AppButton(
            label: 'End Session',
            onPressed: () => _confirmEndSession(context),
            backgroundColor: AppColors.error,
            padding: const EdgeInsets.symmetric(
              horizontal: Insets.medium,
              vertical: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWaitingIndicator(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(Insets.normal),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: Insets.small),
          Text(
            'Waiting for response...',
            style: AppTextStyle.bodyMedium.copyWith(
              color: context.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDurationPicker(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Insets.normal,
            vertical: Insets.small,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              AppButton(
                label: 'Cancel',
                onPressed: () => setState(() => _isExpanded = false),
                variant: AppButtonVariant.tinted,
                backgroundColor: context.colorScheme.onSurface,
                pillShaped: true,
                fullWidth: false,
                padding: const EdgeInsets.symmetric(
                  horizontal: Insets.normal,
                  vertical: Insets.extraSmall,
                ),
                fontSize: AppTextStyle.labelLarge.fontSize,
              ),
              Text(
                'Add more time',
                style: AppTextStyle.bodyMedium.copyWith(
                  color: context.colorScheme.onSurface,
                ),
              ),
              AppButton(
                label: 'Save',
                onPressed: _submitExtension,
                variant: AppButtonVariant.tinted,
                pillShaped: true,
                fullWidth: false,
                padding: const EdgeInsets.symmetric(
                  horizontal: Insets.normal,
                  vertical: Insets.extraSmall,
                ),
                fontSize: AppTextStyle.labelLarge.fontSize,
              ),
            ],
          ),
        ),
        SizedBox(
          height: 160,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 100,
                child: _buildScrollWheel(
                  context: context,
                  controller: _hoursController,
                  label: 'hours',
                  maxValue: 3,
                  currentValue: _extendHours,
                  onChanged: (v) {
                    setState(() => _extendHours = v);
                    if (_extendHours == 0 && _extendMinutes == 0) {
                      _minutesController.animateToItem(
                        1,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      );
                    }
                  },
                ),
              ),
              const SizedBox(width: 20),
              SizedBox(
                width: 100,
                child: _buildScrollWheel(
                  context: context,
                  controller: _minutesController,
                  label: 'min',
                  maxValue: 59,
                  step: 5,
                  currentValue: _extendMinutes,
                  onChanged: (v) {
                    setState(() => _extendMinutes = v);
                    if (_extendHours == 0 && _extendMinutes == 0) {
                      _minutesController.animateToItem(
                        1,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      );
                    }
                  },
                ),
              ),
            ],
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
    required ValueChanged<int> onChanged,
    int step = 1,
  }) {
    final items = <int>[];
    for (int i = 0; i <= maxValue; i += step) {
      items.add(i);
    }

    return ListWheelScrollView.useDelegate(
      controller: controller,
      itemExtent: 50,
      perspective: 0.005,
      diameterRatio: 1.2,
      physics: const FixedExtentScrollPhysics(),
      onSelectedItemChanged: (index) => onChanged(items[index]),
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
    );
  }

  void _submitExtension() {
    final totalSeconds = (_extendHours * 3600) + (_extendMinutes * 60);
    if (totalSeconds > 0) {
      setState(() {
        _lastRequestedSeconds = totalSeconds;
        _isExpanded = false;
      });
      context.read<ShareRecordsBloc>().add(
            ShareRecordsEvent.sessionExtendRequested(totalSeconds),
          );
    }
  }

  String _formatDuration(int? seconds) {
    if (seconds == null || seconds <= 0) return '';
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h > 0 && m > 0) return '${h}h ${m}min';
    if (h > 0) return '${h}h';
    return '${m}min';
  }

  void _confirmEndSession(BuildContext context) async {
    final confirmed = await ExitConfirmationDialog.show(context: context);
    if (confirmed == true && context.mounted) {
      context.read<ShareRecordsBloc>().add(widget.endSessionEvent);
    }
  }
}
