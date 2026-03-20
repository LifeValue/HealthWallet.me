import 'package:auto_route/auto_route.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_wallet/core/config/constants/app_constants.dart';
import 'package:health_wallet/core/config/constants/shared_prefs_constants.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/services/device_capability_service.dart';
import 'package:health_wallet/core/navigation/app_router.dart';
import 'package:health_wallet/features/dashboard/presentation/helpers/page_view_navigation_controller.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/features/scan/domain/entity/processing_session.dart';
import 'package:health_wallet/features/scan/domain/repository/scan_repository.dart';
import 'package:health_wallet/features/scan/presentation/bloc/scan_bloc.dart';
import 'package:health_wallet/features/scan/presentation/pages/processing/widgets/processing_mapping_section.dart';
import 'package:health_wallet/features/scan/presentation/pages/processing/widgets/processing_resources_section.dart';
import 'package:health_wallet/features/scan/presentation/widgets/ai_settings/ai_settings_dialog.dart';
import 'package:health_wallet/features/scan/presentation/widgets/attach_to_encounter/attach_to_encounter_widget.dart';
import 'package:health_wallet/features/scan/presentation/widgets/debug_log_sheet.dart';
import 'package:health_wallet/features/scan/presentation/widgets/preview_card.dart';
import 'package:health_wallet/features/scan/presentation/widgets/summary_card.dart';
import 'package:health_wallet/core/widgets/dialogs/app_simple_dialog.dart';
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

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ScanBloc, ScanState>(
      listener: (context, state) async {
        final displayedSession =
            state.sessions.firstWhereOrNull((s) => s.id == widget.sessionId);
        if (displayedSession == null) return;

        if (state.status == const ScanStatus.success()) {
          final sessionToClear = displayedSession;
          final scanBloc = context.read<ScanBloc>();
          final navController = getIt<PageViewNavigationController>();
          final router = context.router;
          final dialogResult = await AppSimpleDialog.showConfirmation(
            context: context,
            title: context.l10n.recordsSavedTitle,
            message: context.l10n.recordsSavedMessage,
            confirmText: context.l10n.continueScanning,
            cancelText: context.l10n.recordsTitle,
            barrierDismissible: true,
            onConfirm: () {
              scanBloc.add(ScanSessionCleared(session: sessionToClear));
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            onCancel: () {
              navController.jumpToPage(1);
              scanBloc.add(ScanSessionCleared(session: sessionToClear));
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
          );
          if (dialogResult == null && context.mounted) {
            navController.jumpToPage(1);
            scanBloc.add(ScanSessionCleared(session: sessionToClear));
            Navigator.of(context).popUntil((route) => route.isFirst);
          }
        }
      },
      builder: (context, state) {
        final displayedSession =
            state.sessions.firstWhereOrNull((s) => s.id == widget.sessionId);

        final canRetry = state.canRetrySession(widget.sessionId);
        final isStep2Retry = state.canRetryStep2(widget.sessionId);

        return Scaffold(
          backgroundColor: context.colorScheme.surface,
          appBar: _buildAppBar(context, displayedSession, canRetry, isStep2Retry),
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
                ProcessingMappingSection(
                  state: state,
                  displayedSession: displayedSession,
                  sessionId: widget.sessionId,
                  onShowAiSettings: _showAiSettingsDialog,
                  onRetryStep1: () => context.read<ScanBloc>().add(
                        ScanMappingInitiated(sessionId: widget.sessionId),
                      ),
                  onRetryStep2: () => context.read<ScanBloc>().add(
                        ScanProcessRemainingResources(
                          sessionId: widget.sessionId,
                        ),
                      ),
                  onCancel: () => context.read<ScanBloc>().add(
                        ScanMappingCancelled(sessionId: widget.sessionId),
                      ),
                  checkModelExistence: () => getIt<ScanRepository>().checkModelExistence(),
                ),
                ProcessingResourcesSection(
                  state: state,
                  displayedSession: displayedSession,
                  sessionId: widget.sessionId,
                  formKey: _formKey,
                  encounterSectionKey: _encounterSectionKey,
                  deviceCapability: _deviceCapability,
                  onScrollToFormErrors: _scrollToFormErrors,
                  onSaveResources: () => _saveResources(state),
                ),
                const SizedBox(height: Insets.large),
              ]),
            );
          }),
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
