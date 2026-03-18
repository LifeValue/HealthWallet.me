import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_wallet/core/navigation/app_router.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/core/utils/responsive.dart';
import 'package:health_wallet/core/utils/patient_source_utils.dart';
import 'package:health_wallet/core/widgets/overlay_annotations/overlay_annotations.dart';
import 'package:health_wallet/features/home/core/constants/home_constants.dart';
import 'package:health_wallet/features/home/domain/entities/patient_vitals.dart';
import 'package:health_wallet/features/home/presentation/bloc/home_bloc.dart';
import 'package:health_wallet/features/home/presentation/sections/medical_records_section.dart';
import 'package:health_wallet/features/home/presentation/sections/recent_records_section.dart';
import 'package:health_wallet/features/home/presentation/sections/vitals_section.dart';
import 'package:health_wallet/features/home/presentation/widgets/home_dialog_controller.dart';
import 'package:health_wallet/features/home/presentation/widgets/home_section_header.dart';
import 'package:health_wallet/features/home/presentation/widgets/section_info_modal.dart';
import 'package:health_wallet/features/home/presentation/widgets/source/source_selector_widget.dart';
import 'package:health_wallet/features/records/presentation/bloc/records_bloc.dart';
import 'package:health_wallet/features/user/presentation/preferences_modal/sections/patient/bloc/patient_bloc.dart';

class HomeDashboardSections extends StatelessWidget {
  final HomeState state;
  final bool editMode;
  final HomeHighlightController highlightController;
  final PageController pageController;

  const HomeDashboardSections({
    super.key,
    required this.state,
    required this.editMode,
    required this.highlightController,
    required this.pageController,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;

    return SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: context.screenHorizontalPadding),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          SizedBox(height: context.isTablet ? Insets.normal : Insets.small),
          if (state.hasDataLoaded || editMode)
            _buildVitalsSection(context, colorScheme),
          _buildResponsiveSpacing(context),
          if (state.hasDataLoaded || editMode)
            _buildOverviewSection(context, colorScheme),
          _buildResponsiveSpacing(context),
          if (state.hasDataLoaded || editMode)
            _buildRecentRecordsSection(context, colorScheme),
          const SizedBox(height: HomeConstants.bottomPadding),
        ]),
      ),
    );
  }

  Widget _buildResponsiveSpacing(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height < 700
          ? Insets.medium
          : Insets.large,
    );
  }

  Widget _buildResponsiveSectionSpacing(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height < 700
          ? Insets.small
          : Insets.smallNormal,
    );
  }

  Widget _buildVitalsSection(BuildContext context, ColorScheme colorScheme) {
    return Column(
      children: [
        HomeSectionHeader(
          title: context.l10n.homeVitalSigns,
          filterLabel: editMode ? context.l10n.vitals : null,
          onFilterTap: editMode
              ? () => HomeDialogController.showEditVitalsDialog(
                    context,
                    state,
                    (updated) {
                      context
                          .read<HomeBloc>()
                          .add(HomeVitalsFiltersChanged(updated));
                    },
                  )
              : null,
          colorScheme: colorScheme,
          isEditMode: editMode,
          isFilterDisabled: state.vitalsExpanded,
          onInfoTap: () => SectionInfoModal.show(
            context,
            context.l10n.vitalSigns,
            context.l10n.longPressToReorder,
          ),
        ),
        _buildResponsiveSectionSpacing(context),
        VitalsSection(
          vitals: state.vitalsExpanded
              ? state.allAvailableVitals
              : state.patientVitals,
          allAvailableVitals: state.allAvailableVitals,
          editMode: editMode,
          vitalsExpanded: state.vitalsExpanded,
          firstCardKey: highlightController.firstVitalCardKey,
          selectedVitals: Map.fromEntries(
            state.selectedVitals.entries.map(
              (e) => MapEntry(e.key.title, e.value),
            ),
          ),
          onReorder: (oldIndex, newIndex) {
            context
                .read<HomeBloc>()
                .add(HomeVitalsReordered(oldIndex, newIndex));
          },
          onLongPressCard: () => context
              .read<HomeBloc>()
              .add(const HomeEditModeChanged(true)),
          onExpandToggle: () {
            context.read<HomeBloc>().add(const HomeVitalsExpansionToggled());
          },
        ),
      ],
    );
  }

  Widget _buildOverviewSection(BuildContext context, ColorScheme colorScheme) {
    final filteredCards = state.visibleOverviewCards;

    return Column(
      children: [
        HomeSectionHeader(
          title: context.l10n.overview,
          subtitle: state.sources.isNotEmpty
              ? SourceSelectorWidget(
                  sources: state.sources,
                  selectedSource: state.selectedSource,
                  onSourceChanged: (sourceId, patientSourceIds) {
                    context.read<HomeBloc>().add(HomeSourceChanged(sourceId,
                        patientSourceIds: patientSourceIds));
                  },
                  currentPatient: state.patient,
                  onSourceLabelEdit: (source) {
                    context.read<HomeBloc>().add(
                          HomeSourceLabelUpdated(
                              source.id, source.labelSource ?? ''),
                        );
                  },
                  onSourceDelete: (source) {
                    final patientSourceIds =
                        PatientSourceUtils.getPatientSourceIds(context);
                    final filteredPatientSourceIds = patientSourceIds
                        ?.where((id) => id != source.id)
                        .toList();

                    final patientState = context.read<PatientBloc>().state;
                    final selectedPatientId = patientState.selectedPatientId;

                    context.read<HomeBloc>().add(
                          HomeSourceDeleted(source.id,
                              patientSourceIds: filteredPatientSourceIds),
                        );

                    if (selectedPatientId != null) {
                      context.read<PatientBloc>().add(
                            PatientPatientsLoaded(
                              preserveOrder: true,
                              preservePatientId: selectedPatientId,
                            ),
                          );
                    }
                  },
                )
              : null,
          filterLabel: context.l10n.records,
          onFilterTap: () => HomeDialogController.showEditRecordsDialog(
            context,
            state,
            (newSelection) {
              context
                  .read<HomeBloc>()
                  .add(HomeRecordsFiltersChanged(newSelection));
            },
          ),
          colorScheme: colorScheme,
          isEditMode: editMode,
          onInfoTap: () => SectionInfoModal.show(
            context,
            context.l10n.overview,
            context.l10n.longPressToReorder,
          ),
        ),
        _buildResponsiveSectionSpacing(context),
        MedicalRecordsSection(
          overviewCards: filteredCards,
          editMode: editMode,
          firstCardKey: highlightController.firstOverviewCardKey,
          onLongPressCard: () => context
              .read<HomeBloc>()
              .add(const HomeEditModeChanged(true)),
          onReorder: (oldIndex, newIndex) {
            context
                .read<HomeBloc>()
                .add(HomeRecordsReordered(oldIndex, newIndex));
          },
          onTapCard: (card) {
            context
                .read<RecordsBloc>()
                .add(RecordsFiltersApplied(card.category.resourceTypes));
            pageController.animateToPage(
              1,
              duration: HomeConstants.pageTransitionDuration,
              curve: Curves.ease,
            );
          },
        ),
      ],
    );
  }

  Widget _buildRecentRecordsSection(
      BuildContext context, ColorScheme colorScheme) {
    return Column(
      children: [
        HomeSectionHeader(
          title: context.l10n.recentRecords,
          trailing: TextButton(
            onPressed: () {
              pageController.animateToPage(
                1,
                duration: HomeConstants.pageTransitionDuration,
                curve: Curves.ease,
              );
            },
            style: TextButton.styleFrom(
              foregroundColor: context.colorScheme.primary,
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              context.l10n.viewAll,
              style: AppTextStyle.labelLarge.copyWith(
                color: context.colorScheme.primary,
              ),
            ),
          ),
          colorScheme: colorScheme,
        ),
        _buildResponsiveSectionSpacing(context),
        RecentRecordsSection(
          recentRecords: state.recentRecords,
          onViewAll: () {
            pageController.animateToPage(
              1,
              duration: HomeConstants.pageTransitionDuration,
              curve: Curves.ease,
            );
          },
          onTapRecord: (record) {
            context.router.push(RecordDetailsRoute(resource: record));
          },
        ),
      ],
    );
  }
}
