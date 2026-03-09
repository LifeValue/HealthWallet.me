import 'package:flutter/material.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/gen/assets.gen.dart';
import 'filters/date_range_filter_model.dart';
import 'filters/date_range_selector.dart';

class RecordsFilterBottomSheet extends StatefulWidget {
  const RecordsFilterBottomSheet({
    required this.activeFilters,
    required this.onApply,
    this.currentDateFilter,
    super.key,
  });

  final List<FhirType> activeFilters;
  final void Function(List<FhirType>, DateFilter?) onApply;
  final DateFilter? currentDateFilter;

  @override
  State<RecordsFilterBottomSheet> createState() =>
      _RecordsFilterBottomSheetState();
}

class _RecordsFilterBottomSheetState extends State<RecordsFilterBottomSheet>
    with SingleTickerProviderStateMixin {
  List<FhirType> _selectedFilters = [];
  late DateRangeFilterModel _dateRangeModel;
  late TabController _tabController;
  final GlobalKey _dateRangeContainerKey = GlobalKey();

  @override
  void initState() {
    _selectedFilters = [...widget.activeFilters];
    final df = widget.currentDateFilter;
    _dateRangeModel = DateRangeFilterModel(
      fromYear: df?.fromYear,
      fromMonth: df?.fromMonth,
      fromDay: df?.fromDay,
      toYear: df?.toYear,
      toMonth: df?.toMonth,
      toDay: df?.toDay,
    );

    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });
    super.initState();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _clampDay({required bool isFrom}) {
    final year = isFrom ? _dateRangeModel.fromYear : _dateRangeModel.toYear;
    final month = isFrom ? _dateRangeModel.fromMonth : _dateRangeModel.toMonth;
    final day = isFrom ? _dateRangeModel.fromDay : _dateRangeModel.toDay;
    if (day == null || month == null) return;
    final maxDay = DateTime(year ?? DateTime.now().year, month + 1, 0).day;
    if (day > maxDay) {
      if (isFrom) {
        _dateRangeModel.fromDay = maxDay;
      } else {
        _dateRangeModel.toDay = maxDay;
      }
    }
  }

  void _toggleFitler(FhirType filter) {
    setState(() {
      if (_selectedFilters.contains(filter)) {
        _selectedFilters.remove(filter);
      } else {
        _selectedFilters.add(filter);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height / 1.12,
      width: MediaQuery.of(context).size.width,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: context.colorScheme.onSurface.withValues(alpha: 0.18),
                    width: 1,
                  ),
                ),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final totalWidth = constraints.maxWidth;
                  final tabWidth = totalWidth / 2;

                  return Stack(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: TabBar(
                                controller: _tabController,
                                indicatorColor: Colors.transparent,
                                labelColor: context.colorScheme.primary,
                                unselectedLabelColor: context.colorScheme.onSurface.withValues(alpha: 0.6),
                                labelStyle: AppTextStyle.bodyMedium,
                                unselectedLabelStyle: AppTextStyle.bodyMedium,
                                dividerColor: Colors.transparent,
                                tabs: const [
                                  Tab(text: "Filters"),
                                  Tab(text: "Time Range"),
                                ],
                              ),
                            ),
                            IconButton(
                              iconSize: 18,
                              visualDensity:
                                  const VisualDensity(horizontal: -4, vertical: -4),
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.close),
                            )
                          ],
                        ),
                      ),
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 200),
                        bottom: 0,
                        left: _tabController.index == 0 ? 16 : tabWidth + 16,
                        right: _tabController.index == 0 ? tabWidth + 16 : 0,
                        child: Container(
                          height: 2,
                          color: context.colorScheme.primary,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildFiltersTab(context),
                  _buildTimeRangeTab(context),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: context.colorScheme.onSurface.withValues(alpha: 0.18),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Text(
                        "Cancel",
                        style: AppTextStyle.buttonMedium.copyWith(
                          color: context.colorScheme.primary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.colorScheme.primary,
                        foregroundColor: context.isDarkMode
                            ? Colors.white
                            : context.colorScheme.onPrimary,
                        padding: const EdgeInsets.all(10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadiusGeometry.circular(6)),
                      ),
                      onPressed: () {
                        final dateFilter = _dateRangeModel.hasValue
                            ? DateFilter(
                                fromYear: _dateRangeModel.fromYear,
                                fromMonth: _dateRangeModel.fromMonth,
                                fromDay: _dateRangeModel.fromDay,
                                toYear: _dateRangeModel.toYear,
                                toMonth: _dateRangeModel.toMonth,
                                toDay: _dateRangeModel.toDay,
                              )
                            : null;

                        final validationError = dateFilter?.validate();
                        if (validationError != null) {
                          return;
                        }

                        widget.onApply.call(_selectedFilters, dateFilter);
                        Navigator.of(context).pop();
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Assets.icons.checkmarkCircleOutline.svg(
                            width: 14,
                            colorFilter: const ColorFilter.mode(
                              Colors.white,
                              BlendMode.srcIn,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Text("Apply filters",
                              style: AppTextStyle.buttonMedium),
                        ],
                      ),
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

  Widget _buildFiltersTab(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        shrinkWrap: true,
        children: [
          Text(
            "Record type",
            style: AppTextStyle.buttonSmall.copyWith(
              color: context.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: FhirType.values.map((filter) {
              final isSelected = _selectedFilters.contains(filter);
              return GestureDetector(
                onTap: () => _toggleFitler(filter),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  width: MediaQuery.sizeOf(context).width,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? context.colorScheme.primary.withValues(alpha: 0.12)
                        : context.colorScheme.surface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(filter.display,
                      style: AppTextStyle.labelLarge.copyWith(
                        color: isSelected
                            ? context.colorScheme.primary
                            : context.colorScheme.onSurface,
                      )),
                ),
              );
            }).toList(),
          )
        ],
      ),
    );
  }

  Widget _buildTimeRangeTab(BuildContext context) {
    final currentFilter = _dateRangeModel.hasValue
        ? DateFilter(
            fromYear: _dateRangeModel.fromYear,
            fromMonth: _dateRangeModel.fromMonth,
            fromDay: _dateRangeModel.fromDay,
            toYear: _dateRangeModel.toYear,
            toMonth: _dateRangeModel.toMonth,
            toDay: _dateRangeModel.toDay,
          )
        : null;
    final validationError = currentFilter?.validate();
    final rangePreview = _buildDateRangePreview();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _dateRangeModel.hasValue
                  ? context.colorScheme.primary.withValues(alpha: 0.08)
                  : context.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _dateRangeModel.hasValue
                    ? context.colorScheme.primary.withValues(alpha: 0.2)
                    : context.colorScheme.onSurface.withValues(alpha: 0.15),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Selected Range',
                  style: AppTextStyle.labelSmall.copyWith(
                    color: context.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  rangePreview ?? 'No range selected',
                  style: AppTextStyle.titleSmall.copyWith(
                    color: rangePreview != null
                        ? context.colorScheme.primary
                        : context.colorScheme.onSurface.withValues(alpha: 0.4),
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            key: _dateRangeContainerKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DateRangeSelector(
                  label: 'Start',
                  icon: Assets.icons.calendar,
                  containerKey: _dateRangeContainerKey,
                  year: _dateRangeModel.fromYear,
                  month: _dateRangeModel.fromMonth,
                  day: _dateRangeModel.fromDay,
                  onYearChanged: (value) {
                    setState(() {
                      _dateRangeModel.fromYear = value;
                      _clampDay(isFrom: true);
                    });
                  },
                  onMonthChanged: (value) {
                    setState(() {
                      _dateRangeModel.fromMonth = value;
                      _clampDay(isFrom: true);
                    });
                  },
                  onDayChanged: (value) {
                    setState(() {
                      _dateRangeModel.fromDay = value;
                    });
                  },
                ),
                const SizedBox(height: 24),
                DateRangeSelector(
                  label: 'End',
                  icon: Assets.icons.calendar,
                  containerKey: _dateRangeContainerKey,
                  openUpward: true,
                  year: _dateRangeModel.toYear,
                  month: _dateRangeModel.toMonth,
                  day: _dateRangeModel.toDay,
                  onYearChanged: (value) {
                    setState(() {
                      _dateRangeModel.toYear = value;
                      _clampDay(isFrom: false);
                    });
                  },
                  onMonthChanged: (value) {
                    setState(() {
                      _dateRangeModel.toMonth = value;
                      _clampDay(isFrom: false);
                    });
                  },
                  onDayChanged: (value) {
                    setState(() {
                      _dateRangeModel.toDay = value;
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _dateRangeModel.hasValue
                ? () {
                    setState(() {
                      _dateRangeModel.clear();
                    });
                  }
                : null,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _dateRangeModel.hasValue
                      ? context.colorScheme.error
                      : context.colorScheme.onSurface.withValues(alpha: 0.1),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.close,
                    size: 18,
                    color: _dateRangeModel.hasValue
                        ? context.colorScheme.error
                        : context.colorScheme.onSurface.withValues(alpha: 0.3),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Clear data range',
                    style: AppTextStyle.labelLarge.copyWith(
                      color: _dateRangeModel.hasValue
                          ? context.colorScheme.error
                          : context.colorScheme.onSurface.withValues(alpha: 0.3),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (validationError != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.colorScheme.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: context.colorScheme.error.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 18,
                    color: context.colorScheme.error,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      validationError,
                      style: AppTextStyle.bodySmall.copyWith(
                        color: context.colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String? _buildDateRangePreview() {
    if (!_dateRangeModel.hasValue) return null;

    final fromYear = _dateRangeModel.fromYear;
    final fromMonth = _dateRangeModel.fromMonth;
    final fromDay = _dateRangeModel.fromDay;
    final toYear = _dateRangeModel.toYear;
    final toMonth = _dateRangeModel.toMonth;
    final toDay = _dateRangeModel.toDay;

    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];

    String formatDate(int? year, int? month, int? day) {
      final parts = <String>[];
      if (day != null) parts.add('$day');
      if (month != null) parts.add(months[month - 1]);
      if (year != null) parts.add('$year');
      return parts.join(' ');
    }

    final start = formatDate(fromYear, fromMonth, fromDay);
    final end = formatDate(toYear, toMonth, toDay);

    if (start.isNotEmpty && end.isNotEmpty) {
      return '$start - $end';
    } else if (start.isNotEmpty) {
      return 'From $start';
    } else if (end.isNotEmpty) {
      return 'Until $end';
    }

    return null;
  }
}
