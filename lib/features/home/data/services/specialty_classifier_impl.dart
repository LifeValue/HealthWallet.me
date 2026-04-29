import 'package:injectable/injectable.dart';
import 'package:health_wallet/features/home/domain/entities/medical_specialty.dart';
import 'package:health_wallet/features/home/domain/services/specialty_classifier.dart';
import 'package:health_wallet/features/home/data/services/specialty_code_registry.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';

@LazySingleton(as: SpecialtyClassifier)
class SpecialtyClassifierImpl implements SpecialtyClassifier {
  static const _headResourceTypes = {
    FhirType.Encounter,
    FhirType.DiagnosticReport,
  };

  @override
  void buildEncounterIndex(List<IFhirResource> allResources) {}

  @override
  Set<MedicalSpecialty> classify(IFhirResource resource) {
    if (!_headResourceTypes.contains(resource.fhirType)) {
      return {};
    }

    final raw = resource.rawResource;

    final tagOverride = _parseSpecialtyFromTag(raw['meta']?['tag'] as List?);
    if (tagOverride != null && tagOverride.isNotEmpty) {
      return tagOverride;
    }

    final directSpecialties = _classifyByDirectFhirSpecialty(resource, raw);
    if (directSpecialties.isNotEmpty) {
      return directSpecialties;
    }

    final codeSpecialties = _classifyByCodes(raw);
    if (codeSpecialties.isNotEmpty) {
      return codeSpecialties;
    }

    return {MedicalSpecialty.generalCare};
  }

  Set<MedicalSpecialty>? _parseSpecialtyFromTag(List? tags) {
    if (tags == null || tags.isEmpty) return null;

    final result = <MedicalSpecialty>{};
    for (final tag in tags) {
      if (tag is! Map<String, dynamic>) continue;
      if (tag['system'] != 'http://healthwallet.me/specialty') continue;

      final code = tag['code'] as String?;
      if (code == null) continue;

      for (final specialty in MedicalSpecialty.values) {
        if (specialty.name == code) {
          result.add(specialty);
          break;
        }
      }
    }

    return result.isEmpty ? null : result;
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

    final codeCoding = raw['code']?['coding'] as List?;
    if (codeCoding != null) {
      for (final c in codeCoding) {
        if (c is Map<String, dynamic>) codings.add(c);
      }
    }

    final categoryList = raw['category'] as List?;
    if (categoryList != null) {
      for (final category in categoryList) {
        if (category is Map<String, dynamic>) {
          final catCoding = category['coding'] as List?;
          if (catCoding != null) {
            for (final c in catCoding) {
              if (c is Map<String, dynamic>) codings.add(c);
            }
          }
        }
      }
    }

    final medCoding = raw['medicationCodeableConcept']?['coding'] as List?;
    if (medCoding != null) {
      for (final c in medCoding) {
        if (c is Map<String, dynamic>) codings.add(c);
      }
    }

    final reasonCodeList = raw['reasonCode'] as List?;
    if (reasonCodeList != null) {
      for (final reason in reasonCodeList) {
        if (reason is Map<String, dynamic>) {
          final reasonCoding = reason['coding'] as List?;
          if (reasonCoding != null) {
            for (final c in reasonCoding) {
              if (c is Map<String, dynamic>) codings.add(c);
            }
          }
        }
      }
    }

    return codings;
  }

}
