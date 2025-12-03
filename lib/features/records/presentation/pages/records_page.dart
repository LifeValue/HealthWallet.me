import 'dart:async';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/features/home/presentation/bloc/home_bloc.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/sync/presentation/bloc/sync_bloc.dart';

import 'package:health_wallet/features/records/presentation/bloc/records_bloc.dart';
import 'package:health_wallet/features/records/presentation/widgets/records_filter_bottom_sheet.dart';
import 'package:health_wallet/features/records/presentation/widgets/search_widget.dart';
import 'package:health_wallet/features/sync/presentation/widgets/sync_placeholder_widget.dart';
import 'package:health_wallet/features/user/presentation/preferences_modal/sections/patient/bloc/patient_bloc.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/features/records/presentation/widgets/fhir_cards/resource_card.dart';

import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/gen/assets.gen.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/core/widgets/custom_app_bar.dart';
import 'package:intl/intl.dart';

@RoutePage()
class RecordsPage extends StatelessWidget {
  final List<FhirType>? initFilters;
  final PageController? pageController;

  const RecordsPage({super.key, this.initFilters, this.pageController});

  @override
  Widget build(BuildContext context) {
    return RecordsView(
        initFilters: initFilters, pageController: pageController);
  }
}

class RecordsView extends StatefulWidget {
  final List<FhirType>? initFilters;
  final PageController? pageController;

  const RecordsView({super.key, this.initFilters, this.pageController});

  @override
  State<RecordsView> createState() => _RecordsViewState();
}

class _RecordsViewState extends State<RecordsView> {
  final ScrollController _scrollController = ScrollController();

  Timer? _debounceTimer;
  bool _showScrollToTopButton = false;

  @override
  void initState() {
    super.initState();

    _scrollController.addListener(_onScroll);

    final selected = context.read<HomeBloc>().state.selectedSource;
    final selectedSourceId = selected == 'All' ? null : selected;

    // Get patient source IDs when "All" is selected
    List<String>? patientSourceIds;
    if (selected == 'All') {
      try {
        final patientBloc = context.read<PatientBloc>();
        final patientState = patientBloc.state;
        final selectedPatientId = patientState.selectedPatientId;

        if (selectedPatientId != null &&
            patientState.patientGroups.isNotEmpty) {
          final patientGroup = patientState.patientGroups[selectedPatientId];
          if (patientGroup != null) {
            patientSourceIds = patientGroup.sourceIds;
          }
        }
      } catch (e) {
        // PatientBloc not available, continue without patient source IDs
      }
    }

    context.read<RecordsBloc>().add(const RecordsInitialised());
    context.read<RecordsBloc>().add(
        RecordsSourceChanged(selectedSourceId, sourceIds: patientSourceIds));

    if (widget.initFilters != null) {
      context
          .read<RecordsBloc>()
          .add(RecordsFiltersApplied(widget.initFilters!));
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final currentScroll = _scrollController.offset;
    final maxScroll = _scrollController.position.maxScrollExtent;

    final shouldShowButton = currentScroll > 200;
    if (shouldShowButton != _showScrollToTopButton) {
      setState(() {
        _showScrollToTopButton = shouldShowButton;
      });
    }

    if (maxScroll > 0 && currentScroll >= maxScroll - 200) {
      _loadMoreData();
    }
  }

  void _loadMoreData() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        final state = context.read<RecordsBloc>().state;
        if (state.status != RecordsStatus.loading() && state.hasMorePages) {
          context.read<RecordsBloc>().add(const RecordsLoadMore());
        }
      }
    });
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  FloatingActionButtonLocation get _customFabLocation {
    return _CustomFabLocation();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<HomeBloc, HomeState>(
          listener: (context, state) {
            final selectedSourceId =
                state.selectedSource == 'All' ? null : state.selectedSource;

            // Get patient source IDs when "All" is selected
            List<String>? patientSourceIds;
            if (state.selectedSource == 'All') {
              try {
                final patientBloc = context.read<PatientBloc>();
                final patientState = patientBloc.state;
                final selectedPatientId = patientState.selectedPatientId;

                if (selectedPatientId != null &&
                    patientState.patientGroups.isNotEmpty) {
                  final patientGroup =
                      patientState.patientGroups[selectedPatientId];
                  if (patientGroup != null) {
                    patientSourceIds = patientGroup.sourceIds;
                  }
                }
              } catch (e) {
                // PatientBloc not available, continue without patient source IDs
              }
            }

            context.read<RecordsBloc>().add(RecordsSourceChanged(
                selectedSourceId,
                sourceIds: patientSourceIds));
          },
        ),
        BlocListener<SyncBloc, SyncState>(
          listener: (context, state) {
            if (state.hasDemoData || state.hasSyncedData) {
              context.read<RecordsBloc>().add(const RecordsInitialised());

              final homeState = context.read<HomeBloc>().state;
              final selectedSourceId = homeState.selectedSource == 'All'
                  ? null
                  : homeState.selectedSource;

              // Get patient source IDs when "All" is selected
              List<String>? patientSourceIds;
              if (homeState.selectedSource == 'All') {
                try {
                  final patientBloc = context.read<PatientBloc>();
                  final patientState = patientBloc.state;
                  final selectedPatientId = patientState.selectedPatientId;

                  if (selectedPatientId != null &&
                      patientState.patientGroups.isNotEmpty) {
                    final patientGroup =
                        patientState.patientGroups[selectedPatientId];
                    if (patientGroup != null) {
                      patientSourceIds = patientGroup.sourceIds;
                    }
                  }
                } catch (e) {
                  // PatientBloc not available, continue without patient source IDs
                }
              }

              context.read<RecordsBloc>().add(RecordsSourceChanged(
                  selectedSourceId,
                  sourceIds: patientSourceIds));
            }
          },
        ),
      ],
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Scaffold(
          appBar: CustomAppBar(
            title: context.l10n.medicalRecords,
            automaticallyImplyLeading: false,
            actions: [
              IconButton(
                onPressed: () => context
                    .read<RecordsBloc>()
                    .add(const RecordsSharePressed()),
                icon: Assets.icons.share.svg(
                  colorFilter: ColorFilter.mode(
                    context.colorScheme.onSurface,
                    BlendMode.srcIn,
                  ),
                ),
              ),
              BlocBuilder<RecordsBloc, RecordsState>(
                builder: (context, state) {
                  return IconButton(
                    onPressed: () async {
                      showModalBottomSheet(
                        context: context,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        builder: (context) => RecordsFilterBottomSheet(
                          activeFilters: state.activeFilters,
                          onApply: (filters) => context
                              .read<RecordsBloc>()
                              .add(RecordsFiltersApplied(filters)),
                        ),
                        isScrollControlled: true,
                      );
                    },
                    icon: Assets.icons.filter.svg(
                      colorFilter: ColorFilter.mode(
                        context.colorScheme.onSurface,
                        BlendMode.srcIn,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          floatingActionButton: _showScrollToTopButton
              ? FloatingActionButton(
                  onPressed: _scrollToTop,
                  mini: true,
                  backgroundColor: context.colorScheme.primary,
                  foregroundColor: context.isDarkMode
                      ? Colors.white
                      : context.colorScheme.onPrimary,
                  child: const Icon(Icons.keyboard_arrow_up),
                )
              : null,
          floatingActionButtonLocation: _customFabLocation,
          body: Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SearchWidget(),
                    const SizedBox(height: Insets.small),
                    BlocBuilder<RecordsBloc, RecordsState>(
                      buildWhen: (previous, current) =>
                          previous.activeFilters != current.activeFilters,
                      builder: (context, recordsState) {
                        if (recordsState.activeFilters.isEmpty) {
                          return const SizedBox();
                        }

                        return BlocBuilder<HomeBloc, HomeState>(
                          buildWhen: (previous, current) =>
                              previous.hasDataLoaded != current.hasDataLoaded,
                          builder: (context, homeState) {
                            if (!homeState.hasDataLoaded) {
                              return const SizedBox();
                            }

                            return Row(
                              children: [
                                Expanded(
                                  child: Wrap(
                                    spacing: 8.0,
                                    runSpacing: 8,
                                    children: recordsState.activeFilters
                                        .map(
                                          (filter) => GestureDetector(
                                            onTap: () => context
                                                .read<RecordsBloc>()
                                                .add(RecordsFilterRemoved(
                                                    filter)),
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 4,
                                                      horizontal: 8),
                                              decoration: BoxDecoration(
                                                color: AppColors.primary
                                                    .withValues(alpha: 0.08),
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    filter.display,
                                                    style: AppTextStyle
                                                        .labelSmall
                                                        .copyWith(
                                                            color: AppColors
                                                                .primary),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  const Icon(
                                                    Icons.close,
                                                    color: AppColors.primary,
                                                    size: 12,
                                                  )
                                                ],
                                              ),
                                            ),
                                          ),
                                        )
                                        .toList(),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => context
                                      .read<RecordsBloc>()
                                      .add(RecordsFiltersApplied([])),
                                  child: Text(
                                    context.l10n.clearAllFilters,
                                    style: AppTextStyle.labelMedium.copyWith(
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: BlocBuilder<RecordsBloc, RecordsState>(
                  buildWhen: (previous, current) =>
                      previous.status != current.status ||
                      previous.resources != current.resources ||
                      previous.searchQuery != current.searchQuery,
                  builder: (context, state) {
                    if (state.status == const RecordsStatus.loading()) {
                      return Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 4,
                          color: context.colorScheme.primary,
                        ),
                      );
                    }

                    if (state.status == RecordsStatus.failure(Exception())) {
                      return Center(child: Text(state.status.toString()));
                    }

                    final timelineResources =
                        List<IFhirResource>.from(state.resources);

                    if (timelineResources.isEmpty) {
                      if (state.searchQuery.isNotEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.search_off,
                                  size: 64,
                                  color: context.colorScheme.onSurface
                                      .withOpacity(0.4),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  context.l10n.noRecordsFound,
                                  style: AppTextStyle.titleMedium.copyWith(
                                    color: context.colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  context.l10n.tryDifferentKeywords,
                                  style: AppTextStyle.bodyMedium.copyWith(
                                    color: context.colorScheme.onSurface
                                        .withOpacity(0.6),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        );
                      } else {
                        return LayoutBuilder(
                          builder: (context, constraints) {
                            final double bottomSafeInset =
                                MediaQuery.of(context).padding.bottom;
                            const double bottomBarHeight = Insets.extraLarge;
                            const double bottomBarOffset = Insets.medium;
                            const double extraSpacing = Insets.large;
                            
                            return SingleChildScrollView(
                              controller: _scrollController,
                              physics: const ClampingScrollPhysics(),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minHeight: constraints.maxHeight,
                                ),
                                child: Padding(
                                  padding: EdgeInsets.only(
                                    bottom: bottomSafeInset +
                                        bottomBarHeight +
                                        bottomBarOffset +
                                        extraSpacing,
                                  ),
                                  child: IntrinsicHeight(
                                    child: SyncPlaceholderWidget(
                                      pageController: widget.pageController,
                                      recordTypeName: state.activeFilters.isNotEmpty
                                          ? state.activeFilters.length == 1
                                              ? state.activeFilters.first.display
                                              : state.activeFilters
                                                  .map((f) => f.display)
                                                  .join(', ')
                                          : null,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      }
                    }

                    const double bottomBarHeight = Insets.extraLarge;
                    const double bottomBarOffset = Insets.medium;
                    const double extraSpacing = Insets.large;
                    final double bottomSafeInset =
                        MediaQuery.of(context).padding.bottom;

                    return ListView.builder(
                      controller: _scrollController,
                      padding: EdgeInsets.only(
                        bottom: bottomSafeInset +
                            bottomBarHeight +
                            bottomBarOffset +
                            extraSpacing,
                      ),
                      itemCount: timelineResources.length +
                          (state.hasMorePages ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == timelineResources.length) {
                          return Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 4,
                                color: context.colorScheme.primary,
                              ),
                            ),
                          );
                        }

                        final resource = timelineResources[index];
                        return _buildTimelineResourceEntry(
                          context,
                          resource: resource,
                          index: index,
                          isFirst: index == 0,
                          isLast: index == timelineResources.length - 1,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimelineResourceEntry(
    BuildContext context, {
    required IFhirResource resource,
    required int index,
    required bool isFirst,
    required bool isLast,
  }) {
    const double dotSize = 16.0;
    const double lineWidth = 2.0;

    FhirType recordType = resource.fhirType;

    return IntrinsicHeight(
      key: ValueKey('timeline-${resource.fhirType}-${resource.id}-$index'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Stack(
          children: [
            // Main content
            Padding(
              padding: const EdgeInsets.only(
                bottom: Insets.normal,
              ),
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: context.theme.dividerColor),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(Insets.normal),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Resource type tag and date
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          GestureDetector(
                            onTap: () {
                              context.read<RecordsBloc>().add(
                                    RecordsFiltersApplied([recordType]),
                                  );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: Insets.small,
                                vertical: Insets.extraSmall,
                              ),
                              decoration: BoxDecoration(
                                color: context.colorScheme.onSurface
                                    .withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                children: [
                                  recordType.icon.svg(
                                    width: 15,
                                    colorFilter: ColorFilter.mode(
                                      context.colorScheme.onSurface,
                                      BlendMode.srcIn,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    recordType.display,
                                    style: AppTextStyle.labelSmall,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (resource.date != null)
                            Text(
                              DateFormat.yMMMMd().format(resource.date!),
                              style: AppTextStyle.labelMedium.copyWith(
                                color: context.colorScheme.onSurface
                                    .withOpacity(0.6),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: Insets.small),

                      ResourceCard(resource: resource)
                    ],
                  ),
                ),
              ),
            ),
            // Timeline line and dot
            Transform.translate(
              offset: const Offset(-dotSize / 2, 0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Upper line
                  Expanded(
                    child: Container(
                      width: lineWidth,
                      color: !isFirst ? AppColors.primary : Colors.transparent,
                    ),
                  ),
                  // Dot
                  Container(
                    width: dotSize,
                    height: dotSize,
                    decoration: BoxDecoration(
                        color: context.colorScheme.surface,
                        border: Border.all(
                          color: AppColors.primary,
                          width: 3,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            offset: const Offset(0, 1),
                            color: AppColors.primary.withValues(alpha: 0.6),
                            blurRadius: 3,
                          )
                        ]),
                  ),
                  // Lower line
                  Expanded(
                    child: Container(
                      width: lineWidth,
                      color: !isLast ? AppColors.primary : Colors.transparent,
                    ),
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

class _CustomFabLocation extends FloatingActionButtonLocation {
  @override
  Offset getOffset(ScaffoldPrelayoutGeometry scaffoldGeometry) {
    final defaultOffset =
        FloatingActionButtonLocation.endFloat.getOffset(scaffoldGeometry);
    return Offset(defaultOffset.dx, defaultOffset.dy - 38);
  }
}
