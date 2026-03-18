import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/features/user/presentation/bloc/user_bloc.dart';

class ReceiveModeToggleButton extends StatelessWidget {
  const ReceiveModeToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = context.colorScheme;
    final borderColor = context.theme.dividerColor;

    return BlocBuilder<UserBloc, UserState>(
      builder: (context, state) {
        final isReceiveModeEnabled = state.user.isReceiveModeEnabled;

        return AnimatedContainer(
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
                    color: !isReceiveModeEnabled
                        ? colorScheme.primary
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Center(
                    child: Text(
                      'OFF',
                      style: context.textTheme.bodySmall?.copyWith(
                        color: !isReceiveModeEnabled
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
                    color: isReceiveModeEnabled
                        ? colorScheme.primary
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Center(
                    child: Text(
                      'ON',
                      style: context.textTheme.bodySmall?.copyWith(
                        color: isReceiveModeEnabled
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
        );
      },
    );
  }
}
