import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/core/widgets/app_button.dart';
import 'package:health_wallet/features/share_records/presentation/bloc/share_records_bloc.dart';
import 'package:health_wallet/features/share_records/presentation/bloc/share_records_event.dart';
import 'package:health_wallet/features/share_records/presentation/bloc/share_records_state.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:health_wallet/gen/assets.gen.dart';

class SessionEndedView extends StatelessWidget {
  final ShareRecordsState state;

  const SessionEndedView({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final statusMessage = state.statusMessage?.toLowerCase() ?? '';
    final isRejected = statusMessage.contains('declined') ||
                       statusMessage.contains('rejected');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Insets.large),
      child: Column(
        children: [
          const Spacer(flex: 2),
          isRejected
              ? SvgPicture.asset(
                  'assets/images/invitation-declined.svg',
                  width: 120,
                  height: 120,
                )
              : Assets.images.completeCheck.svg(width: 64, height: 64),
          const SizedBox(height: Insets.large),
          Text(
            isRejected ? 'Invitation Declined' : 'Session Complete',
            style: AppTextStyle.titleMedium.copyWith(
              color: context.colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: Insets.small),
          Text(
            isRejected
                ? 'The receiver declined your invitation to view the records.'
                : 'All shared data has been securely removed from this device',
            style: AppTextStyle.bodyMedium.copyWith(
              color: context.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: Insets.large),
          AppButton(
            label: 'Back Home',
            onPressed: () => context.maybePop(),
          ),
          const Spacer(flex: 3),
        ],
      ),
    );
  }
}

class ErrorView extends StatelessWidget {
  final ShareRecordsState state;

  const ErrorView({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Insets.large),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: AppColors.error,
            ),
            const SizedBox(height: Insets.large),
            Text(
              'Connection Failed',
              style: AppTextStyle.titleMedium.copyWith(
                color: context.colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Insets.small),
            Text(
              state.errorMessage ?? 'Unable to connect. Please try again.',
              style: AppTextStyle.bodyMedium.copyWith(
                color: context.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Insets.large),
            AppButton(
              label: 'Retry',
              variant: AppButtonVariant.primary,
              fullWidth: true,
              onPressed: () {
                context.read<ShareRecordsBloc>().add(
                      const ShareRecordsEvent.connectionRetried(),
                    );
              },
            ),
            const SizedBox(height: Insets.small),
            AppButton(
              label: 'Cancel',
              variant: AppButtonVariant.outlined,
              fullWidth: true,
              onPressed: () {
                context.read<ShareRecordsBloc>().add(
                      state.mode == ShareMode.sending
                          ? const ShareRecordsEvent.sendModeSelected()
                          : const ShareRecordsEvent.modeCleared(),
                    );
              },
            ),
          ],
        ),
      ),
    );
  }
}
