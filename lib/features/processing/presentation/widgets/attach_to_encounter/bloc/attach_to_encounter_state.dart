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
    @Default(StagedEncounter()) StagedEncounter encounter,
    dynamic selectedPatient,
    String? errorMessage,
  }) = _AttachToEncounterState;
}
