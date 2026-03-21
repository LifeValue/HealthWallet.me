import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/widgets/dialogs/app_simple_dialog.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/features/scan/presentation/widgets/patient_modified_banner.dart';
import 'package:health_wallet/core/widgets/app_dropdown_field.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/scan/domain/entity/mapping_resources/mapping_patient.dart';
import 'package:health_wallet/features/scan/domain/entity/staged_resource.dart';
import 'package:health_wallet/features/scan/presentation/widgets/attach_to_encounter/bloc/attach_to_encounter_bloc.dart';

class PatientSelector extends StatelessWidget {
  final String? title;

  const PatientSelector({
    super.key,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AttachToEncounterBloc, AttachToEncounterState>(
      builder: (context, state) {
        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: context.colorScheme.surfaceVariant.withOpacity(0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title ?? 'Patient & Source Information',
                style: AppTextStyle.bodyLarge.copyWith(
                  color: context.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              if (state.patient.draft != null &&
                  state.patient.existing != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: Insets.small),
                  child: PatientModifiedBanner(
                    patientName: state.patient.existing!.displayTitle,
                    onRevert: () {
                      context.read<AttachToEncounterBloc>().add(
                            AttachToEncounterPatientChanged(
                                state.patient.existing!),
                          );
                    },
                  ),
                ),
              _buildPatientSelector(context, state),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPatientSelector(
      BuildContext context, AttachToEncounterState state) {
    final patient = state.patient;

    if (state.existingPatients.isEmpty && patient.draft == null) {
      return Text(
        'No patients available',
        style: AppTextStyle.bodySmall.copyWith(
          color: context.colorScheme.onSurfaceVariant,
        ),
      );
    }

    final items = <dynamic>[];
    final isModifyingExisting = patient.draft != null && patient.existing != null;
    if (patient.draft != null && !isModifyingExisting) {
      items.add(patient.draft);
    }
    items.addAll(state.existingPatients);

    String getDisplayText(dynamic item) {
      if (item is MappingPatient) {
        final name = "${item.familyName.value}, ${item.givenName.value}";
        if (patient.existing != null) {
          return name;
        }
        return "${context.l10n.patient} (new): $name";
      } else if (item is Patient) {
        return item.displayTitle;
      }
      return '';
    }

    final selectedValue = state.selectedPatient;
    final displayText = selectedValue != null
        ? getDisplayText(selectedValue)
        : 'Select patient';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Patient',
          style: AppTextStyle.bodySmall.copyWith(
            color: context.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        AppDropdownField<dynamic>(
          value: displayText,
          items: items,
          getDisplayText: getDisplayText,
          onChanged: (dynamic newValue) {
            if (newValue == null) return;
            if (patient.mode == ImportMode.createNew &&
                patient.draft != null &&
                newValue is Patient) {
              AppSimpleDialog.showDestructiveConfirmation(
                context: context,
                title: context.l10n.dropModificationsTitle,
                message: context.l10n.dropModificationsMessage,
                confirmText: context.l10n.continueButton,
                cancelText: context.l10n.cancel,
                onConfirm: () {
                  context.read<AttachToEncounterBloc>().add(
                        AttachToEncounterPatientChanged(newValue),
                      );
                },
              );
              return;
            }
            context.read<AttachToEncounterBloc>().add(
                  AttachToEncounterPatientChanged(newValue),
                );
          },
        ),
      ],
    );
  }
}
