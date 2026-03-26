import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/records/domain/entity/i_fhir_resource.dart';
import 'package:health_wallet/features/records/presentation/widgets/record_type_header.dart';
import 'package:health_wallet/features/records/presentation/widgets/fhir_cards/resource_card.dart';
import 'package:health_wallet/features/records/presentation/widgets/timeline_entry.dart';
import 'package:health_wallet/features/share_records/presentation/bloc/share_records_bloc.dart';
import 'package:health_wallet/features/share_records/presentation/bloc/share_records_event.dart';
import 'package:health_wallet/features/share_records/presentation/bloc/share_records_state.dart';

class SelectableRecordsList extends StatelessWidget {
  final List<IFhirResource> filteredRecords;
  final ShareRecordsState shareState;
  final bool hasActiveFilters;
  final bool hasAppliedFilters;

  const SelectableRecordsList({
    super.key,
    required this.filteredRecords,
    required this.shareState,
    required this.hasActiveFilters,
    required this.hasAppliedFilters,
  });

  @override
  Widget build(BuildContext context) {
    if (filteredRecords.isEmpty) {
      return _buildEmptyState(context);
    }
    return _buildRecordList(context);
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
              hasActiveFilters
                  ? context.l10n.shareNoRecordsMatchSelectedFilters
                  : hasAppliedFilters
                      ? context.l10n.shareNoRecordsForAppliedFilters
                      : context.l10n.shareNoRecordsAvailable,
              style: AppTextStyle.titleMedium.copyWith(
                color: context.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              hasActiveFilters
                  ? context.l10n.shareTryClearingFilters
                  : hasAppliedFilters
                      ? context.l10n.shareRecordsPageFiltersNoResults
                      : context.l10n.shareImportOrSyncRecords,
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

  Widget _buildRecordList(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.only(
        top: 8,
        bottom: Insets.small,
      ),
      itemCount: filteredRecords.length,
      itemBuilder: (context, index) {
        final resource = filteredRecords[index];
        final isSelected = shareState.selection.isSelected(resource.id);
        return TimelineEntry(
          isFirst: index == 0,
          isLast: index == filteredRecords.length - 1,
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
}
