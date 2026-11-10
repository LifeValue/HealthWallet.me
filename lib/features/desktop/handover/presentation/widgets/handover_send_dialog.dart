import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/l10n/display_names.dart';
import 'package:health_wallet/core/l10n/l10n.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/core/widgets/app_button.dart';
import 'package:health_wallet/features/desktop/handover/domain/entity/handover_session.dart';
import 'package:health_wallet/features/desktop/handover/presentation/bloc/phone_handover_bloc.dart';

/// Sends a processing session to the desktop and shows the transfer. Once
/// the files are there the session waits on the phone as handed over, and
/// its draft comes back to review.
class HandoverSendDialog extends StatefulWidget {
  const HandoverSendDialog({
    super.key,
    required this.sessionId,
    required this.fileCount,
    this.continueLabel,
  });

  final String sessionId;
  final int fileCount;

  /// The button that leaves the processing screen once the files are sent;
  /// "Continue scanning" when null.
  final String? continueLabel;

  static Future<void> show(
    BuildContext context, {
    required String sessionId,
    required int fileCount,
    String? continueLabel,
  }) => showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => Dialog(
      backgroundColor: context.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Insets.smallNormal),
      ),
      child: HandoverSendDialog(
        sessionId: sessionId,
        fileCount: fileCount,
        continueLabel: continueLabel,
      ),
    ),
  );

  @override
  State<HandoverSendDialog> createState() => _HandoverSendDialogState();
}

class _HandoverSendDialogState extends State<HandoverSendDialog> {
  final _bloc = getIt<PhoneHandoverBloc>();

  @override
  void initState() {
    super.initState();
    _bloc.add(PhoneHandoverSendRequested(sessionId: widget.sessionId));
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PhoneHandoverBloc, PhoneHandoverState>(
      bloc: _bloc,
      buildWhen: (a, b) =>
          a.transfers[widget.sessionId] != b.transfers[widget.sessionId],
      builder: (context, state) {
        final transfer = state.transfers[widget.sessionId];
        final status = transfer?.status;
        return ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(Insets.medium),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  context.l10n.desktopHandoverSendingToDesktop,
                  style: AppTextStyle.bodyMedium.copyWith(
                    color: context.colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: Insets.small),
                Text(
                  context.l10n.desktopHandoverFileCount(widget.fileCount),
                  style: AppTextStyle.labelLarge.copyWith(
                    color: context.secondaryTextColor,
                  ),
                ),
                const SizedBox(height: Insets.normal),
                switch (status) {
                  HandoverStatus.sent => const Icon(
                    Icons.check_circle_outline,
                    size: Insets.extraLarge,
                    color: AppColors.success,
                  ),
                  HandoverStatus.error => const Icon(
                    Icons.error_outline,
                    size: Insets.extraLarge,
                    color: AppColors.error,
                  ),
                  _ => LinearProgressIndicator(
                    value: status == HandoverStatus.sending
                        ? transfer?.progress
                        : null,
                    backgroundColor: context.borderColor,
                  ),
                },
                const SizedBox(height: Insets.small),
                Text(
                  phoneHandoverStatusText(transfer, context.l10n),
                  style: AppTextStyle.labelSmall.copyWith(
                    color: status == HandoverStatus.error
                        ? AppColors.error
                        : context.secondaryTextColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: Insets.normal),
                ..._buttons(context, status),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buttons(BuildContext context, HandoverStatus? status) =>
      switch (status) {
        HandoverStatus.sent => [
          AppButton(
            label: widget.continueLabel ?? context.l10n.continueScanning,
            height: Insets.large,
            onPressed: () =>
                Navigator.of(context).popUntil((route) => route.isFirst),
          ),
          const SizedBox(height: Insets.small),
          AppButton(
            label: context.l10n.desktopClose,
            variant: AppButtonVariant.outlined,
            height: Insets.large,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
        HandoverStatus.error => [
          AppButton(
            label: context.l10n.desktopClose,
            height: Insets.large,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
        _ => [
          AppButton(
            label: context.l10n.cancel,
            variant: AppButtonVariant.outlined,
            height: Insets.large,
            onPressed: () {
              _bloc.add(
                PhoneHandoverCancelRequested(sessionId: widget.sessionId),
              );
              Navigator.of(context).pop();
            },
          ),
        ],
      };
}
