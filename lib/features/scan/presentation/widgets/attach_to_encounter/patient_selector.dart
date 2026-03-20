import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
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
    if (patient.draft != null) {
      items.add(patient.draft);
    }
    if (patient.mode == ImportMode.createNew && patient.existing != null) {
      items.addAll(state.existingPatients
          .where((p) => p.id != patient.existing!.id));
    } else {
      items.addAll(state.existingPatients);
    }

    String getDisplayText(dynamic item) {
      if (item is MappingPatient) {
        final name = "${item.familyName.value}, ${item.givenName.value}";
        if (patient.existing != null) return name;
        return "${context.l10n.patient}: $name";
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
            if (newValue != null) {
              context.read<AttachToEncounterBloc>().add(
                    AttachToEncounterPatientChanged(newValue),
                  );
            }
          },
        ),
      ],
    );
  }
}
