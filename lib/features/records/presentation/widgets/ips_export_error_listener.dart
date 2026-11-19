import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_wallet/core/l10n/l10n.dart';
import 'package:health_wallet/core/widgets/app_snack_bar.dart';
import 'package:health_wallet/features/records/presentation/bloc/records_bloc.dart';

/// Shows a translated snackbar when an IPS export fails. The export is
/// started from the share menu on Home and Records, so this sits above the
/// router to cover both.
class IpsExportErrorListener extends StatelessWidget {
  const IpsExportErrorListener({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocListener<RecordsBloc, RecordsState>(
      listenWhen: (previous, current) =>
          previous.ipsExportStatus != current.ipsExportStatus &&
          current.ipsExportStatus == IpsExportStatus.failed,
      listener: (context, state) {
        AppSnackBar.show(
          context,
          message: context.l10n.ipsExportFailed,
          type: AppSnackBarType.error,
        );
      },
      child: child,
    );
  }
}
