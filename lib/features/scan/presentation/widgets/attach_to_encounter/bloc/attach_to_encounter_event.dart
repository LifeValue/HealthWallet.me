part of 'attach_to_encounter_bloc.dart';

abstract class AttachToEncounterEvent {
  const AttachToEncounterEvent();
}

@freezed
class AttachToEncounterStarted extends AttachToEncounterEvent
    with _$AttachToEncounterStarted {
  const factory AttachToEncounterStarted({
    @Default(StagedPatient()) StagedPatient patient,
    @Default(StagedEncounter()) StagedEncounter encounter,
  }) = _AttachToEncounterStarted;
}

@freezed
class AttachToEncounterPatientChanged extends AttachToEncounterEvent
    with _$AttachToEncounterPatientChanged {
  const factory AttachToEncounterPatientChanged(dynamic patient) =
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
  const factory AttachToEncounterSelected(dynamic encounter) =
      _AttachToEncounterSelected;
}

@freezed
class AttachToEncounterNewEncounterCreated extends AttachToEncounterEvent
    with _$AttachToEncounterNewEncounterCreated {
  const factory AttachToEncounterNewEncounterCreated(
      MappingEncounter encounter) = _AttachToEncounterNewEncounterCreated;
}
