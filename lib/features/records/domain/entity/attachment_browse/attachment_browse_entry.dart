import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';

part 'attachment_browse_entry.freezed.dart';

@freezed
class AttachmentBrowseEntry with _$AttachmentBrowseEntry {
  const factory AttachmentBrowseEntry({
    required IFhirResource record,
    String? thumbnailPath,
    @Default(0) int attachmentCount,
  }) = _AttachmentBrowseEntry;
}
