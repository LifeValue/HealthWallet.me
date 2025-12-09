import 'package:health_wallet/features/records/domain/entity/patient/patient.dart';
import 'package:health_wallet/features/user/domain/services/patient_deduplication_service.dart';
import 'package:injectable/injectable.dart';

@injectable
class PatientSelectionService {
  final PatientDeduplicationService _deduplicationService;

  PatientSelectionService(this._deduplicationService);

  Patient? getPatientForSource({
    required List<Patient> patients,
    String? sourceId,
    String? selectedPatientId,
    Map<String, PatientGroup>? patientGroups,
  }) {
    if (patients.isEmpty || selectedPatientId == null) {
      return patients.isNotEmpty ? patients.first : null;
    }

    final groups = patientGroups ?? _deduplicationService.deduplicatePatients(patients);

    final patientGroup = _findPatientGroup(groups, selectedPatientId);

    if (patientGroup == null) {
      return patients.first;
    }

    if (sourceId == null || sourceId == 'All') {
      final walletPatients = patientGroup.allPatientInstances
          .where((p) => p.sourceId.startsWith('wallet'))
          .toList();
      if (walletPatients.isNotEmpty) {
        return walletPatients.first;
      }
      return patientGroup.representativePatient;
    }

    final sourcePatient = patientGroup.getPatientForSource(sourceId);
    return sourcePatient ?? patientGroup.representativePatient;
  }

  Patient getPatientFromGroup({
    required PatientGroup patientGroup,
    String? selectedSource,
    Patient? fallbackPatient,
  }) {
    if (selectedSource == null || selectedSource == 'All') {
      final walletPatient = patientGroup.allPatientInstances
          .where((p) => p.sourceId.startsWith('wallet'))
          .toList();
      if (walletPatient.isNotEmpty) {
        return walletPatient.first;
      }
      return patientGroup.representativePatient;
    }

    final sourcePatient = patientGroup.getPatientForSource(selectedSource);
    return sourcePatient ?? patientGroup.representativePatient;
  }

  PatientGroup? _findPatientGroup(
    Map<String, PatientGroup> groups,
    String patientId,
  ) {
    for (final group in groups.values) {
      if (group.representativePatient.id == patientId ||
          group.allPatientInstances.any((p) => p.id == patientId || p.resourceId == patientId)) {
        return group;
      }
    }
    return null;
  }
}

