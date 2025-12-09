import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:health_wallet/features/scan/domain/entity/mapping_resources/mapped_property.dart';
import 'package:health_wallet/features/scan/domain/entity/mapping_resources/mapping_resource.dart';
import 'package:health_wallet/features/scan/domain/entity/text_field_descriptor.dart';
import 'package:health_wallet/features/records/domain/entity/i_fhir_resource.dart';
import 'package:health_wallet/features/records/domain/entity/medication_statement/medication_statement.dart';
import 'package:fhir_r4/fhir_r4.dart' as fhir_r4;
import 'package:uuid/uuid.dart';

part 'mapping_medication_statement.freezed.dart';

@freezed
class MappingMedicationStatement
    with _$MappingMedicationStatement
    implements MappingResource {
  const MappingMedicationStatement._();

  const factory MappingMedicationStatement({
    @Default('') String id,
    @Default(MappedProperty()) MappedProperty medicationName,
    @Default(MappedProperty()) MappedProperty dosage,
    @Default(MappedProperty()) MappedProperty reason,
  }) = _MappingMedicationStatement;

  factory MappingMedicationStatement.fromJson(Map<String, dynamic> json) {
    return MappingMedicationStatement(
      id: json["id"] ?? const Uuid().v4(),
      medicationName: MappedProperty.fromJson(json['medicationName']),
      dosage: MappedProperty.fromJson(json['dosage']),
      reason: MappedProperty.fromJson(json['reason']),
    );
  }

  factory MappingMedicationStatement.empty() {
    return MappingMedicationStatement(
      id: const Uuid().v4(),
      medicationName: MappedProperty.empty(),
      dosage: MappedProperty.empty(),
      reason: MappedProperty.empty(),
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'resourceType': 'MedicationStatement',
        'medicationName': medicationName.toJson(),
        'dosage': dosage.toJson(),
        'reason': reason.toJson(),
      };

  @override
  IFhirResource toFhirResource({
    String? sourceId,
    String? encounterId,
    String? subjectId,
  }) {
    fhir_r4.MedicationStatement medicationStatement =
        fhir_r4.MedicationStatement(
      medicationX: fhir_r4.CodeableConcept(
          text: fhir_r4.FhirString(medicationName.value)),
      dosage: [
        fhir_r4.Dosage(text: fhir_r4.FhirString(dosage.value)),
      ],
      reasonCode: [
        fhir_r4.CodeableConcept(text: fhir_r4.FhirString(reason.value)),
      ],
      subject: fhir_r4.Reference(
          reference: fhir_r4.FhirString('Patient/$subjectId')),
      status: fhir_r4.MedicationStatementStatusCodes.unknown,
    );

    Map<String, dynamic> rawResource = medicationStatement.toJson();

    return MedicationStatement(
      id: id,
      resourceId: id,
      title: medicationName.value,
      sourceId: sourceId ?? '',
      encounterId: encounterId ?? '',
      subjectId: subjectId ?? '',
      rawResource: rawResource,
      medicationX: medicationStatement.medicationX,
      dosage: medicationStatement.dosage,
      reasonCode: medicationStatement.reasonCode,
    );
  }

  @override
  Map<String, TextFieldDescriptor> getFieldDescriptors() => {
        'medicationName': TextFieldDescriptor(
          label: 'Medication Name',
          value: medicationName.value,
          confidenceLevel: medicationName.confidenceLevel,
        ),
        'dosage': TextFieldDescriptor(
          label: 'Dosage',
          value: dosage.value,
          confidenceLevel: dosage.confidenceLevel,
        ),
        'reason': TextFieldDescriptor(
          label: 'Reason',
          value: reason.value,
          confidenceLevel: reason.confidenceLevel,
        ),
      };

  @override
  MappingResource copyWithMap(Map<String, dynamic> newValues) =>
      MappingMedicationStatement(
        id: id,
        medicationName: MappedProperty(
          value: newValues['medicationName'] ?? medicationName.value,
          confidenceLevel: newValues['medicationName'] != null
              ? 1
              : medicationName.confidenceLevel,
        ),
        dosage: MappedProperty(
          value: newValues['dosage'] ?? dosage.value,
          confidenceLevel:
              newValues['dosage'] != null ? 1 : dosage.confidenceLevel,
        ),
        reason: MappedProperty(
          value: newValues['reason'] ?? reason.value,
          confidenceLevel:
              newValues['reason'] != null ? 1 : reason.confidenceLevel,
        ),
      );

  @override
  String get label => 'Medication Statement';

  @override
  MappingResource populateConfidence(String inputText) => copyWith(
        medicationName: medicationName.calculateConfidence(inputText),
        dosage: dosage.calculateConfidence(inputText),
        reason: reason.calculateConfidence(inputText),
      );

  @override
  bool get isValid =>
      medicationName.isValid || dosage.isValid || reason.isValid;
}
