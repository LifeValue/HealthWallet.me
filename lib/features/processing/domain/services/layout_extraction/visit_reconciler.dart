import 'package:collection/collection.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_identifier.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_resource.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_vision_prescription.dart';
import 'package:health_wallet/features/processing/domain/entity/staged_resource.dart';
import 'package:health_wallet/features/processing/domain/services/layout_extraction/layout_extractor.dart';
import 'package:health_wallet/features/processing/domain/services/layout_extraction/record_completion.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';

/// The container and resources a layout document is staged with.
class LayoutStaging {
  const LayoutStaging({required this.encounter, required this.resources});

  final StagedEncounter encounter;
  final List<MappingResource> resources;
}

/// Finds what of a layout document is already in the wallet of the person it
/// is filed under. The visit is the anchor: its key is an Encounter
/// identifier, so both documents of one visit find the same Encounter in
/// either order. Nothing ambiguous is resolved by guessing.
class VisitReconciler {
  const VisitReconciler();

  /// [records] are the matched person's Encounters, VisionPrescriptions,
  /// Organizations and Practitioners; empty for someone new.
  LayoutStaging reconcile(
    LayoutExtraction extraction,
    List<IFhirResource> records,
  ) {
    final visitKey = extraction.visitKey;
    final visits = visitKey == null
        ? const <Encounter>[]
        : records
              .whereType<Encounter>()
              .where((e) => _carries(e.rawResource, visitKey))
              .toList();
    // Several Encounters with the key (two devices each made one) is not
    // resolved here: a new draft, which the user can swap for one of them.
    final visit = visits.length == 1 ? visits.single : null;
    final encounter = visit == null
        ? StagedEncounter(draft: extraction.encounter)
        : StagedEncounter(
            draft: extraction.encounter,
            existing: visit,
            mode: ImportMode.linkExisting,
          );

    final ids = {for (final r in records) '${r.fhirType.name}/${r.resourceId}'};
    final supporting = <MappingResource>[
      if (!ids.contains('Organization/${extraction.organization.id}'))
        extraction.organization,
      if (extraction.practitioner case final practitioner?)
        if (!ids.contains('Practitioner/${practitioner.id}')) practitioner,
    ];

    final stored = records.whereType<VisionPrescription>().toList();
    final inVisit = visit == null
        ? const <VisionPrescription>[]
        : stored.where((p) => _belongsTo(p, visit)).toList();
    final claimed = <String>{};
    final resources = <MappingResource>[];
    for (final resource in extraction.resources) {
      if (resource is! MappingVisionPrescription) {
        resources.add(resource);
        continue;
      }
      final twin =
          _sameSerial(resource, stored, claimed) ??
          _sameValues(resource, inVisit, claimed);
      if (twin == null) {
        resources.add(resource);
        continue;
      }
      claimed.add(twin.id);
      final read = resource
          .toFhirResource(
            subjectId: _reference(twin.patient?.reference?.valueString),
            encounterId: visit?.resourceId,
          )
          .rawResource;
      resources.add(
        resource.copyWith(
          existingId: twin.id,
          completesExisting:
              RecordCompletion.visionPrescription(
                twin.rawResource,
                read,
                provenance: resource.provenance,
              ) !=
              null,
        ),
      );
    }

    return LayoutStaging(
      encounter: encounter,
      resources: [...supporting, ...resources],
    );
  }

  static bool _carries(Map<String, dynamic> raw, MappingIdentifier key) =>
      ((raw['identifier'] as List?) ?? const []).any(key.matchesJson);

  static bool _belongsTo(VisionPrescription p, Encounter visit) {
    final reference = p.encounter?.reference?.valueString;
    final id = reference == null ? p.encounterId : _reference(reference);
    return id.isNotEmpty && (id == visit.resourceId || id == visit.id);
  }

  static String _reference(String? reference) =>
      reference == null ? '' : reference.split('/').last;

  static VisionPrescription? _sameSerial(
    MappingVisionPrescription read,
    List<VisionPrescription> stored,
    Set<String> claimed,
  ) {
    final serial = read.serial.value;
    if (serial.isEmpty) return null;
    final matches = stored
        .where(
          (p) =>
              !claimed.contains(p.id) &&
              (p.identifier ?? const []).any(
                (i) =>
                    i.value?.valueString == serial &&
                    (i.system?.valueString ?? '') == read.serialSystem,
              ),
        )
        .toList();
    return matches.length == 1 ? matches.single : null;
  }

  /// The one stored prescription of the visit with the same lens type and
  /// exactly the same per-eye values; null when none or several are.
  static VisionPrescription? _sameValues(
    MappingVisionPrescription read,
    List<VisionPrescription> inVisit,
    Set<String> claimed,
  ) {
    final matches = inVisit
        .where(
          (p) =>
              !claimed.contains(p.id) &&
              p.lensType == read.lensType &&
              _sameEye(p, read, right: true) &&
              _sameEye(p, read, right: false),
        )
        .toList();
    return matches.length == 1 ? matches.single : null;
  }

  static bool _sameEye(
    VisionPrescription stored,
    MappingVisionPrescription read, {
    required bool right,
  }) {
    final lens = stored.lensSpecification?.firstWhereOrNull(
      (l) => l.eye.valueString == (right ? 'right' : 'left'),
    );
    final values = read.eyeValues(right: right);
    return lens?.sphere?.valueDouble == values.sphere &&
        lens?.cylinder?.valueDouble == values.cylinder &&
        lens?.axis?.valueInt == values.axis &&
        lens?.add?.valueDouble == values.add;
  }
}
