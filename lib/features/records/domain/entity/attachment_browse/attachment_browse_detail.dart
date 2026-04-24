import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/records/domain/entity/attachment_browse/attachment_browse_file.dart';

part 'attachment_browse_detail.freezed.dart';

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
