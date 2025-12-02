part of 'attach_to_encounter_bloc.dart';

abstract class AttachToEncounterEvent {
  const AttachToEncounterEvent();
}

@freezed
class AttachToEncounterStarted extends AttachToEncounterEvent
    with _$AttachToEncounterStarted {
  const factory AttachToEncounterStarted({
    MappingPatient? newPatient, 
    MappingEncounter? newEncounter,
  }) = _AttachToEncounterStarted;
}

@freezed
class AttachToEncounterPatientChanged extends AttachToEncounterEvent
    with _$AttachToEncounterPatientChanged {
  const factory AttachToEncounterPatientChanged(Patient patient) =
      _AttachToEncounterPatientChanged;
}

@freezed
class AttachToEncounterSearchQueryChanged extends AttachToEncounterEvent
    with _$AttachToEncounterSearchQueryChanged {
  const factory AttachToEncounterSearchQueryChanged(String query) =
      _AttachToEncounterSearchQueryChanged;
}

@freezed
class AttachToEncounterSelected extends AttachToEncounterEvent
    with _$AttachToEncounterSelected {
  const factory AttachToEncounterSelected(Encounter encounter) =
      _AttachToEncounterSelected;
}

class AttachToEncounterNewEncounterCreated extends AttachToEncounterEvent {
  final MappingEncounter newEncounter;

  const AttachToEncounterNewEncounterCreated(this.newEncounter);
}
