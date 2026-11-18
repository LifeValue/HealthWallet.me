part of 'patient_bloc.dart';

@freezed
abstract class PatientState with _$PatientState {
  const factory PatientState({
    @Default(PatientStatus.initial()) PatientStatus status,
    @Default([]) List<Patient> patients,
    @Default({}) Map<String, Holder> patientGroups,

    /// People who arrived and match no one, while the wallet has several.
    @Default([]) List<HolderAsk> holderQuestions,

    /// The blood type of each listed patient; null when they have none, and
    /// missing while it loads.
    @Default({}) Map<String, String?> bloodTypes,
    @Default({}) Set<String> expandedPatientIds,
    String? selectedPatientId,
    @Default('') String animatingPatientId,
    @Default('') String collapsingPatientId,
    @Default('') String expandingPatientId,
    @Default('') String swappingFromPatientId,
    @Default('') String swappingToPatientId,
    @Default(PatientAnimationPhase.none) PatientAnimationPhase animationPhase,
    @Default(false) bool isEditingPatient,
    Patient? editingPatient,
  }) = _PatientState;
}

@freezed
sealed class PatientStatus with _$PatientStatus {
  const factory PatientStatus.initial() = _Initial;
  const factory PatientStatus.loading() = _Loading;
  const factory PatientStatus.success() = _Success;
  const factory PatientStatus.failure(Object exception) = _Failure;
}

enum PatientAnimationPhase {
  none,
  collapsing,
  swapping,
  expanding,
}
