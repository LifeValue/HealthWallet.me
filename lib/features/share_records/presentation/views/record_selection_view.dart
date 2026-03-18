import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:health_wallet/core/widgets/animated_sticky_header.dart';
import 'package:health_wallet/core/widgets/custom_arrow_tooltip.dart';
import 'package:health_wallet/core/widgets/record_filter_header.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/records/domain/entity/i_fhir_resource.dart';
import 'package:health_wallet/features/records/presentation/bloc/records_bloc.dart';
import 'package:health_wallet/features/share_records/presentation/bloc/share_records_bloc.dart';
import 'package:health_wallet/features/share_records/presentation/bloc/share_records_state.dart';
import 'package:health_wallet/features/share_records/presentation/widgets/selectable_records_list.dart';
import 'package:health_wallet/features/share_records/presentation/widgets/selection_bottom_bar.dart';

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
  String _searchQuery = '';

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
                      : SelectableRecordsList(
                          filteredRecords: _filteredRecords,
                          shareState: shareState,
                          hasActiveFilters: _filterTypes.isNotEmpty,
                          hasAppliedFilters: widget.appliedFilters?.isNotEmpty ?? false,
                        ),
                ),
              ),
              SelectionBottomBar(
                shareState: shareState,
                filterTypes: _filterTypes,
              ),
            ],
          ),
        );
      },
    );
  }
}
