part of 'attachment_browse_bloc.dart';

enum AttachmentBrowseStatus { loading, success, error }

@freezed
class AttachmentBrowseState with _$AttachmentBrowseState {
  const AttachmentBrowseState._();

  const factory AttachmentBrowseState({
    @Default(AttachmentBrowseStatus.loading) AttachmentBrowseStatus status,
    @Default([]) List<AttachmentBrowseEntry> records,
    @Default(0) int selectedIndex,
    AttachmentBrowseDetail? selectedDetail,
    @Default([]) List<TimelineYear> timelineYears,
    @Default('') String searchQuery,
    @Default([]) List<AttachmentBrowseEntry> allRecords,
    @Default(false) bool readOnly,
    @Default([]) List<IFhirResource> sourceRecords,
  }) = _AttachmentBrowseState;
}
