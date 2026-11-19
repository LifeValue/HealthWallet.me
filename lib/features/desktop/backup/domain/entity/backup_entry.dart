import 'package:freezed_annotation/freezed_annotation.dart';

part 'backup_entry.freezed.dart';
part 'backup_entry.g.dart';

/// A backup as its `<name>.db.meta.json` describes it. The metadata sits next
/// to `<name>.db` and, from [BackupEntry.filesFormat], a `<name>.files/`
/// folder with the attachment files its records refer to.
@freezed
abstract class BackupEntry with _$BackupEntry {
  const BackupEntry._();

  /// The format that holds attachment files. Older metadata has no
  /// `formatVersion` and reads as 1, a database-only backup.
  static const filesFormat = 2;

  @JsonSerializable(explicitToJson: true)
  const factory BackupEntry({
    required String id,
    required DateTime timestamp,

    /// The `.db` file's size; [totalBytes] adds the files.
    required int sizeBytes,
    required int recordCount,

    /// SHA-256 of the `.db` file.
    required String checksum,

    /// Where the `.db` file is. Listing sets it from where the metadata
    /// actually is, so a moved backup folder still works; the stored value
    /// is kept for older app versions.
    required String filePath,
    @Default('') String name,
    @Default(1) int formatVersion,
    @Default(<BackupFile>[]) List<BackupFile> files,

    /// Attachment urls whose file wasn't on this device when the backup was
    /// made.
    @Default(<String>[]) List<String> missing,

    /// Saved automatically before a restore; deleted after 30 days.
    @Default(false) bool isSafetyCopy,
  }) = _BackupEntry;

  factory BackupEntry.fromJson(Map<String, dynamic> json) =>
      _$BackupEntryFromJson(json);

  /// Whether the backup holds attachment files (format 2 and later).
  bool get hasFiles => formatVersion >= filesFormat;

  /// The database and every attachment file.
  int get totalBytes => files.fold(sizeBytes, (sum, f) => sum + f.size);
}

/// One attachment file in a backup's `.files/` folder.
@freezed
abstract class BackupFile with _$BackupFile {
  const factory BackupFile({
    /// The file's name in `.files/`.
    required String name,

    /// The paths (decoded `file://` urls) the backed-up records stored for
    /// it; several when records refer to the same file differently.
    required List<String> sourcePaths,
    required String sha256,
    required int size,
  }) = _BackupFile;

  factory BackupFile.fromJson(Map<String, dynamic> json) =>
      _$BackupFileFromJson(json);
}
