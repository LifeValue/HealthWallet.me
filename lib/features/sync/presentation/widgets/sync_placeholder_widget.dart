import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/widgets/dialogs/app_simple_dialog.dart';
import 'package:health_wallet/gen/assets.gen.dart';
import 'package:health_wallet/features/sync/presentation/bloc/sync_bloc.dart';
import 'package:health_wallet/features/home/presentation/bloc/home_bloc.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/core/navigation/app_router.dart';
import 'package:health_wallet/features/user/domain/services/default_patient_service.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/features/user/presentation/preferences_modal/sections/patient/bloc/patient_bloc.dart';
import 'package:health_wallet/core/utils/logger.dart';
import 'package:health_wallet/core/widgets/patient_setup_dialog.dart';
import 'package:health_wallet/core/widgets/overlay_annotations/overlay_annotations.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SyncPlaceholderWidget extends StatefulWidget {
  final PageController? pageController;
  final VoidCallback? onSyncPressed;
  final String? recordTypeName;

  const SyncPlaceholderWidget({
    super.key,
    this.pageController,
    this.onSyncPressed,
    this.recordTypeName,
  });

  @override
  State<SyncPlaceholderWidget> createState() => SyncPlaceholderWidgetState();
}

class SyncPlaceholderWidgetState extends State<SyncPlaceholderWidget> {
  bool _hasInitiatedDemoDataLoading = false;
  SyncBloc? _syncBloc;
  late final SyncPlaceholderHighlightController _highlightController;
  late final StepByStepOverlayController _overlayController;
  bool _hasShownTutorial = false;

  static const String _tutorialShownKey = 'sync_placeholder_tutorial_shown';

  @override
  void initState() {
    super.initState();
    _highlightController = SyncPlaceholderHighlightController();
    _overlayController = StepByStepOverlayController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoTriggerTutorialIfNeeded();
    });
  }

  Future<void> _autoTriggerTutorialIfNeeded() async {
    if (!mounted || _hasShownTutorial) return;

    final prefs = await SharedPreferences.getInstance();
    final hasSeenOnboarding = prefs.getBool('hasSeenOnboarding') ?? false;
    final tutorialShown = prefs.getBool(_tutorialShownKey) ?? false;

    if (hasSeenOnboarding && !tutorialShown && mounted) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        _hasShownTutorial = true;
        _showTutorialSequence();
      }
    }
  }

  @override
  void dispose() {
    _overlayController.hide();
    super.dispose();
  }

  SyncPlaceholderHighlightController get highlightController =>
      _highlightController;

  void showTutorial() {
    if (_hasShownTutorial) return;

    _checkAndShowTutorialIfNeeded();
  }

  Future<void> _checkAndShowTutorialIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final tutorialShown = prefs.getBool(_tutorialShownKey) ?? false;

    if (!tutorialShown && mounted) {
      _hasShownTutorial = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showTutorialSequence();
        }
      });
    }
  }

  void _showTutorialSequence() {
    if (!mounted) return;

    final steps = [
      OverlayStep(
        targetKey: _highlightController.setupButtonKey,
        message: context.l10n.syncPlaceholderTutorialStep1,
        subtitle: context.l10n.tapToContinue,
      ),
      OverlayStep(
        targetKey: _highlightController.loadDemoDataButtonKey,
        message: context.l10n.syncPlaceholderTutorialStep2,
        subtitle: context.l10n.tapToContinue,
      ),
      OverlayStep(
        targetKey: _highlightController.syncDataButtonKey,
        message: context.l10n.syncPlaceholderTutorialStep3,
        subtitle: context.l10n.tapToContinue,
      ),
    ];

    _overlayController.showSequence(
      context: context,
      steps: steps,
      onComplete: () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_tutorialShownKey, true);
        _hasShownTutorial = false;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    _syncBloc = context.read<SyncBloc>();

    return BlocListener<SyncBloc, SyncState>(listenWhen: (previous, current) {
      return current.hasDemoData && !current.hasSyncedData;
    }, listener: (context, state) {
      if (state.hasDemoData &&
          !state.hasSyncedData &&
          _hasInitiatedDemoDataLoading) {
        _handleDemoDataCompletion(context);
        _hasInitiatedDemoDataLoading = false;
      } else {}
    }, child: BlocBuilder<HomeBloc, HomeState>(
      builder: (context, homeState) {
        final hasVitalDataLoaded = homeState.patientVitals.any(
            (vital) => vital.value != 'N/A' && vital.observationId != null);
        final hasOverviewDataLoaded =
            homeState.overviewCards.any((card) => card.count != '0');
        final hasRecent = homeState.recentRecords.isNotEmpty;
        final hasAnyMeaningfulData =
            hasVitalDataLoaded || hasOverviewDataLoaded || hasRecent;

        return SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: Insets.medium),
              SizedBox(
                width: 240,
                height: 240,
                child: context.isDarkMode
                    ? Assets.images.placeholderDark.svg(
                        fit: BoxFit.contain,
                      )
                    : Assets.images.placeholder.svg(
                        fit: BoxFit.contain,
                      ),
              ),
              const SizedBox(height: Insets.large),
              _buildMessageSection(context, hasAnyMeaningfulData),
              const SizedBox(height: Insets.large),
              _buildActionButtons(context, hasAnyMeaningfulData),
              const SizedBox(height: Insets.large),
            ],
          ),
        );
      },
    ));
  }

  Widget _buildMessageSection(BuildContext context, bool hasAnyMeaningfulData) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: Insets.medium),
      child: Column(
        children: [
          Text(
            _getTitle(context, hasAnyMeaningfulData),
            style: AppTextStyle.titleLarge.copyWith(
              color: context.colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: Insets.medium),
          Text(
            _getSubtitle(context, hasAnyMeaningfulData),
            style: AppTextStyle.bodyMedium.copyWith(
              color: context.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, bool hasAnyMeaningfulData) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: Insets.medium),
      child: Column(
        children: [
          if (!hasAnyMeaningfulData) ...[
            SizedBox(
              key: _highlightController.setupButtonKey,
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _handleSetUpWallet(context),
                icon: Assets.icons.user.svg(
                  width: 16,
                  height: 16,
                  colorFilter:
                      const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                ),
                label: Text(
                  context.l10n.setup,
                  style: AppTextStyle.buttonMedium.copyWith(
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: Insets.medium,
                    vertical: Insets.smallNormal,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(Insets.small),
                  ),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: Insets.small),
            SizedBox(
              key: _highlightController.loadDemoDataButtonKey,
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _handleLoadDemoData(context),
                icon: Assets.icons.cloudDownload.svg(
                  width: 16,
                  height: 16,
                  colorFilter:
                      const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                ),
                label: Text(
                  context.l10n.loadDemoData,
                  style: AppTextStyle.buttonMedium.copyWith(
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.colorScheme.secondary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: Insets.medium,
                    vertical: Insets.smallNormal,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(Insets.small),
                  ),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: Insets.small),
          ],
          SizedBox(
            key: _highlightController.syncDataButtonKey,
            width: double.infinity,
            child: hasAnyMeaningfulData
                ? ElevatedButton.icon(
                    onPressed: widget.onSyncPressed ??
                        () => _handleSyncRecords(context),
                    icon: Assets.icons.renewSync.svg(
                      width: 16,
                      height: 16,
                      colorFilter:
                          const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                    ),
                    label: Text(
                      context.l10n.syncTitle,
                      style: AppTextStyle.buttonMedium.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: Insets.medium,
                        vertical: Insets.smallNormal,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(Insets.small),
                      ),
                      elevation: 0,
                    ),
                  )
                : TextButton.icon(
                    onPressed: widget.onSyncPressed ??
                        () => _handleSyncRecords(context),
                    icon: Assets.icons.renewSync.svg(
                      width: 16,
                      height: 16,
                      colorFilter: ColorFilter.mode(
                        context.isDarkMode
                            ? Colors.white
                            : context.colorScheme.primary,
                        BlendMode.srcIn,
                      ),
                    ),
                    label: Text(
                      context.l10n.syncTitle,
                      style: AppTextStyle.buttonMedium.copyWith(
                        color: context.isDarkMode
                            ? Colors.white
                            : context.colorScheme.primary,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  String _getTitle(BuildContext context, bool hasAnyMeaningfulData) {
    if (hasAnyMeaningfulData && widget.recordTypeName != null) {
      return context.l10n.noRecords;
    }
    return context.l10n.noMedicalRecordsYet;
  }

  String _getSubtitle(BuildContext context, bool hasAnyMeaningfulData) {
    if (hasAnyMeaningfulData && widget.recordTypeName != null) {
      return 'Sync or update your data to view ${widget.recordTypeName} records';
    }
    return context.l10n.loadDemoDataMessage;
  }

  void _handleLoadDemoData(BuildContext context) {
    _hasInitiatedDemoDataLoading = true;
    context.read<SyncBloc>().add(const LoadDemoData());
  }

  void _handleDemoDataCompletion(BuildContext context) async {
    if (!mounted || !context.mounted) return;

    final patientBloc = context.read<PatientBloc>();
    final homeBloc = context.read<HomeBloc>();
    final syncBloc = context.read<SyncBloc>();

    AppSimpleDialog.showSuccess(
      context: context,
      title: context.l10n.success,
      message: context.l10n.demoDataLoadedSuccessfully,
      onOkPressed: () async {
        _syncBloc?.add(const DemoDataConfirmed());

        patientBloc.add(const PatientInitialised());
        await Future.delayed(const Duration(milliseconds: 300));

        final patientState = patientBloc.state;
        final demoPatients = patientState.patients
            .where((p) => p.sourceId == 'demo_data')
            .toList();

        if (demoPatients.isNotEmpty) {
          final demoPatient = demoPatients.first;
          if (patientState.selectedPatientId != demoPatient.id) {
            patientBloc.add(PatientSelectionChanged(patientId: demoPatient.id));
          }
          homeBloc.add(
            const HomeSourceChanged('demo_data',
                patientSourceIds: ['demo_data']),
          );
        }

        await Future.delayed(const Duration(milliseconds: 200));

        if (context.mounted) {
          Navigator.of(context).pop();
        }

        final pageControllerRef = widget.pageController;
        if (pageControllerRef != null) {
          pageControllerRef.animateToPage(0,
              duration: const Duration(milliseconds: 300), curve: Curves.ease);
        } else if (context.mounted) {
          context.router.pop();
        }

        Future.delayed(const Duration(milliseconds: 350), () {
          syncBloc.add(const TriggerTutorial());
        });
      },
    );
  }

  void _handleSyncRecords(BuildContext context) {
    if (context.mounted) {
      context.router.push(const SyncRoute());
    }
  }

  void _handleSetUpWallet(BuildContext context) async {
    final syncBloc = context.read<SyncBloc>();
    final homeBloc = context.read<HomeBloc>();
    final patientBloc = context.read<PatientBloc>();
    final pageController = widget.pageController;

    try {
      syncBloc.add(const CreateWalletSource());
      await Future.delayed(const Duration(milliseconds: 100));

      final defaultPatientService = getIt<DefaultPatientService>();
      await defaultPatientService.createAndSetAsMain();

      homeBloc.add(const HomeSourceChanged('wallet'));
      patientBloc.add(const PatientInitialised());

      final walletPatient = await _waitForWalletPatient(patientBloc);

      if (!mounted) return;

      if (walletPatient != null) {
        if (mounted) {
          PatientSetupDialog.show(
            context,
            walletPatient,
            onDismiss: () {
              if (pageController != null) {
                pageController.animateToPage(0,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.ease);
              }

              Future.delayed(const Duration(milliseconds: 400), () {
                try {
                  syncBloc.add(const TriggerTutorial());
                } catch (e) {
                  logger.e('Failed to trigger tutorial: $e');
                }
              });
            },
          );
        }
      } else {
        logger.w('No wallet patient found, navigating without dialog');
        if (pageController != null) {
          pageController.animateToPage(0,
              duration: const Duration(milliseconds: 300), curve: Curves.ease);
        }

        Future.delayed(const Duration(milliseconds: 400), () {
          try {
            syncBloc.add(const TriggerTutorial());
          } catch (e) {
            logger.e('Failed to trigger tutorial: $e');
          }
        });
      }
    } catch (e) {
      logger.e('Error in _handleSetUpWallet: $e');
      if (pageController != null) {
        pageController.animateToPage(0,
            duration: const Duration(milliseconds: 300), curve: Curves.ease);
      }
    }
  }

  Future<dynamic> _waitForWalletPatient(PatientBloc patientBloc) async {
    final currentState = patientBloc.state;
    final existingWalletPatients = currentState.patients
        .where((p) => p.sourceId.startsWith('wallet'))
        .toList();
    if (existingWalletPatients.isNotEmpty) {
      return existingWalletPatients.first;
    }

    try {
      final stateWithPatient = await patientBloc.stream
          .where((state) =>
              state.patients.any((p) => p.sourceId.startsWith('wallet')))
          .first
          .timeout(const Duration(seconds: 3));

      final walletPatients = stateWithPatient.patients
          .where((p) => p.sourceId.startsWith('wallet'))
          .toList();

      return walletPatients.isNotEmpty ? walletPatients.first : null;
    } on TimeoutException {
      logger.w('Timeout waiting for wallet patient');
      final finalState = patientBloc.state;
      final finalWalletPatients = finalState.patients
          .where((p) => p.sourceId.startsWith('wallet'))
          .toList();
      return finalWalletPatients.isNotEmpty ? finalWalletPatients.first : null;
    } catch (e) {
      logger.e('Error waiting for wallet patient: $e');
      return null;
    }
  }
}
