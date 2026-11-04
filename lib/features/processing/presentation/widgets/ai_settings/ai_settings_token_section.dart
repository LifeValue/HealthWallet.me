import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:health_wallet/core/l10n/l10n.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';

enum TokenPreset {
  low(100),
  medium(500),
  high(2000),
  custom(0);

  final int tokens;
  const TokenPreset(this.tokens);
}

class AiTokenOptionsSection extends StatelessWidget {
  final TokenPreset selectedPreset;
  final TextEditingController customController;
  final ValueChanged<TokenPreset> onPresetChanged;
  final VoidCallback onCustomValueChanged;
  final Color textColor;
  final Color borderColor;

  const AiTokenOptionsSection({
    required this.selectedPreset,
    required this.customController,
    required this.onPresetChanged,
    required this.onCustomValueChanged,
    required this.textColor,
    required this.borderColor,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildTokenChip(
          context,
          TokenPreset.low,
          context.l10n.tokenPresetLow,
          '~100',
        ),
        const SizedBox(height: Insets.extraSmall),
        _buildTokenChip(
          context,
          TokenPreset.medium,
          context.l10n.tokenPresetMedium,
          '~500',
        ),
        const SizedBox(height: Insets.extraSmall),
        _buildTokenChip(
          context,
          TokenPreset.high,
          context.l10n.tokenPresetHigh,
          '~2000',
        ),
        const SizedBox(height: Insets.extraSmall),
        _buildCustomTokenRow(context),
      ],
    );
  }

  Widget _buildTokenChip(
    BuildContext context,
    TokenPreset preset,
    String title,
    String tokenLabel,
  ) {
    final isSelected = selectedPreset == preset;

    return GestureDetector(
      onTap: () => onPresetChanged(preset),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: Insets.smallNormal,
          vertical: Insets.small,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.primary : borderColor,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            _buildRadioCircle(isSelected),
            const SizedBox(width: Insets.small),
            Text(
              title,
              style: AppTextStyle.bodyMedium.copyWith(
                color: textColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Text(
              '$tokenLabel ${context.l10n.tokens}',
              style: AppTextStyle.labelSmall.copyWith(color: textColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomTokenRow(BuildContext context) {
    final isSelected = selectedPreset == TokenPreset.custom;

    return GestureDetector(
      onTap: () => onPresetChanged(TokenPreset.custom),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: Insets.smallNormal,
          vertical: Insets.small,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.primary : borderColor,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            _buildRadioCircle(isSelected),
            const SizedBox(width: Insets.small),
            Text(
              context.l10n.tokenPresetCustom,
              style: AppTextStyle.bodyMedium.copyWith(
                color: textColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: Insets.small),
              Expanded(
                child: SizedBox(
                  height: 32,
                  child: TextField(
                    controller: customController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    onChanged: (_) => onCustomValueChanged(),
                    style: AppTextStyle.labelLarge.copyWith(
                      color: textColor,
                      height: 1.6,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: Insets.small,
                        vertical: 7,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(color: borderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(color: borderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(color: AppColors.primary),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRadioCircle(bool isSelected) {
    if (isSelected) {
      return Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.primary, width: 2),
        ),
        child: Center(
          child: Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary,
            ),
          ),
        ),
      );
    }

    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: const Color.fromRGBO(30, 30, 30, 0.3),
          width: 1.5,
        ),
      ),
    );
  }
}

/// A whole-number slider with its value above it and a link back to the
/// recommended value.
///
/// While the thumb is dragged the value is held here, so a drag redraws only
/// this slider (thumb, value bubble and the number above it); [onChanged]
/// reports the value once, when the user lets go, or when the
/// recommendation is tapped. With no drag running it shows [value], so a
/// value the parent changes is shown at once.
class AiSliderSetting extends StatefulWidget {
  final int value;
  final int min;
  final int max;
  final int recommended;

  /// Called with the picked value when a drag ends, or with [recommended]
  /// when the recommendation is tapped.
  final ValueChanged<int> onChanged;
  final Color textColor;
  final Color borderColor;

  /// What to show for [value] instead of the value itself, e.g. a saved
  /// context size that is no step.
  final String? label;

  /// The values the slider positions stand for: with them the slider moves
  /// over their indices and shows the value at the index.
  final List<int>? stepValues;

  const AiSliderSetting({
    required this.value,
    required this.min,
    required this.max,
    required this.recommended,
    required this.onChanged,
    required this.textColor,
    required this.borderColor,
    this.label,
    this.stepValues,
    super.key,
  });

  @override
  State<AiSliderSetting> createState() => _AiSliderSettingState();
}

class _AiSliderSettingState extends State<AiSliderSetting> {
  /// The value under the thumb while a drag runs, null otherwise.
  int? _dragValue;

  @override
  void didUpdateWidget(AiSliderSetting oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A value set from outside (e.g. the recommendation) wins over a drag
    // the user has not let go of yet.
    if (oldWidget.value != widget.value) _dragValue = null;
  }

  String _format(int position) {
    final steps = widget.stepValues;
    if (steps == null) return '$position';
    return '${steps[position.clamp(0, steps.length - 1)]}';
  }

  void _onDrag(double v) {
    final position = v.round();
    if (position != _dragValue) setState(() => _dragValue = position);
  }

  void _onDragEnd(double v) {
    setState(() => _dragValue = null);
    widget.onChanged(v.round());
  }

  @override
  Widget build(BuildContext context) {
    final dragValue = _dragValue;
    final current = dragValue ?? widget.value;
    final isRecommended = current == widget.recommended;
    final displayValue = dragValue != null
        ? _format(dragValue)
        : widget.label ?? _format(widget.value);
    final min = widget.min;
    final max = widget.max;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              displayValue,
              style: AppTextStyle.titleSmall.copyWith(
                color: widget.textColor,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (isRecommended)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  context.l10n.recommended,
                  style: AppTextStyle.labelSmall.copyWith(
                    color: AppColors.success,
                    fontWeight: FontWeight.w600,
                    fontSize: 10,
                  ),
                ),
              )
            else
              GestureDetector(
                onTap: () {
                  setState(() => _dragValue = null);
                  widget.onChanged(widget.recommended);
                },
                child: Text(
                  '${context.l10n.recommended}: '
                  '${_format(widget.recommended)}',
                  style: AppTextStyle.labelSmall.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w500,
                    fontSize: 10,
                  ),
                ),
              ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            activeTrackColor: AppColors.primary,
            inactiveTrackColor: widget.borderColor,
            thumbColor: AppColors.primary,
            showValueIndicator: ShowValueIndicator.onDrag,
            valueIndicatorColor: AppColors.primary,
            valueIndicatorTextStyle: AppTextStyle.labelLarge.copyWith(
              color: AppColors.textPrimaryDark,
              fontWeight: FontWeight.w600,
            ),
          ),
          child: Slider(
            value: current.clamp(min, max).toDouble(),
            min: min.toDouble(),
            max: max.toDouble(),
            divisions: max - min > 0 ? max - min : 1,
            label: _format(current),
            onChanged: _onDrag,
            onChangeEnd: _onDragEnd,
          ),
        ),
      ],
    );
  }
}
