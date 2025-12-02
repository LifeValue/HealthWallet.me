import 'package:flutter/material.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/user/domain/services/patient_deduplication_service.dart';

class PatientDropdown extends StatelessWidget {
  const PatientDropdown({
    required this.options,
    required this.selectedPatient,
    required this.onChanged,
    super.key,
  });

  final List<PatientGroup> options;
  final PatientGroup selectedPatient;
  final Function(PatientGroup?) onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<PatientGroup>(
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        disabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: AppColors.primary.withValues(alpha: 0.6)),
          borderRadius: BorderRadius.circular(8),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: AppColors.primary.withValues(alpha: 0.6)),
          borderRadius: BorderRadius.circular(8),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: AppColors.primary.withValues(alpha: 0.6)),
          borderRadius: BorderRadius.circular(8),
        ),
        errorBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Theme.of(context).colorScheme.error),
          borderRadius: BorderRadius.circular(8),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderSide: BorderSide(
              color: Theme.of(context).colorScheme.error, width: 1.5),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      style: AppTextStyle.labelLarge.copyWith(color: Colors.black),
      hint: const Text('Please select an option'),
      value: selectedPatient,
      isExpanded: true,
      items: options.map((PatientGroup patient) {
        return DropdownMenuItem<PatientGroup>(
          value: patient,
          child: Text(patient.representativePatient.title),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }
}
