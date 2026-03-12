import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_wallet/features/notifications/notification_widget.dart';
import 'package:health_wallet/features/home/presentation/widgets/home_dialog_controller.dart';
import 'package:health_wallet/core/widgets/overlay_annotations/overlay_annotations.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/patient_source_utils.dart';
import 'package:health_wallet/features/home/presentation/bloc/home_bloc.dart';
import 'package:health_wallet/features/sync/presentation/bloc/sync_bloc.dart';
import 'package:health_wallet/features/user/presentation/bloc/user_bloc.dart';
import 'package:health_wallet/features/records/presentation/bloc/records_bloc.dart';
import 'package:health_wallet/features/user/presentation/preferences_modal/sections/patient/bloc/patient_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/core/widgets/custom_app_bar.dart';
import 'package:health_wallet/features/home/presentation/widgets/home_section_header.dart';
import 'package:health_wallet/features/home/presentation/widgets/source_selector_widget.dart';
import 'package:health_wallet/features/home/presentation/widgets/section_info_modal.dart';
import 'package:health_wallet/features/home/presentation/sections/vitals_section.dart';
import 'package:health_wallet/features/home/presentation/sections/medical_records_section.dart';
import 'package:health_wallet/features/home/presentation/sections/recent_records_section.dart';
import 'package:health_wallet/features/user/presentation/preferences_modal/preference_modal.dart';
import 'package:health_wallet/features/home/core/constants/home_constants.dart';
import 'package:health_wallet/features/home/domain/entities/patient_vitals.dart';
import 'package:health_wallet/features/sync/presentation/widgets/sync_placeholder_widget.dart';
import 'package:health_wallet/gen/assets.gen.dart';
import 'package:health_wallet/core/navigation/app_router.dart';
import 'package:health_wallet/features/records/domain/utils/fhir_field_extractor.dart';
import 'package:health_wallet/features/home/presentation/widgets/share_options_sheet.dart';

@RoutePage()
class HomePage extends StatelessWidget {
  final PageController pageController;
  const HomePage({super.key, required this.pageController});

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
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
        BlocListener<UserBloc, UserState>(
          listenWhen: (previous, current) =>
              previous.regionPreset != current.regionPreset,
          listener: (context, state) {
            context.read<HomeBloc>().add(const HomeRefreshPreservingOrder());
          },
        ),
      ],
      child: HomeView(pageController: pageController),
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
  bool _isShareMenuOpen = false;
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

  void _measurePatientRow() {
    final renderBox =
        _patientRowKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null && mounted) {
      final height = renderBox.size.height;
      if (height != _patientRowHeight && height > 0) {
        setState(() => _patientRowHeight = height);
      }
    }
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

          return Scaffold(
            backgroundColor: context.colorScheme.surface,
            extendBody: true,
            appBar: CustomAppBar(
              automaticallyImplyLeading: false,
              titleWidget: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        BlocBuilder<UserBloc, UserState>(
                          builder: (context, userState) {
                            return BlocBuilder<SyncBloc, SyncState>(
                              builder: (context, syncState) {
                                final displayName =
                                    userState.user.name.isNotEmpty
                                        ? userState.user.name
                                        : (syncState.syncQrData?.tokenMeta
                                                    .fullName.isNotEmpty ==
                                                true
                                            ? syncState
                                                .syncQrData!.tokenMeta.fullName
                                            : 'User');
                                return RichText(
                                  text: TextSpan(
                                    style: AppTextStyle.titleMedium.copyWith(
                                      color: context.colorScheme.onSurface,
                                    ),
                                    children: [
                                      TextSpan(text: context.l10n.homeHi),
                                      TextSpan(
                                          text: displayName,
                                          style: TextStyle(
                                              color:
                                                  context.colorScheme.primary)),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  _buildActions(state),
                ],
              ),
              actions: const [],
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

  Widget _buildActions(HomeState state) {
    if (state.editMode) {
      return TextButton(
        onPressed: () =>
            context.read<HomeBloc>().add(const HomeEditModeChanged(false)),
        style: TextButton.styleFrom(
          foregroundColor: context.colorScheme.primary,
        ),
        child: Text(context.l10n.done),
      );
    }

    return Row(
      children: [
        const NotificationWidget(),
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
          ),
          child: IconButton(
            icon: Assets.icons.settings.svg(
              colorFilter: ColorFilter.mode(
                context.colorScheme.onSurface,
                BlendMode.srcIn,
              ),
            ),
            onPressed: () {
              PreferenceModal.show(context);
            },
            padding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }

  Widget _buildHomeContent(BuildContext context, HomeState state) {
    final hasVitalDataLoaded = state.patientVitals
        .any((vital) => vital.value != 'N/A' && vital.observationId != null);

    final hasOverviewDataLoaded =
        state.overviewCards.any((card) => card.count != '0');

    final hasRecent = state.recentRecords.isNotEmpty;

    final hasAnyMeaningfulData =
        hasVitalDataLoaded || hasOverviewDataLoaded || hasRecent;

    final shouldShowPlaceholder =
        !hasAnyMeaningfulData && state.selectedSource != 'wallet';

    if (shouldShowPlaceholder) {
      return SyncPlaceholderWidget(
        pageController: widget.pageController,
        onSyncPressed: () {
          context.router.push(const SyncRoute());
        },
        recordTypeName: null,
      );
    }

    return _buildDashboardContent(
      context,
      context.textTheme,
      context.colorScheme,
      state,
      state.editMode,
    );
  }

  Widget _buildDashboardContent(
    BuildContext context,
    TextTheme textTheme,
    ColorScheme colorScheme,
    HomeState state,
    bool editMode,
  ) {
    final filteredCards = state.overviewCards
        .where((card) => state.selectedRecordTypes[card.category] ?? false)
        .toList();

    WidgetsBinding.instance.addPostFrameCallback((_) => _measurePatientRow());

    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (state.hasDataLoaded)
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
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: Insets.normal),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    const SizedBox(height: Insets.small),
                    if (state.hasDataLoaded || editMode)
                      Column(
                        children: [
                          HomeSectionHeader(
                            title: context.l10n.homeVitalSigns,
                            filterLabel: editMode ? context.l10n.vitals : null,
                            onFilterTap: editMode
                                ? () =>
                                    HomeDialogController.showEditVitalsDialog(
                                      context,
                                      state,
                                      (updated) {
                                        context.read<HomeBloc>().add(
                                            HomeVitalsFiltersChanged(updated));
                                      },
                                    )
                                : null,
                            colorScheme: colorScheme,
                            isEditMode: editMode,
                            isFilterDisabled: state.vitalsExpanded,
                            onInfoTap: () => SectionInfoModal.show(
                              context,
                              context.l10n.vitalSigns,
                              context.l10n.longPressToReorder,
                            ),
                          ),
                          SizedBox(
                              height: MediaQuery.of(context).size.height < 700
                                  ? Insets.small
                                  : Insets.smallNormal),
                          VitalsSection(
                            vitals: state.vitalsExpanded
                                ? state.allAvailableVitals
                                : state.patientVitals,
                            allAvailableVitals: state.allAvailableVitals,
                            editMode: editMode,
                            vitalsExpanded: state.vitalsExpanded,
                            firstCardKey:
                                _highlightController.firstVitalCardKey,
                            selectedVitals: Map.fromEntries(
                              state.selectedVitals.entries.map(
                                (e) => MapEntry(e.key.title, e.value),
                              ),
                            ),
                            onReorder: (oldIndex, newIndex) {
                              context
                                  .read<HomeBloc>()
                                  .add(HomeVitalsReordered(oldIndex, newIndex));
                            },
                            onLongPressCard: () => context
                                .read<HomeBloc>()
                                .add(const HomeEditModeChanged(true)),
                            onExpandToggle: () {
                              context
                                  .read<HomeBloc>()
                                  .add(const HomeVitalsExpansionToggled());
                            },
                          ),
                        ],
                      ),
                    SizedBox(
                        height: MediaQuery.of(context).size.height < 700
                            ? Insets.medium
                            : Insets.large),
                    if (state.hasDataLoaded || editMode)
                      Column(
                        children: [
                          HomeSectionHeader(
                            title: context.l10n.overview,
                            subtitle: state.sources.isNotEmpty
                                ? SourceSelectorWidget(
                                    sources: state.sources,
                                    selectedSource: state.selectedSource,
                                    onSourceChanged:
                                        (sourceId, patientSourceIds) {
                                      context.read<HomeBloc>().add(
                                          HomeSourceChanged(sourceId,
                                              patientSourceIds:
                                                  patientSourceIds));
                                    },
                                    currentPatient: state.patient,
                                    onSourceLabelEdit: (source) {
                                      context.read<HomeBloc>().add(
                                            HomeSourceLabelUpdated(source.id,
                                                source.labelSource ?? ''),
                                          );
                                    },
                                    onSourceDelete: (source) {
                                      final patientSourceIds =
                                          PatientSourceUtils
                                              .getPatientSourceIds(context);
                                      final filteredPatientSourceIds =
                                          patientSourceIds
                                              ?.where((id) => id != source.id)
                                              .toList();

                                      final patientState =
                                          context.read<PatientBloc>().state;
                                      final selectedPatientId =
                                          patientState.selectedPatientId;

                                      context.read<HomeBloc>().add(
                                            HomeSourceDeleted(source.id,
                                                patientSourceIds:
                                                    filteredPatientSourceIds),
                                          );

                                      if (selectedPatientId != null) {
                                        context.read<PatientBloc>().add(
                                              PatientPatientsLoaded(
                                                preserveOrder: true,
                                                preservePatientId:
                                                    selectedPatientId,
                                              ),
                                            );
                                      }
                                    },
                                  )
                                : null,
                            filterLabel: context.l10n.records,
                            onFilterTap: () =>
                                HomeDialogController.showEditRecordsDialog(
                              context,
                              state,
                              (newSelection) {
                                context.read<HomeBloc>().add(
                                    HomeRecordsFiltersChanged(newSelection));
                              },
                            ),
                            colorScheme: colorScheme,
                            isEditMode: editMode,
                            onInfoTap: () => SectionInfoModal.show(
                              context,
                              context.l10n.overview,
                              context.l10n.longPressToReorder,
                            ),
                          ),
                          SizedBox(
                              height: MediaQuery.of(context).size.height < 700
                                  ? Insets.small
                                  : Insets.smallNormal),
                          MedicalRecordsSection(
                            overviewCards: filteredCards,
                            editMode: editMode,
                            firstCardKey:
                                _highlightController.firstOverviewCardKey,
                            onLongPressCard: () => context
                                .read<HomeBloc>()
                                .add(const HomeEditModeChanged(true)),
                            onReorder: (oldIndex, newIndex) {
                              context.read<HomeBloc>().add(
                                  HomeRecordsReordered(oldIndex, newIndex));
                            },
                            onTapCard: (card) {
                              context.read<RecordsBloc>().add(
                                  RecordsFiltersApplied(
                                      card.category.resourceTypes));
                              widget.pageController.animateToPage(
                                1,
                                duration: HomeConstants.pageTransitionDuration,
                                curve: Curves.ease,
                              );
                            },
                          ),
                        ],
                      ),
                    SizedBox(
                        height: MediaQuery.of(context).size.height < 700
                            ? Insets.medium
                            : Insets.large),
                    if (state.hasDataLoaded || editMode)
                      Column(
                        children: [
                          HomeSectionHeader(
                            title: context.l10n.recentRecords,
                            trailing: TextButton(
                              onPressed: () {
                                widget.pageController.animateToPage(
                                  1,
                                  duration:
                                      HomeConstants.pageTransitionDuration,
                                  curve: Curves.ease,
                                );
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: context.colorScheme.primary,
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                context.l10n.viewAll,
                                style: AppTextStyle.labelLarge.copyWith(
                                  color: context.colorScheme.primary,
                                ),
                              ),
                            ),
                            colorScheme: colorScheme,
                          ),
                          SizedBox(
                              height: MediaQuery.of(context).size.height < 700
                                  ? Insets.small
                                  : Insets.smallNormal),
                          RecentRecordsSection(
                            recentRecords: state.recentRecords,
                            onViewAll: () {
                              widget.pageController.animateToPage(
                                1,
                                duration: HomeConstants.pageTransitionDuration,
                                curve: Curves.ease,
                              );
                            },
                            onTapRecord: (record) {
                              context.router
                                  .push(RecordDetailsRoute(resource: record));
                            },
                          ),
                        ],
                      ),
                    const SizedBox(height: HomeConstants.bottomPadding),
                  ]),
                ),
              ),
            ],
          ),
        ),
        ),
          ],
        ),
        if (state.hasDataLoaded)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              key: _patientRowKey,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: context.colorScheme.surface,
                borderRadius: _isScrolled
                    ? const BorderRadius.only(
                        bottomLeft: Radius.circular(20),
                        bottomRight: Radius.circular(20),
                      )
                    : BorderRadius.zero,
                boxShadow: _isScrolled
                    ? [
                        BoxShadow(
                          offset: const Offset(0, 4),
                          blurRadius: 12,
                          color: Colors.black.withValues(alpha: 0.15),
                        ),
                      ]
                    : [],
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: Insets.normal,
                vertical: Insets.small,
              ),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (_isShareMenuOpen) return;
                  final row = _patientRowKey.currentContext
                      ?.findRenderObject() as RenderBox?;
                  if (row == null) return;
                  final overlay = Overlay.of(context)
                      .context
                      .findRenderObject() as RenderBox;
                  final rowTopLeft = row.localToGlobal(
                    Offset.zero,
                    ancestor: overlay,
                  );
                  final position = RelativeRect.fromLTRB(
                    Insets.normal,
                    rowTopLeft.dy + row.size.height,
                    Insets.normal,
                    0,
                  );

                  setState(() => _isShareMenuOpen = true);

                  final patientName =
                      FhirFieldExtractor.extractHumanNameFamilyFirst(
                          state.patient?.name?.first);
                  showShareOptionsMenu(
                    context,
                    position: position,
                    patientName: patientName,
                    patientId: state.patient?.id,
                  ).then((_) {
                    if (mounted) {
                      setState(() => _isShareMenuOpen = false);
                    }
                  });
                },
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        'Patient: ${FhirFieldExtractor.extractHumanNameFamilyFirst(state.patient?.name?.first) ?? 'Loading...'}',
                        style: AppTextStyle.bodyMedium.copyWith(
                          color: context.colorScheme.onSurface,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: Insets.extraSmall),
                    AnimatedRotation(
                      turns: _isShareMenuOpen ? 0.5 : 0,
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
              ),
            ),
          ),
      ],
    );
  }
}
