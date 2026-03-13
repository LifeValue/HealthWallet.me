import 'package:health_wallet/core/utils/fhir_reference_utils.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';

class FhirResourceRelationshipService {
  static List<IFhirResource> findRelatedInMemory({
    required IFhirResource resource,
    required List<IFhirResource> allRecords,
  }) {
    final related = <IFhirResource>[];

    if (resource.fhirType == FhirType.Encounter) {
      for (final r in allRecords) {
        if (r.id == resource.id) continue;
        if (_resourceReferencesEncounter(r, resource.resourceId)) {
          related.add(r);
        }
      }
    } else {
      final encounterId = _extractEncounterIdFromResource(resource);
      if (encounterId != null) {
        final encounter = allRecords
            .where((r) =>
                r.fhirType == FhirType.Encounter &&
                r.resourceId == encounterId)
            .firstOrNull;
        if (encounter != null) related.add(encounter);
      }

      for (final ref in resource.resourceReferences) {
        final refId = FhirReferenceUtils.extractReferenceId(ref);
        if (refId == null) continue;
        final match = allRecords.where((r) {
          if (r.id == resource.id) return false;
          return r.resourceId == refId;
        }).firstOrNull;
        if (match != null && !related.contains(match)) {
          related.add(match);
        }
      }
    }

    return related;
  }

  static bool _resourceReferencesEncounter(
      IFhirResource r, String encounterId) {
    if (r.encounterId.isNotEmpty && r.encounterId == encounterId) {
      return true;
    }

    final encRef = r.rawResource['encounter']?['reference'] as String?;
    if (encRef != null) {
      final extractedId = FhirReferenceUtils.extractReferenceId(encRef);
      if (extractedId == encounterId) return true;
    }

    final contextEnc = r.rawResource['context']?['encounter'] as List?;
    if (contextEnc != null) {
      return contextEnc.any((e) {
        final ref = e['reference'] as String?;
        final extractedId = FhirReferenceUtils.extractReferenceId(ref);
        return extractedId == encounterId;
      });
    }

    return false;
  }

  static String? _extractEncounterIdFromResource(IFhirResource resource) {
    if (resource.encounterId.isNotEmpty) return resource.encounterId;

    final encRef = resource.rawResource['encounter']?['reference'] as String?;
    if (encRef != null) {
      return FhirReferenceUtils.extractReferenceId(encRef);
    }

    final contextEnc = resource.rawResource['context']?['encounter'] as List?;
    if (contextEnc != null && contextEnc.isNotEmpty) {
      final ref = contextEnc.first['reference'] as String?;
      return FhirReferenceUtils.extractReferenceId(ref);
    }

    return null;
  }
}
