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
    @Default(MappedProperty()) MappedProperty referenceRange,
    @Default(MappedProperty()) MappedProperty interpretation,
  }) = _MappingObservation;

  factory MappingObservation.fromJson(Map<String, dynamic> json) {
    return MappingObservation(
      id: json["id"] ?? const Uuid().v4(),
      observationName: MappedProperty.fromJson(json['observationName']),
      value: MappedProperty.fromJson(json['value']),
      unit: MappedProperty.fromJson(json['unit']),
      referenceRange: MappedProperty.fromJson(json['referenceRange']),
      interpretation: MappedProperty.fromJson(json['interpretation']),
    );
  }

  factory MappingObservation.empty() {
    return MappingObservation(
      id: const Uuid().v4(),
      observationName: MappedProperty.empty(),
      value: MappedProperty.empty(),
      unit: MappedProperty.empty(),
      referenceRange: MappedProperty.empty(),
      interpretation: MappedProperty.empty(),
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'resourceType': 'Observation',
        'observationName': observationName.toJson(),
        'value': value.toJson(),
        'unit': unit.toJson(),
        'referenceRange': referenceRange.toJson(),
        'interpretation': interpretation.toJson(),
      };

  @override
  IFhirResource toFhirResource({
    String? sourceId,
    String? encounterId,
    String? subjectId,
  }) {
    List<fhir_r4.ObservationReferenceRange>? fhirReferenceRange;
    if (referenceRange.value.isNotEmpty) {
      fhirReferenceRange = [
        fhir_r4.ObservationReferenceRange(
          text: fhir_r4.FhirString(referenceRange.value),
        ),
      ];
    }

    List<fhir_r4.CodeableConcept>? fhirInterpretation;
    if (interpretation.value.isNotEmpty) {
      final code = switch (interpretation.value.toLowerCase()) {
        'high' || 'h' => 'H',
        'low' || 'l' => 'L',
        _ => 'N',
      };
      final display = switch (code) {
        'H' => 'High',
        'L' => 'Low',
        _ => 'Normal',
      };
      fhirInterpretation = [
        fhir_r4.CodeableConcept(
          coding: [
            fhir_r4.Coding(
              system: fhir_r4.FhirUri(
                  'http://terminology.hl7.org/CodeSystem/v3-ObservationInterpretation'),
              code: fhir_r4.FhirCode(code),
              display: fhir_r4.FhirString(display),
            ),
          ],
          text: fhir_r4.FhirString(display),
        ),
      ];
    }

    final numericValue = double.tryParse(value.value);
    final fhir_r4.ValueXObservation? valueX;
    if (numericValue != null) {
      valueX = fhir_r4.Quantity(
        value: fhir_r4.FhirDecimal(numericValue),
        unit: fhir_r4.FhirString(unit.value),
      );
    } else if (value.value.isNotEmpty) {
      valueX = fhir_r4.FhirString(value.value);
    } else {
      valueX = null;
    }

    fhir_r4.Observation observation = fhir_r4.Observation(
      code: fhir_r4.CodeableConcept(
          text: fhir_r4.FhirString(observationName.value)),
      valueX: valueX,
      status: fhir_r4.ObservationStatus.unknown,
      subject: fhir_r4.Reference(
          reference: fhir_r4.FhirString('Patient/$subjectId')),
      encounter: fhir_r4.Reference(
          reference: fhir_r4.FhirString('Encounter/$encounterId')),
      referenceRange: fhirReferenceRange,
      interpretation: fhirInterpretation,
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
        'referenceRange': TextFieldDescriptor(
          label: 'Reference Range',
          value: referenceRange.value,
          confidenceLevel: referenceRange.confidenceLevel,
        ),
        'interpretation': TextFieldDescriptor(
          label: 'Interpretation',
          value: interpretation.value,
          confidenceLevel: interpretation.confidenceLevel,
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
        referenceRange: MappedProperty(
          value: newValues['referenceRange'] ?? referenceRange.value,
          confidenceLevel: newValues['referenceRange'] != null
              ? 1
              : referenceRange.confidenceLevel,
        ),
        interpretation: MappedProperty(
          value: newValues['interpretation'] ?? interpretation.value,
          confidenceLevel: newValues['interpretation'] != null
              ? 1
              : interpretation.confidenceLevel,
        ),
      );

  @override
  String get label => 'Observation';

  @override
  MappingResource populateConfidence(String inputText) => copyWith(
        observationName: observationName.calculateConfidence(inputText),
        value: value.calculateConfidence(inputText),
        unit: unit.calculateConfidence(inputText),
        referenceRange: referenceRange.calculateConfidence(inputText),
        interpretation: interpretation.calculateConfidence(inputText),
      );

  @override
  bool get isValid =>
      observationName.isValid ||
      value.isValid ||
      unit.isValid ||
      referenceRange.isValid ||
      interpretation.isValid;
}
