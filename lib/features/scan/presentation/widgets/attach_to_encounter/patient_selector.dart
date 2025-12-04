import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/scan/domain/entity/mapping_resources/mapping_patient.dart';
import 'package:health_wallet/features/scan/presentation/widgets/attach_to_encounter/bloc/attach_to_encounter_bloc.dart';
import 'package:health_wallet/gen/assets.gen.dart';

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
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: context.colorScheme.surfaceVariant.withOpacity(0.5),
            border: Border.all(
              color: context.colorScheme.outline.withOpacity(0.1),
            ),
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
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border:
                Border.all(color: context.colorScheme.outline.withOpacity(0.1)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<dynamic>(
              value: state.selectedPatient,
              isExpanded: true,
              icon: Assets.icons.chevronDown.svg(),
              borderRadius: BorderRadius.circular(8),
              items: [
                if (patient.draft != null)
                  DropdownMenuItem<MappingPatient>(
                    value: patient.draft,
                    child: Text(
                      "New Patient: ${patient.draft!.givenName.value} ${patient.draft!.familyName.value}",
                      style: AppTextStyle.labelLarge.copyWith(
                        color: context.colorScheme.onSurface,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ...state.existingPatients.map((Patient patient) {
                  return DropdownMenuItem<Patient>(
                    value: patient,
                    child: Text(
                      patient.displayTitle,
                      style: AppTextStyle.labelLarge.copyWith(
                        color: context.colorScheme.onSurface,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                })
              ],
              onChanged: (dynamic newValue) {
                if (newValue != null) {
                  context.read<AttachToEncounterBloc>().add(
                        AttachToEncounterPatientChanged(newValue),
                      );
                }
              },
            ),
          ),
        ),
      ],
    );
  }
}
