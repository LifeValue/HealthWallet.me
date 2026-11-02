import 'package:health_wallet/features/holders/domain/entity/holder.dart';
import 'package:health_wallet/features/holders/domain/entity/holder_snapshot.dart';
import 'package:health_wallet/features/records/domain/entity/patient/patient.dart';
import 'package:injectable/injectable.dart';

@injectable
class PatientSelectionService {
  const PatientSelectionService();

  Patient? getPatientForSource({
    required List<Patient> patients,
    String? sourceId,
    String? selectedPatientId,
    Map<String, Holder>? patientGroups,
  }) {
    if (patients.isEmpty || selectedPatientId == null) {
      return patients.isNotEmpty ? patients.first : null;
    }

    final patientGroup = _findPatientGroup(
      patientGroups ?? const {},
      selectedPatientId,
    );

    if (patientGroup == null) {
      return patients.first;
    }

    return getPatientFromGroup(
      patientGroup: patientGroup,
      selectedSource: sourceId,
    );
  }

  Patient getPatientFromGroup({
    required Holder patientGroup,
    String? selectedSource,
    Patient? fallbackPatient,
  }) {
    if (selectedSource == null || selectedSource == 'All') {
      final walletPatient = patientGroup.allPatientInstances
          .where((p) => p.sourceId.startsWith(HolderSource.walletPrefix))
          .toList();
      if (walletPatient.isNotEmpty) {
        return walletPatient.first;
      }
      return patientGroup.representativePatient;
    }

    final sourcePatient = patientGroup.getPatientForSource(selectedSource);
    return sourcePatient ?? patientGroup.representativePatient;
  }

  Holder? _findPatientGroup(Map<String, Holder> groups, String patientId) =>
      HolderDirectory(holders: groups.values.toList()).ofPatientId(patientId);
}
