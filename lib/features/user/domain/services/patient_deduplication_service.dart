import 'package:health_wallet/features/records/domain/entity/patient/patient.dart'
    as entity;
import 'package:health_wallet/features/records/domain/repository/records_repository.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/core/utils/logger.dart';
import 'package:injectable/injectable.dart';

@injectable
class PatientDeduplicationService {
  final RecordsRepository _recordsRepository;

  PatientDeduplicationService(this._recordsRepository);

  Map<String, PatientGroup> deduplicatePatients(
      List<entity.Patient> allPatients) {
    final Map<String, List<entity.Patient>> identifierGroups = {};
    final Map<String, String> patientToGroupKey = {};

    for (final patient in allPatients) {
      final identifierKey = _getPatientIdentifierKey(patient);

      if (identifierKey != null) {
        identifierGroups.putIfAbsent(identifierKey, () => []).add(patient);
        patientToGroupKey[patient.id] = identifierKey;
      } else {
        final uniqueKey = 'unique_${patient.id}';
        identifierGroups[uniqueKey] = [patient];
        patientToGroupKey[patient.id] = uniqueKey;
      }
    }

    final Map<String, PatientGroup> result = {};
    for (final entry in identifierGroups.entries) {
      final patients = entry.value;
      if (patients.isEmpty) continue;

      final walletPatient =
          patients.where((p) => p.sourceId.startsWith('wallet')).firstOrNull;

      final representative = walletPatient ?? patients.first;
      final sourceIds = patients
          .map((p) => p.sourceId)
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();

      result[representative.id] = PatientGroup(
        representativePatient: representative,
        sourceIds: sourceIds,
        allPatientInstances: patients,
      );
    }

    return result;
  }

  List<entity.Patient> getUniquePatients(List<entity.Patient> allPatients) {
    final groups = deduplicatePatients(allPatients);
    return groups.values.map((g) => g.representativePatient).toList();
  }

  List<String> getSourcesForPatient(
      String patientId, List<entity.Patient> allPatients) {
    final groups = deduplicatePatients(allPatients);
    final group = groups[patientId];
    if (group != null) {
      return group.sourceIds;
    }

    for (final g in groups.values) {
      if (g.allPatientInstances.any((p) => p.id == patientId)) {
        return g.sourceIds;
      }
    }

    return [];
  }

  bool hasMultipleSources(String patientId, List<entity.Patient> allPatients) {
    final sources = getSourcesForPatient(patientId, allPatients);
    return sources.length > 1;
  }

  String? _getPatientIdentifierKey(entity.Patient patient) {
    if (patient.identifier == null || patient.identifier!.isEmpty) {
      return null;
    }

    final identifierKeys = patient.identifier!
        .where((id) =>
            id.system?.valueString != null && id.value?.valueString != null)
        .map((id) =>
            '${_normalizeSystem(id.system!.valueString!)}:${_normalizeValue(id.value!.valueString!)}')
        .toList()
      ..sort();

    return identifierKeys.isEmpty ? null : identifierKeys.join('|');
  }

  String _normalizeSystem(String system) {
    return system.trim().toLowerCase();
  }

  String _normalizeValue(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'[-\s]'), '');
  }

  int _scorePatientCompleteness(entity.Patient patient) {
    int score = 0;

    if (patient.name != null && patient.name!.isNotEmpty) score += 10;
    if (patient.birthDate != null) score += 5;
    if (patient.gender != null) score += 3;
    if (patient.address != null && patient.address!.isNotEmpty) score += 3;
    if (patient.telecom != null && patient.telecom!.isNotEmpty) score += 2;
    if (patient.identifier != null && patient.identifier!.isNotEmpty) {
      score += patient.identifier!.length;
    }

    return score;
  }

  Future<Map<String, PatientGroup>> enhancePatientGroupsWithSubjectId(
    Map<String, PatientGroup> patientGroups,
    List<entity.Patient> allPatients,
  ) async {
    try {
      final enhancedGroups = Map<String, PatientGroup>.from(patientGroups);

      for (final patient in allPatients) {
        final sourcesForPatient = await getSourceIdsForPatient(patient.id);

        final allSourceIds = {
          ...sourcesForPatient,
          if (patient.sourceId.isNotEmpty) patient.sourceId
        }.toList();

        final existingGroup = enhancedGroups[patient.id];
        if (existingGroup != null) {
          final combinedSourceIds =
              {...existingGroup.sourceIds, ...allSourceIds}.toList();
          enhancedGroups[patient.id] = PatientGroup(
            representativePatient: existingGroup.representativePatient,
            sourceIds: combinedSourceIds,
            allPatientInstances: existingGroup.allPatientInstances,
          );
        } else {
          enhancedGroups[patient.id] = PatientGroup(
            representativePatient: patient,
            sourceIds: allSourceIds,
            allPatientInstances: [patient],
          );
        }
      }

      return enhancedGroups;
    } catch (e) {
      logger.e('Error in enhancePatientGroupsWithSubjectId: $e');
      return patientGroups;
    }
  }

  Future<List<String>> getSourceIdsForPatient(String patientId) async {
    try {
      final allResources = await _recordsRepository.getResources(
        resourceTypes: [],
        limit: 10000,
      );

      final sourceIds = allResources
          .where((resource) {
            if (resource is Patient) return false;

            final subjectRef = resource.rawResource['subject'];
            if (subjectRef == null) return false;

            final reference = subjectRef['reference'];
            if (reference == null) return false;

            return reference.toString().contains(patientId);
          })
          .map((r) => r.sourceId)
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();

      return sourceIds;
    } catch (e) {
      logger.e('Error in _getSourceIdsForPatient: $e');
      return [];
    }
  }

  PatientGroup? findPatientGroup(
    Map<String, PatientGroup> groups,
    String patientId,
  ) {
    for (final group in groups.values) {
      if (group.representativePatient.id == patientId ||
          group.allPatientInstances
              .any((p) => p.id == patientId || p.resourceId == patientId)) {
        return group;
      }
    }
    return null;
  }
}

class PatientGroup {
  final entity.Patient representativePatient;

  final List<String> sourceIds;

  final List<entity.Patient> allPatientInstances;

  const PatientGroup({
    required this.representativePatient,
    required this.sourceIds,
    required this.allPatientInstances,
  });

  String get patientId => representativePatient.id;

  bool existsInSource(String sourceId) => sourceIds.contains(sourceId);

  entity.Patient? getPatientForSource(String sourceId) {
    try {
      return allPatientInstances.firstWhere((p) => p.sourceId == sourceId);
    } catch (e) {
      return null;
    }
  }
}
