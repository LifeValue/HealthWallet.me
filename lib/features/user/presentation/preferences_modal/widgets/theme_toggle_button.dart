import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/features/user/presentation/bloc/user_bloc.dart';
import 'package:health_wallet/gen/assets.gen.dart';

class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = context.colorScheme;
    final borderColor = context.theme.dividerColor;
    final iconColor = colorScheme.onSurface;

    return BlocBuilder<UserBloc, UserState>(
      builder: (context, state) {
        final isDarkMode = state.user.isDarkMode;
        return GestureDetector(
          onTap: () {
            context.read<UserBloc>().add(const UserThemeToggled());
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 76,
            height: 40,
            padding: const EdgeInsets.all(Insets.extraSmall),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    decoration: BoxDecoration(
                      color: !isDarkMode
                          ? colorScheme.primary
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: Assets.icons.sun.svg(
                        width: 20,
                        height: 20,
                        colorFilter: ColorFilter.mode(
                          !isDarkMode ? Colors.white : iconColor,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    decoration: BoxDecoration(
                      color:
                          isDarkMode ? colorScheme.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: Assets.icons.moon.svg(
                        width: 20,
                        height: 20,
                        colorFilter: ColorFilter.mode(
                          isDarkMode ? Colors.white : iconColor,
                          BlendMode.srcIn,
                        ),
                      ),
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
}
