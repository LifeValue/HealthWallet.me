import 'package:injectable/injectable.dart';
import 'package:health_wallet/features/home/domain/entities/medical_specialty.dart';
import 'package:health_wallet/features/home/domain/services/specialty_classifier.dart';
import 'package:health_wallet/features/home/data/services/specialty_code_registry.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';

@LazySingleton(as: SpecialtyClassifier)
class SpecialtyClassifierImpl implements SpecialtyClassifier {
  final Map<String, Set<MedicalSpecialty>> _encounterSpecialties = {};

  @override
  void buildEncounterIndex(List<IFhirResource> allResources) {
    _encounterSpecialties.clear();
    final encounters = allResources
        .where((r) => r.fhirType == FhirType.Encounter);
    for (final encounter in encounters) {
      final specialties = _classifyInternal(encounter);
      if (specialties.isNotEmpty) {
        _encounterSpecialties[encounter.resourceId] = specialties;
      }
    }
  }

  @override
  Set<MedicalSpecialty> classify(
    IFhirResource resource, {
    MedicalSpecialty? override,
  }) {
    if (FhirType.supportingTypes.contains(resource.fhirType)) {
      return {};
    }

    if (override != null) {
      return {override};
    }

    final result = _classifyInternal(resource);
    if (result.isNotEmpty) {
      return result;
    }

    if (resource.encounterId.isNotEmpty) {
      final inherited = _encounterSpecialties[resource.encounterId];
      if (inherited != null && inherited.isNotEmpty) {
        return inherited;
      }
    }

    return {MedicalSpecialty.generalCare};
  }

  Set<MedicalSpecialty> _classifyInternal(IFhirResource resource) {
    final raw = resource.rawResource;

    final directSpecialties = _classifyByDirectFhirSpecialty(resource, raw);
    if (directSpecialties.isNotEmpty) {
      return directSpecialties;
    }

    final codeSpecialties = _classifyByCodes(raw);
    if (codeSpecialties.isNotEmpty) {
      return codeSpecialties;
    }

    return {};
  }

  Set<MedicalSpecialty> _classifyByDirectFhirSpecialty(
    IFhirResource resource,
    Map<String, dynamic> raw,
  ) {
    final result = <MedicalSpecialty>{};

    if (resource.fhirType == FhirType.Encounter) {
      _matchSnomedSpecialtyCodes(
        raw['serviceType']?['coding'] as List?,
        result,
      );
      final typeList = raw['type'] as List?;
      if (typeList != null) {
        for (final type in typeList) {
          if (type is Map<String, dynamic>) {
            _matchSnomedSpecialtyCodes(type['coding'] as List?, result);
          }
        }
      }

      final classCode =
          (raw['class'] as Map<String, dynamic>?)?['code'] as String?;
      if (classCode == 'EMER') {
        result.add(MedicalSpecialty.emergencyMedicine);
      }
    }

    if (resource.fhirType == FhirType.PractitionerRole) {
      final specialtyList = raw['specialty'] as List?;
      if (specialtyList != null) {
        for (final concept in specialtyList) {
          if (concept is Map<String, dynamic>) {
            _matchSnomedSpecialtyCodes(concept['coding'] as List?, result);
          }
        }
      }
    }

    return result;
  }

  void _matchSnomedSpecialtyCodes(
    List? codings,
    Set<MedicalSpecialty> result,
  ) {
    if (codings == null) return;
    for (final coding in codings) {
      if (coding is! Map<String, dynamic>) continue;
      final code = coding['code'] as String?;
      if (code == null) continue;

      for (final specialty in MedicalSpecialty.values) {
        if (specialty.snomedSpecialtyCode == code) {
          result.add(specialty);
        }
      }
    }
  }

  Set<MedicalSpecialty> _classifyByCodes(Map<String, dynamic> raw) {
    final result = <MedicalSpecialty>{};
    final allCodings = _extractAllCodings(raw);

    for (final coding in allCodings) {
      final system = coding['system'] as String?;
      final code = coding['code'] as String?;
      if (system == null || code == null) continue;

      if (system == 'http://loinc.org') {
        final matches = SpecialtyCodeRegistry.loincToSpecialties[code];
        if (matches != null) result.addAll(matches);
      } else if (system == 'http://snomed.info/sct') {
        final matches = SpecialtyCodeRegistry.snomedToSpecialties[code];
        if (matches != null) result.addAll(matches);
      }
    }

    return result;
  }

  List<Map<String, dynamic>> _extractAllCodings(Map<String, dynamic> raw) {
    final codings = <Map<String, dynamic>>[];

    void addCodingsFrom(List? codingList) {
      if (codingList == null) return;
      for (final c in codingList) {
        if (c is Map<String, dynamic>) codings.add(c);
      }
    }

    void addCodingsFromConcept(Map<String, dynamic>? concept) {
      if (concept == null) return;
      addCodingsFrom(concept['coding'] as List?);
    }

    addCodingsFrom(raw['code']?['coding'] as List?);

    final categoryList = raw['category'] as List?;
    if (categoryList != null) {
      for (final category in categoryList) {
        if (category is Map<String, dynamic>) {
          addCodingsFrom(category['coding'] as List?);
        }
      }
    }

    addCodingsFrom(raw['medicationCodeableConcept']?['coding'] as List?);

    final reasonCodeList = raw['reasonCode'] as List?;
    if (reasonCodeList != null) {
      for (final reason in reasonCodeList) {
        if (reason is Map<String, dynamic>) {
          addCodingsFrom(reason['coding'] as List?);
        }
      }
    }

    addCodingsFromConcept(raw['vaccineCode'] as Map<String, dynamic>?);

    addCodingsFromConcept(raw['substance'] as Map<String, dynamic>?);

    final reactionList = raw['reaction'] as List?;
    if (reactionList != null) {
      for (final reaction in reactionList) {
        if (reaction is Map<String, dynamic>) {
          addCodingsFromConcept(reaction['substance'] as Map<String, dynamic>?);
        }
      }
    }

    return codings;
  }
}
