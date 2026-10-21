part of 'attach_to_encounter_bloc.dart';

abstract class AttachToEncounterEvent {
  const AttachToEncounterEvent();
}

@freezed
abstract class AttachToEncounterStarted extends AttachToEncounterEvent
    with _$AttachToEncounterStarted {
  const AttachToEncounterStarted._();

  const factory AttachToEncounterStarted({
    @Default(StagedPatient()) StagedPatient patient,
    @Default(StagedEncounter()) StagedEncounter encounter,
  }) = _AttachToEncounterStarted;
}

@freezed
abstract class AttachToEncounterPatientChanged extends AttachToEncounterEvent
    with _$AttachToEncounterPatientChanged {
  const AttachToEncounterPatientChanged._();

  const factory AttachToEncounterPatientChanged(dynamic patient) =
      _AttachToEncounterPatientChanged;
}

@freezed
abstract class AttachToEncounterSearchQueryChanged extends AttachToEncounterEvent
    with _$AttachToEncounterSearchQueryChanged {
  const AttachToEncounterSearchQueryChanged._();

  const factory AttachToEncounterSearchQueryChanged(String query) =
      _AttachToEncounterSearchQueryChanged;
}

@freezed
abstract class AttachToEncounterSelected extends AttachToEncounterEvent
    with _$AttachToEncounterSelected {
  const AttachToEncounterSelected._();

  const factory AttachToEncounterSelected(dynamic encounter) =
      _AttachToEncounterSelected;
}

@freezed
abstract class AttachToEncounterNewEncounterCreated extends AttachToEncounterEvent
    with _$AttachToEncounterNewEncounterCreated {
  const AttachToEncounterNewEncounterCreated._();

  const factory AttachToEncounterNewEncounterCreated(
      MappingEncounter encounter) = _AttachToEncounterNewEncounterCreated;
}
