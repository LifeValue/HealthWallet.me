import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_wallet/core/navigation/app_router.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/core/utils/responsive.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/records/presentation/bloc/records_bloc.dart';
import 'package:health_wallet/features/records/presentation/widgets/fhir_cards/resource_card.dart';
import 'package:health_wallet/features/records/presentation/widgets/record_type_header.dart';
import 'package:health_wallet/features/records/presentation/widgets/timeline_entry.dart';
import 'package:health_wallet/features/sync/presentation/widgets/sync_placeholder_widget.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/l10n/l10n.dart';

class RecordsListBody extends StatelessWidget {
  final RecordsState state;
  final List<IFhirResource> resources;
  final ScrollController scrollController;
  final PageController? pageController;
  final VoidCallback? onImportDocument;
  final VoidCallback? onPickImage;
  final VoidCallback? onScanDocument;

  const RecordsListBody({
    super.key,
    required this.state,
    required this.resources,
    required this.scrollController,
    this.pageController,
    this.onImportDocument,
    this.onPickImage,
    this.onScanDocument,
  });

  @override
  Widget build(BuildContext context) {
    if (resources.isEmpty) {
      return _buildEmptyState(context);
    }
    return _buildList(context);
  }

  Widget _buildEmptyState(BuildContext context) {
    if (state.searchQuery.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.search_off,
                size: 64,
                color: context.colorScheme.onSurface.withOpacity(0.4),
              ),
              const SizedBox(height: 16),
              Text(
                context.l10n.noRecordsFound,
                style: AppTextStyle.titleMedium.copyWith(
                  color: context.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.tryDifferentKeywords,
                style: AppTextStyle.bodyMedium.copyWith(
                  color: context.colorScheme.onSurface.withOpacity(0.6),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        const double bottomNavBarSpacing = 100.0;

        final placeholder = SyncPlaceholderWidget(
          pageController: pageController,
          recordTypeName: state.activeFilters.isNotEmpty
              ? state.activeFilters.length == 1
                  ? state.activeFilters.first.display
                  : state.activeFilters
                      .map((f) => f.display)
                      .join(', ')
              : null,
          onImportDocument: onImportDocument,
          onPickImage: onPickImage,
          onScanDocument: onScanDocument,
        );

        return SingleChildScrollView(
          controller: scrollController,
          physics: const ClampingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight,
            ),
            child: Padding(
              padding: const EdgeInsets.only(
                bottom: bottomNavBarSpacing,
              ),
              child: context.isTablet
                  ? Align(
                      alignment: const Alignment(0, -0.3),
                      child: placeholder,
                    )
                  : IntrinsicHeight(child: placeholder),
            ),
          ),
        );
      },
    );
  }

  Widget _buildList(BuildContext context) {
    const double bottomBarHeight = Insets.extraLarge;
    const double bottomBarOffset = Insets.medium;
    const double extraSpacing = Insets.large;
    final double bottomSafeInset = MediaQuery.of(context).padding.bottom;

    return ListView.builder(
      controller: scrollController,
      padding: EdgeInsets.only(
        top: 8,
        bottom: bottomSafeInset +
            bottomBarHeight +
            bottomBarOffset +
            extraSpacing,
      ),
      itemCount: resources.length + (state.hasMorePages ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == resources.length) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Center(
              child: CircularProgressIndicator(
                strokeWidth: 4,
                color: context.colorScheme.primary,
              ),
            ),
          );
        }

        final resource = resources[index];
        return TimelineEntry(
          key: ValueKey(
              'timeline-${resource.fhirType}-${resource.id}-$index'),
          isFirst: index == 0,
          isLast: index == resources.length - 1,
          isSelected: state.selectedResourceIds.contains(resource.id),
          isSelectionMode: state.isSelectionMode,
          onTap: () {
            if (state.isSelectionMode) {
              context.read<RecordsBloc>().add(
                    RecordsSelectionToggled(resource.id),
                  );
            } else {
              context.router.push(
                RecordDetailsRoute(resource: resource),
              );
            }
          },
          onLongPress: state.isSelectionMode
              ? null
              : () {
                  final bloc = context.read<RecordsBloc>();
                  bloc.add(const RecordsSelectionModeToggled());
                  bloc.add(RecordsSelectionToggled(resource.id));
                },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RecordTypeHeader(
                fhirType: resource.fhirType,
                date: resource.date,
                onTypeTap: state.isSelectionMode
                    ? null
                    : () {
                        context.read<RecordsBloc>().add(
                              RecordsFiltersApplied([resource.fhirType]),
                            );
                      },
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
