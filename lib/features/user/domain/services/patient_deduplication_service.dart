import 'package:health_wallet/features/records/domain/entity/patient/patient.dart'
    as entity;
import 'package:health_wallet/features/records/domain/repository/records_repository.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/core/utils/logger.dart';
import 'package:health_wallet/features/sync/domain/repository/sync_repository.dart';
import 'package:health_wallet/features/scan/domain/entity/mapping_resources/mapping_patient.dart';
import 'package:health_wallet/features/records/domain/utils/fhir_field_extractor.dart';
import 'package:injectable/injectable.dart';

@injectable
class PatientDeduplicationService {
  final RecordsRepository _recordsRepository;
  final SyncRepository _syncRepository;

  PatientDeduplicationService(this._recordsRepository, this._syncRepository);

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
    return _removeDiacritics(
        value.trim().toLowerCase().replaceAll(RegExp(r'[-\s]'), ''));
  }

  static final _diacriticsMap = {
    'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a', 'ă': 'a',
    'æ': 'ae',
    'ç': 'c',
    'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e',
    'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i',
    'đ': 'd',
    'ñ': 'n',
    'ò': 'o', 'ó': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o', 'ø': 'o',
    'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u',
    'ý': 'y', 'ÿ': 'y',
    'þ': 'th',
    'ș': 's', 'ş': 's',
    'ț': 't', 'ţ': 't',
  };

  static String _removeDiacritics(String text) {
    final buffer = StringBuffer();
    for (final char in text.runes) {
      final c = String.fromCharCode(char);
      buffer.write(_diacriticsMap[c] ?? c);
    }
    return buffer.toString();
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

      final resourceSourceIds = allResources
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

      final allSources = await _syncRepository.getSources();
      final walletSourceIds = allSources
          .where((source) {
            if (source.platformType == 'wallet') {
              return source.id == 'wallet-$patientId';
            }
            return false;
          })
          .map((s) => s.id)
          .toList();

      final combinedSourceIds = {
        ...resourceSourceIds,
        ...walletSourceIds,
      }.toList();

      return combinedSourceIds;
    } catch (e) {
      logger.e('Error in getSourceIdsForPatient: $e');
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

  /// Finds an existing patient that matches the draft patient extracted from OCR
  /// Matches by identifier (MRN) first, then by name + date of birth
  /// Prefers wallet source patients if multiple matches found
  entity.Patient? findMatchingPatient(
    MappingPatient draftPatient,
    List<entity.Patient> allPatients,
  ) {
    if (allPatients.isEmpty) return null;

    if (draftPatient.patientIdentifier.value.isNotEmpty) {
      final normalizedDraftMRN = _normalizeValue(draftPatient.patientIdentifier.value);

      final identifierMatches = allPatients.where((patient) {
        if (patient.identifier == null || patient.identifier!.isEmpty) {
          return false;
        }

        return patient.identifier!.any((id) {
          if (id.value?.valueString == null) return false;
          final normalizedPatientMRN = _normalizeValue(id.value!.valueString!);
          return normalizedPatientMRN == normalizedDraftMRN;
        });
      }).toList();

      if (identifierMatches.isNotEmpty) {
        final walletMatch = identifierMatches
            .where((p) => p.sourceId.startsWith('wallet'))
            .firstOrNull;
        return walletMatch ?? identifierMatches.first;
      }
    }

    if (draftPatient.familyName.value.isNotEmpty &&
        draftPatient.givenName.value.isNotEmpty &&
        draftPatient.dateOfBirth.value.isNotEmpty) {
      final normalizedDraftFamily =
          _normalizeValue(draftPatient.familyName.value);
      final normalizedDraftGiven =
          _normalizeValue(draftPatient.givenName.value);

      DateTime? draftDOB;
      try {
        draftDOB = DateTime.parse(draftPatient.dateOfBirth.value);
      } catch (e) {}

      final nameMatches = allPatients.where((patient) {
        final patientFamily = FhirFieldExtractor.extractPatientFamily(patient);
        final patientGiven = FhirFieldExtractor.extractPatientGiven(patient);

        if (patientFamily.isEmpty || patientGiven.isEmpty) return false;

        final normalizedPatientFamily = _normalizeValue(patientFamily);
        final normalizedPatientGiven = _normalizeValue(patientGiven);

        final nameMatch = normalizedPatientFamily == normalizedDraftFamily &&
            normalizedPatientGiven == normalizedDraftGiven;

        if (!nameMatch) return false;

        if (draftDOB != null) {
          try {
            final patientDOB =
                FhirFieldExtractor.extractPatientBirthDate(patient);
            if (patientDOB != null) {
              return patientDOB.year == draftDOB.year &&
                  patientDOB.month == draftDOB.month &&
                  patientDOB.day == draftDOB.day;
            }
          } catch (e) {
            return false;
          }
        }

        return true;
      }).toList();

      if (nameMatches.isNotEmpty) {
        final walletMatch = nameMatches
            .where((p) => p.sourceId.startsWith('wallet'))
            .firstOrNull;
        return walletMatch ?? nameMatches.first;
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
