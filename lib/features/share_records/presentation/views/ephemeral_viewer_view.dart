import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/navigation/app_router.dart';
import 'package:health_wallet/features/home/domain/services/specialty_classifier.dart';
import 'package:health_wallet/core/services/screen_security_service.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/core/widgets/animated_sticky_header.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/records/domain/entity/i_fhir_resource.dart';
import 'package:health_wallet/features/records/presentation/bloc/attachment_browse_bloc.dart';
import 'package:health_wallet/features/share_records/presentation/widgets/ephemeral_attachment_view.dart';
import 'package:health_wallet/features/records/presentation/widgets/record_type_header.dart';
import 'package:health_wallet/features/records/presentation/widgets/fhir_cards/resource_card.dart';
import 'package:health_wallet/features/records/presentation/widgets/records_filter_bottom_sheet.dart';
import 'package:health_wallet/features/records/presentation/widgets/records_view_toggle.dart';
import 'package:health_wallet/features/records/presentation/widgets/timeline_entry.dart';
import 'package:health_wallet/features/share_records/data/service/ephemeral_attachment_browse_service.dart';
import 'package:health_wallet/features/share_records/presentation/bloc/share_records_event.dart';
import 'package:health_wallet/features/share_records/presentation/bloc/share_records_state.dart';
import 'package:health_wallet/features/share_records/presentation/widgets/session/session_bottom_bar.dart';
import 'package:health_wallet/core/l10n/l10n.dart';
import 'package:health_wallet/gen/assets.gen.dart';

class EphemeralViewerView extends StatefulWidget {
  final ShareRecordsState state;

  const EphemeralViewerView({super.key, required this.state});

  @override
  State<EphemeralViewerView> createState() => _EphemeralViewerViewState();
}

class _EphemeralViewerViewState extends State<EphemeralViewerView>
    with SingleTickerProviderStateMixin {
  List<FhirType> _filterTypes = [];
  String _searchQuery = '';
  bool _filtersInitialized = false;
  RecordsViewMode _viewMode = RecordsViewMode.attachments;
  AttachmentBrowseBloc? _attachmentBrowseBloc;

  bool _isSearchExpanded = false;
  late final AnimationController _searchAnimController;
  late final Animation<double> _searchExpandAnimation;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ValueNotifier<bool> _isScrolled = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    ScreenSecurityService.enable();
    _searchAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _searchExpandAnimation = CurvedAnimation(
      parent: _searchAnimController,
      curve: Curves.easeInOut,
    );
    _searchFocusNode.addListener(_onSearchFocusChanged);
  }

  @override
  void didUpdateWidget(covariant EphemeralViewerView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _applyInitialFilters();
  }

  void _applyInitialFilters() {
    if (_filtersInitialized) return;
    final receivedData = widget.state.receivedData;
    if (receivedData == null) return;

    final senderFilters = receivedData.activeFilters;
    if (senderFilters.isNotEmpty) {
      final resolved = senderFilters
          .map((name) => FhirType.values
              .where((t) => t.name == name)
              .firstOrNull)
          .whereType<FhirType>()
          .toList();

      if (resolved.isNotEmpty) {
        setState(() => _filterTypes = resolved);
      }
    }
    _filtersInitialized = true;
  }

  List<IFhirResource> get _allRecords =>
      widget.state.receivedData?.records ?? const [];

  void _ensureAttachmentBrowseBloc(List<IFhirResource> records) {
    if (_attachmentBrowseBloc != null) return;
    final service = EphemeralAttachmentBrowseService(records, getIt<SpecialtyClassifier>());
    _attachmentBrowseBloc = AttachmentBrowseBloc(service, getIt<SpecialtyClassifier>());
    _attachmentBrowseBloc!.add(AttachmentBrowseInitialised(
      resourceTypes: _filterTypes,
      readOnly: true,
      sourceRecords: records,
    ));
  }

  void _onSearchFocusChanged() {
    setState(() {});
    if (!_searchFocusNode.hasFocus && _isSearchExpanded) {
      _collapseSearch();
    }
  }

  void _openSearch() {
    setState(() => _isSearchExpanded = true);
    _searchAnimController.forward();
    _searchFocusNode.requestFocus();
  }

  void _collapseSearch() {
    _searchAnimController.reverse().then((_) {
      if (mounted) setState(() => _isSearchExpanded = false);
    });
  }

  void _onSearchChanged(String query) {
    setState(() => _searchQuery = query);
    if (_viewMode == RecordsViewMode.attachments) {
      _attachmentBrowseBloc?.add(AttachmentBrowseSearchChanged(query));
    }
  }

  void _handleSearchSuffixTap() {
    if (_searchController.text.isNotEmpty) {
      _searchController.clear();
      _onSearchChanged('');
      _searchFocusNode.requestFocus();
    } else {
      _searchFocusNode.unfocus();
    }
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      isScrollControlled: true,
      builder: (_) {
        final receivedData = widget.state.receivedData;
        final availableTypes = receivedData != null
            ? receivedData.records
                .map((r) => r.fhirType)
                .toSet()
                .toList()
            : <FhirType>[];
        return RecordsFilterBottomSheet(
          activeFilters: _filterTypes,
          availableFilters: availableTypes,
          onApply: (filters, _, __) {
            setState(() => _filterTypes = filters);
            if (_viewMode == RecordsViewMode.attachments) {
              _attachmentBrowseBloc?.add(AttachmentBrowseInitialised(
                resourceTypes: filters,
                readOnly: true,
                sourceRecords: _allRecords,
              ));
            }
          },
        );
      },
    );
  }

  void _removeFilter(FhirType filter) {
    setState(() => _filterTypes = _filterTypes.where((f) => f != filter).toList());
    if (_viewMode == RecordsViewMode.attachments) {
      _attachmentBrowseBloc?.add(AttachmentBrowseInitialised(
        resourceTypes: _filterTypes,
        readOnly: true,
        sourceRecords: _allRecords,
      ));
    }
  }

  void _clearAllFilters() {
    setState(() => _filterTypes = []);
    if (_viewMode == RecordsViewMode.attachments) {
      _attachmentBrowseBloc?.add(AttachmentBrowseInitialised(
        readOnly: true,
        sourceRecords: _allRecords,
      ));
    }
  }

  @override
  void dispose() {
    _searchFocusNode.removeListener(_onSearchFocusChanged);
    _searchAnimController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _attachmentBrowseBloc?.close();
    ScreenSecurityService.disable();
    super.dispose();
  }

  List<IFhirResource> get _filteredRecords {
    final receivedData = widget.state.receivedData;
    if (receivedData == null) return [];

    var records = receivedData.records;

    if (_filterTypes.isNotEmpty) {
      records = records.where((r) => _filterTypes.contains(r.fhirType)).toList();
    }

    if (_searchQuery.isNotEmpty && _searchQuery.length >= 2) {
      final query = _searchQuery.toLowerCase();
      records = records.where((r) {
        final title = r.title.toLowerCase();
        final displayTitle = r.displayTitle.toLowerCase();
        final statusDisplay = r.statusDisplay.toLowerCase();
        final additionalInfoText = r.additionalInfo
            .map((info) => info.info)
            .join(' ')
            .toLowerCase();

        return title.contains(query) ||
               displayTitle.contains(query) ||
               statusDisplay.contains(query) ||
               additionalInfoText.contains(query);
      }).toList();
    }

    return records;
  }

  @override
  Widget build(BuildContext context) {
    _applyInitialFilters();

    final receivedData = widget.state.receivedData;
    if (receivedData == null) {
      return Center(child: Text(context.l10n.shareNoDataReceived));
    }

    return Column(
      children: [
        Expanded(
          child: _viewMode == RecordsViewMode.attachments
              ? _buildAttachmentsBody(context, receivedData.records)
              : _buildListBody(context),
        ),
        if (!_searchFocusNode.hasFocus)
          SessionBottomBar(
            state: widget.state,
            peerRole: 'sender',
            endSessionEvent: const ShareRecordsEvent.dataDestructionConfirmed(),
            isReceiver: true,
          ),
      ],
    );
  }

  Widget _buildStyledHeader(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _isScrolled,
      builder: (context, isScrolled, _) {
        return Container(
          decoration: BoxDecoration(
            color: context.colorScheme.surface,
            borderRadius: isScrolled
                ? const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  )
                : BorderRadius.zero,
            boxShadow: isScrolled
                ? [
                    BoxShadow(
                      offset: const Offset(0, 4),
                      blurRadius: 12,
                      color: Colors.black.withValues(alpha: 0.15),
                    ),
                  ]
                : [],
          ),
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 8,
              bottom: isScrolled ? 8 : 4,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildToolbar(context),
                _buildActiveFiltersBar(context),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildListBody(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.axis != Axis.vertical) return false;
        final scrolled = notification.metrics.pixels > 0;
        if (scrolled != _isScrolled.value) {
          _isScrolled.value = scrolled;
        }
        return false;
      },
      child: Column(
        children: [
          _buildStyledHeader(context),
          Expanded(
            child: _filteredRecords.isEmpty
                ? _buildEmptyState(context)
                : _buildRecordsList(context),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar(BuildContext context) {
    final iconColor = context.colorScheme.onSurface;

    return SizedBox(
      height: 36,
      child: Row(
        children: [
          Expanded(
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                FadeTransition(
                  opacity: ReverseAnimation(_searchExpandAnimation),
                  child: IgnorePointer(
                    ignoring: _isSearchExpanded,
                    child: RecordsViewToggle(
                      mode: _viewMode,
                      onChanged: (mode) {
                        _isScrolled.value = false;
                        setState(() => _viewMode = mode);
                        if (mode == RecordsViewMode.attachments) {
                          _attachmentBrowseBloc?.add(AttachmentBrowseInitialised(
                            resourceTypes: _filterTypes,
                            readOnly: true,
                            sourceRecords: _allRecords,
                          ));
                        }
                      },
                    ),
                  ),
                ),
                if (_isSearchExpanded)
                  FadeTransition(
                    opacity: _searchExpandAnimation,
                    child: _buildSearchField(context),
                  ),
              ],
            ),
          ),
          if (!_isSearchExpanded) ...[
            GestureDetector(
              onTap: _openSearch,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Assets.icons.search.svg(
                  width: 22,
                  height: 22,
                  colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
                ),
              ),
            ),
            GestureDetector(
              onTap: _showFilterSheet,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Assets.icons.filter.svg(
                  width: 22,
                  height: 22,
                  colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchField(BuildContext context) {
    return SizedBox(
      height: 36,
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        onChanged: _onSearchChanged,
        onSubmitted: (_) => _searchFocusNode.unfocus(),
        style: AppTextStyle.bodyMedium,
        maxLines: 1,
        decoration: InputDecoration(
          isDense: true,
          hintText: context.l10n.shareSearchRecords,
          hintStyle: AppTextStyle.labelLarge.copyWith(
            color: context.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.all(10),
            child: Assets.icons.search.svg(
              width: 16,
              colorFilter: ColorFilter.mode(
                context.colorScheme.onSurface.withValues(alpha: 0.6),
                BlendMode.srcIn,
              ),
            ),
          ),
          suffixIcon: GestureDetector(
            onTap: _handleSearchSuffixTap,
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Icon(
                Icons.close,
                size: 22,
                color: context.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
          suffixIconConstraints: const BoxConstraints(
            minWidth: 38,
            minHeight: 22,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(100),
            borderSide: BorderSide(color: context.theme.dividerColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(100),
            borderSide: BorderSide(color: context.theme.dividerColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(100),
            borderSide: const BorderSide(color: AppColors.primary),
          ),
          filled: true,
          fillColor: context.colorScheme.surface,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 0,
            horizontal: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildActiveFiltersBar(BuildContext context) {
    if (_filterTypes.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.only(top: 4, bottom: _filterTypes.length > 2 ? 4 : 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Wrap(
              spacing: 6.0,
              runSpacing: 6,
              children: _filterTypes.map((filter) => _buildFilterChip(
                context,
                label: filter.display,
                onTap: () => _removeFilter(filter),
              )).toList(),
            ),
          ),
          GestureDetector(
            onTap: _clearAllFilters,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Assets.icons.close.svg(
                width: 18,
                height: 18,
                colorFilter: const ColorFilter.mode(
                  AppColors.primary,
                  BlendMode.srcIn,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    BuildContext context, {
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AppTextStyle.labelSmall.copyWith(color: AppColors.primary),
            ),
            const SizedBox(width: 4),
            Assets.icons.close.svg(
              width: 12,
              height: 12,
              colorFilter: const ColorFilter.mode(
                AppColors.primary,
                BlendMode.srcIn,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentsBody(BuildContext context, List<IFhirResource> records) {
    _ensureAttachmentBrowseBloc(records);

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.axis != Axis.vertical) return false;
        final scrolled = notification.metrics.pixels > 0;
        if (scrolled != _isScrolled.value) {
          _isScrolled.value = scrolled;
        }
        return false;
      },
      child: Column(
        children: [
          _buildStyledHeader(context),
          Expanded(
            child: BlocProvider.value(
              value: _attachmentBrowseBloc!,
              child: const EphemeralAttachmentView(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.folder_open_outlined,
              size: 64,
              color: context.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              _filterTypes.isNotEmpty || _searchQuery.isNotEmpty
                  ? context.l10n.shareNoRecordsMatchFilters
                  : context.l10n.shareNoRecordsAvailable,
              style: AppTextStyle.titleMedium.copyWith(
                color: context.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordsList(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.only(
        top: 8,
        bottom: Insets.small,
      ),
      itemCount: _filteredRecords.length,
      itemBuilder: (context, index) {
        final resource = _filteredRecords[index];
        return TimelineEntry(
          key: ValueKey('viewing-${resource.fhirType}-${resource.id}-$index'),
          isFirst: index == 0,
          isLast: index == _filteredRecords.length - 1,
          onTap: () {
            context.pushRoute(
              RecordDetailsRoute(
                resource: resource,
                ephemeralRecords:
                    widget.state.receivedData?.records ?? const [],
              ),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RecordTypeHeader(
                fhirType: resource.fhirType,
                date: resource.date,
              ),
              const SizedBox(height: Insets.small),
              ResourceCard(
                resource: resource,
                readOnly: true,
                ephemeralRecords: widget.state.receivedData?.records ?? const [],
              ),
            ],
          ),
        );
      },
    );
  }
}
