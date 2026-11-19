import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_wallet/core/l10n/l10n.dart';
import 'package:health_wallet/core/widgets/app_snack_bar.dart';
import 'package:health_wallet/features/wallet_pass/presentation/bloc/wallet_pass_bloc.dart';

/// Shows a translated snackbar when adding a wallet pass fails. Success shows
/// nothing: the Apple or Google Wallet screen is the confirmation.
class WalletPassErrorListener extends StatelessWidget {
  const WalletPassErrorListener({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocListener<WalletPassBloc, WalletPassState>(
      listenWhen: (previous, current) =>
          previous.status != current.status &&
          current.status == WalletPassStatus.failure,
      listener: (context, state) {
        AppSnackBar.show(
          context,
          message: state.errorMessage ?? context.l10n.walletPassFailed,
          type: AppSnackBarType.error,
        );
      },
      child: child,
    );
  }
}
