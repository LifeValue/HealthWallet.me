import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_wallet/features/home/presentation/bloc/home_bloc.dart';
import 'package:health_wallet/features/user/presentation/preferences_modal/sections/patient/bloc/patient_bloc.dart';

/// Utility class for handling patient source filtering logic
class PatientSourceUtils {
  /// Reload home data with current patient's source filtering
  static void reloadHomeWithPatientFilter(BuildContext context, String source) {
    final patientSourceIds = getPatientSourceIds(context);
    context.read<HomeBloc>().add(
      HomeSourceChanged(source, patientSourceIds: patientSourceIds),
    );
  }

  /// Get the selected patient's source IDs from PatientBloc
  static List<String>? getPatientSourceIds(BuildContext context) {
    try {
      final patientState = context.read<PatientBloc>().state;
      final selectedPatientId = patientState.selectedPatientId;

      if (selectedPatientId != null && patientState.patientGroups.isNotEmpty) {
        final patientGroup = patientState.patientGroups[selectedPatientId];
        return patientGroup?.sourceIds;
      }
    } catch (e) {
      // PatientBloc not available
    }
    return null;
  }

  /// Extract patient source IDs from PatientState
  static List<String>? getPatientSourceIdsFromState(PatientState patientState) {
    final selectedPatientId = patientState.selectedPatientId;
    if (selectedPatientId != null && patientState.patientGroups.isNotEmpty) {
      final patientGroup = patientState.patientGroups[selectedPatientId];
      return patientGroup?.sourceIds;
    }
    return null;
  }

  /// Validate that a source exists for the patient, fallback to "All" if not
  static String validateSourceForPatient(
    String currentSource,
    List<String>? patientSourceIds,
  ) {
    final source = currentSource.isEmpty ? 'All' : currentSource;

    // If source is "All" or patient has no sources, keep it
    if (source == 'All' ||
        patientSourceIds == null ||
        patientSourceIds.isEmpty) {
      return source;
    }

    // If source exists for patient, keep it; otherwise fallback to "All"
    final isValid = patientSourceIds.contains(source);
    final result = isValid ? source : 'All';
    return result;
  }

  /// Handle patient selection change with source validation
  static void handlePatientChange(
    BuildContext context,
    PatientState patientState,
  ) {
    final homeState = context.read<HomeBloc>().state;
    final currentSource = homeState.selectedSource;

    // Get the new patient's source IDs
    final patientSourceIds = getPatientSourceIdsFromState(patientState);

    // Validate that the current source exists for the new patient
    final validSource = validateSourceForPatient(
      currentSource,
      patientSourceIds,
    );

    // Reload home with validated source and new patient's sources
    context.read<HomeBloc>().add(
      HomeSourceChanged(validSource, patientSourceIds: patientSourceIds),
    );
  }
}
