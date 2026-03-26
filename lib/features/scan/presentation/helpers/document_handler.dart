import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/navigation/app_router.dart';
import 'package:health_wallet/features/home/presentation/bloc/home_bloc.dart';
import 'package:health_wallet/features/records/domain/entity/encounter/encounter.dart';
import 'package:health_wallet/features/scan/domain/entity/processing_session.dart';
import 'package:health_wallet/features/scan/domain/repository/scan_repository.dart';
import 'package:health_wallet/features/scan/domain/services/document_reference_service.dart';
import 'package:health_wallet/features/scan/presentation/bloc/scan_bloc.dart';
import 'package:health_wallet/features/scan/presentation/widgets/dialog_helper.dart';
import 'package:health_wallet/features/scan/presentation/widgets/attach_to_encounter/attach_to_encounter_widget.dart';
import 'package:health_wallet/features/sync/domain/repository/sync_repository.dart';
import 'package:health_wallet/features/sync/domain/services/source_type_service.dart';
import 'package:health_wallet/features/user/presentation/preferences_modal/sections/patient/bloc/patient_bloc.dart';
import 'package:auto_route/auto_route.dart';

mixin DocumentHandler<T extends StatefulWidget> on State<T> {
  Future<void> navigateToFhirMapper(
    BuildContext context,
    ProcessingSession session,
  ) async {
    try {
      final scanRepository = getIt<ScanRepository>();

      final isModelLoaded = await scanRepository.checkModelExistence();

      if (!context.mounted) return;

      if (isModelLoaded) {
        context.router.push(ProcessingRoute(sessionId: session.id));
        return;
      }

      navigateToLoadModel(context, session);
    } catch (e) {
      if (context.mounted) {
        DialogHelper.showErrorDialog(context, 'Failed to create encounter: $e');
      }
    }
  }

  Future<void> navigateToLoadModel(
    BuildContext context,
    ProcessingSession session,
  ) async {
    final result = await context.router
        .push<bool>(LoadModelRoute(canAttachToEncounter: true));
    if (!context.mounted) return;

    if (result == true) {
      context.router.push(ProcessingRoute(sessionId: session.id));
    } else {
      if (result == false) {
        final result = await showDialog<AttachToEncounterResult>(
          context: context,
          barrierDismissible: false,
          builder: (context) => const AttachToEncounterWidget(),
        );

        if (result == null || !context.mounted) return;

        final (patient, encounter) = result;

        final existingPatient = patient.existing!;

        Encounter finalEncounter;
        if (encounter.draft != null) {
          final homeState = context.read<HomeBloc>().state;
          final patientState = context.read<PatientBloc>().state;

          final selectedPatient = patientState.patients.isNotEmpty
              ? patientState.patients.firstWhere(
                  (p) => p.id == patientState.selectedPatientId,
                  orElse: () => patientState.patients.first,
                )
              : null;

          final patientForSource = selectedPatient ?? homeState.patient;
          final patientId = patientForSource?.id ?? 'patient-default';
          final patientName =
              patientForSource?.displayTitle ?? 'Unknown Patient';

          final sourceTypeService =
              getIt<SourceTypeService>();
          final walletSource =
              await sourceTypeService.getWritableSourceForPatient(
            patientId: patientId,
            patientName: patientName,
            availableSources: homeState.sources,
          );

          finalEncounter = encounter.draft!.toFhirResource(
            sourceId: walletSource.id,
            subjectId: existingPatient.subjectId,
          ) as Encounter;

          getIt<SyncRepository>().saveResources([finalEncounter]);
        } else {
          finalEncounter = encounter.existing!;
        }

        if (!context.mounted) return;

        try {
          await attachToEncounter(context, session.filePaths, finalEncounter);
          if (context.mounted) {
            context.read<ScanBloc>().add(ScanSessionCleared(session: session));
          }
        } catch (e) {
          if (context.mounted) {
            context.read<ScanBloc>().add(ScanSessionCleared(session: session));
          }
          rethrow;
        }
      }
    }
  }
  Future<void> attachToEncounter(
    BuildContext context,
    List<String> filePaths,
    Encounter encounter,
  ) async {
    try {
      final homeState = context.read<HomeBloc>().state;
      final patientState = context.read<PatientBloc>().state;

      final selectedPatient = patientState.patients.isNotEmpty
          ? patientState.patients.firstWhere(
              (p) => p.id == patientState.selectedPatientId,
              orElse: () => patientState.patients.first,
            )
          : null;

      final patient = selectedPatient ?? homeState.patient;
      final patientId = patient?.id ?? 'patient-default';
      final patientName = patient?.displayTitle ?? 'Unknown Patient';

      final sourceTypeService = getIt<SourceTypeService>();
      final walletSource = await sourceTypeService.getWritableSourceForPatient(
        patientId: patientId,
        patientName: patientName,
        availableSources: homeState.sources,
      );

      if (context.mounted) {
        context.read<PatientBloc>().add(
              const PatientPatientsLoaded(),
            );
      }

      final documentReferenceService =
          getIt<DocumentReferenceService>();

      await documentReferenceService.saveGroupedDocumentsAsFhirRecords(
        filePaths: filePaths,
        patientId: patientId,
        encounter: encounter,
        sourceId: walletSource.id,
        title: 'Attached Documents',
      );

      if (context.mounted) {
        context.read<HomeBloc>().add(const HomeRefreshPreservingOrder());
      }

      if (context.mounted) {
        context.router.replaceAll([RecordsRoute()]);
      }
    } catch (e) {
      if (context.mounted) Navigator.of(context).pop();

      if (context.mounted) {
        DialogHelper.showErrorDialog(context, 'Failed to attach documents: $e');
      }
    }
  }
}