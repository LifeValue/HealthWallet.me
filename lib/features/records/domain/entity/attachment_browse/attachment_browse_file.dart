import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';

part 'attachment_browse_file.freezed.dart';

@freezed
class AttachmentBrowseFile with _$AttachmentBrowseFile {
  const factory AttachmentBrowseFile({
    required String id,
    required IFhirResource resource,
    required String title,
    String? filePath,
    String? contentType,
    String? sourceRecordTitle,
    String? sourceRecordType,
  }) = _AttachmentBrowseFile;
}
