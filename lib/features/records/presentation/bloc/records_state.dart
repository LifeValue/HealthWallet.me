part of 'records_bloc.dart';

@freezed
class RecordsState with _$RecordsState {
  const factory RecordsState({
    @Default(RecordsStatus.initial()) RecordsStatus status,
    @Default([]) List<IFhirResource> resources,
    @Default([]) List<FhirType> activeFilters,
    String? sourceId,
    List<String>? sourceIds,
    @Default(false) bool hasMorePages,
    @Default(RecordDetailStatus.initial())
    RecordDetailStatus recordDetailStatus,
    @Default([]) List<IFhirResource> relatedResources,
    @Default(false) bool hasDemoData,
    @Default(false) bool isLoadingDemoData,
    String? demoDataError,
    @Default('') String searchQuery,
    @Default({}) Set<String> selectedResourceIds,
    @Default(false) bool isSelectionMode,
    DateFilter? dateFilter,
  }) = _RecordsState;
}

@freezed
class RecordsStatus with _$RecordsStatus {
  const factory RecordsStatus.initial() = _Initial;
  const factory RecordsStatus.loading() = _Loading;
  const factory RecordsStatus.success() = _Success;
  const factory RecordsStatus.failure(Object error) = _Failure;
}

@freezed
class RecordDetailStatus with _$RecordDetailStatus {
  const factory RecordDetailStatus.initial() = _DetailInitial;
  const factory RecordDetailStatus.loading() = _DetailLoading;
  const factory RecordDetailStatus.success() = _DetailSuccess;
  const factory RecordDetailStatus.failure(Object error) = _DetailFailure;
}
