import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/features/user/presentation/bloc/user_bloc.dart';

class DiscoverableModeIndicator extends StatelessWidget {
  const DiscoverableModeIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<UserBloc, UserState>(
      builder: (context, state) {
        if (!state.user.isReceiveModeEnabled) {
          return const SizedBox.shrink();
        }

        const successColor = AppColors.success;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: successColor.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: successColor, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_tethering, color: successColor, size: 16),
              const SizedBox(width: 4),
              Text(
                'Discoverable',
                style: TextStyle(color: successColor, fontSize: 12),
              ),
            ],
          ),
        );
      },
    );
  }
}
