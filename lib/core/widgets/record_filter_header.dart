import 'package:flutter/material.dart';

import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/records/domain/entity/i_fhir_resource.dart';
import 'package:health_wallet/gen/assets.gen.dart';

class RecordFilterHeader extends StatefulWidget {
  final List<IFhirResource> records;
  final Set<FhirType> initialFilters;
  final bool initiallyExpanded;
  final ValueChanged<Set<FhirType>> onFilterChanged;
  final ValueChanged<String> onSearchChanged;
  final String? hintText;

  const RecordFilterHeader({
    required this.records,
    required this.onFilterChanged,
    required this.onSearchChanged,
    this.initialFilters = const {},
    this.initiallyExpanded = false,
    this.hintText,
    super.key,
  });

  @override
  State<RecordFilterHeader> createState() => RecordFilterHeaderState();
}

class RecordFilterHeaderState extends State<RecordFilterHeader> {
  final TextEditingController _searchController = TextEditingController();
  final Set<FhirType> _filterTypes = {};
  bool _filtersExpanded = false;
  String _searchQuery = '';
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _filtersExpanded = widget.initiallyExpanded;
    if (widget.initialFilters.isNotEmpty) {
      _filterTypes.addAll(widget.initialFilters);
    }
    _initialized = widget.initialFilters.isNotEmpty || widget.records.isNotEmpty;
  }

  @override
  void didUpdateWidget(covariant RecordFilterHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_initialized && widget.initialFilters.isNotEmpty) {
      setState(() {
        _filterTypes.addAll(widget.initialFilters);
        _filtersExpanded = true;
      });
      _initialized = true;
      widget.onFilterChanged(Set.of(_filterTypes));
    }
  }

  Set<FhirType> get _availableTypes =>
      widget.records.map((r) => r.fhirType).toSet();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Widget> buildHeaderChildren() {
    return [
      _buildSearchAndFilterRow(context),
      if (_filtersExpanded && _availableTypes.length > 1)
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Insets.normal,
            Insets.extraSmall,
            Insets.normal,
            Insets.small,
          ),
          child: _buildFilterChips(context),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: buildHeaderChildren(),
    );
  }

  Widget _buildSearchField(BuildContext context) {
    return SizedBox(
      height: 42,
      child: TextField(
        controller: _searchController,
        onChanged: (query) {
          setState(() {
            _searchQuery = query;
          });
          widget.onSearchChanged(query);
        },
        onSubmitted: (_) => FocusScope.of(context).unfocus(),
        style: AppTextStyle.bodyMedium,
        maxLines: 1,
        decoration: InputDecoration(
          isDense: true,
          hintText: widget.hintText ?? context.l10n.searchRecordsHint,
          hintStyle: AppTextStyle.labelLarge.copyWith(
            color: context.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.all(14),
            child: Assets.icons.search.svg(
              width: 16,
              colorFilter: ColorFilter.mode(
                context.colorScheme.onSurface.withValues(alpha: 0.6),
                BlendMode.srcIn,
              ),
            ),
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                    });
                    widget.onSearchChanged('');
                  },
                  icon: Assets.icons.close.svg(
                    width: Insets.normal,
                    height: Insets.normal,
                    colorFilter: ColorFilter.mode(
                      context.colorScheme.onSurface.withValues(alpha: 0.6),
                      BlendMode.srcIn,
                    ),
                  ),
                )
              : null,
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
            vertical: 12,
            horizontal: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildSearchAndFilterRow(BuildContext context) {
    final hasMultipleTypes = _availableTypes.length > 1;
    final activeFilterCount = _filterTypes.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Insets.normal,
        Insets.extraSmall,
        Insets.normal,
        Insets.normal,
      ),
      child: Row(
        children: [
          Expanded(child: _buildSearchField(context)),
          if (hasMultipleTypes) ...[
            const SizedBox(width: Insets.small),
            GestureDetector(
              onTap: () => setState(() => _filtersExpanded = !_filtersExpanded),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: activeFilterCount > 0
                      ? AppColors.primary.withValues(alpha: 0.12)
                      : context.colorScheme.onSurface.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.filter_list,
                      size: 18,
                      color: activeFilterCount > 0
                          ? AppColors.primary
                          : context.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      _filtersExpanded ? Icons.expand_less : Icons.expand_more,
                      size: 18,
                      color: activeFilterCount > 0
                          ? AppColors.primary
                          : context.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterChips(BuildContext context) {
    final sortedTypes = _availableTypes.toList()
      ..sort((a, b) => a.display.compareTo(b.display));

    return Row(
      children: [
        Expanded(
          child: Wrap(
            spacing: 8.0,
            runSpacing: 8.0,
            children: [
              GestureDetector(
                onTap: () {
                  setState(() => _filterTypes.clear());
                  widget.onFilterChanged({});
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  decoration: BoxDecoration(
                    color: _filterTypes.isEmpty
                        ? AppColors.primary.withValues(alpha: 0.12)
                        : context.colorScheme.onSurface.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'All',
                    style: AppTextStyle.labelSmall.copyWith(
                      color: _filterTypes.isEmpty
                          ? AppColors.primary
                          : context.colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
              ...sortedTypes.map((type) {
                final isActive = _filterTypes.contains(type);
                final count =
                    widget.records.where((r) => r.fhirType == type).length;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (isActive) {
                        _filterTypes.remove(type);
                      } else {
                        _filterTypes.add(type);
                      }
                    });
                    widget.onFilterChanged(Set.of(_filterTypes));
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    decoration: BoxDecoration(
                      color: isActive
                          ? AppColors.primary.withValues(alpha: 0.12)
                          : context.colorScheme.onSurface.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        type.icon.svg(
                          width: 14,
                          colorFilter: ColorFilter.mode(
                            isActive
                                ? AppColors.primary
                                : context.colorScheme.onSurface,
                            BlendMode.srcIn,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${type.display} ($count)',
                          style: AppTextStyle.labelSmall.copyWith(
                            color: isActive
                                ? AppColors.primary
                                : context.colorScheme.onSurface,
                          ),
                        ),
                        if (isActive) ...[
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
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
        if (_filterTypes.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _filterTypes.clear();
                  _filtersExpanded = false;
                });
                widget.onFilterChanged({});
              },
              child: Assets.icons.close.svg(
                width: 20,
                height: 20,
                colorFilter: const ColorFilter.mode(
                  AppColors.primary,
                  BlendMode.srcIn,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
