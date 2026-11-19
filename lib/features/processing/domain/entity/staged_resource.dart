import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:health_wallet/features/holders/domain/entity/holder_patient.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_diagnostic_report.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_encounter.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_patient.dart';
import 'package:health_wallet/features/records/domain/entity/encounter/encounter.dart';
import 'package:health_wallet/features/records/domain/entity/patient/patient.dart';
import 'package:health_wallet/features/sync/data/dto/fhir_resource_dto.dart';
import 'package:uuid/uuid.dart';

part 'staged_resource.freezed.dart';

@freezed
abstract class StagedResource<D, F> with _$StagedResource<D, F> {
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
      case 'createNew':
        return ImportMode.createNew;
      default:
        return ImportMode.linkExisting;
    }
  }

  @override
  String toString() {
    switch (this) {
      case ImportMode.createNew:
        return 'createNew';
      case ImportMode.linkExisting:
        return 'linkExisting';
    }
  }
}

typedef StagedPatient = StagedResource<MappingPatient, Patient>;
typedef StagedEncounter = StagedResource<MappingEncounter, Encounter>;
typedef StagedDiagnosticReport = StagedResource<MappingDiagnosticReport, Never>;

/// What the review says about the scan's patient, and so what saving does.
enum PatientReview {
  /// A new person, but the document names no one: a name is needed first.
  unidentified,

  /// A new person, with the details the document gives.
  newPerson,

  /// The unnamed default holder, taken to be the user: the document's
  /// details (or the ones entered) name them on save.
  you,

  /// Someone already in the wallet, as they are.
  existing,

  /// Someone already in the wallet, with details changed in the review.
  existingEdited,

  /// Someone already in the wallet, picked instead of the document's
  /// patient, whose details are kept for a swap back.
  changedTo,
}

extension StagedPatientReview on StagedPatient {
  /// Whether the linked patient is the default holder no one has named yet.
  bool get existingIsUnnamed {
    final patient = existing;
    return patient != null &&
        HolderPatient.fromRow(
          rowId: patient.id,
          resourceId: patient.resourceId,
          sourceId: patient.sourceId,
          raw: patient.rawResource,
        ).isPlaceholder;
  }

  PatientReview get review {
    if (mode == ImportMode.createNew || existing == null) {
      return draft?.isIdentified ?? false
          ? PatientReview.newPerson
          : PatientReview.unidentified;
    }
    if (existingIsUnnamed) return PatientReview.you;
    if (draft == null) return PatientReview.existing;
    return draft!.id == existing!.id
        ? PatientReview.existingEdited
        : PatientReview.changedTo;
  }

  /// The details the review shows, which are the ones saving writes, and
  /// the ones an edit in the review starts from.
  MappingPatient get shown => switch (review) {
    PatientReview.existing ||
    PatientReview.changedTo => MappingPatient.fromFhirResource(existing!),
    // Nothing read yet: empty fields, under the holder's id so they keep
    // their identity while the first one is typed.
    PatientReview.you => draft ?? MappingPatient(id: existing!.id),
    _ => draft ?? const MappingPatient(),
  };

  /// Whether the review can switch between the linked patient and a new
  /// person with the document's details.
  bool get canSwap => switch (review) {
    PatientReview.you || PatientReview.changedTo => true,
    PatientReview.newPerson || PatientReview.unidentified => existing != null,
    _ => false,
  };

  /// The other side of [canSwap]: the document's patient (or the details
  /// entered for the user) as a new person, or back. A new person never
  /// takes the linked patient's id.
  StagedPatient get swapped {
    if (mode == ImportMode.createNew) {
      return copyWith(mode: ImportMode.linkExisting);
    }
    final details = review == PatientReview.you ? shown : draft!;
    return copyWith(
      mode: ImportMode.createNew,
      draft: details.id.isEmpty || details.id == existing?.id
          ? details.copyWith(id: const Uuid().v4())
          : details,
    );
  }

  /// Whether saving must wait for a name: a new person the document does
  /// not name, who would otherwise be saved as a nameless holder.
  bool get needsName =>
      mode == ImportMode.createNew && draft != null && !draft!.isIdentified;
}

extension StagedVisit on StagedEncounter {
  /// Whether this is the visit of a layout document linked to a visit the
  /// wallet already holds.
  bool get isExistingVisit =>
      mode == ImportMode.linkExisting &&
      existing != null &&
      draft?.visitKey != null;

  /// Whether saving adds identifiers (a document serial) to that visit.
  bool get completesExistingVisit =>
      isExistingVisit &&
      draft!.identifiersMissingFrom(existing!.rawResource).isNotEmpty;
}

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
  draft: json['draft'] != null ? MappingPatient.fromJson(json['draft']) : null,
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

Map<String, dynamic> stagedDiagnosticReportToJson(
  StagedDiagnosticReport report,
) => {
  'draft': report.draft?.toJson(),
  'existing': null,
  'mode': report.mode.toString(),
};

StagedDiagnosticReport stagedDiagnosticReportFromJson(
  Map<String, dynamic> json,
) => StagedDiagnosticReport(
  draft: json['draft'] != null
      ? MappingDiagnosticReport.fromJson(json['draft'])
      : null,
  mode: ImportMode.fromString(json['mode']),
);
