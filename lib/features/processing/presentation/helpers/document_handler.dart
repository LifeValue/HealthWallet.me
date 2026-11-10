import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/l10n/l10n.dart';
import 'package:health_wallet/core/navigation/app_router.dart';
import 'package:health_wallet/core/utils/logger.dart';
import 'package:health_wallet/features/home/presentation/bloc/home_bloc.dart';
import 'package:health_wallet/features/processing/domain/entity/processing_session.dart';
import 'package:health_wallet/features/processing/domain/services/attach_documents_service.dart';
import 'package:health_wallet/features/processing/domain/services/layout_extraction/layout_extraction_service.dart';
import 'package:health_wallet/features/processing/presentation/bloc/processing_bloc.dart';
import 'package:health_wallet/features/processing/presentation/widgets/attach_to_encounter/attach_to_encounter_widget.dart';
import 'package:health_wallet/features/processing/presentation/widgets/dialog_helper.dart';
import 'package:health_wallet/features/user/presentation/preferences_modal/sections/patient/bloc/patient_bloc.dart';

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

    if (result == true) {
      unawaited(context.router.push(ProcessingRoute(sessionId: session.id)));
    } else {
      if (result == false) {
        final result = await showDialog<AttachToEncounterResult>(
          context: context,
          barrierDismissible: false,
          builder: (context) => const AttachToEncounterWidget(),
        );

        if (result == null || !context.mounted) return;

        final (patient, encounter) = result;
        final title = context.l10n.attachedDocuments;

        try {
          await getIt<AttachDocumentsService>().attach(
            patient: patient.existing!,
            encounter: encounter,
            filePaths: session.filePaths,
            title: title,
          );
          if (context.mounted) {
            context.read<PatientBloc>().add(const PatientPatientsLoaded());
            context.read<HomeBloc>().add(const HomeRefreshPreservingOrder());
            unawaited(context.router.replaceAll([RecordsRoute()]));
          }
        } catch (e, s) {
          logger.e('Attaching documents failed', e, s);
          if (context.mounted) {
            Navigator.of(context).pop();
            DialogHelper.showErrorDialog(
              context,
              context.l10n.failedToAttachDocuments('$e'),
            );
          }
        } finally {
          if (context.mounted) {
            context.read<ProcessingBloc>().add(
              SessionCleared(session: session),
            );
          }
        }
      }
    }
  }
}
