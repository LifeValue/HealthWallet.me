import 'dart:async';
import 'dart:ui';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_wallet/core/navigation/app_router.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/utils/date_format_utils.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/l10n/l10n.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/core/widgets/animated_sticky_header.dart';
import 'package:health_wallet/features/desktop/backup/presentation/bloc/backup_bloc.dart';
import 'package:health_wallet/features/desktop/communication/presentation/bloc/communication_bloc.dart';
import 'package:health_wallet/features/desktop/lww_sync/presentation/bloc/lww_sync_bloc.dart';
import 'package:health_wallet/features/desktop/presentation/widgets/connection_dialog.dart';
import 'package:health_wallet/features/desktop/presentation/widgets/device_sync_dialog.dart';
import 'package:health_wallet/features/desktop/presentation/widgets/sync_dialog.dart';
import 'package:health_wallet/features/desktop/presentation/widgets/backup_card.dart';
import 'package:health_wallet/features/notifications/notification_widget.dart';
import 'package:health_wallet/features/user/presentation/preferences_modal/preference_modal.dart';
import 'package:health_wallet/features/home/presentation/widgets/share_options_sheet.dart';
import 'package:health_wallet/features/records/domain/utils/fhir_field_extractor.dart';
import 'package:health_wallet/gen/assets.gen.dart';
import 'package:health_wallet/core/utils/patient_source_utils.dart';
import 'package:health_wallet/core/widgets/custom_app_bar.dart';
import 'package:health_wallet/core/widgets/overlay_annotations/overlay_annotations.dart';
import 'package:health_wallet/features/home/core/constants/home_constants.dart';
import 'package:health_wallet/features/home/presentation/bloc/home_bloc.dart';
import 'package:health_wallet/features/home/presentation/widgets/home_dashboard_sections.dart';
import 'package:health_wallet/features/home/presentation/widgets/home_greeting_title.dart';
import 'package:health_wallet/features/home/presentation/widgets/home_patient_bar.dart';
import 'package:health_wallet/features/sync/presentation/bloc/sync_bloc.dart';
import 'package:health_wallet/features/sync/presentation/widgets/sync_placeholder_widget.dart';
import 'package:health_wallet/core/config/app_platform.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/utils/responsive.dart';
import 'package:health_wallet/features/user/presentation/bloc/user_bloc.dart';
import 'package:health_wallet/features/user/presentation/preferences_modal/sections/patient/bloc/patient_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

@RoutePage()
class HomePage extends StatelessWidget {
  final PageController pageController;
  const HomePage({super.key, required this.pageController});

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: getIt<LwwSyncBloc>(),
      child: MultiBlocListener(
        listeners: [
          BlocListener<PatientBloc, PatientState>(
            listenWhen: (previous, current) {
              final selectionChanged =
                  previous.selectedPatientId != current.selectedPatientId;

              final selectedId = current.selectedPatientId;
              if (selectedId != null) {
                final previousPatient = previous.patients
                    .where((p) => p.id == selectedId)
                    .firstOrNull;
                final currentPatient =
                    current.patients.where((p) => p.id == selectedId).firstOrNull;
                final dataChanged =
                    previousPatient?.displayTitle != currentPatient?.displayTitle;

                return selectionChanged || dataChanged;
              }

              return selectionChanged;
            },
            listener: (context, patientState) {
              PatientSourceUtils.handlePatientChange(context, patientState);
              context.read<HomeBloc>().add(const HomeRefreshPreservingOrder());
            },
          ),
          BlocListener<SyncBloc, SyncState>(
            listenWhen: (previous, current) =>
                (previous.hasDemoData != current.hasDemoData) ||
                (previous.hasSyncedData != current.hasSyncedData),
            listener: (context, state) {
              if (state.hasDemoData || state.hasSyncedData) {
                context.read<HomeBloc>().add(const HomeRefreshPreservingOrder());
              }
            },
          ),
          BlocListener<LwwSyncBloc, LwwSyncState>(
            listenWhen: (previous, current) =>
                current.receivedRows > previous.receivedRows ||
                (previous.syncStatus == LwwSyncStatus.syncing &&
                    current.syncStatus == LwwSyncStatus.idle &&
                    current.receivedRows > 0),
            listener: (context, state) {
              context.read<HomeBloc>().add(const HomeRefreshPreservingOrder());
            },
          ),
          BlocListener<UserBloc, UserState>(
            listenWhen: (previous, current) =>
                previous.regionPreset != current.regionPreset,
            listener: (context, state) {
              context.read<HomeBloc>().add(const HomeRefreshPreservingOrder());
            },
          ),
        ],
        child: HomeView(pageController: pageController),
      ),
    );
  }
}

class HomeView extends StatefulWidget {
  final PageController pageController;
  const HomeView({super.key, required this.pageController});

  @override
  State<HomeView> createState() => HomeViewState();
}

class HomeViewState extends State<HomeView> {
  late final HomeHighlightController _highlightController;
  late final MultiHighlightOverlayController _overlayController;

  bool _hasShownOnboarding = false;
  bool _isScrolled = false;
  final GlobalKey _patientRowKey = GlobalKey();
  double _patientRowHeight = 0;

  @override
  void initState() {
    super.initState();
    _highlightController = HomeHighlightController();
    _overlayController = MultiHighlightOverlayController();
  }

  @override
  void dispose() {
    _overlayController.hide();
    super.dispose();
  }

  void showOnboardingDirectly() {
    _hasShownOnboarding = false;
    _showOnboardingOverlay();
  }

  void _showOnboardingOverlay() {
    if (!mounted) return;

    _overlayController.show(
      context: context,
      targetKeys: _highlightController.highlightTargetKeys,
      message: context.l10n.homeOnboardingReorderMessage,
      subtitle: context.l10n.tapToContinue,
      onDismiss: () async {
        context.read<SyncBloc>().add(const ResetTutorial());

        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('onboarding_shown', true);

        _hasShownOnboarding = false;
      },
    );
  }

  Future<void> _onRefresh() async {
    context.read<HomeBloc>().add(const HomeRefreshPreservingOrder());
    await Future.delayed(HomeConstants.refreshDelay);
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<SyncBloc, SyncState>(
      listenWhen: (previous, current) {
        return previous.shouldShowTutorial != current.shouldShowTutorial;
      },
      listener: (context, syncState) {
        if (!syncState.shouldShowTutorial) {
          _hasShownOnboarding = false;
          return;
        }

        if (syncState.shouldShowTutorial && !_hasShownOnboarding) {
          _hasShownOnboarding = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _showOnboardingOverlay();
            }
          });
        }
      },
      child: BlocBuilder<HomeBloc, HomeState>(
        builder: (context, state) {
          if (state.status.runtimeType ==
              const HomeStatus.initial().runtimeType) {
            return Scaffold(
              backgroundColor: context.colorScheme.surface,
              body: Center(
                child: CircularProgressIndicator(
                  color: context.colorScheme.primary,
                ),
              ),
            );
          }

          final isDesktop = getIt<AppPlatform>() == AppPlatform.desktop;

          if (isDesktop) {
            return Scaffold(
              backgroundColor: context.colorScheme.surface,
              extendBody: true,
              body: _buildDesktopLayout(context, state),
            );
          }

          return Scaffold(
            backgroundColor: context.colorScheme.surface,
            extendBody: true,
            appBar: CustomAppBar(
              automaticallyImplyLeading: false,
              titleWidget: HomeGreetingTitle(homeState: state),
              actions: const [],
              extraTopPadding: context.isTablet ? 16 : 0,
            ),
            body: RefreshIndicator(
              onRefresh: _onRefresh,
              color: context.colorScheme.primary,
              child: _buildHomeContent(context, state),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHomeContent(BuildContext context, HomeState state) {
    if (state.shouldShowPlaceholder) {
      final placeholder = SyncPlaceholderWidget(
        pageController: widget.pageController,
        onSyncPressed: () {
          DeviceSyncDialog.show(context);
        },
        recordTypeName: null,
      );

      if (context.isTablet) {
        return LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: Align(
                  alignment: const Alignment(0, -0.3),
                  child: placeholder,
                ),
              ),
            );
          },
        );
      }

      return placeholder;
    }

    return _buildDashboardLayout(context, state);
  }

  Widget _buildDesktopLayout(BuildContext context, HomeState state) {
    if (state.shouldShowPlaceholder) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Insets.medium),
            child: SizedBox(
              height: 60,
              child: Stack(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: HomeGreetingTitle(homeState: state),
                  ),
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const _ConnectionMiniCard(),
                        const SizedBox(width: 8),
                        _PeriodicBuilder(builder: (_, tick) => _SyncMiniCard(key: ValueKey('sync_$tick'))),
                        const SizedBox(width: 8),
                        _PeriodicBuilder(builder: (_, tick) => _BackupMiniCard(key: ValueKey('backup_$tick'))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Center(
                child: SyncPlaceholderWidget(
                  pageController: widget.pageController,
                  onSyncPressed: () => DeviceSyncDialog.show(context),
                  recordTypeName: null,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return AnimatedStickyHeader(
      padding: EdgeInsets.symmetric(
        horizontal: context.screenHorizontalPadding,
        vertical: 12,
      ),
      children: [
        Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                HomeGreetingTitle(homeState: state),
                if (state.patient != null) ...[
                  const SizedBox(height: 6),
                  _PatientRow(homeState: state),
                ],
              ],
            ),
            Positioned.fill(
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const _ConnectionMiniCard(),
                    const SizedBox(width: 8),
                    const _SyncMiniCard(),
                    const SizedBox(width: 8),
                    const _BackupMiniCard(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
      body: CustomScrollView(
        slivers: [
          HomeDashboardSections(
            state: state,
            editMode: state.editMode,
            highlightController: _highlightController,
            pageController: widget.pageController,
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardLayout(BuildContext context, HomeState state) {
    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (state.hasDataLoaded && getIt<AppPlatform>() != AppPlatform.desktop)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                height: _patientRowHeight,
                color: Colors.transparent,
              ),
            Expanded(
              child: NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  final scrolled = notification.metrics.pixels > 0;
                  if (scrolled != _isScrolled) {
                    setState(() => _isScrolled = scrolled);
                  }
                  return false;
                },
                child: CustomScrollView(
                  slivers: [
                    HomeDashboardSections(
                      state: state,
                      editMode: state.editMode,
                      highlightController: _highlightController,
                      pageController: widget.pageController,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (state.hasDataLoaded && getIt<AppPlatform>() != AppPlatform.desktop)
          HomePatientBar(
            state: state,
            isScrolled: _isScrolled,
            patientRowKey: _patientRowKey,
            onHeightMeasured: (height) {
              if (height != _patientRowHeight && mounted) {
                setState(() => _patientRowHeight = height);
              }
            },
          ),
      ],
    );
  }
}

class _PatientRow extends StatefulWidget {
  final HomeState homeState;

  const _PatientRow({required this.homeState});

  @override
  State<_PatientRow> createState() => _PatientRowState();
}

class _PatientRowState extends State<_PatientRow> {
  final GlobalKey _tapKey = GlobalKey();
  bool _isMenuOpen = false;

  void _onTap() {
    if (_isMenuOpen) return;
    final box = _tapKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final pos = box.localToGlobal(Offset.zero, ancestor: overlay);

    setState(() => _isMenuOpen = true);

    final patientName = FhirFieldExtractor.extractHumanNameFamilyFirst(
        widget.homeState.patient?.name?.first);

    showShareOptionsMenu(
      context,
      position: RelativeRect.fromLTRB(
        pos.dx,
        pos.dy + box.size.height + 4,
        pos.dx + box.size.width,
        0,
      ),
      patientName: patientName,
      patientId: widget.homeState.patient?.id,
    ).then((_) {
      if (mounted) setState(() => _isMenuOpen = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final patientName = FhirFieldExtractor.extractHumanNameFamilyFirst(
            widget.homeState.patient?.name?.first) ??
        context.l10n.loading;

    return GestureDetector(
      key: _tapKey,
      behavior: HitTestBehavior.opaque,
      onTap: _onTap,
      child: Row(
        children: [
          Text(
            '${context.l10n.patient}: ',
            style: AppTextStyle.bodyMedium.copyWith(
              color: context.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          Flexible(
            child: Text(
              patientName,
              style: AppTextStyle.bodyMedium.copyWith(
                color: context.colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
          AnimatedRotation(
            turns: _isMenuOpen ? 0.5 : 0,
            duration: const Duration(milliseconds: 200),
            child: Assets.icons.chevronDown.svg(
              width: 20,
              height: 20,
              colorFilter: ColorFilter.mode(
                context.colorScheme.primary,
                BlendMode.srcIn,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PeriodicBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, int tick) builder;
  const _PeriodicBuilder({required this.builder});

  static final _ticker = Stream<int>.periodic(
    const Duration(seconds: 30),
    (i) => i,
  ).asBroadcastStream();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: _ticker,
      builder: (context, snapshot) => builder(context, snapshot.data ?? 0),
    );
  }
}

class _ConnectionMiniCard extends StatelessWidget {
  const _ConnectionMiniCard();

  @override
  Widget build(BuildContext context) {
    try {
      return BlocProvider.value(
        value: getIt<CommunicationBloc>(),
        child: BlocBuilder<CommunicationBloc, DesktopSyncState>(
          builder: (context, commState) {
            final isConnected =
                commState.connectionStatus == ConnectionStatus.connected;
            final isDiscovering =
                commState.connectionStatus == ConnectionStatus.discovering;

            final Color color;
            final String subtitle;

            if (isConnected) {
              color = AppColors.success;
              subtitle = commState.connectedDeviceName ?? context.l10n.connectionStatusConnected;
            } else if (isDiscovering) {
              color = AppColors.warning;
              subtitle = context.l10n.connectionStatusConnecting;
            } else {
              color = commState.pairedDevice != null
                  ? AppColors.error
                  : AppColors.error;
              subtitle = commState.pairedDevice != null
                  ? context.l10n.connectionStatusDisconnected
                  : context.l10n.connectionStatusNotPaired;
            }

            return _MiniStatusCard(
              icon: isConnected ? Icons.link : Icons.link_off,
              label: context.l10n.connectionLabel,
              subtitle: subtitle,
              color: color,
              onTap: () => ConnectionDialog.show(context),
            );
          },
        ),
      );
    } catch (e) {
      debugPrint('[Connection] MiniCard error: $e');
      return _MiniStatusCard(
        icon: Icons.link_off,
        label: context.l10n.connectionLabel,
        subtitle: context.l10n.connectionStatusNotPaired,
        color: AppColors.error,
        onTap: () => ConnectionDialog.show(context),
      );
    }
  }
}

class _SyncMiniCard extends StatelessWidget {
  const _SyncMiniCard({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: getIt<LwwSyncBloc>(),
      child: BlocBuilder<LwwSyncBloc, LwwSyncState>(
        builder: (context, syncState) {
          final isSyncing = syncState.syncStatus == LwwSyncStatus.syncing;
          final color = isSyncing
              ? AppColors.primary
              : syncState.isSynced
                  ? AppColors.success
                  : syncState.pendingChangeCount > 0
                      ? AppColors.warning
                      : AppColors.error;

          final subtitle = isSyncing
              ? context.l10n.syncStatusSyncing
              : syncState.lastSyncTime != null
                  ? DateFormatUtils.getSincePretty(syncState.lastSyncTime!)
                  : context.l10n.syncStatusNotSynced;

          return _MiniStatusCard(
            icon: Icons.sync,
            label: context.l10n.syncLabel,
            subtitle: subtitle,
            color: color,
            isLoading: isSyncing,
            onTap: () => _showSyncDialog(context),
          );
        },
      ),
    );
  }
}

class _BackupMiniCard extends StatelessWidget {
  const _BackupMiniCard({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: getIt<BackupBloc>(),
      child: BlocBuilder<BackupBloc, BackupState>(
        builder: (context, backupState) {
          final hasBackup = backupState.backupHistory.isNotEmpty;
          final hasRemoteBackup = backupState.desktopLastBackupTime != null;
          final hasAnyBackup = hasBackup || hasRemoteBackup;
          final color = backupState.isBackingUp
              ? AppColors.primary
              : hasAnyBackup
                  ? AppColors.success
                  : AppColors.warning;

          String subtitle;
          if (backupState.isBackingUp) {
            subtitle = context.l10n.backupStatusWorking;
          } else if (hasBackup) {
            subtitle = DateFormatUtils.getSincePretty(backupState.backupHistory.first.timestamp);
          } else if (hasRemoteBackup) {
            subtitle = DateFormatUtils.getSincePretty(backupState.desktopLastBackupTime!);
          } else {
            subtitle = context.l10n.backupStatusNoBackup;
          }

          return _MiniStatusCard(
            icon: Icons.shield_outlined,
            label: context.l10n.backupLabel,
            onTap: () => _showBackupDialog(context),
            subtitle: subtitle,
            color: color,
            isLoading: backupState.isBackingUp,
          );
        },
      ),
    );
  }
}

void _showSyncDialog(BuildContext context) {
  SyncDialog.show(context);
}

void _showBackupDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (_) => BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
      child: Dialog(
        backgroundColor: Colors.transparent,
        child: SizedBox(
        width: 500,
        height: 600,
        child: MultiBlocProvider(
          providers: [
            BlocProvider.value(value: getIt<CommunicationBloc>()),
            BlocProvider.value(value: getIt<BackupBloc>()),
            BlocProvider.value(value: getIt<LwwSyncBloc>()),
          ],
          child: BlocBuilder<CommunicationBloc, DesktopSyncState>(
            builder: (context, commState) {
              return BlocBuilder<BackupBloc, BackupState>(
                builder: (context, backupState) {
                  return Container(
                    decoration: BoxDecoration(
                      color: context.colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: Insets.medium,
                            vertical: Insets.smallNormal,
                          ),
                          child: Row(
                            children: [
                              Text(
                                context.l10n.backupLabel,
                                style: AppTextStyle.bodyMedium.copyWith(
                                  color: context.colorScheme.onSurface,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const Spacer(),
                              GestureDetector(
                                onTap: () => Navigator.of(context).pop(),
                                child: Icon(
                                  Icons.close,
                                  size: 20,
                                  color: context.colorScheme.onSurface
                                      .withValues(alpha: 0.4),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Divider(
                          height: 1,
                          color: context.theme.dividerColor,
                        ),
                        Expanded(
                          child: BackupCard(
                            syncState: commState,
                            backupState: backupState,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
      ),
    ),
  );
}

class _MiniStatusCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final bool isLoading;
  final VoidCallback? onTap;

  const _MiniStatusCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    this.isLoading = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final bgAlpha = isDark ? 0.24 : 0.08;
    final subtitleColor = isDark
        ? Colors.white
        : context.colorScheme.onSurface;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 140,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: bgAlpha),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          children: [
            if (isLoading)
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: color,
                ),
              )
            else
              Icon(icon, size: 20, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTextStyle.labelSmall.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: color,
                      letterSpacing: -0.14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTextStyle.labelSmall.copyWith(
                      fontSize: 12,
                      color: subtitleColor,
                      letterSpacing: -0.12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
