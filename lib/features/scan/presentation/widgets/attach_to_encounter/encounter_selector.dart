import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/scan/domain/entity/mapping_resources/mapping_encounter.dart';
import 'package:health_wallet/features/scan/domain/entity/staged_resource.dart';
import 'package:health_wallet/features/scan/presentation/widgets/attach_to_encounter/bloc/attach_to_encounter_bloc.dart';
import 'package:health_wallet/features/scan/presentation/widgets/attach_to_encounter/create_encounter_dialog.dart';
import 'package:health_wallet/gen/assets.gen.dart';
import 'package:intl/intl.dart';

class EncounterSelector extends StatefulWidget {
  const EncounterSelector({super.key});

  @override
  State<EncounterSelector> createState() => _EncounterSelectorState();
}

class _EncounterSelectorState extends State<EncounterSelector> {
  final TextEditingController _searchController = TextEditingController();
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _handleCreateEncounter(BuildContext context) async {
    final encounter = await CreateEncounterDialog.show(context);
    if (encounter != null && context.mounted) {
      context.read<AttachToEncounterBloc>().add(
            AttachToEncounterNewEncounterCreated(encounter),
          );
    }
  }

  void _handleSelect(BuildContext context, dynamic encounter) {
    context.read<AttachToEncounterBloc>().add(
          AttachToEncounterSelected(encounter),
        );
  }

  @override
  Widget build(BuildContext context) {
    final textColor =
        context.isDarkMode ? AppColors.textPrimaryDark : AppColors.textPrimary;
    final iconColor = context.isDarkMode
        ? AppColors.textSecondaryDark
        : AppColors.textSecondary;
    final borderColor = context.theme.dividerColor;

    return BlocBuilder<AttachToEncounterBloc, AttachToEncounterState>(
      builder: (context, state) {
        return Column(
          children: [
            SizedBox(
              height: 42,
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  context.read<AttachToEncounterBloc>().add(
                        AttachToEncounterSearchQueryChanged(value),
                      );
                },
                onSubmitted: (_) => FocusScope.of(context).unfocus(),
                style: AppTextStyle.bodyMedium,
                maxLines: 1,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Search encounters...',
                  hintStyle: AppTextStyle.labelLarge.copyWith(
                    color: context.colorScheme.onSurface.withOpacity(0.6),
                  ),
                  prefixIcon: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Assets.icons.search.svg(
                      width: 16,
                      colorFilter: ColorFilter.mode(
                        context.colorScheme.onSurface,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                  suffixIcon: state.searchQuery.isNotEmpty
                      ? IconButton(
                          onPressed: () {
                            _searchController.clear();
                            context.read<AttachToEncounterBloc>().add(
                                  const AttachToEncounterSearchQueryChanged(''),
                                );
                          },
                          icon: Assets.icons.close.svg(
                            width: Insets.normal,
                            height: Insets.normal,
                            colorFilter: ColorFilter.mode(
                              context.colorScheme.onSurface.withOpacity(0.6),
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
            ),
            const SizedBox(height: 24),
            Flexible(
              child: state.status == AttachToEncounterStatus.loading
                  ? Center(
                      child: CircularProgressIndicator(
                        color: context.colorScheme.primary,
                      ),
                    )
                  : state.filteredEncounters.isEmpty &&
                          state.encounter.draft == null
                      ? SingleChildScrollView(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.inbox_outlined,
                                size: 48,
                                color: iconColor,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No encounters found',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: textColor,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Create a new encounter first or select a different patient.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: iconColor,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              _buildCreateEncounterButton(context, borderColor),
                            ],
                          ),
                        )
                      : ListView(shrinkWrap: true, children: [
                          if (state.encounter.draft != null)
                            _buildEncounterCard(
                              state.encounter.draft,
                              state.encounter.mode == ImportMode.createNew,
                              borderColor,
                              textColor,
                              iconColor,
                            ),
                          ...state.existingEncounters.map(
                            (encounter) {
                              final isSelected = state.encounter.mode ==
                                      ImportMode.linkExisting &&
                                  state.encounter.existing?.id == encounter.id;

                              return _buildEncounterCard(
                                encounter,
                                isSelected,
                                borderColor,
                                textColor,
                                iconColor,
                              );
                            },
                          ),
                          if (state.encounter.draft == null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _buildCreateEncounterButton(
                                  context, borderColor),
                            ),
                        ]),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEncounterCard(
    dynamic encounter,
    bool isSelected,
    Color borderColor,
    Color textColor,
    Color iconColor,
  ) {
    String title = '';

    if (encounter is MappingEncounter) {
      title = "New encounter: ${encounter.encounterType.value}";
    } else if (encounter is Encounter) {
      title = encounter.displayTitle;
    } else {
      return const SizedBox();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: BoxBorder.all(
          color: isSelected
              ? context.colorScheme.primary
              : borderColor.withOpacity(0.3),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        onTap: () => _handleSelect(context, encounter),
        child: Row(
          mainAxisSize: MainAxisSize.max,
          children: [
            Container(
              width: 32,
              height: 32,
              padding: const EdgeInsetsGeometry.all(8),
              decoration: BoxDecoration(
                color: isSelected
                    ? context.colorScheme.primaryContainer
                    : context.colorScheme.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Assets.icons.briefcaseProcedures.svg(
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: AppTextStyle.bodySmall.copyWith(color: textColor),
              ),
            ),
            Radio<bool>(
              visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
              value: true,
              groupValue: isSelected,
              onChanged: (_) => _handleSelect(context, encounter),
              activeColor: context.colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateEncounterButton(BuildContext context, Color borderColor) {
    return DottedBorder(
      options: RoundedRectDottedBorderOptions(
        radius: const Radius.circular(8),
        dashPattern: [6, 6],
        color: context.colorScheme.outline.withOpacity(0.2),
      ),
      child: GestureDetector(
        onTap: () => _handleCreateEncounter(context),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add,
                color: context.colorScheme.onSurface,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Create Encounter',
                style: AppTextStyle.bodySmall.copyWith(
                  color: context.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
