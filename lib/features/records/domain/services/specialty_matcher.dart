import 'package:health_wallet/features/home/domain/entities/medical_specialty.dart';
import 'package:health_wallet/features/home/domain/services/specialty_classifier.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';

/// Whether a record belongs to one of [specialties], classified the way Home
/// counts them: a record without specialty codes of its own takes its
/// encounter's, so [encounters] should be every encounter in scope, not only
/// those on screen.
class SpecialtyMatcher {
  SpecialtyMatcher(
    this._classifier,
    this.specialties,
    Iterable<IFhirResource> encounters,
  ) : _encounters = _classifier.indexEncounters(encounters);

  final SpecialtyClassifier _classifier;
  final List<MedicalSpecialty> specialties;
  final EncounterSpecialties _encounters;

  bool matches(IFhirResource resource) {
    final override = MedicalSpecialty.values
        .where((s) => s.name == resource.specialtyOverride)
        .firstOrNull;
    final classified = _classifier.classify(
      resource,
      override: override,
      encounterSpecialties: _encounters,
    );
    return specialties.any(classified.contains);
  }
}
