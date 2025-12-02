import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/scan/domain/entity/mapping_resources/mapping_encounter.dart';
import 'package:health_wallet/features/scan/domain/entity/mapping_resources/mapping_patient.dart';
import 'package:health_wallet/features/scan/presentation/widgets/attach_to_encounter/bloc/attach_to_encounter_bloc.dart';
import 'package:health_wallet/features/scan/presentation/widgets/attach_to_encounter/create_encounter_dialog.dart';
import 'package:health_wallet/features/scan/presentation/widgets/patient_selector.dart';
import 'package:health_wallet/gen/assets.gen.dart';
import 'package:intl/intl.dart';

typedef AttachToEncounterResult = (Patient, Encounter);

class AttachToEncounterWidget extends StatelessWidget {
  const AttachToEncounterWidget({
    this.newPatient,
    this.newEncounter,
    super.key,
  });

  final MappingPatient? newPatient;
  final MappingEncounter? newEncounter;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => getIt<AttachToEncounterBloc>()
        ..add(AttachToEncounterStarted(
          newPatient: newPatient,
          newEncounter: newEncounter,
        )),
      child: const _AttachToEncounterView(),
    );
  }
}

class _AttachToEncounterView extends StatefulWidget {
  const _AttachToEncounterView();

  @override
  State<_AttachToEncounterView> createState() => _AttachToEncounterViewState();
}

class _AttachToEncounterViewState extends State<_AttachToEncounterView> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _handleCancel() {
    Navigator.of(context).pop();
  }

  void _handleSelect(BuildContext context, Encounter encounter) {
    context.read<AttachToEncounterBloc>().add(
          AttachToEncounterSelected(encounter),
        );
  }

  void _handleDone(
    BuildContext context,
    Patient selectedPatient,
    Encounter selectedEncounter,
  ) {
    Navigator.of(context)
        .pop<AttachToEncounterResult>((selectedPatient, selectedEncounter));
  }

  Future<void> _handleCreateEncounter(BuildContext context) async {
    final newEncounter = await CreateEncounterDialog.show(context);
    if (newEncounter != null && context.mounted) {
      context.read<AttachToEncounterBloc>().add(
            AttachToEncounterNewEncounterCreated(newEncounter),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = context.theme.dividerColor;
    final textColor =
        context.isDarkMode ? AppColors.textPrimaryDark : AppColors.textPrimary;
    final iconColor = context.isDarkMode
        ? AppColors.textSecondaryDark
        : AppColors.textSecondary;

    return Dialog(
      backgroundColor: context.colorScheme.surface,
      surfaceTintColor: context.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      insetPadding: const EdgeInsets.all(Insets.normal),
      child: BlocConsumer<AttachToEncounterBloc, AttachToEncounterState>(
        listener: (context, state) {
          if (state.status == AttachToEncounterStatus.failure &&
              state.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.errorMessage!)),
            );
          }
        },
        builder: (context, state) {
          return Container(
            constraints: const BoxConstraints(maxHeight: 600),
            decoration: BoxDecoration(
              color: context.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor, width: 1),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Insets.normal,
                    vertical: Insets.small,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text('Attach to encounter'),
                      ),
                      IconButton(
                        onPressed: _handleCancel,
                        icon: const Icon(Icons.close),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        style: IconButton.styleFrom(
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(height: 1, color: borderColor),

                // Content
                Flexible(
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: Insets.normal),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Padding(
                          padding:
                              EdgeInsets.symmetric(vertical: Insets.normal),
                          child: PatientSelector(
                            title: 'Current Patient & Source',
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: Insets.normal),
                          child: SizedBox(
                            height: 42,
                            child: TextField(
                              controller: _searchController,
                              onChanged: (value) {
                                context.read<AttachToEncounterBloc>().add(
                                      AttachToEncounterSearchQueryChanged(
                                          value),
                                    );
                              },
                              onSubmitted: (_) =>
                                  FocusScope.of(context).unfocus(),
                              style: AppTextStyle.bodyMedium,
                              maxLines: 1,
                              decoration: InputDecoration(
                                isDense: true,
                                hintText: 'Search encounters...',
                                hintStyle: AppTextStyle.labelLarge.copyWith(
                                  color: context.colorScheme.onSurface
                                      .withOpacity(0.6),
                                ),
                                prefixIcon: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Assets.icons.search.svg(
                                    width: 16,
                                    colorFilter: ColorFilter.mode(
                                      context.colorScheme.onSurface
                                          .withOpacity(0.6),
                                      BlendMode.srcIn,
                                    ),
                                  ),
                                ),
                                suffixIcon: state.searchQuery.isNotEmpty
                                    ? IconButton(
                                        onPressed: () {
                                          _searchController.clear();
                                          context
                                              .read<AttachToEncounterBloc>()
                                              .add(
                                                const AttachToEncounterSearchQueryChanged(
                                                    ''),
                                              );
                                        },
                                        icon: Assets.icons.close.svg(
                                          width: Insets.normal,
                                          height: Insets.normal,
                                          colorFilter: ColorFilter.mode(
                                            context.colorScheme.onSurface
                                                .withOpacity(0.6),
                                            BlendMode.srcIn,
                                          ),
                                        ),
                                      )
                                    : null,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(100),
                                  borderSide: BorderSide(
                                      color: context.theme.dividerColor),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(100),
                                  borderSide: BorderSide(
                                      color: context.theme.dividerColor),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(100),
                                  borderSide: const BorderSide(
                                      color: AppColors.primary),
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
                        ),
                        Flexible(
                          child: state.status == AttachToEncounterStatus.loading
                              ? Center(
                                  child: CircularProgressIndicator(
                                    color: context.colorScheme.primary,
                                  ),
                                )
                              : state.filteredEncounters.isEmpty
                                  ? Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
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
                                        _buildCreateEncounterButton(
                                            context, borderColor),
                                      ],
                                    )
                                  : ListView.builder(
                                      shrinkWrap: true,
                                      itemCount:
                                          state.filteredEncounters.length + 1,
                                      itemBuilder: (context, index) {
                                        // Last item is the create button
                                        if (index ==
                                            state.filteredEncounters.length) {
                                          return Padding(
                                            padding: const EdgeInsets.only(
                                                bottom: 8),
                                            child: _buildCreateEncounterButton(
                                                context, borderColor),
                                          );
                                        }

                                        final encounter =
                                            state.filteredEncounters[index];
                                        final isSelected =
                                            state.selectedEncounter?.id ==
                                                encounter.id;
                                        return Card(
                                          margin:
                                              const EdgeInsets.only(bottom: 8),
                                          elevation: isSelected ? 3 : 1,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            side: BorderSide(
                                              color: isSelected
                                                  ? context.colorScheme.primary
                                                  : borderColor
                                                      .withOpacity(0.3),
                                              width: isSelected ? 2 : 1,
                                            ),
                                          ),
                                          child: ListTile(
                                            leading: Container(
                                              width: 40,
                                              height: 40,
                                              decoration: BoxDecoration(
                                                color: isSelected
                                                    ? context.colorScheme
                                                        .primaryContainer
                                                    : context
                                                        .colorScheme.primary,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Icon(
                                                isSelected
                                                    ? Icons.check
                                                    : Icons.medical_information,
                                                color: isSelected
                                                    ? context.colorScheme
                                                        .onPrimaryContainer
                                                    : context
                                                        .colorScheme.onPrimary,
                                                size: 20,
                                              ),
                                            ),
                                            title: Text(
                                              encounter.displayTitle,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                                color: textColor,
                                              ),
                                            ),
                                            subtitle: encounter.date != null
                                                ? Text(
                                                    DateFormat.yMMMd().format(
                                                        encounter.date!),
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: iconColor,
                                                    ),
                                                  )
                                                : null,
                                            trailing: Radio<bool>(
                                              value: true,
                                              groupValue: isSelected,
                                              onChanged: (_) => _handleSelect(
                                                  context, encounter),
                                              activeColor:
                                                  context.colorScheme.primary,
                                            ),
                                            onTap: () => _handleSelect(
                                                context, encounter),
                                            hoverColor: context
                                                .colorScheme.primaryContainer
                                                .withOpacity(0.3),
                                            selectedTileColor: context
                                                .colorScheme.primaryContainer
                                                .withOpacity(0.1),
                                            selected: isSelected,
                                          ),
                                        );
                                      },
                                    ),
                        ),
                      ],
                    ),
                  ),
                ),

                Container(height: 1, color: borderColor),

                // Footer
                Padding(
                  padding: const EdgeInsets.all(Insets.normal),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _handleCancel,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: AppColors.primary,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                                vertical: Insets.small),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          child:
                              Text('Cancel', style: AppTextStyle.buttonSmall),
                        ),
                      ),
                      const SizedBox(width: Insets.small),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: state.selectedEncounter != null
                              ? () => _handleDone(
                                    context,
                                    state.selectedPatient!,
                                    state.selectedEncounter!,
                                  )
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: state.selectedEncounter != null
                                ? AppColors.primary
                                : context.colorScheme.surfaceVariant,
                            foregroundColor: state.selectedEncounter != null
                                ? Colors.white
                                : context.colorScheme.onSurfaceVariant,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                                vertical: Insets.small),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          child: Text('Attach', style: AppTextStyle.buttonSmall),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCreateEncounterButton(BuildContext context, Color borderColor) {
    return GestureDetector(
      onTap: () => _handleCreateEncounter(context),
      child: CustomPaint(
        painter: _DashedBorderPainter(
          color: borderColor,
          strokeWidth: 1,
          dashWidth: 6,
          dashSpace: 4,
          borderRadius: 8,
        ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: Insets.small),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add,
                color: context.colorScheme.onSurface.withOpacity(0.6),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Create Encounter',
                style: AppTextStyle.bodyMedium.copyWith(
                  color: context.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashWidth;
  final double dashSpace;
  final double borderRadius;

  _DashedBorderPainter({
    required this.color,
    required this.strokeWidth,
    required this.dashWidth,
    required this.dashSpace,
    required this.borderRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Radius.circular(borderRadius),
      ));

    final dashPath = Path();
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final start = distance;
        final end = (distance + dashWidth).clamp(0, metric.length);
        dashPath.addPath(
          metric.extractPath(start, end.toDouble()),
          Offset.zero,
        );
        distance += dashWidth + dashSpace;
      }
    }

    canvas.drawPath(dashPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
