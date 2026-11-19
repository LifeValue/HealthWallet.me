import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_wallet/core/config/app_platform.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/l10n/l10n.dart';
import 'package:health_wallet/core/navigation/app_router.dart';
import 'package:health_wallet/core/widgets/dialogs/app_simple_dialog.dart';
import 'package:health_wallet/features/desktop/communication/presentation/bloc/communication_bloc.dart';

/// Desktop: asks the user whether a phone that holds the pairing key but
/// isn't the paired one may take its place. Nothing syncs until they answer.
class PhoneApprovalListener extends StatelessWidget {
  const PhoneApprovalListener({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!getIt<AppPlatform>().isDesktop) return child;
    final bloc = getIt<CommunicationBloc>();
    return BlocListener<CommunicationBloc, DesktopSyncState>(
      bloc: bloc,
      listenWhen: (previous, current) =>
          current.pendingApprovalName != null &&
          previous.pendingApprovalName != current.pendingApprovalName,
      listener: (context, state) {
        final dialogContext = getIt<AppRouter>().navigatorKey.currentContext;
        if (dialogContext == null) return;
        final l10n = dialogContext.l10n;
        AppSimpleDialog.showConfirmation(
          context: dialogContext,
          title: l10n.desktopNewDeviceConnecting,
          message: l10n.desktopApprovePhoneMessage(
            state.pendingApprovalName!,
            state.pairedDevice?.peerDeviceName ?? l10n.desktopCurrentDevice,
          ),
          confirmText: l10n.desktopSwitch,
          cancelText: l10n.desktopKeepCurrent,
          onConfirm: () =>
              bloc.add(const CommunicationApprovalAnswered(accepted: true)),
          onCancel: () =>
              bloc.add(const CommunicationApprovalAnswered(accepted: false)),
        );
      },
      child: child,
    );
  }
}
