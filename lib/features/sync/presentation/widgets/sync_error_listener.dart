import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_wallet/core/widgets/app_snack_bar.dart';
import 'package:health_wallet/features/sync/presentation/bloc/sync_bloc.dart';

/// Shows a failed sync's translated message as a snackbar. It sits above
/// the router, because Fasten and demo-data syncs start outside the sync page.
class SyncErrorListener extends StatelessWidget {
  const SyncErrorListener({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocListener<SyncBloc, SyncState>(
      listenWhen: (previous, current) =>
          previous.errorMessage != current.errorMessage &&
          current.errorMessage != null,
      listener: (context, state) {
        AppSnackBar.show(
          context,
          message: state.errorMessage!,
          type: AppSnackBarType.error,
        );
      },
      child: child,
    );
  }
}
