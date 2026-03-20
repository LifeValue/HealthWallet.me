import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_wallet/core/services/device_capability_service.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/core/widgets/app_button.dart';
import 'package:health_wallet/features/scan/domain/entity/staged_resource.dart';
import 'package:health_wallet/core/widgets/dialogs/app_dialog.dart';
import 'package:health_wallet/core/widgets/dialogs/app_simple_dialog.dart';
import 'package:health_wallet/features/scan/domain/entity/processing_session.dart';
import 'package:health_wallet/features/scan/presentation/bloc/scan_bloc.dart';
import 'package:health_wallet/features/scan/presentation/pages/processing/widgets/resources_form.dart';
import 'package:health_wallet/features/scan/presentation/widgets/attach_to_encounter/attach_to_encounter_widget.dart';
import 'package:health_wallet/gen/assets.gen.dart';

class ProcessingResourcesSection extends StatelessWidget {
  final ScanState state;
  final ProcessingSession displayedSession;
  final String sessionId;
  final GlobalKey<FormState> formKey;
  final GlobalKey encounterSectionKey;
  final DeviceAiCapability deviceCapability;
  final VoidCallback onScrollToFormErrors;
  final VoidCallback onSaveResources;

  const ProcessingResourcesSection({
    required this.state,
    required this.displayedSession,
    required this.sessionId,
    required this.formKey,
    required this.encounterSectionKey,
    required this.deviceCapability,
    required this.onScrollToFormErrors,
    required this.onSaveResources,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (displayedSession.status != ProcessingStatus.draft &&
        displayedSession.status != ProcessingStatus.patientExtracted) {
      return const SizedBox();
    }

    final isPatientMatched =
        displayedSession.patient.mode == ImportMode.linkExisting &&
            displayedSession.patient.existing != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ResourcesForm(
          formKey: formKey,
          encounterSectionKey: encounterSectionKey,
          resources: displayedSession.resources,
          sessionId: sessionId,
          patient: displayedSession.patient,
          encounter: displayedSession.encounter,
          diagnosticReport: displayedSession.diagnosticReport,
          isAttachmentLocked: displayedSession.isDocumentAttached,
        ),
        if (displayedSession.status == ProcessingStatus.patientExtracted) ...[
          _ScannedBasicButtons(
            state: state,
            session: displayedSession,
            sessionId: sessionId,
            formKey: formKey,
            deviceCapability: deviceCapability,
            onScrollToFormErrors: onScrollToFormErrors,
          ),
        ] else ...[
          _AddResourceButton(sessionId: sessionId),
          const SizedBox(height: Insets.normal),
          _SaveButton(
            state: state,
            onSaveResources: onSaveResources,
          ),
        ]
      ],
    );
  }
}

class _SaveButton extends StatelessWidget {
  final ScanState state;
  final VoidCallback onSaveResources;

  const _SaveButton({
    required this.state,
    required this.onSaveResources,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: context.colorScheme.primary,
          foregroundColor: context.isDarkMode
              ? Colors.white
              : context.colorScheme.onPrimary,
          padding: const EdgeInsets.all(8),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadiusGeometry.circular(8)),
        ),
        onPressed: state.status == const ScanStatus.savingResources()
            ? null
            : onSaveResources,
        child: Text(context.l10n.done),
      ),
    );
  }
}

class _AddResourceButton extends StatelessWidget {
  final String sessionId;

  const _AddResourceButton({required this.sessionId});

  @override
  Widget build(BuildContext context) {
    return DottedBorder(
      options: RoundedRectDottedBorderOptions(
        radius: const Radius.circular(8),
        dashPattern: [6, 6],
        color: context.colorScheme.outline.withOpacity(
          context.isDarkMode ? 0.4 : 0.2,
        ),
      ),
      child: GestureDetector(
        onTap: () => _showAddResourceDialog(context),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: Insets.normal),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add,
                color: context.colorScheme.onSurface,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                context.l10n.addResources,
                style: AppTextStyle.bodySmall.copyWith(
                  color: context.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<DialogItem> _getResourceTypes(BuildContext context) {
    return [
      DialogItem(
          id: 'AllergyIntolerance', label: context.l10n.allergyIntolerance),
      DialogItem(id: 'Condition', label: context.l10n.condition),
      DialogItem(id: 'DiagnosticReport', label: context.l10n.diagnosticReport),
      DialogItem(
          id: 'MedicationStatement', label: context.l10n.medicationStatement),
      DialogItem(id: 'Observation', label: context.l10n.observation),
      DialogItem(id: 'Organization', label: context.l10n.organization),
      DialogItem(id: 'Practitioner', label: context.l10n.practitioner),
      DialogItem(id: 'Procedure', label: context.l10n.procedure),
    ];
  }

  void _showAddResourceDialog(BuildContext context) async {
    final selectedResourceIds = await AppDialog.showMultiSelect(
      context: context,
      title: context.l10n.addResourcesTitle,
      description: context.l10n.chooseResourcesDescription,
      items: _getResourceTypes(context),
      confirmText: context.l10n.add,
    );

    if (selectedResourceIds != null &&
        selectedResourceIds.isNotEmpty &&
        context.mounted) {
      context.read<ScanBloc>().add(ScanResourcesAdded(
            sessionId: sessionId,
            resourceTypes: selectedResourceIds,
          ));
    }
  }
}

class _ScannedBasicButtons extends StatelessWidget {
  final ScanState state;
  final ProcessingSession session;
  final String sessionId;
  final GlobalKey<FormState> formKey;
  final DeviceAiCapability deviceCapability;
  final VoidCallback onScrollToFormErrors;

  const _ScannedBasicButtons({
    required this.state,
    required this.session,
    required this.sessionId,
    required this.formKey,
    required this.deviceCapability,
    required this.onScrollToFormErrors,
  });

  @override
  Widget build(BuildContext context) {
    final anotherSessionProcessing = state.sessions.any(
      (s) => s.id != session.id && s.isProcessing,
    );
    final isVisionOnBasicDevice =
        deviceCapability == DeviceAiCapability.basicOnly && state.useVision;
    final isStep2Blocked = anotherSessionProcessing || isVisionOnBasicDevice;

    return Column(
      children: [
        if (isVisionOnBasicDevice) ...[
          _VisionNotAvailableBanner(),
          const SizedBox(height: Insets.smallNormal),
        ],
        Row(
          children: [
            if (!session.isDocumentAttached) ...[
              Expanded(
                child: AppButton(
                  label: context.l10n.attachToEncounter,
                  variant: AppButtonVariant.transparent,
                  onPressed: () => _attachToEncounter(context),
                  fullWidth: false,
                  padding: const EdgeInsets.all(8),
                ),
              ),
              const SizedBox(width: Insets.normal),
            ] else ...[
              Expanded(
                child: AppButton(
                  label: context.l10n.done,
                  variant: AppButtonVariant.transparent,
                  onPressed: () => _finishSession(context),
                  fullWidth: false,
                  padding: const EdgeInsets.all(8),
                ),
              ),
              const SizedBox(width: Insets.normal),
            ],
            Expanded(
              child: AppButton(
                label: context.l10n.continueProcessing,
                variant: AppButtonVariant.primary,
                onPressed: isStep2Blocked
                    ? null
                    : () => context.read<ScanBloc>().add(
                          ScanProcessRemainingResources(
                            sessionId: sessionId,
                          ),
                        ),
                enabled: !isStep2Blocked,
                fullWidth: false,
                padding: const EdgeInsets.all(8),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _attachToEncounter(BuildContext context) async {
    if (!formKey.currentState!.validate()) {
      onScrollToFormErrors();
      return;
    }

    if (session.patient.mode == ImportMode.linkExisting &&
        session.patient.hasSelection &&
        (session.encounter.hasSelection ||
            session.isDiagnosticReportContainer)) {
      context.read<ScanBloc>().add(
            ScanDocumentAttached(
              sessionId: sessionId,
            ),
          );
      return;
    }

    final result = await showDialog<AttachToEncounterResult>(
      context: context,
      builder: (context) => AttachToEncounterWidget(
        patient: session.patient,
        encounter: session.encounter,
      ),
    );

    if (result == null || !context.mounted) return;

    final (patient, encounter) = result;

    context.read<ScanBloc>().add(
          ScanEncounterAttached(
            sessionId: sessionId,
            patient: patient,
            encounter: encounter,
          ),
        );

    context.read<ScanBloc>().add(
          ScanDocumentAttached(
            sessionId: sessionId,
          ),
        );
  }

  void _finishSession(BuildContext context) {
    AppSimpleDialog.showDestructiveConfirmation(
      context: context,
      title: context.l10n.finishProcessing,
      message: context.l10n.finishProcessingMessage,
      confirmText: context.l10n.done,
      cancelText: context.l10n.cancel,
      warningText: context.l10n.finishProcessingWarning,
      confirmButtonColor: context.colorScheme.primary,
      onConfirm: () {
        context.read<ScanBloc>().add(
              ScanResourceCreationInitiated(sessionId: sessionId),
            );
      },
    );
  }
}

class _VisionNotAvailableBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Insets.normal),
      decoration: BoxDecoration(
        color: context.colorScheme.tertiaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: context.colorScheme.tertiary.withOpacity(0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.processingStep2NotAvailableTitle,
            style: AppTextStyle.bodyMedium.copyWith(
              color: context.colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Assets.icons.information.svg(
                width: 18,
                height: 18,
                colorFilter: ColorFilter.mode(
                  context.colorScheme.tertiary,
                  BlendMode.srcIn,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  context.l10n.processingStep2NotEnoughRam,
                  style: AppTextStyle.bodySmall.copyWith(
                    color: context.colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
