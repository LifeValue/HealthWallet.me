import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_wallet/core/l10n/l10n.dart';
import 'package:health_wallet/core/widgets/app_snack_bar.dart';
import 'package:health_wallet/features/processing/presentation/bloc/processing_bloc.dart';

/// Shows a translated snackbar when a scan or an import fails before it
/// becomes a session. Later failures belong to a session and are shown on
/// its processing page instead.
class CaptureErrorListener extends StatelessWidget {
  const CaptureErrorListener({required this.child, super.key});

  final Widget child;

  static const _captureReasons = {
    PipelineFailureReason.scanFailed,
    PipelineFailureReason.importFailed,
    PipelineFailureReason.noValidFiles,
  };

  @override
  Widget build(BuildContext context) {
    return BlocListener<ProcessingBloc, ProcessingState>(
      listenWhen: (previous, current) =>
          previous.status != current.status &&
          current.status is Failure &&
          _captureReasons.contains((current.status as Failure).reason),
      listener: (context, state) {
        final failure = state.status as Failure;
        AppSnackBar.show(
          context,
          message: failure.reason.localizedMessage(context.l10n),
          type: AppSnackBarType.error,
        );
      },
      child: child,
    );
  }
}
