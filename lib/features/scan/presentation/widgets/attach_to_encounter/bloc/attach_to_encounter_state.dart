part of 'attach_to_encounter_bloc.dart';

enum AttachToEncounterStatus { initial, loading, success, failure }

@freezed
class AttachToEncounterState with _$AttachToEncounterState {
  const factory AttachToEncounterState({
    @Default(AttachToEncounterStatus.initial) AttachToEncounterStatus status,
    @Default([]) List<Patient> patients,
    Patient? selectedPatient,
    @Default([]) List<Encounter> encounters,
    @Default([]) List<Encounter> filteredEncounters,
    Encounter? selectedEncounter,
    @Default('') String searchQuery,
    MappingPatient? newPatient,
    MappingEncounter? newEncounter,
    String? errorMessage,
  }) = _AttachToEncounterState;
}
