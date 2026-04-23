import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/features/home/presentation/bloc/home_bloc.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/records/presentation/bloc/records_bloc.dart';
import 'package:health_wallet/features/records/domain/entity/date_filter/date_filter.dart';
import 'package:health_wallet/gen/assets.gen.dart';

class RecordsActiveFiltersBar extends StatelessWidget {
  final List<FhirType> activeFilters;
  final DateFilter? dateFilter;

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

        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 6.0,
                  runSpacing: 6,
                  children: allChips,
                ),
              ),
              GestureDetector(
                onTap: () {
                  context
                      .read<RecordsBloc>()
                      .add(const RecordsFiltersApplied([]));
                  context
                      .read<RecordsBloc>()
                      .add(const RecordsDateRangeCleared());
                },
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Assets.icons.close.svg(
                    width: 22,
                    height: 22,
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
          vertical: 2,
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
