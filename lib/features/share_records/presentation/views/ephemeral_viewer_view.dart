import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

import 'package:health_wallet/core/navigation/app_router.dart';
import 'package:health_wallet/core/services/screen_security_service.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/core/widgets/animated_sticky_header.dart';
import 'package:health_wallet/core/widgets/record_filter_header.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/records/domain/entity/i_fhir_resource.dart';
import 'package:health_wallet/features/records/presentation/widgets/record_type_header.dart';
import 'package:health_wallet/features/records/presentation/widgets/fhir_cards/resource_card.dart';
import 'package:health_wallet/features/records/presentation/widgets/timeline_entry.dart';
import 'package:health_wallet/features/share_records/presentation/bloc/share_records_event.dart';
import 'package:health_wallet/features/share_records/presentation/bloc/share_records_state.dart';
import 'package:health_wallet/features/share_records/presentation/widgets/session/session_bottom_bar.dart';

class EphemeralViewerView extends StatefulWidget {
  final ShareRecordsState state;

  const EphemeralViewerView({super.key, required this.state});

  @override
  State<EphemeralViewerView> createState() => _EphemeralViewerViewState();
}

class _EphemeralViewerViewState extends State<EphemeralViewerView> {
  final Set<FhirType> _filterTypes = {};
  String _searchQuery = '';
  bool _filtersInitialized = false;
  Set<FhirType> _initialFilters = {};

  @override
  void initState() {
    super.initState();
    ScreenSecurityService.enable();
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
          .toSet();

      if (resolved.isNotEmpty) {
        setState(() {
          _filterTypes.addAll(resolved);
          _initialFilters = Set.of(resolved);
        });
      }
    }
    _filtersInitialized = true;
  }

  @override
  void dispose() {
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
      return const Center(child: Text('No data received'));
    }

    return Column(
      children: [
        Expanded(
          child: AnimatedStickyHeader(
            padding: EdgeInsets.zero,
            children: [
              RecordFilterHeader(
                records: receivedData.records,
                initialFilters: _initialFilters,
                initiallyExpanded: _initialFilters.isNotEmpty,
                hintText: 'Search records',
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
            body: _filteredRecords.isEmpty
                ? _buildEmptyState(context)
                : _buildRecordsList(context),
          ),
        ),
        SessionBottomBar(
          state: widget.state,
          peerRole: 'sender',
          endSessionEvent: const ShareRecordsEvent.dataDestructionConfirmed(),
          isReceiver: true,
        ),
      ],
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
                  ? 'No records match the filters'
                  : 'No records available',
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
