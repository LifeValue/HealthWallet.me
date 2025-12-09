import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:health_wallet/features/scan/domain/entity/mapping_resources/mapped_property.dart';
import 'package:health_wallet/features/scan/domain/entity/mapping_resources/mapping_resource.dart';
import 'package:health_wallet/features/scan/domain/entity/text_field_descriptor.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:fhir_r4/fhir_r4.dart' as fhir_r4;
import 'package:uuid/uuid.dart';

part 'mapping_allergy_intolerance.freezed.dart';

@freezed
class MappingAllergyIntolerance
    with _$MappingAllergyIntolerance
    implements MappingResource {
  const MappingAllergyIntolerance._();

  const factory MappingAllergyIntolerance({
    @Default('') String id,
    @Default(MappedProperty()) MappedProperty substance,
    @Default(MappedProperty()) MappedProperty manifestation,
    @Default(MappedProperty()) MappedProperty category,
  }) = _MappingAllergyIntolerance;

  factory MappingAllergyIntolerance.fromJson(Map<String, dynamic> json) {
    return MappingAllergyIntolerance(
      id: json["id"] ?? const Uuid().v4(),
      substance: MappedProperty.fromJson(json['substance']),
      manifestation: MappedProperty.fromJson(json['manifestation']),
      category: MappedProperty.fromJson(json['category']),
    );
  }

  factory MappingAllergyIntolerance.empty() {
    return MappingAllergyIntolerance(
      id: const Uuid().v4(),
      substance: MappedProperty.empty(),
      manifestation: MappedProperty.empty(),
      category: MappedProperty.empty(),
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'resourceType': 'AllergyIntolerance',
        'substance': substance.toJson(),
        'manifestation': manifestation.toJson(),
        'category': category.toJson(),
      };

  @override
  IFhirResource toFhirResource({
    String? sourceId,
    String? encounterId,
    String? subjectId,
  }) {
    fhir_r4.AllergyIntolerance allergyIntolerance = fhir_r4.AllergyIntolerance(
      code: fhir_r4.CodeableConcept(text: fhir_r4.FhirString(substance.value)),
      reaction: [
        fhir_r4.AllergyIntoleranceReaction(
          manifestation: [
            fhir_r4.CodeableConcept(
                text: fhir_r4.FhirString(manifestation.value))
          ],
        ),
      ],
      category: [fhir_r4.AllergyIntoleranceCategory(category.value)],
      patient: fhir_r4.Reference(
          reference: fhir_r4.FhirString('Patient/$subjectId')),
      encounter: fhir_r4.Reference(
          reference: fhir_r4.FhirString('Encounter/$encounterId')),
    );

    Map<String, dynamic> rawResource = allergyIntolerance.toJson();

    return AllergyIntolerance(
      id: id,
      resourceId: id,
      title: substance.value,
      sourceId: sourceId ?? '',
      encounterId: encounterId ?? '',
      subjectId: subjectId ?? '',
      rawResource: rawResource,
      code: allergyIntolerance.code,
      reaction: allergyIntolerance.reaction,
      category: allergyIntolerance.category,
    );
  }

  @override
  Map<String, TextFieldDescriptor> getFieldDescriptors() => {
        'substance': TextFieldDescriptor(
          label: 'Substance',
          value: substance.value,
          confidenceLevel: substance.confidenceLevel,
        ),
        'manifestation': TextFieldDescriptor(
          label: 'Manifestation',
          value: manifestation.value,
          confidenceLevel: manifestation.confidenceLevel,
        ),
        'category': TextFieldDescriptor(
          label: 'Category',
          value: category.value,
          confidenceLevel: category.confidenceLevel,
        ),
      };

  @override
  MappingResource copyWithMap(Map<String, dynamic> newValues) =>
      MappingAllergyIntolerance(
        id: id,
        substance: MappedProperty(
          value: newValues['substance'] ?? substance.value,
          confidenceLevel:
              newValues['substance'] != null ? 1 : substance.confidenceLevel,
        ),
        manifestation: MappedProperty(
          value: newValues['manifestation'] ?? manifestation.value,
          confidenceLevel: newValues['manifestation'] != null
              ? 1
              : manifestation.confidenceLevel,
        ),
        category: MappedProperty(
          value: newValues['category'] ?? category.value,
          confidenceLevel:
              newValues['category'] != null ? 1 : category.confidenceLevel,
        ),
      );

  @override
  String get label => 'Allergy Intolerance';

  @override
  MappingResource populateConfidence(String inputText) => copyWith(
        substance: substance.calculateConfidence(inputText),
        manifestation: manifestation.calculateConfidence(inputText),
        category: category.calculateConfidence(inputText),
      );

  @override
  bool get isValid =>
      substance.isValid || manifestation.isValid || category.isValid;
}
