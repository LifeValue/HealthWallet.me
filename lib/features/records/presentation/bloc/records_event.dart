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

  const factory RecordsSourceChanged(
    String? sourceId, {
    List<String>? sourceIds,
    @Default(false) bool isShareContext,
  }) = _RecordsSourceChanged;
}

@freezed
abstract class RecordsFiltersApplied extends RecordsEvent
    with _$RecordsFiltersApplied {
  const RecordsFiltersApplied._();

  const factory RecordsFiltersApplied(
    List<FhirType> filters, {
    DateFilter? dateFilter,
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
abstract class LoadDemoData extends RecordsEvent with _$LoadDemoData {
  const LoadDemoData._();

  const factory LoadDemoData() = _LoadDemoData;
}

@freezed
abstract class ClearDemoData extends RecordsEvent with _$ClearDemoData {
  const ClearDemoData._();

  const factory ClearDemoData() = _ClearDemoData;
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

  /// [sourceId] is the source selected on Home, or null for all of the
  /// patient's sources.
  const factory RecordsSharePressed({
    String? patientName,
    String? patientId,
    String? sourceId,
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
    @Default(false) bool deleteRelated,
    @Default([]) List<String> selectedRelatedIds,
  }) = _RecordsResourceDeleted;
}

@freezed
abstract class RecordsSpecialtyApplied extends RecordsEvent
    with _$RecordsSpecialtyApplied {
  const RecordsSpecialtyApplied._();

  const factory RecordsSpecialtyApplied(List<MedicalSpecialty> specialties) =
      _RecordsSpecialtyApplied;
}

class RecordsRefreshRequested extends RecordsEvent {}

class RecordsClearAllFilters extends RecordsEvent {}
