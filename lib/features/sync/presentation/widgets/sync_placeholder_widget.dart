import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/widgets/success_dialog.dart';
import 'package:health_wallet/gen/assets.gen.dart';
import 'package:health_wallet/features/sync/presentation/bloc/sync_bloc.dart';
import 'package:health_wallet/features/home/presentation/bloc/home_bloc.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/core/navigation/app_router.dart';
import 'package:health_wallet/features/user/domain/services/default_patient_service.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/features/user/presentation/preferences_modal/sections/patient/bloc/patient_bloc.dart';
import 'package:health_wallet/core/utils/logger.dart';
import 'package:health_wallet/features/user/presentation/preferences_modal/sections/patient/patient_edit_dialog.dart';

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
  State<SyncPlaceholderWidget> createState() => _SyncPlaceholderWidgetState();
}

class _SyncPlaceholderWidgetState extends State<SyncPlaceholderWidget> {
  bool _hasInitiatedDemoDataLoading = false;
  SyncBloc? _syncBloc;

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

        return Column(
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
          ],
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
            // Set Up my Health Wallet button
            SizedBox(
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
            // Load Demo Data button
            SizedBox(
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
          // Sync Data button
          SizedBox(
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
                      context.l10n.syncData,
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
                      context.l10n.syncData,
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
      return 'No ${widget.recordTypeName} yet';
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
    // BlocListener will handle completion when hasDemoData becomes true
  }

  void _handleDemoDataCompletion(BuildContext context) async {
    if (!mounted || !context.mounted) return;

    final patientBloc = context.read<PatientBloc>();
    final homeBloc = context.read<HomeBloc>();
    final syncBloc = context.read<SyncBloc>();

    SuccessDialog.show(
      context: context,
      title: context.l10n.success,
      message: context.l10n.demoDataLoadedSuccessfully,
      onOkPressed: () async {
        _syncBloc?.add(const DemoDataConfirmed());

        // Initialize and select demo patient
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

        // Close dialog
        if (context.mounted) {
          Navigator.of(context).pop();
        }

        // Navigate to home
        final pageControllerRef = widget.pageController;
        if (pageControllerRef != null) {
          pageControllerRef.animateToPage(0,
              duration: const Duration(milliseconds: 300), curve: Curves.ease);
        } else if (context.mounted) {
          context.router.pop();
        }

        // Trigger tutorial after navigation completes
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
    // Capture blocs before async operations to avoid context issues
    final syncBloc = context.read<SyncBloc>();
    final homeBloc = context.read<HomeBloc>();
    final patientBloc = context.read<PatientBloc>();
    final pageController = widget.pageController;

    try {
      // Create wallet source and default patient first
      syncBloc.add(const CreateWalletSource());
      await Future.delayed(const Duration(milliseconds: 100));

      final defaultPatientService = getIt<DefaultPatientService>();
      await defaultPatientService.createAndSetAsMain();

      homeBloc.add(const HomeSourceChanged('wallet'));
      patientBloc.add(const PatientInitialised());

      // Wait for PatientBloc to load patients with a stream listener
      final walletPatient = await _waitForWalletPatient(patientBloc);

      if (!mounted) return;

      if (walletPatient != null) {
        // Show the PatientEditDialog in setup mode
        if (mounted) {
          PatientEditDialog.showSetupMode(
            context,
            walletPatient,
            onDismiss: () {
              // Navigate to home page after dialog is dismissed
              if (pageController != null) {
                pageController.animateToPage(0,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.ease);
              }

              // Trigger tutorial after a delay (home page will handle displaying it)
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
        // Fallback: navigate without showing dialog
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

  /// Waits for the PatientBloc to load wallet patients with a timeout
  Future<dynamic> _waitForWalletPatient(PatientBloc patientBloc) async {
    // First check if already available
    final currentState = patientBloc.state;
    final existingWalletPatients = currentState.patients
        .where((p) => p.sourceId.startsWith('wallet'))
        .toList();
    if (existingWalletPatients.isNotEmpty) {
      return existingWalletPatients.first;
    }

    // Wait for the bloc to emit a state with wallet patients
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
      // Try one more time from current state
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
