import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/features/scan/domain/entity/staged_resource.dart';
import 'package:health_wallet/features/scan/presentation/widgets/attach_to_encounter/bloc/attach_to_encounter_bloc.dart';
import 'package:health_wallet/features/scan/presentation/widgets/attach_to_encounter/encounter_selector.dart';
import 'package:health_wallet/features/scan/presentation/widgets/attach_to_encounter/patient_selector.dart';

typedef AttachToEncounterResult = (StagedPatient, StagedEncounter);

class AttachToEncounterWidget extends StatelessWidget {
  const AttachToEncounterWidget({
    this.patient,
    this.encounter,
    super.key,
  });

  final StagedPatient? patient;
  final StagedEncounter? encounter;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => getIt<AttachToEncounterBloc>()
        ..add(AttachToEncounterStarted(
          patient: patient ?? const StagedPatient(),
          encounter: encounter ?? const StagedEncounter(),
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
  void _handleCancel() {
    Navigator.of(context).pop();
  }

  void _handleDone(
    BuildContext context,
    StagedPatient patient,
    StagedEncounter encounter,
  ) {
    Navigator.of(context).pop<AttachToEncounterResult>((patient, encounter));
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = context.theme.dividerColor;

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
          final canProceed =
              state.patient.hasSelection && state.encounter.hasSelection;
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
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text('Attach to encounter',
                            style: AppTextStyle.bodyMedium),
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
                const Expanded(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        PatientSelector(
                          title: 'Current Patient & Source',
                        ),
                        SizedBox(height: 24),
                        Expanded(child: EncounterSelector()),
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
                          onPressed: canProceed
                              ? () => _handleDone(
                                  context, state.patient, state.encounter)
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: canProceed
                                ? AppColors.primary
                                : context.colorScheme.surfaceVariant,
                            foregroundColor: canProceed
                                ? Colors.white
                                : context.colorScheme.onSurfaceVariant,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                                vertical: Insets.small),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          child:
                              Text('Attach', style: AppTextStyle.buttonSmall),
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
}
