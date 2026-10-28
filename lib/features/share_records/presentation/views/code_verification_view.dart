import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_wallet/core/l10n/l10n.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/core/utils/responsive.dart';
import 'package:health_wallet/core/widgets/app_button.dart';
import 'package:health_wallet/features/share_records/presentation/bloc/share_records_bloc.dart';
import 'package:health_wallet/features/share_records/presentation/bloc/share_records_event.dart';
import 'package:health_wallet/features/share_records/presentation/bloc/share_records_state.dart';

/// Both phones show the same code; the sender releases the records only
/// after the users have checked that the codes match.
class CodeVerificationView extends StatelessWidget {
  final ShareRecordsState state;

  const CodeVerificationView({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final code = state.verificationCode ?? '';
    final mutedColor = context.colorScheme.onSurface.withValues(alpha: 0.6);

    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: context.screenHorizontalPadding,
          vertical: Insets.large,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.verified_user_outlined,
                size: Insets.huge,
                color: AppColors.primary,
              ),
              const SizedBox(height: Insets.medium),
              Text(
                _formatCode(code),
                textAlign: TextAlign.center,
                style: AppTextStyle.titleLarge.copyWith(
                  fontSize: 44,
                  letterSpacing: 4,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: context.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: Insets.medium),
              Text(
                state.isSending
                    ? context.l10n.shareVerifySenderHint
                    : context.l10n.shareVerifyReceiverHint,
                textAlign: TextAlign.center,
                style: AppTextStyle.bodyMedium.copyWith(color: mutedColor),
              ),
              const SizedBox(height: Insets.large),
              if (state.isSending) ...[
                AppButton(
                  label: context.l10n.shareVerifyCodesMatch,
                  onPressed: () => context.read<ShareRecordsBloc>().add(
                    const ShareRecordsEvent.verificationConfirmed(),
                  ),
                ),
                const SizedBox(height: Insets.small),
              ] else ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: Insets.normal,
                      height: Insets.normal,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: Insets.small),
                    Flexible(
                      child: Text(
                        context.l10n.shareVerifyWaitingForSender,
                        style: AppTextStyle.bodyMedium.copyWith(
                          color: mutedColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Insets.medium),
              ],
              AppButton(
                label: context.l10n.cancel,
                variant: AppButtonVariant.outlined,
                onPressed: () => cancel(context, state),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Ends the session on both phones; the records are never released.
  static void cancel(BuildContext context, ShareRecordsState state) {
    context.read<ShareRecordsBloc>().add(
      state.isSending
          ? const ShareRecordsEvent.killSessionRequested()
          : const ShareRecordsEvent.dataDestructionConfirmed(),
    );
  }

  static String _formatCode(String code) =>
      code.length == 6 ? '${code.substring(0, 3)} ${code.substring(3)}' : code;
}
