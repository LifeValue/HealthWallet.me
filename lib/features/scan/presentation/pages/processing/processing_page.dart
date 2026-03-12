import 'package:auto_route/auto_route.dart';
import 'package:collection/collection.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_wallet/core/config/constants/app_constants.dart';
import 'package:health_wallet/core/config/constants/shared_prefs_constants.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/services/device_capability_service.dart';
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
import 'package:health_wallet/features/scan/presentation/widgets/ai_settings_dialog.dart';
import 'package:health_wallet/features/scan/presentation/widgets/debug_log_sheet.dart';
import 'package:health_wallet/features/scan/presentation/widgets/attach_to_encounter/attach_to_encounter_widget.dart';
import 'package:health_wallet/features/scan/presentation/widgets/custom_progress_indicator.dart';
import 'package:health_wallet/features/scan/presentation/widgets/preview_card.dart';
import 'package:health_wallet/features/scan/presentation/widgets/summary_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  final _encounterSectionKey = GlobalKey();
  final _encounterNameController = TextEditingController();
  final _pageController = PageController();
  DeviceAiCapability _deviceCapability = DeviceAiCapability.full;

  @override
  void initState() {
    context
        .read<ScanBloc>()
        .add(ScanSessionActivated(sessionId: widget.sessionId));
    _checkDeviceCapability();
    super.initState();
  }

  void _checkDeviceCapability() async {
    final capability = await getIt<DeviceCapabilityService>().getCapability();
    if (mounted) setState(() => _deviceCapability = capability);
  }

  @override
  void dispose() {
    _encounterNameController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _scrollToFormErrors() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _encounterSectionKey.currentContext ?? _formKey.currentContext;
      if (target == null) return;
      Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        alignment: 0.1,
      );
    });
  }

  void _saveResources(ScanState state) async {
    if (!_formKey.currentState!.validate()) {
      _scrollToFormErrors();
      return;
    }

    final activeSession =
        state.sessions.firstWhere((session) => session.id == widget.sessionId);

    if (activeSession.patient.hasSelection &&
        (activeSession.encounter.hasSelection ||
            activeSession.isDiagnosticReportContainer)) {
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
    return BlocConsumer<ScanBloc, ScanState>(
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

        final canRetry = displayedSession != null &&
            (displayedSession.status == ProcessingStatus.patientExtracted ||
                displayedSession.status == ProcessingStatus.draft ||
                displayedSession.status == ProcessingStatus.cancelled ||
                state.status is Failure ||
                state.status is CapacityFailure);

        final isStep2Retry = displayedSession != null &&
            (displayedSession.status == ProcessingStatus.draft ||
                (displayedSession.status == ProcessingStatus.patientExtracted &&
                    state.status is Failure));

        return Scaffold(
          backgroundColor: context.colorScheme.surface,
          appBar: AppBar(
            title: Text(context.l10n.processing, style: AppTextStyle.titleMedium),
            centerTitle: true,
            backgroundColor: context.colorScheme.surface,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            actions: [
              if (canRetry)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    Icons.refresh,
                    size: 20,
                    color: context.colorScheme.onSurface,
                  ),
                  tooltip: isStep2Retry
                      ? '${context.l10n.retry} (Step 2)'
                      : '${context.l10n.retry} (Step 1)',
                  onPressed: () {
                    if (isStep2Retry) {
                      context.read<ScanBloc>().add(
                            ScanProcessRemainingResources(
                              sessionId: widget.sessionId,
                            ),
                          );
                    } else {
                      context.read<ScanBloc>().add(
                            ScanMappingInitiated(sessionId: widget.sessionId),
                          );
                    }
                  },
                ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  Icons.tune,
                  size: 20,
                  color: displayedSession != null && displayedSession.isProcessing
                      ? context.colorScheme.onSurface.withValues(alpha: 0.3)
                      : context.colorScheme.onSurface,
                ),
                onPressed: displayedSession != null && displayedSession.isProcessing
                    ? null
                    : _showAiSettingsDialog,
              ),
              IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    Icons.terminal,
                    size: 18,
                    color: context.colorScheme.onSurface,
                  ),
                  onPressed: () => DebugLogSheet.show(context),
                ),
            ],
          ),
          body: Builder(builder: (context) {
          if (displayedSession == null) {
            return Center(child: Text(context.l10n.sessionNotFound));
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
            return _buildLoadingIndicator(context.l10n.preparingPreview);
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
                  isEditable: true,
                  onPagesChanged: (reordered) {
                    context.read<ScanBloc>().add(ScanPagesReordered(
                          sessionId: widget.sessionId,
                          reorderedPaths: reordered,
                        ));
                  },
                ),
                const SizedBox(height: Insets.small),
              ],
              const SizedBox(height: Insets.large),
              _buildMappingSection(state, displayedSession),
              _buildResourcesSection(state, displayedSession),
              const SizedBox(height: Insets.large),
            ]),
          );
        }),
        );
      },
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
    if (state.status is CapacityFailure) {
      return _buildCapacityFailure();
    }

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
                      context.l10n.processingFailed,
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
              label: context.l10n.retry,
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
                  context.l10n.processingCancelled,
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
            label: context.l10n.retry,
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
                ? context.l10n.processingBasicDetails
                : context.l10n.processingPages,
            secondaryText:
                displayedSession.status == ProcessingStatus.processingPatient
                    ? context.l10n.extractingPatientInfo
                    : context.l10n.pleaseWait,
            showProgressBar:
                displayedSession.status == ProcessingStatus.processing &&
                    state.useVision,
          ),
          const SizedBox(height: Insets.normal),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: context.l10n.cancel,
                  variant: AppButtonVariant.outlined,
                  onPressed: () => context
                      .read<ScanBloc>()
                      .add(ScanMappingCancelled(sessionId: widget.sessionId)),
                ),
              ),
              const SizedBox(width: Insets.smallNormal),
              Expanded(
                child: AppButton(
                  label: context.l10n.focusMode,
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

  Widget _buildCapacityFailure() {
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
                    Icons.memory,
                    color: context.colorScheme.error,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    context.l10n.processingFailed,
                    style: AppTextStyle.bodyMedium.copyWith(
                      color: context.colorScheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.processingFailedCapacity,
                style: AppTextStyle.bodySmall.copyWith(
                  color: context.colorScheme.onErrorContainer,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                context.l10n.processingFailedCapacitySuggestion,
                style: AppTextStyle.labelSmall.copyWith(
                  color: context.colorScheme.onErrorContainer.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Insets.normal),
        AppButton(
          label: context.l10n.increaseAiModelCapacity,
          variant: AppButtonVariant.primary,
          onPressed: _showAiSettingsDialog,
        ),
        const SizedBox(height: Insets.small),
        AppButton(
          label: context.l10n.goBack,
          variant: AppButtonVariant.transparent,
          onPressed: () => context.router.maybePop(),
        ),
      ],
    );
  }

  void _showAiSettingsDialog() async {
    final prefs = getIt<SharedPreferences>();
    final previousTokens =
        prefs.getInt(SharedPrefsConstants.aiMaxTokens) ??
            AppConstants.defaultMaxTokens;
    final previousGpu = prefs.getInt(SharedPrefsConstants.aiGpuLayers);
    final previousThreads = prefs.getInt(SharedPrefsConstants.aiThreads);
    final previousCtx = prefs.getInt(SharedPrefsConstants.aiContextSize);

    final result = await AiTokenSettingsDialog.show(
      context,
      currentTokens: previousTokens,
    );

    if (result != null && mounted) {
      await prefs.setInt(SharedPrefsConstants.aiGpuLayers, result.gpuLayers);
      await prefs.setInt(SharedPrefsConstants.aiThreads, result.threads);
      await prefs.setInt(SharedPrefsConstants.aiContextSize, result.contextSize);

      final bloc = context.read<ScanBloc>();
      bloc.add(ScanVisionToggled(useVision: result.useVision));

      final modelSettingsChanged = result.maxTokens != previousTokens ||
          result.gpuLayers != previousGpu ||
          result.threads != previousThreads ||
          result.contextSize != previousCtx;

      if (modelSettingsChanged) {
        bloc.add(ScanTokenCapacityUpdated(
          newMaxTokens: result.maxTokens,
          sessionId: widget.sessionId,
        ));
      }
    }
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
                  ? context.l10n.onlyOneSessionAtTime
                  : context.l10n.aiModelNotAvailable,
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
          encounterSectionKey: _encounterSectionKey,
          resources: displayedSession.resources,
          sessionId: widget.sessionId,
          patient: displayedSession.patient,
          encounter: displayedSession.encounter,
          diagnosticReport: displayedSession.diagnosticReport,
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

  void _showAddResourceDialog() async {
    final selectedResourceIds = await AppDialog.showMultiSelect(
      context: context,
      title: context.l10n.addResourcesTitle,
      description: context.l10n.chooseResourcesDescription,
      items: _getResourceTypes(context),
      confirmText: context.l10n.add,
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
    final isVisionOnBasicDevice =
        _deviceCapability == DeviceAiCapability.basicOnly && state.useVision;
    final isStep2Blocked = anotherSessionProcessing || isVisionOnBasicDevice;

    return Column(
      children: [
        if (isVisionOnBasicDevice) ...[
          Container(
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
          ),
          const SizedBox(height: Insets.smallNormal),
        ],
        Row(
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
                onPressed: isStep2Blocked
                    ? null
                    : () => context.read<ScanBloc>().add(
                          ScanProcessRemainingResources(
                            sessionId: widget.sessionId,
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

  void _attachToEncounter(ProcessingSession session) async {
    if (!_formKey.currentState!.validate()) {
      _scrollToFormErrors();
      return;
    }

    if (session.patient.hasSelection &&
        (session.encounter.hasSelection ||
            session.isDiagnosticReportContainer)) {
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
              ScanResourceCreationInitiated(sessionId: widget.sessionId),
            );
      },
    );
  }
}
