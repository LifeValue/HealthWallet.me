import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:health_wallet/core/utils/validator.dart';
import 'package:health_wallet/features/scan/domain/entity/mapping_resources/mapped_property.dart';
import 'package:health_wallet/features/scan/domain/entity/mapping_resources/mapping_resource.dart';
import 'package:health_wallet/features/scan/domain/entity/text_field_descriptor.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:fhir_r4/fhir_r4.dart' as fhir_r4;
import 'package:uuid/uuid.dart';

part 'mapping_condition.freezed.dart';

@freezed
class MappingCondition with _$MappingCondition implements MappingResource {
  const MappingCondition._();

  const factory MappingCondition({
    @Default('') String id,
    @Default(MappedProperty()) MappedProperty conditionName,
    @Default(MappedProperty()) MappedProperty onsetDateTime,
    @Default(MappedProperty()) MappedProperty clinicalStatus,
  }) = _MappingCondition;

  factory MappingCondition.fromJson(Map<String, dynamic> json) {
    final rawOnset = MappedProperty.fromJson(json['onsetDateTime']);
    return MappingCondition(
      id: json["id"] ?? const Uuid().v4(),
      conditionName: MappedProperty.fromJson(json['conditionName']),
      onsetDateTime: rawOnset.copyWith(
        value: MappingResource.normalizeDateValue(rawOnset.value),
      ),
      clinicalStatus: MappedProperty.fromJson(json['clinicalStatus']),
    );
  }

  factory MappingCondition.empty() {
    return MappingCondition(
      id: const Uuid().v4(),
      conditionName: MappedProperty.empty(),
      onsetDateTime: MappedProperty.empty(),
      clinicalStatus: MappedProperty.empty(),
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'resourceType': 'Condition',
        'conditionName': conditionName.toJson(),
        'onsetDateTime': onsetDateTime.toJson(),
        'clinicalStatus': clinicalStatus.toJson(),
      };

  @override
  IFhirResource toFhirResource({
    String? sourceId,
    String? encounterId,
    String? subjectId,
  }) {
    fhir_r4.Condition condition = fhir_r4.Condition(
      code: fhir_r4.CodeableConcept(
          text: fhir_r4.FhirString(conditionName.value)),
      onsetX: fhir_r4.FhirDateTime.fromString(onsetDateTime.value),
      clinicalStatus: fhir_r4.CodeableConcept(
          text: fhir_r4.FhirString(clinicalStatus.value)),
      subject: fhir_r4.Reference(
          reference: fhir_r4.FhirString('Patient/$subjectId')),
      encounter: fhir_r4.Reference(
          reference: fhir_r4.FhirString('Encounter/$encounterId')),
    );

    Map<String, dynamic> rawResource = condition.toJson();

    return Condition(
      id: id,
      resourceId: id,
      title: conditionName.value,
      date: DateTime.tryParse(onsetDateTime.value),
      sourceId: sourceId ?? '',
      encounterId: encounterId ?? '',
      subjectId: subjectId ?? '',
      rawResource: rawResource,
      code: condition.code,
      onsetX: condition.onsetX,
      clinicalStatus: condition.clinicalStatus,
    );
  }

  @override
  Map<String, TextFieldDescriptor> getFieldDescriptors() => {
        'conditionName': TextFieldDescriptor(
          label: 'Condition Name',
          value: conditionName.value,
          confidenceLevel: conditionName.confidenceLevel,
        ),
        'onsetDateTime': TextFieldDescriptor(
          label: 'Onset Date',
          value: onsetDateTime.value,
          confidenceLevel: onsetDateTime.confidenceLevel,
          fieldType: FieldType.date,
          validators: [nonEmptyValidator, dateValidator],
        ),
        'clinicalStatus': TextFieldDescriptor(
          label: 'Clinical Status',
          value: clinicalStatus.value,
          confidenceLevel: clinicalStatus.confidenceLevel,
        ),
      };

  @override
  MappingResource copyWithMap(Map<String, dynamic> newValues) =>
      MappingCondition(
        id: id,
        conditionName: MappedProperty(
          value: newValues['conditionName'] ?? conditionName.value,
          confidenceLevel: newValues['conditionName'] != null
              ? 1
              : conditionName.confidenceLevel,
        ),
        onsetDateTime: MappedProperty(
          value: newValues['onsetDateTime'] ?? onsetDateTime.value,
          confidenceLevel: newValues['onsetDateTime'] != null
              ? 1
              : onsetDateTime.confidenceLevel,
        ),
        clinicalStatus: MappedProperty(
          value: newValues['clinicalStatus'] ?? clinicalStatus.value,
          confidenceLevel: newValues['clinicalStatus'] != null
              ? 1
              : clinicalStatus.confidenceLevel,
        ),
      );

  @override
  String get label => 'Condition';

  @override
  MappingResource populateConfidence(String inputText) => copyWith(
        conditionName: conditionName.calculateConfidence(inputText),
        onsetDateTime: onsetDateTime.calculateConfidence(inputText),
        clinicalStatus: clinicalStatus.calculateConfidence(inputText),
      );

  @override
  bool get isValid =>
      conditionName.isValid || onsetDateTime.isValid || clinicalStatus.isValid;
}
