import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/l10n/l10n.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/core/widgets/app_snack_bar.dart';
import 'package:health_wallet/features/processing/domain/entity/staged_resource.dart';
import 'package:health_wallet/features/processing/presentation/widgets/attach_to_encounter/bloc/attach_to_encounter_bloc.dart';
import 'package:health_wallet/features/processing/presentation/widgets/attach_to_encounter/encounter_selector.dart';
import 'package:health_wallet/features/processing/presentation/widgets/attach_to_encounter/patient_selector.dart';

typedef AttachToEncounterResult = (StagedPatient, StagedEncounter);

class AttachToEncounterWidget extends StatelessWidget {
  const AttachToEncounterWidget({
    this.patient,
    this.encounter,
    this.confirmText,
    this.patientOnly = false,
    super.key,
  });

  final StagedPatient? patient;
  final StagedEncounter? encounter;
  final String? confirmText;

  /// Only the patient is chosen: the scan is filed under a diagnostic
  /// report, which takes no encounter, so the session's stays as it is.
  final bool patientOnly;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => getIt<AttachToEncounterBloc>()
        ..add(
          AttachToEncounterStarted(
            patient: patient ?? const StagedPatient(),
            encounter: encounter ?? const StagedEncounter(),
          ),
        ),
      child: _AttachToEncounterView(
        confirmText: confirmText,
        patientOnly: patientOnly,
      ),
    );
  }
}

class _AttachToEncounterView extends StatefulWidget {
  final String? confirmText;
  final bool patientOnly;
  const _AttachToEncounterView({this.confirmText, this.patientOnly = false});

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
            AppSnackBar.show(
              context,
              message: state.errorMessage!,
              type: AppSnackBarType.error,
            );
          }
        },
        builder: (context, state) {
          final patientOnly = widget.patientOnly;
          final canProceed =
              state.patient.hasSelection &&
              (patientOnly || state.encounter.hasSelection);
          final selectors = Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: patientOnly ? MainAxisSize.min : MainAxisSize.max,
              children: [
                PatientSelector(title: context.l10n.currentPatientAndSource),
                if (!patientOnly) ...[
                  const SizedBox(height: 24),
                  const Expanded(child: EncounterSelector()),
                ],
              ],
            ),
          );
          return Container(
            constraints: const BoxConstraints(maxHeight: 600, maxWidth: 500),
            decoration: BoxDecoration(
              color: context.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor, width: 1),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          patientOnly
                              ? context.l10n.attachToPatient
                              : context.l10n.attachToEncounter,
                          style: AppTextStyle.bodyMedium,
                        ),
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

                if (patientOnly) selectors else Expanded(child: selectors),

                Container(height: 1, color: borderColor),

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
                              vertical: Insets.small,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          child: Text(
                            context.l10n.cancel,
                            style: AppTextStyle.buttonSmall,
                          ),
                        ),
                      ),
                      const SizedBox(width: Insets.small),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: canProceed
                              ? () => _handleDone(
                                  context,
                                  state.patient,
                                  state.encounter,
                                )
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: canProceed
                                ? AppColors.primary
                                : context.colorScheme.surfaceContainerHighest,
                            foregroundColor: canProceed
                                ? Colors.white
                                : context.colorScheme.onSurfaceVariant,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                              vertical: Insets.small,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          child: Text(
                            widget.confirmText ?? context.l10n.save,
                            style: AppTextStyle.buttonSmall,
                          ),
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
