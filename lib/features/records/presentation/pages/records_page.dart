import 'dart:async';
import 'dart:io';
import 'package:auto_route/auto_route.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/navigation/app_router.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/features/dashboard/presentation/helpers/page_view_navigation_controller.dart';
import 'package:health_wallet/features/home/presentation/bloc/home_bloc.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/scan/presentation/bloc/scan_bloc.dart';
import 'package:health_wallet/features/sync/presentation/bloc/sync_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:health_wallet/features/records/presentation/bloc/records_bloc.dart';
import 'package:health_wallet/features/records/presentation/widgets/records_active_filters_bar.dart';
import 'package:health_wallet/features/records/presentation/widgets/records_filter_bottom_sheet.dart';
import 'package:health_wallet/features/records/presentation/widgets/search_widget.dart';
import 'package:health_wallet/features/sync/presentation/widgets/sync_placeholder_widget.dart';
import 'package:health_wallet/core/utils/responsive.dart';
import 'package:health_wallet/features/user/presentation/preferences_modal/sections/patient/bloc/patient_bloc.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/features/records/presentation/widgets/fhir_cards/resource_card.dart';

import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/gen/assets.gen.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/core/widgets/animated_sticky_header.dart';
import 'package:health_wallet/core/widgets/custom_app_bar.dart';
import 'package:health_wallet/core/widgets/custom_arrow_tooltip.dart';
import 'package:health_wallet/features/records/presentation/widgets/record_type_header.dart';
import 'package:health_wallet/features/records/presentation/widgets/timeline_entry.dart';
import 'package:health_wallet/features/share_records/core/share_permissions_helper.dart';
import 'package:health_wallet/features/user/presentation/bloc/user_bloc.dart';

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
  final GlobalKey _shareTooltipKey = GlobalKey();

  Timer? _debounceTimer;
  bool _showScrollToTopButton = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    final selected = context.read<HomeBloc>().state.selectedSource;
    final selectedSourceId = selected == 'All' ? null : selected;
    final patientSourceIds = _resolvePatientSourceIds(context, selected);

    context.read<RecordsBloc>().add(const RecordsInitialised());
    context.read<RecordsBloc>().add(
        RecordsSourceChanged(selectedSourceId, sourceIds: patientSourceIds));

    if (widget.initFilters != null) {
      context
          .read<RecordsBloc>()
          .add(RecordsFiltersApplied(widget.initFilters!));
    }
  }

  List<String>? _resolvePatientSourceIds(
      BuildContext context, String? selectedSource) {
    if (selectedSource != 'All') return null;

    try {
      final patientBloc = context.read<PatientBloc>();
      final patientState = patientBloc.state;
      final selectedPatientId = patientState.selectedPatientId;

      if (selectedPatientId != null &&
          patientState.patientGroups.isNotEmpty) {
        final patientGroup = patientState.patientGroups[selectedPatientId];
        if (patientGroup != null) {
          return patientGroup.sourceIds;
        }
      }
    } catch (e) {
      debugPrint(
          'PatientBloc not available, continue without patient source IDs');
    }
    return null;
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

  void _showPermissionsSettingsDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Permissions Required'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              SharePermissionsHelper.openSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _handleImportDocument() async {
    try {
      await Future.delayed(const Duration(milliseconds: 100));
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        allowCompression: false,
        withData: false,
        withReadStream: false,
        type: FileType.custom,
        allowedExtensions: [
          'pdf', 'jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'tiff'
        ],
      );
      if (result != null && result.files.isNotEmpty) {
        final validPaths = <String>[];
        for (final file in result.files) {
          if (file.path == null || file.path!.isEmpty) continue;
          if (await File(file.path!).exists()) {
            validPaths.add(file.path!);
          }
        }
        if (validPaths.isNotEmpty && mounted) {
          context
              .read<ScanBloc>()
              .add(DocumentImported(filePaths: validPaths));
          getIt<PageViewNavigationController>().navigateToPage(3);
        }
      }
    } catch (_) {}
  }

  Future<void> _handlePickImage() async {
    try {
      await Future.delayed(const Duration(milliseconds: 100));
      final picker = ImagePicker();
      final images = await picker.pickMultiImage();
      if (images.isEmpty) return;
      final validPaths = <String>[];
      for (final image in images) {
        if (await File(image.path).exists()) {
          validPaths.add(image.path);
        }
      }
      if (validPaths.isNotEmpty && mounted) {
        context
            .read<ScanBloc>()
            .add(DocumentImported(filePaths: validPaths));
        getIt<PageViewNavigationController>().navigateToPage(3);
      }
    } catch (_) {}
  }

  void _handleScanDocument() {
    final navController = getIt<PageViewNavigationController>();
    navController.navigateToPage(2);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 100), () async {
        final cameraStatus = await Permission.camera.request();
        if (cameraStatus.isGranted && mounted) {
          context.read<ScanBloc>().add(const ScanButtonPressed());
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<HomeBloc, HomeState>(
          listener: (context, state) {
            final selectedSourceId =
                state.selectedSource == 'All' ? null : state.selectedSource;
            final patientSourceIds =
                _resolvePatientSourceIds(context, state.selectedSource);

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
              final patientSourceIds =
                  _resolvePatientSourceIds(context, homeState.selectedSource);

              context.read<RecordsBloc>().add(RecordsSourceChanged(
                  selectedSourceId,
                  sourceIds: patientSourceIds));
            }
          },
        ),
      ],
      child: BlocBuilder<RecordsBloc, RecordsState>(
        buildWhen: (previous, current) =>
            previous.isSelectionMode != current.isSelectionMode ||
            previous.selectedResourceIds != current.selectedResourceIds,
        builder: (context, appBarState) {
          return GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: Scaffold(
              appBar: _buildAppBar(context, appBarState),
              body: Stack(
                children: [
                  _buildBody(context),
                  if (_showScrollToTopButton)
                    Positioned(
                      right: 16,
                      bottom: 100,
                      child: FloatingActionButton(
                        onPressed: _scrollToTop,
                        mini: true,
                        backgroundColor: context.colorScheme.primary,
                        foregroundColor: context.isDarkMode
                            ? Colors.white
                            : context.colorScheme.onPrimary,
                        child: const Icon(Icons.keyboard_arrow_up),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  CustomAppBar _buildAppBar(BuildContext context, RecordsState appBarState) {
    return CustomAppBar(
      titleWidget: Text(
        appBarState.isSelectionMode
            ? '${appBarState.selectedResourceIds.length} ${appBarState.selectedResourceIds.length == 1 ? 'record' : 'records'} selected'
            : 'No records selected',
        style: AppTextStyle.bodyMedium.copyWith(
          color: context.colorScheme.onSurface,
        ),
      ),
      automaticallyImplyLeading: false,
      extraTopPadding: context.isTablet ? 16 : 0,
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: context.colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: TextButton(
            onPressed: () {
              CustomArrowTooltip.dismiss();
              context
                  .read<RecordsBloc>()
                  .add(const RecordsSelectionModeToggled());
            },
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 8,
              ),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              appBarState.isSelectionMode ? 'Cancel' : 'Select',
              style: AppTextStyle.labelLarge.copyWith(
                color: context.colorScheme.primary,
              ),
            ),
          ),
        ),
        IconButton(
          key: _shareTooltipKey,
          onPressed: () => _handleShare(context),
          icon: Assets.icons.shareNearby.svg(
            colorFilter: ColorFilter.mode(
              appBarState.selectedResourceIds.isEmpty
                  ? context.colorScheme.onSurface.withValues(alpha: 0.3)
                  : context.colorScheme.onSurface,
              BlendMode.srcIn,
            ),
          ),
        ),
        BlocBuilder<RecordsBloc, RecordsState>(
          builder: (context, filterState) {
            return IconButton(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  builder: (context) => RecordsFilterBottomSheet(
                    activeFilters: filterState.activeFilters,
                    currentDateFilter: filterState.dateFilter,
                    onApply: (filters, dateFilter) =>
                        context.read<RecordsBloc>().add(RecordsFiltersApplied(
                              filters,
                              dateFilter: dateFilter,
                            )),
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
    );
  }

  Future<void> _handleShare(BuildContext context) async {
    final recordsState = context.read<RecordsBloc>().state;
    final hasSelection = recordsState.selectedResourceIds.isNotEmpty;

    if (!hasSelection) {
      CustomArrowTooltip.show(
        context: context,
        buttonKey: _shareTooltipKey,
        message: 'Select records\nbefore sharing',
        alignment: TooltipAlignment.auto,
        width: 160,
      );
      return;
    }

    final result = await SharePermissionsHelper.requestSharePermissions();
    if (!context.mounted) return;

    switch (result) {
      case PermissionGranted():
        final userBloc = context.read<UserBloc>();
        if (!userBloc.state.user.isReceiveModeEnabled) {
          userBloc.add(const UserReceiveModeToggled(true));
        }
        break;
      case PermissionDenied(:final message):
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
        return;
      case PermissionPermanentlyDenied(:final message):
        _showPermissionsSettingsDialog(context, message);
        return;
    }

    CustomArrowTooltip.dismiss();

    final selectedResources = recordsState.resources
        .where((r) => recordsState.selectedResourceIds.contains(r.id))
        .toList();
    final activeFilters = recordsState.activeFilters;

    context.router.push(
      ShareRecordsSendRoute(
        preSelectedResources: selectedResources,
        appliedFilters: activeFilters.isNotEmpty ? activeFilters : null,
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    return BlocBuilder<RecordsBloc, RecordsState>(
      buildWhen: (previous, current) =>
          previous.activeFilters != current.activeFilters ||
          previous.dateFilter != current.dateFilter,
      builder: (context, filterState) {
        return AnimatedStickyHeader(
          children: [
            const SearchWidget(),
            const SizedBox(height: Insets.small),
            BlocBuilder<RecordsBloc, RecordsState>(
              buildWhen: (previous, current) =>
                  previous.activeFilters != current.activeFilters ||
                  previous.dateFilter != current.dateFilter,
              builder: (context, recordsState) {
                return RecordsActiveFiltersBar(
                  activeFilters: recordsState.activeFilters,
                  dateFilter: recordsState.dateFilter,
                );
              },
            ),
          ],
          body: BlocBuilder<RecordsBloc, RecordsState>(
            buildWhen: (previous, current) =>
                previous.status != current.status ||
                previous.resources != current.resources ||
                previous.searchQuery != current.searchQuery ||
                previous.selectedResourceIds !=
                    current.selectedResourceIds ||
                previous.isSelectionMode != current.isSelectionMode,
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
                return _buildEmptyState(context, state);
              }

              return _buildRecordsList(context, state, timelineResources);
            },
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context, RecordsState state) {
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
                color: context.colorScheme.onSurface.withOpacity(0.4),
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
                  color: context.colorScheme.onSurface.withOpacity(0.6),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        const double bottomNavBarSpacing = 100.0;

        final placeholder = SyncPlaceholderWidget(
          pageController: widget.pageController,
          recordTypeName: state.activeFilters.isNotEmpty
              ? state.activeFilters.length == 1
                  ? state.activeFilters.first.display
                  : state.activeFilters
                      .map((f) => f.display)
                      .join(', ')
              : null,
          onImportDocument: _handleImportDocument,
          onPickImage: _handlePickImage,
          onScanDocument: _handleScanDocument,
        );

        return SingleChildScrollView(
          controller: _scrollController,
          physics: const ClampingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight,
            ),
            child: Padding(
              padding: const EdgeInsets.only(
                bottom: bottomNavBarSpacing,
              ),
              child: context.isTablet
                  ? Align(
                      alignment: const Alignment(0, -0.3),
                      child: placeholder,
                    )
                  : IntrinsicHeight(child: placeholder),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRecordsList(
    BuildContext context,
    RecordsState state,
    List<IFhirResource> timelineResources,
  ) {
    const double bottomBarHeight = Insets.extraLarge;
    const double bottomBarOffset = Insets.medium;
    const double extraSpacing = Insets.large;
    final double bottomSafeInset = MediaQuery.of(context).padding.bottom;

    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.only(
        top: 8,
        bottom: bottomSafeInset +
            bottomBarHeight +
            bottomBarOffset +
            extraSpacing,
      ),
      itemCount:
          timelineResources.length + (state.hasMorePages ? 1 : 0),
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
        return TimelineEntry(
          key: ValueKey(
              'timeline-${resource.fhirType}-${resource.id}-$index'),
          isFirst: index == 0,
          isLast: index == timelineResources.length - 1,
          isSelected:
              state.selectedResourceIds.contains(resource.id),
          isSelectionMode: state.isSelectionMode,
          onTap: () {
            if (state.isSelectionMode) {
              context.read<RecordsBloc>().add(
                    RecordsSelectionToggled(resource.id),
                  );
            } else {
              context.router.push(
                RecordDetailsRoute(resource: resource),
              );
            }
          },
          onLongPress: state.isSelectionMode
              ? null
              : () {
                  final bloc = context.read<RecordsBloc>();
                  bloc.add(const RecordsSelectionModeToggled());
                  bloc.add(RecordsSelectionToggled(resource.id));
                },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RecordTypeHeader(
                fhirType: resource.fhirType,
                date: resource.date,
                onTypeTap: state.isSelectionMode
                    ? null
                    : () {
                        context.read<RecordsBloc>().add(
                              RecordsFiltersApplied(
                                  [resource.fhirType]),
                            );
                      },
              ),
              const SizedBox(height: Insets.small),
              ResourceCard(resource: resource),
            ],
          ),
        );
      },
    );
  }
}
