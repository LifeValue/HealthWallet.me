import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:health_wallet/core/utils/validator.dart';
import 'package:health_wallet/features/scan/domain/entity/mapping_resources/mapped_property.dart';
import 'package:health_wallet/features/scan/domain/entity/mapping_resources/mapping_resource.dart';
import 'package:health_wallet/features/scan/domain/entity/text_field_descriptor.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:fhir_r4/fhir_r4.dart' as fhir_r4;
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

part 'mapping_encounter.freezed.dart';

@freezed
class MappingEncounter with _$MappingEncounter implements MappingResource {
  const MappingEncounter._();

  const factory MappingEncounter({
    @Default('') String id,
    @Default(MappedProperty()) MappedProperty encounterType,
    @Default(MappedProperty()) MappedProperty periodStart,
  }) = _MappingEncounter;

  factory MappingEncounter.fromJson(Map<String, dynamic> json) {
    final rawPeriodStart = MappedProperty.fromJson(json['periodStart']);
    return MappingEncounter(
      id: json["id"] ?? const Uuid().v4(),
      encounterType: MappedProperty.fromJson(json['encounterType']),
      periodStart: rawPeriodStart.copyWith(
        value: MappingResource.normalizeDateValue(rawPeriodStart.value),
      ),
    );
  }

  factory MappingEncounter.empty() {
    return MappingEncounter(
      id: const Uuid().v4(),
      encounterType: MappedProperty.empty(),
      periodStart: MappedProperty.empty(),
    );
  }

  factory MappingEncounter.fromFhirResource(Encounter encounter) {
    return MappingEncounter(
      id: encounter.id,
      encounterType: MappedProperty(
        value: encounter.displayTitle,
        confidenceLevel: 1,
      ),
      periodStart: MappedProperty(
        value: DateFormat('yyyy-MM-dd').format(
          encounter.date ?? DateTime.now(),
        ),
        confidenceLevel: 1,
      ),
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'resourceType': 'Encounter',
        'encounterType': encounterType.toJson(),
        'periodStart': periodStart.toJson(),
      };

  @override
  IFhirResource toFhirResource({
    String? sourceId,
    String? encounterId,
    String? subjectId,
  }) {
    fhir_r4.Encounter encounter = fhir_r4.Encounter(
        type: [
          fhir_r4.CodeableConcept(text: fhir_r4.FhirString(encounterType.value))
        ],
        period: fhir_r4.Period(
          start: fhir_r4.FhirDateTime.fromString(periodStart.value),
        ),
        status: fhir_r4.EncounterStatus.unknown,
        class_: fhir_r4.Coding(code: fhir_r4.FhirCode("AMB")),
        subject: fhir_r4.Reference(
            reference: fhir_r4.FhirString('Patient/$subjectId')));

    Map<String, dynamic> rawResource = encounter.toJson();

    return Encounter(
      id: id,
      resourceId: id,
      title: encounterType.value,
      date: DateTime.tryParse(periodStart.value),
      sourceId: sourceId ?? '',
      encounterId: encounterId ?? '',
      subjectId: subjectId ?? '',
      rawResource: rawResource,
      type: encounter.type,
      period: encounter.period,
    );
  }

  @override
  Map<String, TextFieldDescriptor> getFieldDescriptors() => {
        'encounterType': TextFieldDescriptor(
          label: 'Encounter Name',
          value: encounterType.value,
          confidenceLevel: encounterType.confidenceLevel,
          validators: [nonEmptyValidator],
        ),
        'periodStart': TextFieldDescriptor(
          label: 'Start Date',
          value: periodStart.value,
          confidenceLevel: periodStart.confidenceLevel,
          fieldType: FieldType.date,
          validators: [nonEmptyValidator, dateValidator],
        ),
      };

  @override
  MappingResource copyWithMap(Map<String, dynamic> newValues) =>
      MappingEncounter(
        id: id,
        encounterType: MappedProperty(
          value: newValues['encounterType'] ?? encounterType.value,
          confidenceLevel: newValues['encounterType'] != null
              ? 1
              : encounterType.confidenceLevel,
        ),
        periodStart: MappedProperty(
          value: newValues['periodStart'] ?? periodStart.value,
          confidenceLevel: newValues['periodStart'] != null
              ? 1
              : periodStart.confidenceLevel,
        ),
      );

  @override
  String get label => 'Encounter';

  @override
  MappingResource populateConfidence(String inputText) => copyWith(
        encounterType: encounterType.calculateConfidence(inputText),
        periodStart: periodStart.calculateDateConfidence(inputText),
      );

  @override
  bool get isValid => encounterType.isValid || periodStart.isValid;
}
