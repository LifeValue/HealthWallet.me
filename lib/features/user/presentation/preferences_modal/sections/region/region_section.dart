import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_wallet/core/config/constants/region_preset.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/features/user/presentation/bloc/user_bloc.dart';

class RegionSection extends StatelessWidget {
  const RegionSection({super.key});

  @override
  Widget build(BuildContext context) {
    final borderColor = context.theme.dividerColor;
    final textColor = context.colorScheme.onSurface;

    return BlocBuilder<UserBloc, UserState>(
      buildWhen: (previous, current) =>
          previous.regionPreset != current.regionPreset ||
          previous.appLocale != current.appLocale,
      builder: (context, state) {
        final selected = state.regionPreset;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: Insets.normal),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.regionAndUnits,
                style: AppTextStyle.bodySmall.copyWith(color: textColor),
              ),
              const SizedBox(height: Insets.small),
              Container(
                padding: const EdgeInsets.all(Insets.smallNormal),
                decoration: BoxDecoration(
                  border: Border.all(color: borderColor),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Row(
                      children: RegionPreset.values.map((preset) {
                        final isSelected = preset == selected;
                        return Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                              right: preset != RegionPreset.values.last
                                  ? Insets.small
                                  : 0,
                            ),
                            child: GestureDetector(
                              onTap: () {
                                context.read<UserBloc>().add(
                                      UserRegionPresetChanged(preset),
                                    );
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                  vertical: Insets.small,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.primary.withValues(alpha: 0.15)
                                      : Colors.transparent,
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.primary
                                        : borderColor,
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Center(
                                  child: Text(
                                    _regionDisplayName(context, preset),
                                    style: AppTextStyle.labelLarge.copyWith(
                                      color: isSelected
                                          ? AppColors.primary
                                          : textColor,
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: Insets.small),
                    Text(
                      '${selected.dateFormat}  ·  ${selected.weightUnit}  ·  ${selected.temperatureUnit}  ·  ${selected.glucoseUnit}',
                      style: AppTextStyle.labelMedium.copyWith(
                        color: textColor.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _regionDisplayName(BuildContext context, RegionPreset preset) {
    switch (preset) {
      case RegionPreset.us:
        return context.l10n.regionUS;
      case RegionPreset.europe:
        return context.l10n.regionEurope;
      case RegionPreset.uk:
        return context.l10n.regionUK;
    }
  }
}
