import 'dart:async';
import 'dart:io';
import 'package:auto_route/auto_route.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_wallet/core/config/constants/shared_prefs_constants.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/navigation/app_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/features/dashboard/presentation/helpers/page_view_navigation_controller.dart';
import 'package:health_wallet/features/home/presentation/bloc/home_bloc.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/processing/presentation/bloc/processing_bloc.dart';
import 'package:health_wallet/features/desktop/lww_sync/presentation/bloc/lww_sync_bloc.dart';
import 'package:health_wallet/features/sync/presentation/bloc/sync_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:health_wallet/features/records/presentation/bloc/records_bloc.dart';
import 'package:health_wallet/features/records/presentation/widgets/records_active_filters_bar.dart';
import 'package:health_wallet/features/records/presentation/widgets/records_filter_bottom_sheet.dart';
import 'package:health_wallet/features/records/presentation/widgets/records_toolbar.dart';
import 'package:health_wallet/core/utils/responsive.dart';
import 'package:health_wallet/features/user/presentation/preferences_modal/sections/patient/bloc/patient_bloc.dart';

import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/gen/assets.gen.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/core/widgets/animated_sticky_header.dart';
import 'package:health_wallet/core/widgets/custom_arrow_tooltip.dart';
import 'package:health_wallet/features/share_records/core/share_permissions_helper.dart';
import 'package:health_wallet/features/user/presentation/bloc/user_bloc.dart';
import 'package:health_wallet/features/records/presentation/bloc/attachment_browse_bloc.dart';
import 'package:health_wallet/features/records/presentation/widgets/records_view_toggle.dart';
import 'package:health_wallet/core/l10n/l10n.dart';
import 'package:health_wallet/features/records/presentation/pages/records_list_body.dart';
import 'package:health_wallet/features/records/presentation/pages/records_attachments_body.dart';

@RoutePage()
class RecordsPage extends StatelessWidget {
  final List<FhirType>? initFilters;
  final PageController? pageController;

  const RecordsPage({super.key, this.initFilters, this.pageController});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<AttachmentBrowseBloc>(),
      child: RecordsView(
          initFilters: initFilters, pageController: pageController),
    );
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
  RecordsViewMode _viewMode = RecordsViewMode.attachments;
  final ValueNotifier<bool> _isAttachmentScrolled = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadViewMode();
    getIt<PageViewNavigationController>()
        .currentPageNotifier
        .addListener(_updateSwipeState);

    final selected = context.read<HomeBloc>().state.selectedSource;
    final selectedSourceId = selected == 'All' ? null : selected;
    final patientSourceIds = _resolvePatientSourceIds(context, selected);

    context.read<RecordsBloc>().add(const RecordsInitialised());
    context.read<RecordsBloc>().add(
        RecordsSourceChanged(selectedSourceId, sourceIds: patientSourceIds));

    final currentFilters = context.read<RecordsBloc>().state.activeFilters;
    final currentSpecialties = context.read<RecordsBloc>().state.activeSpecialties;
    final attachmentFilters = widget.initFilters ??
        (currentSpecialties.isNotEmpty
            ? <FhirType>[]
            : currentFilters.isNotEmpty
                ? currentFilters
                : <FhirType>[]);
    context.read<AttachmentBrowseBloc>().add(AttachmentBrowseInitialised(
        sourceId: selectedSourceId,
        sourceIds: patientSourceIds,
        resourceTypes: attachmentFilters,
        specialty: currentSpecialties.isNotEmpty
            ? currentSpecialties.first
            : null));

    if (widget.initFilters != null) {
      context
          .read<RecordsBloc>()
          .add(RecordsFiltersApplied(widget.initFilters!));
    }
  }

  void _loadViewMode() {
    final prefs = getIt<SharedPreferences>();
    final saved = prefs.getString(SharedPrefsConstants.recordsViewMode);
    if (saved == RecordsViewMode.recordsList.name) {
      setState(() => _viewMode = RecordsViewMode.recordsList);
    }
    _updateSwipeState();
  }

  void _setViewMode(RecordsViewMode mode) {
    setState(() => _viewMode = mode);
    getIt<SharedPreferences>()
        .setString(SharedPrefsConstants.recordsViewMode, mode.name);
    _updateSwipeState();
  }

  void _updateSwipeState() {
    final nav = getIt<PageViewNavigationController>();
    final isOnRecords = nav.currentPage == 1;
    nav.swipeEnabledNotifier.value =
        !isOnRecords || _viewMode == RecordsViewMode.recordsList;
  }

  void _reloadAttachmentBrowse(BuildContext context,
      {List<FhirType> resourceTypes = const []}) {
    final homeState = context.read<HomeBloc>().state;
    final sourceId =
        homeState.selectedSource == 'All' ? null : homeState.selectedSource;
    final patientSourceIds =
        _resolvePatientSourceIds(context, homeState.selectedSource);
    final specialties = context.read<RecordsBloc>().state.activeSpecialties;
    context.read<AttachmentBrowseBloc>().add(AttachmentBrowseInitialised(
        sourceId: sourceId,
        sourceIds: patientSourceIds,
        resourceTypes: resourceTypes,
        specialty: specialties.firstOrNull));
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
    } catch (_) {}
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
        title: Text(context.l10n.permissionsRequired),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              SharePermissionsHelper.openSettings();
            },
            child: Text(context.l10n.openSettings),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _debounceTimer?.cancel();
    final nav = getIt<PageViewNavigationController>();
    nav.currentPageNotifier.removeListener(_updateSwipeState);
    nav.swipeEnabledNotifier.value = true;
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
              .read<ProcessingBloc>()
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
            .read<ProcessingBloc>()
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
          context.read<ProcessingBloc>().add(const CaptureButtonPressed());
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: getIt<LwwSyncBloc>()),
      ],
      child: MultiBlocListener(
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
          BlocListener<LwwSyncBloc, LwwSyncState>(
            listenWhen: (previous, current) =>
                current.receivedRows > previous.receivedRows ||
                (previous.syncStatus == LwwSyncStatus.syncing &&
                    current.syncStatus == LwwSyncStatus.idle &&
                    current.receivedRows > 0),
            listener: (context, state) {
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
            },
          ),
          BlocListener<RecordsBloc, RecordsState>(
            listenWhen: (previous, current) =>
                current.status == const RecordsStatus.deleted(),
            listener: (context, state) {
              context
                  .read<PatientBloc>()
                  .add(const PatientPatientsLoaded());
            },
          ),
          BlocListener<RecordsBloc, RecordsState>(
            listenWhen: (previous, current) =>
                previous.activeFilters != current.activeFilters ||
                previous.activeSpecialties != current.activeSpecialties ||
                previous.dateFilter != current.dateFilter ||
                previous.sourceId != current.sourceId ||
                previous.sourceIds != current.sourceIds,
            listener: (context, state) {
              debugPrint('[RecordsPage] filter listener: filters=${state.activeFilters}, specialties=${state.activeSpecialties}, source=${state.sourceId}');
              context.read<AttachmentBrowseBloc>().add(
                  AttachmentBrowseInitialised(
                    sourceId: state.sourceId,
                    sourceIds: state.sourceIds,
                    resourceTypes: state.activeFilters,
                    specialty: state.activeSpecialties.isNotEmpty
                        ? state.activeSpecialties.first
                        : null,
                  ));
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
              body: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: context.contentMaxWidth),
                  child: _buildBody(context, appBarState),
                ),
              ),
              floatingActionButton: _showScrollToTopButton
                  ? Padding(
                      padding: const EdgeInsets.only(bottom: 80),
                      child: FloatingActionButton(
                        onPressed: _scrollToTop,
                        mini: true,
                        backgroundColor: context.colorScheme.primary,
                        foregroundColor: context.isDarkMode
                            ? Colors.white
                            : context.colorScheme.onPrimary,
                        child: const Icon(Icons.keyboard_arrow_up),
                      ),
                    )
                  : null,
            ),
          );
        },
      ),
      ),
    );
  }

  Widget _buildTitleRow(BuildContext context, RecordsState appBarState) {
    return Row(
      children: [
        Expanded(
          child: Text(
            appBarState.isSelectionMode
                ? context.l10n.recordsSelectedCount(
                    appBarState.selectedResourceIds.length)
                : context.l10n.noRecordsSelected,
            style: AppTextStyle.bodyMedium.copyWith(
              color: context.colorScheme.onSurface,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: context.colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: GestureDetector(
            onTap: () {
              CustomArrowTooltip.dismiss();
              context
                  .read<RecordsBloc>()
                  .add(const RecordsSelectionModeToggled());
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 6,
              ),
              child: Text(
                appBarState.isSelectionMode
                    ? context.l10n.cancel
                    : context.l10n.select,
                style: AppTextStyle.labelLarge.copyWith(
                  color: context.colorScheme.primary,
                ),
              ),
            ),
          ),
        ),
        IconButton(
          key: _shareTooltipKey,
          visualDensity: VisualDensity.compact,
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
        message: context.l10n.selectRecordsBeforeSharing,
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

  void _showFilterSheet(BuildContext context) {
    final recordsBloc = context.read<RecordsBloc>();
    final recordsState = recordsBloc.state;
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
      builder: (_) => RecordsFilterBottomSheet(
        activeFilters: recordsState.activeFilters,
        currentDateFilter: recordsState.dateFilter,
        currentSpecialties: recordsState.activeSpecialties,
        onApply: (filters, dateFilter, specialties) {
          recordsBloc.add(RecordsFiltersApplied(
            filters,
            dateFilter: dateFilter,
          ));
          recordsBloc.add(RecordsSpecialtyApplied(specialties));
        },
      ),
      isScrollControlled: true,
    );
  }

  Widget _buildBody(BuildContext context, RecordsState appBarState) {
    if (_viewMode == RecordsViewMode.attachments) {
      return KeyedSubtree(
        key: const ValueKey('attachments_body'),
        child: RecordsAttachmentsBody(
          appBarState: appBarState,
          isAttachmentScrolled: _isAttachmentScrolled,
          viewMode: _viewMode,
          onViewModeChanged: (mode) {
            _setViewMode(mode);
            if (mode == RecordsViewMode.attachments) {
              final filters = context.read<RecordsBloc>().state.activeFilters;
              _reloadAttachmentBrowse(context, resourceTypes: filters);
            }
          },
          onFilterTap: () => _showFilterSheet(context),
          titleRow: _buildTitleRow(context, appBarState),
        ),
      );
    }

    return KeyedSubtree(
      key: const ValueKey('records_body'),
      child: BlocBuilder<RecordsBloc, RecordsState>(
      buildWhen: (previous, current) =>
          previous.activeFilters != current.activeFilters ||
          previous.dateFilter != current.dateFilter ||
          previous.activeSpecialties != current.activeSpecialties ||
          previous.status != current.status ||
          previous.resources != current.resources,
      builder: (context, filterState) {
        return AnimatedStickyHeader(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: MediaQuery.of(context).padding.top + Insets.small,
            bottom: 0,
          ),
          children: [
            _buildTitleRow(context, appBarState),
            const SizedBox(height: Insets.extraSmall),
            RecordsToolbar(
              viewMode: _viewMode,
              onViewModeChanged: (mode) {
                _setViewMode(mode);
                if (mode == RecordsViewMode.attachments) {
                  final filters = context.read<RecordsBloc>().state.activeFilters;
                  _reloadAttachmentBrowse(context, resourceTypes: filters);
                }
              },
              onFilterTap: () => _showFilterSheet(context),
            ),
            BlocBuilder<RecordsBloc, RecordsState>(
              buildWhen: (previous, current) =>
                  previous.activeFilters != current.activeFilters ||
                  previous.dateFilter != current.dateFilter ||
                  previous.activeSpecialties != current.activeSpecialties,
              builder: (context, recordsState) {
                return RecordsActiveFiltersBar(
                  activeFilters: recordsState.activeFilters,
                  dateFilter: recordsState.dateFilter,
                  activeSpecialties: recordsState.activeSpecialties,
                );
              },
            ),
          ],
          body: BlocBuilder<RecordsBloc, RecordsState>(
            buildWhen: (previous, current) =>
                previous.status != current.status ||
                previous.resources != current.resources ||
                previous.searchQuery != current.searchQuery ||
                previous.activeSpecialties != current.activeSpecialties ||
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

              final timelineResources =
                  List<IFhirResource>.from(state.resources);

              return RecordsListBody(
                state: state,
                resources: timelineResources,
                scrollController: _scrollController,
                pageController: widget.pageController,
                onImportDocument: _handleImportDocument,
                onPickImage: _handlePickImage,
                onScanDocument: _handleScanDocument,
              );
            },
          ),
        );
      },
      ),
    );
  }
}
