import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:health_wallet/features/scan/domain/entity/mapping_resources/mapped_property.dart';
import 'package:health_wallet/features/scan/domain/entity/mapping_resources/mapping_resource.dart';
import 'package:health_wallet/features/scan/domain/entity/text_field_descriptor.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:fhir_r4/fhir_r4.dart' as fhir_r4;
import 'package:uuid/uuid.dart';

part 'mapping_observation.freezed.dart';

@freezed
class MappingObservation with _$MappingObservation implements MappingResource {
  const MappingObservation._();

  const factory MappingObservation({
    @Default('') String id,
    @Default(MappedProperty()) MappedProperty observationName,
    @Default(MappedProperty()) MappedProperty value,
    @Default(MappedProperty()) MappedProperty unit,
  }) = _MappingObservation;

  factory MappingObservation.fromJson(Map<String, dynamic> json) {
    return MappingObservation(
      id: json["id"] ?? const Uuid().v4(),
      observationName: MappedProperty.fromJson(json['observationName']),
      value: MappedProperty.fromJson(json['value']),
      unit: MappedProperty.fromJson(json['unit']),
    );
  }

  factory MappingObservation.empty() {
    return MappingObservation(
      id: const Uuid().v4(),
      observationName: MappedProperty.empty(),
      value: MappedProperty.empty(),
      unit: MappedProperty.empty(),
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'resourceType': 'Observation',
        'observationName': observationName.toJson(),
        'value': value.toJson(),
        'unit': unit.toJson(),
      };

  @override
  IFhirResource toFhirResource({
    String? sourceId,
    String? encounterId,
    String? subjectId,
  }) {
    fhir_r4.Observation observation = fhir_r4.Observation(
      code: fhir_r4.CodeableConcept(
          text: fhir_r4.FhirString(observationName.value)),
      valueX: fhir_r4.Quantity(
        value: fhir_r4.FhirDecimal(double.tryParse(value.value)),
        unit: fhir_r4.FhirString(unit.value),
      ),
      status: fhir_r4.ObservationStatus.unknown,
      subject: fhir_r4.Reference(
          reference: fhir_r4.FhirString('Patient/$subjectId')),
      encounter: fhir_r4.Reference(
          reference: fhir_r4.FhirString('Encounter/$encounterId')),
    );

    Map<String, dynamic> rawResource = observation.toJson();

    return Observation(
      id: id,
      resourceId: id,
      title: observationName.value,
      sourceId: sourceId ?? '',
      encounterId: encounterId ?? '',
      subjectId: subjectId ?? '',
      rawResource: rawResource,
      code: observation.code,
      valueX: observation.valueX,
    );
  }

  @override
  Map<String, TextFieldDescriptor> getFieldDescriptors() => {
        'observationName': TextFieldDescriptor(
          label: 'Observation name',
          value: observationName.value,
          confidenceLevel: observationName.confidenceLevel,
        ),
        'value': TextFieldDescriptor(
          label: 'Value',
          value: value.value,
          confidenceLevel: value.confidenceLevel,
        ),
        'unit': TextFieldDescriptor(
          label: 'Unit',
          value: unit.value,
          confidenceLevel: unit.confidenceLevel,
        ),
      };

  @override
  MappingResource copyWithMap(Map<String, dynamic> newValues) =>
      MappingObservation(
        id: id,
        observationName: MappedProperty(
          value: newValues['observationName'] ?? observationName.value,
          confidenceLevel: newValues['observationName'] != null
              ? 1
              : observationName.confidenceLevel,
        ),
        value: MappedProperty(
          value: newValues['value'] ?? value.value,
          confidenceLevel:
              newValues['value'] != null ? 1 : value.confidenceLevel,
        ),
        unit: MappedProperty(
          value: newValues['unit'] ?? unit.value,
          confidenceLevel: newValues['unit'] != null ? 1 : unit.confidenceLevel,
        ),
      );

  @override
  String get label => 'Observation';

  @override
  MappingResource populateConfidence(String inputText) => copyWith(
        observationName: observationName.calculateConfidence(inputText),
        value: value.calculateConfidence(inputText),
        unit: unit.calculateConfidence(inputText),
      );

  @override
  bool get isValid => observationName.isValid || value.isValid || unit.isValid;
}
