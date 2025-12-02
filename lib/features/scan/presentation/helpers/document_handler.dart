import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/navigation/app_router.dart';
import 'package:health_wallet/features/home/presentation/bloc/home_bloc.dart';
import 'package:health_wallet/features/scan/domain/entity/processing_session.dart';
import 'package:health_wallet/features/scan/domain/repository/scan_repository.dart';
import 'package:health_wallet/features/scan/domain/services/document_reference_service.dart';
import 'package:health_wallet/features/scan/presentation/bloc/scan_bloc.dart';
import 'package:health_wallet/features/scan/presentation/widgets/dialog_helper.dart';
import 'package:health_wallet/features/sync/domain/services/source_type_service.dart';
import 'package:health_wallet/features/user/presentation/preferences_modal/sections/patient/bloc/patient_bloc.dart';
import 'package:auto_route/auto_route.dart';

/// Mixin providing common document handling functionality for scan and import pages.
///
/// This mixin extracts duplicate code for navigating to FHIR mapper,
/// attaching documents to encounters, and handling document taps/deletion.
mixin DocumentHandler<T extends StatefulWidget> on State<T> {
  /// Navigate to the FHIR mapper page after loading the model.
  Future<void> navigateToFhirMapper(
    BuildContext context,
    ProcessingSession session,
  ) async {
    try {
      final scanRepository = getIt<ScanRepository>();

      final isModelLoaded = await scanRepository.checkModelExistence();

      if (!context.mounted) return;

      if (isModelLoaded) {
        context.router.push(FhirMapperRoute(sessionId: session.id));
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
      context.router.push(FhirMapperRoute(sessionId: session.id));
    } else {
      context.read<ScanBloc>().add(ScanSessionCleared(session: session));

      if (result == false) {
        final encounterId =
            await context.router.push<String>(const AttachToEncounterRoute());

        if (encounterId == null || !context.mounted) return;

        await attachToEncounter(context, session.filePaths, encounterId);
      }
    }
  }

  /// Attach documents to the specified encounter.
  Future<void> attachToEncounter(
    BuildContext context,
    List<String> filePaths,
    String encounterId,
  ) async {
    DialogHelper.showLoadingDialog(
      context,
      'Attaching documents to encounter...',
    );

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

      final sourceTypeService = GetIt.instance.get<SourceTypeService>();
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
          GetIt.instance.get<DocumentReferenceService>();

      await documentReferenceService.saveGroupedDocumentsAsFhirRecords(
        filePaths: filePaths,
        patientId: patientId,
        encounterId: encounterId,
        sourceId: walletSource.id,
        title: 'Attached Documents',
      );

      if (context.mounted) {
        context.read<HomeBloc>().add(const HomeRefreshPreservingOrder());
      }

      if (context.mounted) Navigator.of(context).pop();

      if (context.mounted) {
        final bloc = context.read<ScanBloc>();
        final totalDocuments = filePaths.length;

        DialogHelper.showAttachmentSuccessDialog(
          context,
          totalDocuments,
          encounterId,
          bloc,
        );
      }
    } catch (e) {
      if (context.mounted) Navigator.of(context).pop();

      if (context.mounted) {
        DialogHelper.showErrorDialog(context, 'Failed to attach documents: $e');
      }
    }
  }
}
