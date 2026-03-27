import 'package:freezed_annotation/freezed_annotation.dart';

part 'backup_entry.freezed.dart';
part 'backup_entry.g.dart';

@freezed
class BackupEntry with _$BackupEntry {
  const factory BackupEntry({
    required String id,
    required DateTime timestamp,
    required int sizeBytes,
    required int recordCount,
    required String checksum,
    required String filePath,
  }) = _BackupEntry;

  factory BackupEntry.fromJson(Map<String, dynamic> json) =>
      _$BackupEntryFromJson(json);
}
