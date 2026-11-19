part of 'attach_to_encounter_bloc.dart';

enum AttachToEncounterStatus { loading, success, failure }

@freezed
abstract class AttachToEncounterState with _$AttachToEncounterState {
  const factory AttachToEncounterState({
    @Default(AttachToEncounterStatus.loading) AttachToEncounterStatus status,
    @Default([]) List<Patient> existingPatients,
    @Default([]) List<Encounter> existingEncounters,
    @Default([]) List<Encounter> filteredEncounters,
    @Default('') String searchQuery,
    @Default(StagedPatient()) StagedPatient patient,

    /// The patient read from the document, offered as a new patient even
    /// after the user picked someone else (which drops it from [patient]).
    MappingPatient? scannedPatient,
    @Default(StagedEncounter()) StagedEncounter encounter,
    dynamic selectedPatient,
  }) = _AttachToEncounterState;
}
