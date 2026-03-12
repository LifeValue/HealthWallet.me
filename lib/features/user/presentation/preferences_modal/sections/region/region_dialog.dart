import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_wallet/core/config/constants/region_preset.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/features/user/presentation/bloc/user_bloc.dart';
import 'package:health_wallet/gen/assets.gen.dart';

class RegionDialog extends StatelessWidget {
  const RegionDialog({super.key});

  static void show(BuildContext context) {
    final userBloc = BlocProvider.of<UserBloc>(context);

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return BlocProvider.value(
          value: userBloc,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: const RegionDialog(),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = context.theme.dividerColor;
    final textColor = context.colorScheme.onSurface;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(Insets.medium),
      child: Container(
        decoration: BoxDecoration(
          color: context.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Insets.normal,
                vertical: Insets.small,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    context.l10n.regionAndUnits,
                    style: AppTextStyle.bodyMedium,
                  ),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: IconButton(
                      icon: Assets.icons.close.svg(
                        colorFilter: ColorFilter.mode(
                          context.colorScheme.onSurface,
                          BlendMode.srcIn,
                        ),
                      ),
                      onPressed: () => context.popDialog(),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: borderColor),
            BlocBuilder<UserBloc, UserState>(
              buildWhen: (previous, current) =>
                  previous.regionPreset != current.regionPreset,
              builder: (context, state) {
                final selected = state.regionPreset;

                return Padding(
                  padding: const EdgeInsets.all(Insets.normal),
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
                                  duration:
                                      const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: Insets.small,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppColors.primary
                                            .withValues(alpha: 0.15)
                                        : Colors.transparent,
                                    border: Border.all(
                                      color: isSelected
                                          ? AppColors.primary
                                          : borderColor,
                                    ),
                                    borderRadius:
                                        BorderRadius.circular(6),
                                  ),
                                  child: Center(
                                    child: Text(
                                      _regionDisplayName(context, preset),
                                      style: AppTextStyle.labelLarge
                                          .copyWith(
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
                );
              },
            ),
          ],
        ),
      ),
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
