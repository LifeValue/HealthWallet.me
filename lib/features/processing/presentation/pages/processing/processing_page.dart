import 'package:auto_route/auto_route.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_wallet/core/config/app_platform.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/l10n/l10n.dart';
import 'package:health_wallet/core/services/device_capability_service.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/core/utils/date_format_utils.dart';
import 'package:health_wallet/core/utils/logger.dart';
import 'package:health_wallet/core/utils/responsive.dart';
import 'package:health_wallet/core/widgets/app_button.dart';
import 'package:health_wallet/core/widgets/app_message_card.dart';
import 'package:health_wallet/core/widgets/app_snack_bar.dart';
import 'package:health_wallet/core/widgets/dialogs/app_simple_dialog.dart';
import 'package:health_wallet/features/dashboard/presentation/helpers/page_view_navigation_controller.dart';
import 'package:health_wallet/features/desktop/handover/presentation/utils/handover_utils.dart';
import 'package:health_wallet/features/desktop/lww_sync/presentation/bloc/lww_sync_bloc.dart';
import 'package:health_wallet/features/processing/domain/entity/processing_session.dart';
import 'package:health_wallet/features/processing/domain/entity/staged_resource.dart';
import 'package:health_wallet/features/processing/domain/services/layout_extraction/layout_extraction_service.dart';
import 'package:health_wallet/features/processing/presentation/bloc/processing_bloc.dart';
import 'package:health_wallet/features/processing/presentation/pages/processing/widgets/processing_mapping_section.dart';
import 'package:health_wallet/features/processing/presentation/pages/processing/widgets/processing_resources_section.dart';
import 'package:health_wallet/features/processing/presentation/widgets/ai_settings/ai_settings_dialog.dart';
import 'package:health_wallet/features/processing/presentation/widgets/attach_to_encounter/attach_to_encounter_widget.dart';
import 'package:health_wallet/features/processing/presentation/widgets/debug_log_button.dart';
import 'package:health_wallet/features/processing/presentation/widgets/preview_card.dart';
import 'package:health_wallet/features/processing/presentation/widgets/summary_card.dart';
import 'package:health_wallet/features/user/presentation/bloc/user_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

@RoutePage()
class ProcessingPage extends StatefulWidget {
  const ProcessingPage({
    required this.sessionId,
    this.attachOnly = false,
    super.key,
  });

  final String sessionId;

  /// The user chose to attach the document without the AI: only its pages
  /// and the attach action are shown, nothing is read.
  final bool attachOnly;

  @override
  State<ProcessingPage> createState() => _ProcessingPageState();
}

class _ProcessingPageState extends State<ProcessingPage> {
  final _formKey = GlobalKey<FormState>();
  final _encounterSectionKey = GlobalKey();
  final _encounterNameController = TextEditingController();
  final _pageController = PageController();
  DeviceAiCapability _deviceCapability = DeviceAiCapability.full;

  /// Set once this page clears its own session (after saving), so its
  /// going isn't taken for the other device taking it back.
  bool _leaving = false;

  /// Whether the document was filed without being read, here or from the
  /// pages-only view, so the saved message names the visit it went to.
  bool _attachedWithoutProcessing = false;

  @override
  void initState() {
    context.read<ProcessingBloc>().add(
      SessionActivated(sessionId: widget.sessionId),
    );
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

  /// Asks where the document goes, then files it there without reading it.
  Future<void> _attachWithoutProcessing() async {
    final result = await showDialog<AttachToEncounterResult>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AttachToEncounterWidget(),
    );
    if (result == null || !mounted) return;
    _attachedWithoutProcessing = true;
    final (patient, encounter) = result;
    context.read<ProcessingBloc>()
      ..add(
        EncounterAttached(
          sessionId: widget.sessionId,
          patient: patient,
          encounter: encounter,
        ),
      )
      ..add(ResourceCreationInitiated(sessionId: widget.sessionId));
  }

  /// The visit a document was attached to, as the user picked it: its name
  /// and, when known, its date.
  String _visitLabel(StagedEncounter encounter) {
    final region = context.read<UserBloc>().state.regionPreset;
    final (name, date) = switch (encounter) {
      StagedEncounter(:final existing?) => (
        existing.displayTitle,
        DateFormatUtils.formatDate(existing.date, region),
      ),
      StagedEncounter(:final draft?) => (
        draft.encounterType.value,
        DateFormatUtils.formatIsoForDisplay(draft.periodStart.value, region),
      ),
      _ => ('', ''),
    };
    return [name, date].where((part) => part.isNotEmpty).join(', ');
  }

  void _scrollToFormErrors() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target =
          _encounterSectionKey.currentContext ?? _formKey.currentContext;
      if (target == null) return;
      Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        alignment: 0.1,
      );
    });
  }

  void _saveResources(ProcessingState state) async {
    if (!_formKey.currentState!.validate()) {
      _scrollToFormErrors();
      return;
    }

    final activeSession = state.sessions.firstWhere(
      (session) => session.id == widget.sessionId,
    );

    // A new person the document does not name would be saved nameless.
    if (activeSession.patient.needsName) {
      _scrollToFormErrors();
      AppSnackBar.show(
        context,
        message: context.l10n.patientNameRequired,
        type: AppSnackBarType.error,
      );
      return;
    }

    if (activeSession.patient.hasSelection &&
        (activeSession.encounter.hasSelection ||
            activeSession.isDiagnosticReportContainer)) {
      // Saving changes the details of someone already in the wallet; naming
      // the unnamed default holder is what the review says it does.
      final isPatientModified = switch (activeSession.patient.review) {
        PatientReview.existingEdited || PatientReview.changedTo => true,
        _ => false,
      };

      if (isPatientModified) {
        final confirmed = await AppSimpleDialog.showDestructiveConfirmation(
          context: context,
          title: context.l10n.patient,
          message: context.l10n.patientModifiedUpdating(
            activeSession.patient.existing!.displayTitle,
          ),
          warningText: context.l10n.actionCannotBeUndone,
          confirmText: context.l10n.save,
          cancelText: context.l10n.cancel,
          confirmButtonColor: context.colorScheme.primary,
          onConfirm: () {},
        );
        if (confirmed != true || !mounted) return;
      }

      context.read<ProcessingBloc>().add(
        ResourceCreationInitiated(sessionId: widget.sessionId),
      );
      return;
    }

    final result = await showDialog<AttachToEncounterResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AttachToEncounterWidget(
        patient: activeSession.patient,
        encounter: activeSession.encounter,
        confirmText: activeSession.isDiagnosticReportContainer
            ? context.l10n.attachToPatient
            : context.l10n.attachToEncounter,
        patientOnly: activeSession.isDiagnosticReportContainer,
      ),
    );

    if (result == null || !mounted) return;

    final (patient, encounter) = result;

    context.read<ProcessingBloc>().add(
      EncounterAttached(
        sessionId: widget.sessionId,
        patient: patient,
        encounter: encounter,
      ),
    );

    context.read<ProcessingBloc>().add(
      ResourceCreationInitiated(sessionId: widget.sessionId),
    );
  }

  void _showAiSettingsDialog() async {
    final result = await AiTokenSettingsDialog.show(context);
    if (result == null || !mounted) return;

    // Only what the user changed is saved, and mapping restarts only when a
    // setting the model loads with changed.
    await result.saveLoadSettings(getIt<SharedPreferences>());
    if (!mounted) return;

    final bloc = context.read<ProcessingBloc>();
    final useVision = result.useVision;
    if (useVision != null) bloc.add(VisionToggled(useVision: useVision));

    if (result.changesModel) {
      bloc.add(
        TokenCapacityUpdated(
          newMaxTokens: result.maxTokens,
          sessionId: widget.sessionId,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ProcessingBloc, ProcessingState>(
      listenWhen: (previous, current) =>
          _shows(previous) && !_shows(current) && !_leaving,
      listener: _onSessionGone,
      child: _buildPage(context),
    );
  }

  bool _shows(ProcessingState state) =>
      state.sessions.any((s) => s.id == widget.sessionId);

  /// The session went while this page showed it, not through this page: the
  /// other device took it back or saved it. Back to the list, saying why.
  void _onSessionGone(BuildContext context, ProcessingState state) {
    _leaving = true;
    final message = state.notification?.text;
    final messenger = ScaffoldMessenger.maybeOf(context);
    Navigator.of(context).maybePop();
    if (message != null && messenger != null) {
      AppSnackBar.showOn(
        messenger,
        message: message,
        type: AppSnackBarType.info,
      );
    }
  }

  Widget _buildPage(BuildContext context) {
    return BlocConsumer<ProcessingBloc, ProcessingState>(
      listener: (context, state) async {
        final displayedSession = state.sessions.firstWhereOrNull(
          (s) => s.id == widget.sessionId,
        );
        if (displayedSession == null) return;

        if (state.status is Success) {
          try {
            getIt<LwwSyncBloc>().add(const SyncTriggered());
          } catch (e) {
            logger.w('Could not start a desktop sync after processing', e);
          }
          final sessionToClear = displayedSession;
          final isImport =
              displayedSession.origin == ProcessingOrigin.import ||
              displayedSession.origin == ProcessingOrigin.handover;
          final scanBloc = context.read<ProcessingBloc>();
          final navController = getIt<PageViewNavigationController>();
          final isDesktop = getIt<AppPlatform>().isDesktop;
          final visit = widget.attachOnly || _attachedWithoutProcessing
              ? _visitLabel(displayedSession.encounter)
              : '';
          final dialogResult = await AppSimpleDialog.showConfirmation(
            context: context,
            title: context.l10n.recordsSavedTitle,
            message: visit.isEmpty
                ? null
                : context.l10n.documentAttachedTo(visit),
            subtitle: context.l10n.whatNextQuestion,
            confirmText: isDesktop
                ? context.l10n.goToRecords
                : isImport
                ? context.l10n.continueImporting
                : context.l10n.continueScanning,
            cancelText: isDesktop ? '' : context.l10n.goToRecords,
            // It only reports the save: no close button, and closing it
            // any other way counts as continuing.
            barrierDismissible: true,
            showCloseButton: false,
            onConfirm: () {
              if (isDesktop) {
                navController.jumpToPage(1);
              }
              _leaving = true;
              scanBloc.add(SessionCleared(session: sessionToClear));
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            onCancel: isDesktop
                ? null
                : () {
                    navController.jumpToPage(1);
                    _leaving = true;
                    scanBloc.add(SessionCleared(session: sessionToClear));
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
          );
          // Tapped outside or backed out: the records are saved, so the
          // session goes as with Continue and can't be saved twice.
          if (dialogResult == null && context.mounted) {
            _leaving = true;
            scanBloc.add(SessionCleared(session: sessionToClear));
            Navigator.of(context).popUntil((route) => route.isFirst);
          }
        }
      },
      builder: (context, state) {
        final displayedSession = state.sessions.firstWhereOrNull(
          (s) => s.id == widget.sessionId,
        );

        final canRetry = state.canRetrySession(widget.sessionId);
        final isStep2Retry = state.canRetryStep2(widget.sessionId);

        return Scaffold(
          backgroundColor: context.colorScheme.surface,
          body: Column(
            children: [
              SizedBox(
                height:
                    _buildAppBar(
                      context,
                      displayedSession,
                      canRetry,
                      isStep2Retry,
                    ).preferredSize.height +
                    MediaQuery.of(context).padding.top,
                child: _buildAppBar(
                  context,
                  displayedSession,
                  canRetry,
                  isStep2Retry,
                ),
              ),
              Expanded(
                child: Builder(
                  builder: (context) {
                    if (displayedSession == null) {
                      return Center(child: Text(context.l10n.sessionNotFound));
                    }

                    final sessionImages =
                        state.sessionImagePaths[widget.sessionId] ??
                        const <String>[];

                    final isConverting =
                        state.status == const PipelineStatus.convertingPdfs() &&
                        sessionImages.isEmpty;

                    final isQueuedAndPreparing =
                        displayedSession.status == ProcessingStatus.pending &&
                        sessionImages.isEmpty;

                    if (isConverting || isQueuedAndPreparing) {
                      return _buildLoadingIndicator(
                        context.l10n.preparingPreview,
                      );
                    }

                    return SingleChildScrollView(
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: context.contentMaxWidth,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(Insets.normal),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (!widget.attachOnly) ...[
                                  SummaryCard(
                                    totalPagesForOcr: sessionImages.length,
                                  ),
                                  const SizedBox(height: Insets.normal),
                                ],
                                if (sessionImages.isNotEmpty) ...[
                                  PreviewCard(
                                    imagePaths: sessionImages,
                                    pageController: _pageController,
                                    isEditable: true,
                                    onPagesChanged: (reordered) {
                                      context.read<ProcessingBloc>().add(
                                        PagesReordered(
                                          sessionId: widget.sessionId,
                                          reorderedPaths: reordered,
                                        ),
                                      );
                                    },
                                    onPageRotated: (path, turns) {
                                      context.read<ProcessingBloc>().add(
                                        PageRotated(
                                          sessionId: widget.sessionId,
                                          previewPath: path,
                                          quarterTurns: turns,
                                        ),
                                      );
                                    },
                                  ),
                                  const SizedBox(height: Insets.small),
                                ],
                                const SizedBox(height: Insets.large),
                                if (widget.attachOnly)
                                  _AttachSection(
                                    state: state,
                                    sessionId: widget.sessionId,
                                    onAttach: _attachWithoutProcessing,
                                  )
                                else ...[
                                  ProcessingMappingSection(
                                    state: state,
                                    displayedSession: displayedSession,
                                    sessionId: widget.sessionId,
                                    onShowAiSettings: _showAiSettingsDialog,
                                    onRetryStep1: () =>
                                        context.read<ProcessingBloc>().add(
                                          MappingInitiated(
                                            sessionId: widget.sessionId,
                                          ),
                                        ),
                                    onRetryStep2: () =>
                                        context.read<ProcessingBloc>().add(
                                          ProcessRemainingResources(
                                            sessionId: widget.sessionId,
                                          ),
                                        ),
                                    onCancel: () =>
                                        context.read<ProcessingBloc>().add(
                                          MappingCancelled(
                                            sessionId: widget.sessionId,
                                          ),
                                        ),
                                    checkModelExistence: () =>
                                        getIt<LayoutExtractionService>()
                                            .canProcess(
                                              widget.sessionId,
                                              filePaths:
                                                  displayedSession.filePaths,
                                              imagePaths: state.ocrPagesFor(
                                                widget.sessionId,
                                              ),
                                            ),
                                    onProcessOnDesktop: () {
                                      HandoverUtils.initiateHandover(
                                        context,
                                        session: displayedSession,
                                      );
                                    },
                                    onAttachWithoutProcessing:
                                        _attachWithoutProcessing,
                                  ),
                                  ProcessingResourcesSection(
                                    state: state,
                                    displayedSession: displayedSession,
                                    sessionId: widget.sessionId,
                                    formKey: _formKey,
                                    encounterSectionKey: _encounterSectionKey,
                                    deviceCapability: _deviceCapability,
                                    onScrollToFormErrors: _scrollToFormErrors,
                                    onSaveResources: () =>
                                        _saveResources(state),
                                  ),
                                ],
                                const SizedBox(height: Insets.large),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  AppBar _buildAppBar(
    BuildContext context,
    ProcessingSession? displayedSession,
    bool canRetry,
    bool isStep2Retry,
  ) {
    return AppBar(
      title: Text(
        widget.attachOnly
            ? context.l10n.attachToEncounter
            : context.l10n.processing,
        style: AppTextStyle.titleMedium,
      ),
      centerTitle: true,
      backgroundColor: context.colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      actions: [
        if (canRetry && !widget.attachOnly)
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: Icon(
              Icons.refresh,
              size: 20,
              color: context.colorScheme.onSurface,
            ),
            tooltip: isStep2Retry
                ? context.l10n.retryStep(2)
                : context.l10n.retryStep(1),
            onPressed: () {
              if (isStep2Retry) {
                context.read<ProcessingBloc>().add(
                  ProcessRemainingResources(
                    sessionId: widget.sessionId,
                  ),
                );
              } else {
                context.read<ProcessingBloc>().add(
                  MappingInitiated(sessionId: widget.sessionId),
                );
              }
            },
          ),
        if (!widget.attachOnly)
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
        const DebugLogButton(),
      ],
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
}

/// Attaching without the AI: why the last save failed, if it did, and the
/// action that asks where the document goes and saves it.
class _AttachSection extends StatelessWidget {
  const _AttachSection({
    required this.state,
    required this.sessionId,
    required this.onAttach,
  });

  final ProcessingState state;
  final String sessionId;
  final VoidCallback onAttach;

  @override
  Widget build(BuildContext context) {
    final isSaving = state.status is SavingResources;
    // Only a failed save: that no model is on the device is why the user is
    // here, not an error.
    final failure = switch (state.status) {
      final Failure f
          when f.sessionId == sessionId &&
              f.reason != PipelineFailureReason.modelNotFound =>
        f,
      _ => null,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (failure != null) ...[
          AppMessageCard(
            message: failure.reason.localizedMessage(context.l10n),
            type: AppMessageType.error,
          ),
          const SizedBox(height: Insets.normal),
        ],
        AppButton(
          label: context.l10n.attachToEncounter,
          enabled: !isSaving,
          onPressed: onAttach,
        ),
      ],
    );
  }
}
