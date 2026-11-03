import 'package:freezed_annotation/freezed_annotation.dart';

part 'restore_result.freezed.dart';

/// What a committed restore did with the backup's attachment files.
@freezed
abstract class RestoreResult with _$RestoreResult {
  const factory RestoreResult({
    /// Whether the backup held files; false for a database-only backup,
    /// whose restore kept every current file and added none.
    required bool hadFiles,

    /// Files copied into the documents folder.
    @Default(0) int filesAdded,

    /// Files already there with the same content.
    @Default(0) int filesAlreadyPresent,

    /// Files listed in the backup that were missing or damaged, so they
    /// couldn't be restored. The records were restored anyway.
    @Default(0) int filesNotRestored,

    /// Attachments whose file was already missing when the backup was made.
    @Default(0) int filesMissingFromBackup,
  }) = _RestoreResult;
}
