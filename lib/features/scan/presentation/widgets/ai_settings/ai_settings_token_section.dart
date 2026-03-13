import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';

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

class AiSliderSetting extends StatelessWidget {
  final int value;
  final int min;
  final int max;
  final int recommended;
  final ValueChanged<int> onChanged;
  final Color textColor;
  final Color borderColor;
  final String? label;
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
  Widget build(BuildContext context) {
    final isRecommended = value == recommended;
    final displayValue = label ?? '$value';
    final recLabel = stepValues != null
        ? stepValues![recommended.clamp(0, stepValues!.length - 1)].toString()
        : '$recommended';

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              displayValue,
              style: AppTextStyle.titleSmall.copyWith(
                color: textColor,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (isRecommended)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  context.l10n.recommended,
                  style: AppTextStyle.labelSmall.copyWith(
                    color: const Color(0xFF4CAF50),
                    fontWeight: FontWeight.w600,
                    fontSize: 10,
                  ),
                ),
              )
            else
              GestureDetector(
                onTap: () => onChanged(recommended),
                child: Text(
                  '${context.l10n.recommended}: $recLabel',
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
            inactiveTrackColor: borderColor,
            thumbColor: AppColors.primary,
          ),
          child: Slider(
            value: value.toDouble(),
            min: min.toDouble(),
            max: max.toDouble(),
            divisions: max - min > 0 ? max - min : 1,
            onChanged: (v) => onChanged(v.round()),
          ),
        ),
      ],
    );
  }
}
