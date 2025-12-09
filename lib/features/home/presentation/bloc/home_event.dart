part of 'home_bloc.dart';

abstract class HomeEvent {
  const HomeEvent();
}

@freezed
class HomeInitialised extends HomeEvent with _$HomeInitialised {
  const factory HomeInitialised() = _HomeInitialised;
}

@freezed
class HomeSourceChanged extends HomeEvent with _$HomeSourceChanged {
  const factory HomeSourceChanged(
    String source, {
    List<String>? patientSourceIds,
  }) = _HomeSourceChanged;
}

@freezed
class HomeEditModeChanged extends HomeEvent with _$HomeEditModeChanged {
  const factory HomeEditModeChanged(bool editMode) = _HomeEditModeChanged;
}

@freezed
class HomeRecordsReordered extends HomeEvent with _$HomeRecordsReordered {
  const factory HomeRecordsReordered(int oldIndex, int newIndex) =
      _HomeRecordsReordered;
}

@freezed
class HomeVitalsReordered extends HomeEvent with _$HomeVitalsReordered {
  const factory HomeVitalsReordered(int oldIndex, int newIndex) =
      _HomeVitalsReordered;
}

@freezed
class HomeVitalsFiltersChanged extends HomeEvent
    with _$HomeVitalsFiltersChanged {
  const factory HomeVitalsFiltersChanged(Map<PatientVitalType, bool> filters) =
      _HomeVitalsFiltersChanged;
}

@freezed
class HomeRecordsFiltersChanged extends HomeEvent
    with _$HomeRecordsFiltersChanged {
  const factory HomeRecordsFiltersChanged(
    Map<HomeRecordsCategory, bool> filters,
  ) = _HomeRecordsFiltersChanged;
}

@freezed
class HomeVitalsExpansionToggled extends HomeEvent
    with _$HomeVitalsExpansionToggled {
  const factory HomeVitalsExpansionToggled() = _HomeVitalsExpansionToggled;
}

@freezed
class HomeRefreshPreservingOrder extends HomeEvent
    with _$HomeRefreshPreservingOrder {
  const factory HomeRefreshPreservingOrder() = _HomeRefreshPreservingOrder;
}

@freezed
class HomeSourceLabelUpdated extends HomeEvent with _$HomeSourceLabelUpdated {
  const factory HomeSourceLabelUpdated(String sourceId, String newLabel) =
      _HomeSourceLabelUpdated;
}

@freezed
class HomeSourceDeleted extends HomeEvent with _$HomeSourceDeleted {
  const factory HomeSourceDeleted(
    String sourceId, {
    List<String>? patientSourceIds,
  }) = _HomeSourceDeleted;
}
