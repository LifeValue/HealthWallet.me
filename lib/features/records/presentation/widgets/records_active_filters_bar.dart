import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/features/home/presentation/bloc/home_bloc.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/records/presentation/bloc/records_bloc.dart';
import 'package:health_wallet/features/records/presentation/widgets/filters/date_range_filter_model.dart';
import 'package:health_wallet/gen/assets.gen.dart';

class RecordsActiveFiltersBar extends StatelessWidget {
  final List<FhirType> activeFilters;
  final DateRangeFilterModel? dateFilter;

  const RecordsActiveFiltersBar({
    required this.activeFilters,
    required this.dateFilter,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final hasTypeFilters = activeFilters.isNotEmpty;
    final hasDateFilter = dateFilter?.hasValue ?? false;

    if (!hasTypeFilters && !hasDateFilter) {
      return const SizedBox();
    }

    return BlocBuilder<HomeBloc, HomeState>(
      buildWhen: (previous, current) =>
          previous.hasDataLoaded != current.hasDataLoaded,
      builder: (context, homeState) {
        if (!homeState.hasDataLoaded) {
          return const SizedBox();
        }

        final List<Widget> allChips = [];

        if (hasDateFilter) {
          allChips.add(
            _buildFilterChip(
              context,
              label: dateFilter!.formatChipLabel(),
              onTap: () => context
                  .read<RecordsBloc>()
                  .add(const RecordsDateRangeCleared()),
            ),
          );
        }

        allChips.addAll(
          activeFilters.map(
            (filter) => _buildFilterChip(
              context,
              label: filter.display,
              onTap: () => context
                  .read<RecordsBloc>()
                  .add(RecordsFilterRemoved(filter)),
            ),
          ),
        );

        return Row(
          children: [
            Expanded(
              child: Wrap(
                spacing: 8.0,
                runSpacing: 8,
                children: allChips,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: GestureDetector(
                onTap: () {
                  context
                      .read<RecordsBloc>()
                      .add(const RecordsFiltersApplied([]));
                  context
                      .read<RecordsBloc>()
                      .add(const RecordsDateRangeCleared());
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
      },
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
        padding: const EdgeInsets.symmetric(
          vertical: 4,
          horizontal: 8,
        ),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AppTextStyle.labelSmall.copyWith(
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 4),
            Assets.icons.close.svg(
              width: 12,
              height: 12,
              colorFilter: const ColorFilter.mode(
                AppColors.primary,
                BlendMode.srcIn,
              ),
            )
          ],
        ),
      ),
    );
  }
}
