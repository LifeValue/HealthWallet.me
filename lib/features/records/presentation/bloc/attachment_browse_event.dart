part of 'attachment_browse_bloc.dart';

abstract class AttachmentBrowseEvent {}

@freezed
class AttachmentBrowseInitialised extends AttachmentBrowseEvent
    with _$AttachmentBrowseInitialised {
  const factory AttachmentBrowseInitialised({
    String? sourceId,
    List<String>? sourceIds,
    @Default([]) List<FhirType> resourceTypes,
  }) = _AttachmentBrowseInitialised;
}

@freezed
class AttachmentBrowseSelected extends AttachmentBrowseEvent
    with _$AttachmentBrowseSelected {
  const factory AttachmentBrowseSelected(int index) =
      _AttachmentBrowseSelected;
}

@freezed
class AttachmentBrowseMonthSelected extends AttachmentBrowseEvent
    with _$AttachmentBrowseMonthSelected {
  const factory AttachmentBrowseMonthSelected(int year, int month) =
      _AttachmentBrowseMonthSelected;
}

@freezed
class AttachmentBrowseSearchChanged extends AttachmentBrowseEvent
    with _$AttachmentBrowseSearchChanged {
  const factory AttachmentBrowseSearchChanged(String query) =
      _AttachmentBrowseSearchChanged;
}
