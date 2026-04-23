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
  }) = _AttachmentBrowseState;
}

@freezed
class AttachmentBrowseEntry with _$AttachmentBrowseEntry {
  const factory AttachmentBrowseEntry({
    required IFhirResource record,
    String? thumbnailPath,
    @Default(0) int attachmentCount,
  }) = _AttachmentBrowseEntry;
}

@freezed
class AttachmentBrowseDetail with _$AttachmentBrowseDetail {
  const factory AttachmentBrowseDetail({
    required IFhirResource record,
    @Default([]) List<AttachmentBrowseFile> attachments,
    String? patientName,
    String? organizationName,
    String? practitionerName,
  }) = _AttachmentBrowseDetail;
}

@freezed
class AttachmentBrowseFile with _$AttachmentBrowseFile {
  const factory AttachmentBrowseFile({
    required String id,
    required IFhirResource resource,
    required String title,
    String? filePath,
    String? contentType,
  }) = _AttachmentBrowseFile;
}

@freezed
class TimelineYear with _$TimelineYear {
  const factory TimelineYear({
    required int year,
    @Default([]) List<TimelineMonth> months,
  }) = _TimelineYear;
}

@freezed
class TimelineMonth with _$TimelineMonth {
  const factory TimelineMonth({
    required int month,
    @Default(0) int recordCount,
    @Default(0) int firstRecordIndex,
  }) = _TimelineMonth;
}
