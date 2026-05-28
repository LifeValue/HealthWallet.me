import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/features/desktop/tray/presentation/bloc/tray_bloc.dart';

class MinimizeToTrayToggle extends StatelessWidget {
  const MinimizeToTrayToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = context.colorScheme;
    final borderColor = context.theme.dividerColor;

    return BlocBuilder<TrayBloc, TrayState>(
      builder: (context, state) {
        final isEnabled = state.isMinimizeToTrayEnabled;

        return GestureDetector(
          onTap: () {
            context.read<TrayBloc>().add(
                  TrayMinimizeToTrayToggled(enabled: !isEnabled),
                );
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
                      color: !isEnabled
                          ? colorScheme.primary
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: Text(
                        'OFF',
                        style: context.textTheme.bodySmall?.copyWith(
                          color: !isEnabled
                              ? (context.isDarkMode
                                  ? Colors.white
                                  : colorScheme.onPrimary)
                              : colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    decoration: BoxDecoration(
                      color: isEnabled
                          ? colorScheme.primary
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: Text(
                        'ON',
                        style: context.textTheme.bodySmall?.copyWith(
                          color: isEnabled
                              ? (context.isDarkMode
                                  ? Colors.white
                                  : colorScheme.onPrimary)
                              : colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
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
