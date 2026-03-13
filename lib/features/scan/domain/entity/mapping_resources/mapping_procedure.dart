import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:health_wallet/core/utils/validator.dart';
import 'package:health_wallet/features/scan/domain/entity/mapping_resources/mapped_property.dart';
import 'package:health_wallet/features/scan/domain/entity/mapping_resources/mapping_resource.dart';
import 'package:health_wallet/features/scan/domain/entity/text_field_descriptor.dart';
import 'package:health_wallet/features/records/domain/entity/i_fhir_resource.dart';
import 'package:health_wallet/features/records/domain/entity/procedure/procedure.dart';
import 'package:fhir_r4/fhir_r4.dart' as fhir_r4;
import 'package:uuid/uuid.dart';

part 'mapping_procedure.freezed.dart';

@freezed
class MappingProcedure with _$MappingProcedure implements MappingResource {
  const MappingProcedure._();

  const factory MappingProcedure({
    @Default('') String id,
    @Default(MappedProperty()) MappedProperty procedureName,
    @Default(MappedProperty()) MappedProperty performedDateTime,
    @Default(MappedProperty()) MappedProperty reason,
  }) = _MappingProcedure;

  factory MappingProcedure.fromJson(Map<String, dynamic> json) {
    final rawPerformed = MappedProperty.fromJson(json['performedDateTime']);
    return MappingProcedure(
      id: json["id"] ?? const Uuid().v4(),
      procedureName: MappedProperty.fromJson(json['procedureName']),
      performedDateTime: rawPerformed.copyWith(
        value: MappingResource.normalizeDateValue(rawPerformed.value),
      ),
      reason: MappedProperty.fromJson(json['reason']),
    );
  }

  factory MappingProcedure.empty() {
    return MappingProcedure(
      id: const Uuid().v4(),
      procedureName: MappedProperty.empty(),
      performedDateTime: MappedProperty.empty(),
      reason: MappedProperty.empty(),
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'resourceType': 'Procedure',
        'procedureName': procedureName.toJson(),
        'performedDateTime': performedDateTime.toJson(),
        'reason': reason.toJson(),
      };

  @override
  IFhirResource toFhirResource({
    String? sourceId,
    String? encounterId,
    String? subjectId,
  }) {
    fhir_r4.Procedure procedure = fhir_r4.Procedure(
      code: fhir_r4.CodeableConcept(
          text: fhir_r4.FhirString(procedureName.value)),
      performedX: performedDateTime.value.isNotEmpty
          ? fhir_r4.FhirDateTime.fromString(performedDateTime.value)
          : null,
      reasonCode: [
        fhir_r4.CodeableConcept(text: fhir_r4.FhirString(reason.value))
      ],
      subject: fhir_r4.Reference(
          reference: fhir_r4.FhirString('Patient/$subjectId')),
      status: fhir_r4.EventStatus.unknown,
      encounter: fhir_r4.Reference(
          reference: fhir_r4.FhirString('Encounter/$encounterId')),
    );

    Map<String, dynamic> rawResource = procedure.toJson();

    return Procedure(
      id: id,
      resourceId: id,
      title: procedureName.value,
      date: DateTime.tryParse(performedDateTime.value),
      sourceId: sourceId ?? '',
      encounterId: encounterId ?? '',
      subjectId: subjectId ?? '',
      rawResource: rawResource,
      code: procedure.code,
      performedX: procedure.performedX,
      reasonCode: procedure.reasonCode,
    );
  }

  @override
  Map<String, TextFieldDescriptor> getFieldDescriptors() => {
        'procedureName': TextFieldDescriptor(
          label: 'Procedure Name',
          value: procedureName.value,
          confidenceLevel: procedureName.confidenceLevel,
        ),
        'performedDateTime': TextFieldDescriptor(
          label: 'Performed Date',
          value: performedDateTime.value,
          confidenceLevel: performedDateTime.confidenceLevel,
          fieldType: FieldType.date,
        ),
        'reason': TextFieldDescriptor(
          label: 'Reason',
          value: reason.value,
          confidenceLevel: reason.confidenceLevel,
        ),
      };

  @override
  MappingResource copyWithMap(Map<String, dynamic> newValues) =>
      MappingProcedure(
        id: id,
        procedureName: MappedProperty(
          value: newValues['procedureName'] ?? procedureName.value,
          confidenceLevel: newValues['procedureName'] != null
              ? 1
              : procedureName.confidenceLevel,
        ),
        performedDateTime: MappedProperty(
          value: newValues['performedDateTime'] ?? performedDateTime.value,
          confidenceLevel: newValues['performedDateTime'] != null
              ? 1
              : performedDateTime.confidenceLevel,
        ),
        reason: MappedProperty(
          value: newValues['reason'] ?? reason.value,
          confidenceLevel:
              newValues['reason'] != null ? 1 : reason.confidenceLevel,
        ),
      );

  @override
  String get label => 'Procedure';

  @override
  MappingResource populateConfidence(String inputText) => copyWith(
        procedureName: procedureName.calculateConfidence(inputText),
        performedDateTime: performedDateTime.calculateDateConfidence(inputText),
        reason: reason.calculateConfidence(inputText),
      );

  @override
  bool get isValid =>
      performedDateTime.isValid || performedDateTime.isValid || reason.isValid;
}
