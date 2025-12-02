import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
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
          padding: const EdgeInsets.all(Insets.normal),
          decoration: BoxDecoration(
            color: context.colorScheme.surfaceVariant.withOpacity(0.5),
            border: Border.all(
              color: context.colorScheme.outline.withOpacity(0.3),
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.person_outline,
                    color: context.colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    title ?? 'Patient & Source Information',
                    style: AppTextStyle.bodyMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: context.colorScheme.onSurface,
                    ),
                  ),
                ],
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
    final selectedPatientId = state.selectedPatientId;

    if (state.patients.isEmpty) {
      return Text(
        'No patients available',
        style: AppTextStyle.bodyMedium.copyWith(
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
            fontWeight: FontWeight.w500,
            color: context.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border:
                Border.all(color: context.colorScheme.outline.withOpacity(0.3)),
            borderRadius: BorderRadius.circular(4),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selectedPatientId,
              isExpanded: true,
              icon: Icon(
                Icons.arrow_drop_down,
                color: context.colorScheme.onSurfaceVariant,
                size: 20,
              ),
              items: state.patients.map((Patient patient) {
                return DropdownMenuItem<String>(
                  value: patient.id,
                  child: Text(
                    patient.displayTitle,
                    style: AppTextStyle.bodyMedium.copyWith(
                      color: context.colorScheme.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (String? newValue) {
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
