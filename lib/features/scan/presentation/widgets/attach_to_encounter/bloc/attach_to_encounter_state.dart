part of 'attach_to_encounter_bloc.dart';

enum AttachToEncounterStatus { initial, loading, success, failure }

@freezed
class AttachToEncounterState with _$AttachToEncounterState {
  const factory AttachToEncounterState({
    @Default(AttachToEncounterStatus.initial) AttachToEncounterStatus status,
    @Default([]) List<Patient> patients,
    String? selectedPatientId,
    @Default([]) List<Encounter> encounters,
    @Default([]) List<Encounter> filteredEncounters,
    Encounter? selectedEncounter,
    @Default('') String searchQuery,
    String? errorMessage,
  }) = _AttachToEncounterState;
}
