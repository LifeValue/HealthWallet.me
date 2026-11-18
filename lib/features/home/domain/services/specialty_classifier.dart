import 'package:health_wallet/features/home/domain/entities/medical_specialty.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';

/// The specialties of each encounter, by encounter resource id, which records
/// without specialty codes of their own inherit.
typedef EncounterSpecialties = Map<String, Set<MedicalSpecialty>>;

abstract class SpecialtyClassifier {
  /// [encounterSpecialties] is the index to inherit from (see
  /// [indexEncounters]); without it, the one [buildEncounterIndex] last built.
  Set<MedicalSpecialty> classify(
    IFhirResource resource, {
    MedicalSpecialty? override,
    EncounterSpecialties? encounterSpecialties,
  });

  /// Replaces the shared index with the encounters in [allResources].
  void buildEncounterIndex(List<IFhirResource> allResources);

  /// An index of the encounters in [resources] that the caller keeps, so it
  /// can't be replaced by another screen's [buildEncounterIndex].
  EncounterSpecialties indexEncounters(Iterable<IFhirResource> resources);
}
