part of 'record_attachments_bloc.dart';

abstract class RecordAttachmentsEvent {
  const RecordAttachmentsEvent();
}

@freezed
class RecordAttachmentsInitialised extends RecordAttachmentsEvent
    with _$RecordAttachmentsInitialised {
  const factory RecordAttachmentsInitialised({
    required IFhirResource resource,
    @Default([]) List<IFhirResource> ephemeralRecords,
  }) = _RecordAttachmentsInitialised;
}

@freezed
class RecordAttachmentsFileAttached extends RecordAttachmentsEvent
    with _$RecordAttachmentsFileAttached {
  const factory RecordAttachmentsFileAttached(File file) =
      _RecordAttachmentsFileAttached;
}

@freezed
class RecordAttachmentsFileDeleted extends RecordAttachmentsEvent
    with _$RecordAttachmentsFileDeleted {
  const factory RecordAttachmentsFileDeleted(IFhirResource attachment) =
      _RecordAttachmentsFileDeleted;
}
