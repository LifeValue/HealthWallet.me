import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/core/utils/date_format_utils.dart';
import 'package:health_wallet/core/utils/validator.dart';
import 'package:health_wallet/features/home/domain/entities/medical_specialty.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapped_property.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_resource.dart';
import 'package:health_wallet/features/processing/domain/entity/text_field_descriptor.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:fhir_r4/fhir_r4.dart' as fhir_r4;
import 'package:uuid/uuid.dart';

part 'mapping_encounter.freezed.dart';

@freezed
class MappingEncounter with _$MappingEncounter implements MappingResource {
  const MappingEncounter._();

  const factory MappingEncounter({
    @Default('') String id,
    @Default(MappedProperty()) MappedProperty encounterType,
    @Default(MappedProperty()) MappedProperty periodStart,
    @Default(MappedProperty()) MappedProperty specialty,
  }) = _MappingEncounter;

  factory MappingEncounter.fromJson(Map<String, dynamic> json) {
    final rawPeriodStart = MappedProperty.fromJson(json['periodStart']);
    return MappingEncounter(
      id: json["id"] ?? const Uuid().v4(),
      encounterType: MappedProperty.fromJson(json['encounterType']),
      periodStart: rawPeriodStart.copyWith(
        value: MappingResource.normalizeDateValue(rawPeriodStart.value),
      ),
      specialty: json['specialty'] != null
          ? MappedProperty.fromJson(json['specialty'])
          : const MappedProperty(),
    );
  }

  factory MappingEncounter.empty() {
    return MappingEncounter(
      id: const Uuid().v4(),
      encounterType: MappedProperty.empty(),
      periodStart: MappedProperty.empty(),
      specialty: MappedProperty.empty(),
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
        value: DateFormatUtils.isoCompact(encounter.date ?? DateTime.now()),
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
        'specialty': specialty.toJson(),
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
        serviceType: specialty.value.isNotEmpty
            ? fhir_r4.CodeableConcept(
                coding: [
                  fhir_r4.Coding(
                    system: fhir_r4.FhirUri('http://snomed.info/sct'),
                    code: fhir_r4.FhirCode(_getSnomedCodeForSpecialty(specialty.value)),
                    display: fhir_r4.FhirString(specialty.value),
                  ),
                ],
                text: fhir_r4.FhirString(specialty.value),
              )
            : null,
        meta: specialty.value.isNotEmpty
            ? fhir_r4.FhirMeta(
                tag: [
                  fhir_r4.Coding(
                    system: fhir_r4.FhirUri('http://healthwallet.me/specialty'),
                    code: fhir_r4.FhirCode(_getSpecialtyEnumName(specialty.value)),
                    display: fhir_r4.FhirString(specialty.value),
                  ),
                ],
              )
            : null,
        period: periodStart.value.isNotEmpty
            ? fhir_r4.Period(
                start: fhir_r4.FhirDateTime.fromString(periodStart.value),
              )
            : null,
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

  static Map<String, String> localizedLabels(AppLocalizations l10n) => {
        'encounterType': l10n.labelEncounterName,
        'periodStart': l10n.labelStartDate,
        'specialty': l10n.labelSpecialty,
      };

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
        'specialty': TextFieldDescriptor(
          label: 'Specialty',
          value: specialty.value,
          confidenceLevel: specialty.confidenceLevel,
          fieldType: FieldType.dropdown,
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
        specialty: MappedProperty(
          value: newValues['specialty'] ?? specialty.value,
          confidenceLevel: newValues['specialty'] != null
              ? 1
              : specialty.confidenceLevel,
        ),
      );

  @override
  String get label => 'Encounter';

  @override
  MappingResource populateConfidence(String inputText) => copyWith(
        encounterType: encounterType.calculateConfidence(inputText),
        periodStart: periodStart.calculateDateConfidence(inputText),
        specialty: specialty.calculateConfidence(inputText),
      );

  @override
  bool get isValid => encounterType.isValid || periodStart.isValid;

  static String _getSnomedCodeForSpecialty(String displayName) {
    final match = MedicalSpecialty.values
        .where((s) => s.displayName == displayName)
        .firstOrNull;
    return match?.snomedSpecialtyCode ?? '394802001';
  }

  static String _getSpecialtyEnumName(String displayName) {
    final match = MedicalSpecialty.values
        .where((s) => s.displayName == displayName)
        .firstOrNull;
    return match?.name ?? 'generalCare';
  }
}
