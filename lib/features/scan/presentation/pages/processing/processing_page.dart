import 'package:auto_route/auto_route.dart';
import 'package:collection/collection.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/navigation/app_router.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/core/widgets/app_button.dart';
import 'package:health_wallet/core/widgets/dialogs/app_dialog.dart';
import 'package:health_wallet/core/widgets/dialogs/alert_dialogs.dart';
import 'package:health_wallet/features/scan/domain/entity/processing_session.dart';
import 'package:health_wallet/gen/assets.gen.dart';
import 'package:health_wallet/features/scan/domain/repository/scan_repository.dart';
import 'package:health_wallet/features/scan/presentation/bloc/scan_bloc.dart';
import 'package:health_wallet/features/scan/presentation/pages/processing/widgets/resources_form.dart';
import 'package:health_wallet/features/scan/presentation/widgets/attach_to_encounter/attach_to_encounter_widget.dart';
import 'package:health_wallet/features/scan/presentation/widgets/custom_progress_indicator.dart';
import 'package:health_wallet/features/scan/presentation/widgets/preview_card.dart';
import 'package:health_wallet/features/scan/presentation/widgets/summary_card.dart';

@RoutePage()
class ProcessingPage extends StatefulWidget {
  const ProcessingPage({
    required this.sessionId,
    super.key,
  });

  final String sessionId;

  @override
  State<ProcessingPage> createState() => _ProcessingPageState();
}

class _ProcessingPageState extends State<ProcessingPage> {
  final _formKey = GlobalKey<FormState>();
  final _encounterNameController = TextEditingController();
  final _pageController = PageController();

  @override
  void initState() {
    context
        .read<ScanBloc>()
        .add(ScanSessionActivated(sessionId: widget.sessionId));
    super.initState();
  }

  @override
  void dispose() {
    _encounterNameController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _saveResources(ScanState state) async {
    if (!_formKey.currentState!.validate()) return;

    final activeSession =
        state.sessions.firstWhere((session) => session.id == widget.sessionId);

    if (activeSession.patient.hasSelection &&
        activeSession.encounter.hasSelection) {
      context
          .read<ScanBloc>()
          .add(ScanResourceCreationInitiated(sessionId: widget.sessionId));
      return;
    }

    final result = await showDialog<AttachToEncounterResult>(
      context: context,
      builder: (context) => AttachToEncounterWidget(
        patient: activeSession.patient,
        encounter: activeSession.encounter,
      ),
    );

    if (result == null || !context.mounted) return;

    final (patient, encounter) = result;

    context.read<ScanBloc>().add(
          ScanEncounterAttached(
            sessionId: widget.sessionId,
            patient: patient,
            encounter: encounter,
          ),
        );

    context
        .read<ScanBloc>()
        .add(ScanResourceCreationInitiated(sessionId: widget.sessionId));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Processing', style: AppTextStyle.titleMedium),
        backgroundColor: context.colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: BlocConsumer<ScanBloc, ScanState>(
        listener: (context, state) {
          final displayedSession =
              state.sessions.firstWhereOrNull((s) => s.id == widget.sessionId);
          if (displayedSession == null) return;

          if (state.status == const ScanStatus.success()) {
            context
                .read<ScanBloc>()
                .add(ScanSessionCleared(session: displayedSession));
            context.router.replaceAll([const DashboardRoute()]);
          }
        },
        builder: (context, state) {
          final displayedSession =
              state.sessions.firstWhereOrNull((s) => s.id == widget.sessionId);
          if (displayedSession == null) {
            return const Center(child: Text("Session not found!"));
          }

          final sessionImages = state.sessionImagePaths[widget.sessionId] ??
              state.allImagePathsForOCR;

          final isConverting =
              state.status == const ScanStatus.convertingPdfs() &&
                  sessionImages.isEmpty;

          final isQueuedAndPreparing =
              displayedSession.status == ProcessingStatus.pending &&
                  sessionImages.isEmpty;

          if (isConverting || isQueuedAndPreparing) {
            return _buildLoadingIndicator('Preparing preview...');
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(Insets.normal),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SummaryCard(
                totalPagesForOcr: sessionImages.length,
              ),
              const SizedBox(height: Insets.normal),
              if (sessionImages.isNotEmpty) ...[
                PreviewCard(
                  imagePaths: sessionImages,
                  pageController: _pageController,
                ),
                const SizedBox(height: Insets.small),
              ],
              const SizedBox(height: Insets.large),
              _buildMappingSection(state, displayedSession),
              _buildResourcesSection(state, displayedSession),
              const SizedBox(height: Insets.large),
            ]),
          );
        },
      ),
    );
  }

  Widget _buildLoadingIndicator(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(message),
        ],
      ),
    );
  }

  Widget _buildMappingSection(
      ScanState state, ProcessingSession displayedSession) {
    if (state.status is Failure) {
      final error = (state.status as Failure).error;
      return Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(Insets.normal),
            decoration: BoxDecoration(
              color: context.colorScheme.errorContainer.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
              border:
                  Border.all(color: context.colorScheme.error.withOpacity(0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: context.colorScheme.error,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Processing failed',
                      style: AppTextStyle.bodyMedium.copyWith(
                        color: context.colorScheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  error,
                  style: AppTextStyle.bodySmall.copyWith(
                    color: context.colorScheme.onErrorContainer,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Insets.normal),
          if (displayedSession.status != ProcessingStatus.patientExtracted)
            AppButton(
              label: 'Retry',
              variant: AppButtonVariant.outlined,
              onPressed: () => context
                  .read<ScanBloc>()
                  .add(ScanMappingInitiated(sessionId: widget.sessionId)),
            ),
        ],
      );
    }

    if (displayedSession.status == ProcessingStatus.cancelled) {
      return Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(Insets.normal),
            decoration: BoxDecoration(
              color:
                  context.colorScheme.surfaceContainerHighest.withOpacity(0.5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: context.colorScheme.outline.withOpacity(0.5)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.cancel_outlined,
                  color: context.colorScheme.onSurfaceVariant,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Processing was cancelled',
                  style: AppTextStyle.bodyMedium.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Insets.normal),
          AppButton(
            label: 'Retry',
            variant: AppButtonVariant.outlined,
            onPressed: () => context
                .read<ScanBloc>()
                .add(ScanMappingInitiated(sessionId: widget.sessionId)),
          ),
        ],
      );
    }

    if (displayedSession.isProcessing) {
      return Column(
        children: [
          CustomProgressIndicator(
            progress: displayedSession.progress,
            text: displayedSession.status == ProcessingStatus.processingPatient
                ? 'Processing basic details...'
                : 'Processing pages...',
            secondaryText:
                displayedSession.status == ProcessingStatus.processingPatient
                    ? 'Extracting patient and encounter info.'
                    : 'It might take a while. Please wait.',
            showProgressBar:
                displayedSession.status == ProcessingStatus.processing,
          ),
          const SizedBox(height: Insets.normal),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Cancel',
                  variant: AppButtonVariant.outlined,
                  onPressed: () => context
                      .read<ScanBloc>()
                      .add(ScanMappingCancelled(sessionId: widget.sessionId)),
                ),
              ),
              const SizedBox(width: Insets.smallNormal),
              Expanded(
                child: AppButton(
                  label: 'Focus Mode',
                  icon: Assets.icons.scan.svg(),
                  variant: AppButtonVariant.primary,
                  onPressed: () {
                    context.router.push(const FocusModeRoute());
                  },
                ),
              ),
            ],
          ),
        ],
      );
    }

    if (displayedSession.status == ProcessingStatus.pending) {
      return _buildQueuedMessage();
    }

    return const SizedBox.shrink();
  }

  Widget _buildQueuedMessage() {
    return FutureBuilder(
      future: getIt<ScanRepository>().checkModelExistence(),
      builder: (context, asyncSnapshot) {
        if (!asyncSnapshot.hasData) return const SizedBox();
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.hourglass_empty,
                color: context.colorScheme.primary, size: 20),
            const SizedBox(width: 8),
            Text(
              asyncSnapshot.data!
                  ? 'Only one processing session can run at a time'
                  : 'AI model is not available',
              style: AppTextStyle.bodyMedium.copyWith(
                color: context.colorScheme.primary,
              ),
            )
          ],
        );
      },
    );
  }

  Widget _buildResourcesSection(
      ScanState state, ProcessingSession displayedSession) {
    if (displayedSession.status != ProcessingStatus.draft &&
        displayedSession.status != ProcessingStatus.patientExtracted) {
      return const SizedBox();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ResourcesForm(
          formKey: _formKey,
          resources: displayedSession.resources,
          sessionId: widget.sessionId,
          patient: displayedSession.patient,
          encounter: displayedSession.encounter,
          isAttachmentLocked: displayedSession.isDocumentAttached,
        ),
        if (displayedSession.status == ProcessingStatus.patientExtracted) ...[
          _buildScannedBasicButtons(state, displayedSession),
        ] else ...[
          _buildAddResourceButton(),
          const SizedBox(height: Insets.normal),
          SizedBox(
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
                  : () => _saveResources(state),
              child: Text(context.l10n.done),
            ),
          ),
        ]
      ],
    );
  }

  Widget _buildAddResourceButton() {
    return DottedBorder(
      options: RoundedRectDottedBorderOptions(
        radius: const Radius.circular(8),
        dashPattern: [6, 6],
        color: context.colorScheme.outline.withOpacity(
          context.isDarkMode ? 0.4 : 0.2,
        ),
      ),
      child: GestureDetector(
        onTap: _showAddResourceDialog,
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
                'Add resources',
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

  static const _resourceTypes = [
    DialogItem(id: 'AllergyIntolerance', label: 'Allergy Intolerance'),
    DialogItem(id: 'Condition', label: 'Condition'),
    DialogItem(id: 'DiagnosticReport', label: 'Diagnostic Report'),
    DialogItem(id: 'MedicationStatement', label: 'Medication Statement'),
    DialogItem(id: 'Observation', label: 'Observation'),
    DialogItem(id: 'Organization', label: 'Organization'),
    DialogItem(id: 'Practitioner', label: 'Practitioner'),
    DialogItem(id: 'Procedure', label: 'Procedure'),
  ];

  void _showAddResourceDialog() async {
    final selectedResourceIds = await AppDialog.showMultiSelect(
      context: context,
      title: 'Add Resources',
      description: 'Choose the resources you want to add for processing.',
      items: _resourceTypes,
      confirmText: 'Add',
    );

    if (selectedResourceIds != null &&
        selectedResourceIds.isNotEmpty &&
        mounted) {
      context.read<ScanBloc>().add(ScanResourcesAdded(
            sessionId: widget.sessionId,
            resourceTypes: selectedResourceIds,
          ));
    }
  }

  Widget _buildScannedBasicButtons(ScanState state, ProcessingSession session) {
    final anotherSessionProcessing = state.sessions.any(
      (s) => s.id != session.id && s.isProcessing,
    );
    return Row(
      children: [
        if (!session.isDocumentAttached) ...[
          Expanded(
            child: AppButton(
              label: context.l10n.attachToEncounter,
              variant: AppButtonVariant.transparent,
              onPressed: () => _attachToEncounter(session),
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
              onPressed: () => _finishSession(session),
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
            onPressed: anotherSessionProcessing
                ? null
                : () => context.read<ScanBloc>().add(
                      ScanProcessRemainingResources(
                        sessionId: widget.sessionId,
                      ),
                    ),
            enabled: !anotherSessionProcessing,
            fullWidth: false,
            padding: const EdgeInsets.all(8),
          ),
        ),
      ],
    );
  }

  void _attachToEncounter(ProcessingSession session) async {
    if (!_formKey.currentState!.validate()) return;

    if (session.patient.hasSelection && session.encounter.hasSelection) {
      context.read<ScanBloc>().add(
            ScanDocumentAttached(
              sessionId: widget.sessionId,
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
            sessionId: widget.sessionId,
            patient: patient,
            encounter: encounter,
          ),
        );

    context.read<ScanBloc>().add(
          ScanDocumentAttached(
            sessionId: widget.sessionId,
          ),
        );
  }

  void _finishSession(ProcessingSession session) {
    AlertDialogs.showConfirmation(
      context: context,
      title: context.l10n.finishProcessing,
      message: context.l10n.finishProcessingMessage,
      confirmText: context.l10n.done,
      cancelText: context.l10n.cancel,
      warningText: context.l10n.finishProcessingWarning,
      confirmButtonColor: context.colorScheme.primary,
      onConfirm: () {
        context.read<ScanBloc>().add(
              ScanSessionCleared(session: session),
            );
        context.router.maybePop();
      },
    );
  }
}
