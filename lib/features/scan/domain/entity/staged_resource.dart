import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:health_wallet/features/records/domain/entity/encounter/encounter.dart';
import 'package:health_wallet/features/records/domain/entity/patient/patient.dart';
import 'package:health_wallet/features/scan/domain/entity/mapping_resources/mapping_encounter.dart';
import 'package:health_wallet/features/scan/domain/entity/mapping_resources/mapping_patient.dart';
import 'package:health_wallet/features/sync/data/dto/fhir_resource_dto.dart';

part 'staged_resource.freezed.dart';

@freezed

/// Class to hold patient and encounter resources in their possible states
///
/// D - Draft ([DraftPatient] | [DraftEncounter])
///
/// F - FHIR ([Patient] | [Encounter])
class StagedResource<D, F> with _$StagedResource<D, F> {
  const StagedResource._();

  const factory StagedResource({
    D? draft,
    F? existing,
    @Default(ImportMode.createNew) ImportMode mode,
  }) = _StagedResource<D, F>;

  bool get hasSelection =>
      mode == ImportMode.createNew ? draft != null : existing != null;
}

enum ImportMode {
  createNew,
  linkExisting;

  factory ImportMode.fromString(String string) {
    switch (string) {
      case "createNew":
        return ImportMode.createNew;
      default:
        return ImportMode.linkExisting;
    }
  }

  @override
  String toString() {
    switch (this) {
      case ImportMode.createNew:
        return "createNew";
      case ImportMode.linkExisting:
        return "linkExisting";
    }
  }
}

typedef StagedPatient = StagedResource<MappingPatient, Patient>;
typedef StagedEncounter = StagedResource<MappingEncounter, Encounter>;

Map<String, dynamic> stagedPatientToJson(StagedPatient patient) => {
      'draft': patient.draft?.toJson(),
      'existing': patient.existing?.toDto().toJson(),
      'mode': patient.mode.toString(),
    };

Map<String, dynamic> stagedEncounterToJson(StagedEncounter encounter) => {
      'draft': encounter.draft?.toJson(),
      'existing': encounter.existing?.toDto().toJson(),
      'mode': encounter.mode.toString(),
    };

StagedPatient stagedPatientFromJson(Map<String, dynamic> json) => StagedPatient(
      draft:
          json['draft'] != null ? MappingPatient.fromJson(json['draft']) : null,
      existing: json['existing'] != null
          ? Patient.fromDto(FhirResourceDto.fromJson(json['existing']))
          : null,
      mode: ImportMode.fromString(json['mode']),
    );

StagedEncounter stagedEncounterFromJson(Map<String, dynamic> json) =>
    StagedEncounter(
      draft: json['draft'] != null
          ? MappingEncounter.fromJson(json['draft'] ?? {})
          : null,
      existing: json['existing'] != null
          ? Encounter.fromDto(FhirResourceDto.fromJson(json['existing']))
          : null,
      mode: ImportMode.fromString(json['mode']),
    );
