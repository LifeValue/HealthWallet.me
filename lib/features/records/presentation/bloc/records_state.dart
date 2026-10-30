part of 'records_bloc.dart';

@freezed
abstract class RecordsState with _$RecordsState {
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
    @Default([]) List<MedicalSpecialty> activeSpecialties,
    @Default(IpsExportStatus.idle) IpsExportStatus ipsExportStatus,
  }) = _RecordsState;
}

/// Progress of an IPS export. Each export passes through [exporting], so a
/// second failure in a row is still a new [failed] state for listeners.
enum IpsExportStatus { idle, exporting, failed }

@freezed
sealed class RecordsStatus with _$RecordsStatus {
  const factory RecordsStatus.initial() = _Initial;
  const factory RecordsStatus.loading() = _Loading;
  const factory RecordsStatus.success() = _Success;
  const factory RecordsStatus.deleted() = _Deleted;
  const factory RecordsStatus.failure(Object error) = _Failure;
}

@freezed
sealed class RecordDetailStatus with _$RecordDetailStatus {
  const factory RecordDetailStatus.initial() = _DetailInitial;
  const factory RecordDetailStatus.loading() = _DetailLoading;
  const factory RecordDetailStatus.success() = _DetailSuccess;
  const factory RecordDetailStatus.failure(Object error) = _DetailFailure;
}
