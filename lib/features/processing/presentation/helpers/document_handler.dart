import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/l10n/l10n.dart';
import 'package:health_wallet/core/navigation/app_router.dart';
import 'package:health_wallet/features/processing/domain/entity/processing_session.dart';
import 'package:health_wallet/features/processing/domain/services/layout_extraction/layout_extraction_service.dart';
import 'package:health_wallet/features/processing/presentation/widgets/dialog_helper.dart';

mixin DocumentHandler<T extends StatefulWidget> on State<T> {
  Future<void> navigateToFhirMapper(
    BuildContext context,
    ProcessingSession session,
  ) async {
    try {
      // A document of a known layout is read without the model, so it opens
      // the review instead of the model download.
      final canProcess = await getIt<LayoutExtractionService>().canProcess(
        session.id,
        filePaths: session.filePaths,
      );

      if (!context.mounted) return;

      if (canProcess) {
        unawaited(context.router.push(ProcessingRoute(sessionId: session.id)));
        return;
      }

      unawaited(navigateToLoadModel(context, session));
    } catch (e) {
      if (context.mounted) {
        DialogHelper.showErrorDialog(
          context,
          context.l10n.failedToCreateEncounter('$e'),
        );
      }
    }
  }

  Future<void> navigateToLoadModel(
    BuildContext context,
    ProcessingSession session,
  ) async {
    final result = await context.router.push<bool>(
      LoadModelRoute(canAttachToEncounter: true, sessionId: session.id),
    );
    if (!context.mounted) return;

    // Read with the model now on the device, or, when the user chose to
    // attach without it, shown with only its pages and the attach action.
    if (result == null) return;
    unawaited(
      context.router.push(
        ProcessingRoute(sessionId: session.id, attachOnly: !result),
      ),
    );
  }
}
