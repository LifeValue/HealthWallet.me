part of 'attachment_browse_bloc.dart';

abstract class AttachmentBrowseEvent {
  const AttachmentBrowseEvent();
}

@freezed
abstract class AttachmentBrowseInitialised extends AttachmentBrowseEvent
    with _$AttachmentBrowseInitialised {
  const AttachmentBrowseInitialised._();

  const factory AttachmentBrowseInitialised({
    String? sourceId,
    List<String>? sourceIds,
    @Default([]) List<FhirType> resourceTypes,
    @Default(false) bool readOnly,
    @Default([]) List<IFhirResource> sourceRecords,
    DateFilter? dateFilter,
    MedicalSpecialty? specialty,
  }) = _AttachmentBrowseInitialised;
}

@freezed
abstract class AttachmentBrowseSelected extends AttachmentBrowseEvent
    with _$AttachmentBrowseSelected {
  const AttachmentBrowseSelected._();

  const factory AttachmentBrowseSelected(int index) = _AttachmentBrowseSelected;
}

@freezed
abstract class AttachmentBrowseMonthSelected extends AttachmentBrowseEvent
    with _$AttachmentBrowseMonthSelected {
  const AttachmentBrowseMonthSelected._();

  const factory AttachmentBrowseMonthSelected(int year, int month) =
      _AttachmentBrowseMonthSelected;
}

@freezed
abstract class AttachmentBrowseSearchChanged extends AttachmentBrowseEvent
    with _$AttachmentBrowseSearchChanged {
  const AttachmentBrowseSearchChanged._();

  const factory AttachmentBrowseSearchChanged(String query) =
      _AttachmentBrowseSearchChanged;
}

class AttachmentBrowseDetailRefreshed extends AttachmentBrowseEvent {}
