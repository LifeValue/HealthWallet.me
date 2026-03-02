import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/core/widgets/animated_sticky_header.dart';
import 'package:health_wallet/core/widgets/custom_arrow_tooltip.dart';
import 'package:health_wallet/core/widgets/record_filter_header.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/records/domain/entity/i_fhir_resource.dart';
import 'package:health_wallet/features/records/presentation/bloc/records_bloc.dart';
import 'package:health_wallet/features/records/presentation/widgets/record_type_header.dart';
import 'package:health_wallet/features/records/presentation/widgets/fhir_cards/resource_card.dart';
import 'package:health_wallet/features/records/presentation/widgets/timeline_entry.dart';
import 'package:health_wallet/features/share_records/presentation/bloc/share_records_bloc.dart';
import 'package:health_wallet/features/share_records/presentation/bloc/share_records_event.dart';
import 'package:health_wallet/features/share_records/presentation/bloc/share_records_state.dart';
import 'package:health_wallet/features/share_records/presentation/widgets/duration_wheel_picker.dart';
import 'package:health_wallet/core/widgets/app_button.dart';
import 'package:health_wallet/gen/assets.gen.dart';

class RecordSelectionView extends StatefulWidget {
  final List<FhirType>? appliedFilters;
  final List<IFhirResource>? preSelectedResources;

  const RecordSelectionView({
    super.key,
    this.appliedFilters,
    this.preSelectedResources,
  });

  @override
  State<RecordSelectionView> createState() => _RecordSelectionViewState();
}

class _RecordSelectionViewState extends State<RecordSelectionView> {
  List<IFhirResource> _allRecords = [];
  final Set<FhirType> _filterTypes = {};
  bool _isLoading = true;
  bool _isDurationPickerExpanded = false;
  String _searchQuery = '';
  final GlobalKey _infoIconKey = GlobalKey();
  FixedExtentScrollController? _hoursController;
  FixedExtentScrollController? _minutesController;

  @override
  void initState() {
    super.initState();
    context
        .read<RecordsBloc>()
        .add(const RecordsInitialised(isShareContext: true));
    _loadRecords();
    if (widget.appliedFilters != null && widget.appliedFilters!.isNotEmpty) {
      _filterTypes.addAll(widget.appliedFilters!);
    }
  }

  void _loadRecords() {
    try {
      if (widget.preSelectedResources != null) {
        setState(() {
          _allRecords = widget.preSelectedResources!;
          _isLoading = false;
        });
      } else {
        final recordsBloc = context.read<RecordsBloc>();
        final records = recordsBloc.state.resources;
        setState(() {
          _allRecords = records;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<IFhirResource> get _filteredRecords {
    var records = _allRecords;

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
  void dispose() {
    _hoursController?.dispose();
    _minutesController?.dispose();
    CustomArrowTooltip.dismiss();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ShareRecordsBloc, ShareRecordsState>(
      builder: (context, shareState) {
        return BlocListener<RecordsBloc, RecordsState>(
          listener: (context, recordsState) {
            if (widget.preSelectedResources == null &&
                recordsState.resources != _allRecords) {
              setState(() {
                _allRecords = recordsState.resources;
                _isLoading =
                    recordsState.status == const RecordsStatus.loading();
              });
            }
          },
          child: Column(
            children: [
              Expanded(
                child: AnimatedStickyHeader(
                  padding: EdgeInsets.zero,
                  children: [
                    RecordFilterHeader(
                      records: _allRecords,
                      initialFilters: _filterTypes,
                      initiallyExpanded: _filterTypes.isNotEmpty,
                      onFilterChanged: (filters) {
                        setState(() {
                          _filterTypes
                            ..clear()
                            ..addAll(filters);
                        });
                      },
                      onSearchChanged: (query) {
                        setState(() {
                          _searchQuery = query;
                        });
                      },
                    ),
                  ],
                  body: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _filteredRecords.isEmpty
                          ? _buildEmptyState(context)
                          : _buildRecordList(context, shareState),
                ),
              ),
              _buildBottomBar(context, shareState),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSelectionHeader(BuildContext context, ShareRecordsState state) {
    final count = state.selection.totalCount;
    final allSelected = _filteredRecords.isNotEmpty &&
        _filteredRecords.every((r) => state.selection.isSelected(r.id));
    final hasSelection = state.selection.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Insets.normal,
        Insets.normal,
        Insets.normal,
        Insets.normal,
      ),
      child: Row(
        children: [
          if (hasSelection)
            GestureDetector(
              onTap: () {
                context.read<ShareRecordsBloc>().add(
                      const ShareRecordsEvent.allRecordsDeselected(),
                    );
              },
              child: Assets.icons.close.svg(
                width: 18,
                height: 18,
                colorFilter: ColorFilter.mode(
                  context.colorScheme.onSurface.withValues(alpha: 0.6),
                  BlendMode.srcIn,
                ),
              ),
            ),
          if (hasSelection) const SizedBox(width: Insets.small),
          Text(
            '$count selected',
            style: AppTextStyle.labelLarge.copyWith(
              color: context.colorScheme.onSurface,
            ),
          ),
          const Spacer(),
          GestureDetector(
            key: _infoIconKey,
            onTap: () {
              CustomArrowTooltip.show(
                context: context,
                buttonKey: _infoIconKey,
                message: 'VIEW ONLY - Data will be deleted when you close the session or leave proximity area',
                backgroundColor: const Color(0xFFE37A3C),
                alignment: TooltipAlignment.alignRight,
                width: 240,
              );
            },
            child: Assets.icons.information.svg(
              width: 16,
              height: 16,
              colorFilter: ColorFilter.mode(
                context.colorScheme.onSurface.withValues(alpha: 0.6),
                BlendMode.srcIn,
              ),
            ),
          ),
          const SizedBox(width: Insets.small),
          if (!allSelected)
            TextButton(
              onPressed: () {
                context.read<ShareRecordsBloc>().add(
                      ShareRecordsEvent.allRecordsSelected(_filteredRecords),
                    );
              },
              style: TextButton.styleFrom(
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(
                  horizontal: Insets.small,
                  vertical: Insets.extraSmall,
                ),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Select All'),
            ),
          if (hasSelection)
            TextButton(
              onPressed: () {
                context.read<ShareRecordsBloc>().add(
                      const ShareRecordsEvent.allRecordsDeselected(),
                    );
              },
              style: TextButton.styleFrom(
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(
                  horizontal: Insets.small,
                  vertical: Insets.extraSmall,
                ),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Clear'),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final hasAppliedFilters = widget.appliedFilters?.isNotEmpty ?? false;

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
              _filterTypes.isNotEmpty
                  ? 'No records match the selected filters'
                  : hasAppliedFilters
                      ? 'No records found for the applied filters'
                      : 'No records available',
              style: AppTextStyle.titleMedium.copyWith(
                color: context.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _filterTypes.isNotEmpty
                  ? 'Try clearing some filters'
                  : hasAppliedFilters
                      ? 'The Records page filters returned no results'
                      : 'Import or sync records to share them',
              style: AppTextStyle.bodyMedium.copyWith(
                color: context.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordList(BuildContext context, ShareRecordsState state) {
    return ListView.builder(
      padding: const EdgeInsets.only(
        top: 8,
        bottom: Insets.small,
      ),
      itemCount: _filteredRecords.length,
      itemBuilder: (context, index) {
        final resource = _filteredRecords[index];
        final isSelected = state.selection.isSelected(resource.id);
        return TimelineEntry(
          isFirst: index == 0,
          isLast: index == _filteredRecords.length - 1,
          isSelected: isSelected,
          onTap: () {
            context.read<ShareRecordsBloc>().add(
                  ShareRecordsEvent.recordToggled(resource),
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
              ResourceCard(resource: resource),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBottomBar(BuildContext context, ShareRecordsState state) {
    final selectedCount = state.selection.totalCount;
    final canContinue = selectedCount > 0;

    return Container(
      decoration: BoxDecoration(
        color: context.colorScheme.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, -4),
            blurRadius: 12,
            color: Colors.black.withValues(alpha: 0.15),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BlocBuilder<ShareRecordsBloc, ShareRecordsState>(
              builder: (context, state) {
                final duration = state.selectedViewingDuration;
                final hours = duration.inHours;
                final minutes = duration.inMinutes % 60;
                final isDefaultDuration = state.isDefaultDuration;
                final isZeroDuration = duration == Duration.zero;

                String durationText;
                if (hours > 0) {
                  if (minutes > 0) {
                    durationText = '${hours}h ${minutes} min';
                  } else {
                    durationText = '${hours}h';
                  }
                } else {
                  durationText = '$minutes min';
                }

                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _isDurationPickerExpanded = !_isDurationPickerExpanded),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Insets.normal,
                      vertical: Insets.small,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Session time',
                              style: AppTextStyle.bodyMedium.copyWith(
                                color: context.colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ),
                        Visibility(
                          visible: !isDefaultDuration,
                          maintainSize: true,
                          maintainAnimation: true,
                          maintainState: true,
                          child: AppButton(
                            onPressed: isZeroDuration
                                ? null
                                : () {
                                    context.read<ShareRecordsBloc>().add(
                                          const ShareRecordsEvent.defaultViewingDurationSet(),
                                        );
                                    setState(() {
                                      _isDurationPickerExpanded = false;
                                    });
                                  },
                            label: 'Set as default',
                            variant: AppButtonVariant.transparent,
                            fullWidth: false,
                            fontSize: 14,
                            padding: const EdgeInsets.symmetric(
                              horizontal: Insets.extraSmall,
                              vertical: 0,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.timer_outlined,
                                  size: 16,
                                  color: context.colorScheme.onSurface,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  durationText,
                                  style: AppTextStyle.bodyMedium.copyWith(
                                    color: context.colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  _isDurationPickerExpanded ? Icons.expand_less : Icons.expand_more,
                                  size: 20,
                                  color: context.colorScheme.onSurface,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            if (_isDurationPickerExpanded)
              _buildDurationPicker(context, state),
            Padding(
              padding: const EdgeInsets.fromLTRB(Insets.normal, Insets.small, Insets.normal, Insets.normal),
              child: AppButton(
                onPressed: canContinue
                    ? () {
                        if (_filterTypes.isNotEmpty) {
                          context.read<ShareRecordsBloc>().add(
                                ShareRecordsEvent.filtersApplied(
                                  _filterTypes.toList(),
                                ),
                              );
                        }
                        context.read<ShareRecordsBloc>().add(
                              const ShareRecordsEvent.selectionConfirmed(),
                            );
                      }
                    : null,
                label: canContinue ? 'Share Records' : 'Select records to share',
              ),
            ),
          ],
        ),
      ),
    );
  }

  FixedExtentScrollController _getHoursController(int hours) {
    final items = <int>[0, 1, 2, 3];
    final index = items.indexOf(hours);
    if (_hoursController == null) {
      _hoursController = FixedExtentScrollController(
        initialItem: index >= 0 ? index : 0,
      );
    }
    return _hoursController!;
  }

  FixedExtentScrollController _getMinutesController(int minutes) {
    final items = <int>[];
    for (int i = 0; i <= 59; i += 5) {
      items.add(i);
    }
    final index = items.indexOf(minutes);
    if (_minutesController == null) {
      _minutesController = FixedExtentScrollController(
        initialItem: index >= 0 ? index : 0,
      );
    }
    return _minutesController!;
  }

  Widget _buildDurationPicker(BuildContext context, ShareRecordsState state) {
    return Container(
      height: 160,
      padding: const EdgeInsets.symmetric(vertical: Insets.extraSmall),
      child: BlocBuilder<ShareRecordsBloc, ShareRecordsState>(
        builder: (context, state) {
          final currentDuration = state.selectedViewingDuration;
          final hours = currentDuration.inHours;
          final minutes = currentDuration.inMinutes % 60;

          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 100,
                child: _buildScrollWheel(
                  context: context,
                  controller: _getHoursController(hours),
                  label: 'hours',
                  maxValue: 3,
                  currentValue: hours,
                  onChanged: (newHours) {
                    var newDuration = Duration(hours: newHours, minutes: minutes);
                    if (newDuration == Duration.zero) {
                      newDuration = const Duration(minutes: 5);
                      _minutesController?.animateToItem(
                        1,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      );
                    }
                    context.read<ShareRecordsBloc>().add(
                          ShareRecordsEvent.viewingDurationChanged(newDuration),
                        );
                  },
                ),
              ),
              const SizedBox(width: 20),
              SizedBox(
                width: 100,
                child: _buildScrollWheel(
                  context: context,
                  controller: _getMinutesController(minutes),
                  label: 'min',
                  maxValue: 59,
                  step: 5,
                  currentValue: minutes,
                  onChanged: (newMinutes) {
                    var newDuration = Duration(hours: hours, minutes: newMinutes);
                    if (newDuration == Duration.zero) {
                      newDuration = const Duration(minutes: 5);
                      _minutesController?.animateToItem(
                        1,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      );
                    }
                    context.read<ShareRecordsBloc>().add(
                          ShareRecordsEvent.viewingDurationChanged(newDuration),
                        );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildScrollWheel({
    required BuildContext context,
    required FixedExtentScrollController controller,
    required String label,
    required int maxValue,
    required int currentValue,
    required Function(int) onChanged,
    int step = 1,
  }) {
    final items = <int>[];
    for (int i = 0; i <= maxValue; i += step) {
      items.add(i);
    }

    return Column(
      children: [
        Expanded(
          child: ListWheelScrollView.useDelegate(
            controller: controller,
            itemExtent: 50,
            perspective: 0.005,
            diameterRatio: 1.2,
            physics: const FixedExtentScrollPhysics(),
            onSelectedItemChanged: (index) {
              onChanged(items[index]);
            },
            childDelegate: ListWheelChildBuilderDelegate(
              builder: (context, index) {
                if (index < 0 || index >= items.length) return null;
                final value = items[index];
                final isSelected = value == currentValue;
                return Center(
                  child: Text(
                    '$value $label',
                    style: AppTextStyle.titleMedium.copyWith(
                      color: isSelected
                          ? context.colorScheme.onSurface
                          : context.colorScheme.onSurface.withValues(alpha: 0.4),
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                );
              },
              childCount: items.length,
            ),
          ),
        ),
      ],
    );
  }
}
