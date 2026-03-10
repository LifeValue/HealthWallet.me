import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:health_wallet/core/config/constants/app_constants.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/core/widgets/app_button.dart';

class AiTokenSettingsDialog extends StatefulWidget {
  final int currentTokens;

  const AiTokenSettingsDialog({
    required this.currentTokens,
    super.key,
  });

  static Future<int?> show(BuildContext context, {required int currentTokens}) {
    return showDialog<int>(
      context: context,
      builder: (_) => AiTokenSettingsDialog(currentTokens: currentTokens),
    );
  }

  @override
  State<AiTokenSettingsDialog> createState() => _AiTokenSettingsDialogState();
}

enum _TokenPreset { low, medium, high, custom }

class _AiTokenSettingsDialogState extends State<AiTokenSettingsDialog> {
  late _TokenPreset _selectedPreset;
  late TextEditingController _customController;

  @override
  void initState() {
    super.initState();
    _selectedPreset = _presetFromValue(widget.currentTokens);
    _customController = TextEditingController(
      text: _selectedPreset == _TokenPreset.custom
          ? widget.currentTokens.toString()
          : '',
    );
  }

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  _TokenPreset _presetFromValue(int value) {
    if (value <= 100) return _TokenPreset.low;
    if (value <= 500) return _TokenPreset.medium;
    if (value <= 2048) return _TokenPreset.high;
    return _TokenPreset.custom;
  }

  int _valueFromPreset(_TokenPreset preset) {
    switch (preset) {
      case _TokenPreset.low:
        return 100;
      case _TokenPreset.medium:
        return 500;
      case _TokenPreset.high:
        return 2048;
      case _TokenPreset.custom:
        final parsed = int.tryParse(_customController.text);
        if (parsed == null || parsed < 1) return AppConstants.defaultMaxTokens;
        return parsed.clamp(1, AppConstants.maxAllowedTokens);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textColor =
        context.isDarkMode ? AppColors.textPrimaryDark : AppColors.textPrimary;
    final borderColor =
        context.isDarkMode ? AppColors.borderDark : AppColors.border;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(Insets.normal),
        child: Container(
          decoration: BoxDecoration(
            color: context.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.all(Insets.normal),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.l10n.setAiTokensUsage,
                        style: AppTextStyle.titleSmall
                            .copyWith(color: textColor),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Icon(
                        Icons.close,
                        size: 20,
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Insets.small),
                Text(
                  context.l10n.tokenUsageDescription,
                  style: AppTextStyle.bodySmall.copyWith(
                    color: context.isDarkMode
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: Insets.normal),
                _buildOption(
                  context,
                  preset: _TokenPreset.low,
                  title: context.l10n.tokenPresetLow,
                  description: context.l10n.tokenPresetLowDescription,
                  textColor: textColor,
                ),
                const SizedBox(height: Insets.small),
                _buildOption(
                  context,
                  preset: _TokenPreset.medium,
                  title: context.l10n.tokenPresetMedium,
                  description: context.l10n.tokenPresetMediumDescription,
                  textColor: textColor,
                ),
                const SizedBox(height: Insets.small),
                _buildOption(
                  context,
                  preset: _TokenPreset.high,
                  title: context.l10n.tokenPresetHigh,
                  description: context.l10n.tokenPresetHighDescription,
                  textColor: textColor,
                ),
                const SizedBox(height: Insets.small),
                _buildOption(
                  context,
                  preset: _TokenPreset.custom,
                  title: context.l10n.tokenPresetCustom,
                  description: context.l10n.tokenPresetCustomDescription,
                  textColor: textColor,
                ),
                if (_selectedPreset == _TokenPreset.custom) ...[
                  const SizedBox(height: Insets.small),
                  Padding(
                    padding: const EdgeInsets.only(left: 40),
                    child: SizedBox(
                      width: 140,
                      child: TextField(
                        controller: _customController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        style: AppTextStyle.bodyMedium.copyWith(
                          color: textColor,
                        ),
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: Insets.small,
                            vertical: Insets.small,
                          ),
                          suffixText: context.l10n.tokens,
                          suffixStyle: AppTextStyle.labelSmall.copyWith(
                            color: context.isDarkMode
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondary,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: Insets.medium),
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        label: context.l10n.cancel,
                        variant: AppButtonVariant.outlined,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                    const SizedBox(width: Insets.small),
                    Expanded(
                      child: AppButton(
                        label: context.l10n.setTokens,
                        variant: AppButtonVariant.primary,
                        onPressed: () {
                          Navigator.of(context)
                              .pop(_valueFromPreset(_selectedPreset));
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOption(
    BuildContext context, {
    required _TokenPreset preset,
    required String title,
    required String description,
    required Color textColor,
  }) {
    final isSelected = _selectedPreset == preset;
    return GestureDetector(
      onTap: () => setState(() => _selectedPreset = preset),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Radio<_TokenPreset>(
            value: preset,
            groupValue: _selectedPreset,
            onChanged: (value) {
              if (value != null) setState(() => _selectedPreset = value);
            },
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: Insets.small),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyle.bodyMedium.copyWith(
                    color: textColor,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
                Text(
                  description,
                  style: AppTextStyle.labelSmall.copyWith(
                    color: context.isDarkMode
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
