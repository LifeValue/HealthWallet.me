part of 'patient_bloc.dart';

abstract class PatientEvent {
  const PatientEvent();
}

@freezed
abstract class PatientInitialised extends PatientEvent
    with _$PatientInitialised {
  const PatientInitialised._();

  const factory PatientInitialised() = _PatientInitialised;
}

@freezed
abstract class PatientPatientsLoaded extends PatientEvent
    with _$PatientPatientsLoaded {
  const PatientPatientsLoaded._();

  /// [preserveOrder] keeps the list as it is, as after an edit.
  const factory PatientPatientsLoaded({@Default(false) bool preserveOrder}) =
      _PatientPatientsLoaded;
}

/// The selection changed (see `HolderSelection`).
@freezed
abstract class PatientScopeChanged extends PatientEvent
    with _$PatientScopeChanged {
  const PatientScopeChanged._();

  const factory PatientScopeChanged(HolderScope scope) = _PatientScopeChanged;
}

@freezed
abstract class PatientReorder extends PatientEvent with _$PatientReorder {
  const PatientReorder._();

  const factory PatientReorder(String patientId) = _PatientReorder;
}

@freezed
abstract class PatientDataUpdatedFromSync extends PatientEvent
    with _$PatientDataUpdatedFromSync {
  const PatientDataUpdatedFromSync._();

  const factory PatientDataUpdatedFromSync() = _PatientDataUpdatedFromSync;
}

@freezed
abstract class PatientEditStarted extends PatientEvent
    with _$PatientEditStarted {
  const PatientEditStarted._();

  const factory PatientEditStarted(String patientId) = _PatientEditStarted;
}

@freezed
abstract class PatientEditCancelled extends PatientEvent
    with _$PatientEditCancelled {
  const PatientEditCancelled._();

  const factory PatientEditCancelled() = _PatientEditCancelled;
}

@freezed
abstract class PatientEditSaved extends PatientEvent with _$PatientEditSaved {
  const PatientEditSaved._();

  const factory PatientEditSaved({
    required String patientId,
    required String sourceId,
    List<String>? given,
    String? family,
    DateTime? birthDate,
    String? gender,
    required String bloodType,
    String? identifierValue,
    String? contactPhone,
    required List<dynamic> availableSources,
  }) = _PatientEditSaved;
}

@freezed
abstract class PatientSelectionChanged extends PatientEvent
    with _$PatientSelectionChanged {
  const PatientSelectionChanged._();

  const factory PatientSelectionChanged({
    required String patientId,
  }) = _PatientSelectionChanged;
}

/// The user's answer to [HolderAsk]: [holderId] is the person picked, or
/// null for someone else.
@freezed
abstract class PatientHolderAnswered extends PatientEvent
    with _$PatientHolderAnswered {
  const PatientHolderAnswered._();

  const factory PatientHolderAnswered({
    required HolderAsk ask,
    String? holderId,
  }) = _PatientHolderAnswered;
}
