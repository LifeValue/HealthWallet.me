import 'package:health_wallet/features/home/domain/entities/medical_specialty.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';

abstract class SpecialtyClassifier {
  Set<MedicalSpecialty> classify(IFhirResource resource, {MedicalSpecialty? override});
  void buildEncounterIndex(List<IFhirResource> allResources);
}
