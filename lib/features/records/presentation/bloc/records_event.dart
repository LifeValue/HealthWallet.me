part of 'records_bloc.dart';

abstract class RecordsEvent {
  const RecordsEvent();
}

@freezed
abstract class RecordsInitialised extends RecordsEvent
    with _$RecordsInitialised {
  const RecordsInitialised._();

  const factory RecordsInitialised({
    @Default(false) bool isShareContext,
  }) = _RecordsInitialised;
}

@freezed
abstract class RecordsLoadMore extends RecordsEvent with _$RecordsLoadMore {
  const RecordsLoadMore._();

  const factory RecordsLoadMore() = _RecordsLoadMore;
}

@freezed
abstract class RecordsSourceChanged extends RecordsEvent
    with _$RecordsSourceChanged {
  const RecordsSourceChanged._();

  /// [personId] is the holder whose records these are: their own saved
  /// filters apply. Without one (a share), no filters are kept.
  const factory RecordsSourceChanged(
    String? sourceId, {
    List<String>? sourceIds,
    String? personId,
    @Default(false) bool isShareContext,
  }) = _RecordsSourceChanged;
}

@freezed
abstract class RecordsFiltersApplied extends RecordsEvent
    with _$RecordsFiltersApplied {
  const RecordsFiltersApplied._();

  /// Sets every filter at once: the types, the dates and the specialties.
  /// [remember] false (a Home card) filters this visit only: the person's
  /// saved filters stay as they were. [personId] is the person the card
  /// was shown for, whose records Records opens on next.
  const factory RecordsFiltersApplied(
    List<FhirType> filters, {
    DateFilter? dateFilter,
    @Default([]) List<MedicalSpecialty> specialties,
    @Default(true) bool remember,
    String? personId,
  }) = _RecordsFiltersApplied;
}

@freezed
abstract class RecordsFilterRemoved extends RecordsEvent
    with _$RecordsFilterRemoved {
  const RecordsFilterRemoved._();

  const factory RecordsFilterRemoved(FhirType filter) = _RecordsFilterRemoved;
}

@freezed
abstract class RecordDetailLoaded extends RecordsEvent
    with _$RecordDetailLoaded {
  const RecordDetailLoaded._();

  const factory RecordDetailLoaded(IFhirResource resource) =
      _RecordsDetailLoaded;
}

@freezed
abstract class RecordsSearch extends RecordsEvent with _$RecordsSearch {
  const RecordsSearch._();

  const factory RecordsSearch(String query) = _RecordsSearch;
}

@freezed
abstract class RecordsSearchExecuted extends RecordsEvent
    with _$RecordsSearchExecuted {
  const RecordsSearchExecuted._();

  const factory RecordsSearchExecuted(String query) = _RecordsSearchExecuted;
}

@freezed
abstract class RecordsSharePressed extends RecordsEvent
    with _$RecordsSharePressed {
  const RecordsSharePressed._();

  /// [sourceId] is the source selected on Home, or null for all of
  /// [sourceIds], the person's sources.
  const factory RecordsSharePressed({
    String? patientName,
    String? patientId,
    String? sourceId,
    List<String>? sourceIds,
  }) = _RecordsSharePressed;
}

@freezed
abstract class RecordsSelectionToggled extends RecordsEvent
    with _$RecordsSelectionToggled {
  const RecordsSelectionToggled._();

  const factory RecordsSelectionToggled(String resourceId) =
      _RecordsSelectionToggled;
}

@freezed
abstract class RecordsSelectionCleared extends RecordsEvent
    with _$RecordsSelectionCleared {
  const RecordsSelectionCleared._();

  const factory RecordsSelectionCleared() = _RecordsSelectionCleared;
}

@freezed
abstract class RecordsSelectionModeToggled extends RecordsEvent
    with _$RecordsSelectionModeToggled {
  const RecordsSelectionModeToggled._();

  const factory RecordsSelectionModeToggled() = _RecordsSelectionModeToggled;
}

@freezed
abstract class RecordsDateRangeCleared extends RecordsEvent
    with _$RecordsDateRangeCleared {
  const RecordsDateRangeCleared._();

  const factory RecordsDateRangeCleared() = _RecordsDateRangeCleared;
}

@freezed
abstract class RecordsResourceDeleted extends RecordsEvent
    with _$RecordsResourceDeleted {
  const RecordsResourceDeleted._();

  const factory RecordsResourceDeleted({
    required String resourceId,
    @Default([]) List<String> selectedRelatedIds,
  }) = _RecordsResourceDeleted;
}

@freezed
abstract class RecordsSpecialtyApplied extends RecordsEvent
    with _$RecordsSpecialtyApplied {
  const RecordsSpecialtyApplied._();

  /// Sets the specialties and keeps the type and date filters.
  /// [remember] false (a Home card) filters this visit only: the person's
  /// saved filters stay as they were. [personId] is the person the card
  /// was shown for, whose records Records opens on next.
  const factory RecordsSpecialtyApplied(
    List<MedicalSpecialty> specialties, {
    @Default(true) bool remember,
    String? personId,
  }) = _RecordsSpecialtyApplied;
}

class RecordsRefreshRequested extends RecordsEvent {}

/// The Records tab was left: filters a Home card set for that visit give
/// way to the person's own.
class RecordsVisitEnded extends RecordsEvent {}

class RecordsClearAllFilters extends RecordsEvent {}
