import 'package:freezed_annotation/freezed_annotation.dart';

part 'sync_batch.freezed.dart';
part 'sync_batch.g.dart';

/// Rows sent in one `sync.batch` message and acknowledged together. [id] is
/// the sender's last outbox entry in the batch; the receiver applies all
/// tables in one transaction and acknowledges [id] only after it committed.
@freezed
abstract class SyncBatch with _$SyncBatch {
  const factory SyncBatch({
    required int id,
    required String deviceId,

    /// Rows by table name, in the shape of a `SELECT *` on that table.
    required Map<String, List<Map<String, dynamic>>> tables,

    /// The sender had more changes waiting when it sent this batch, so the
    /// receiver holds off reloading its lists until the last one. Missing
    /// from older senders, which reads as the last batch.
    @Default(false) bool more,
  }) = _SyncBatch;

  factory SyncBatch.fromJson(Map<String, dynamic> json) =>
      _$SyncBatchFromJson(json);
}

/// What one side holds of a table, to tell whether both sides agree without
/// sending the rows: the row count and a hash of every key with its
/// `updated_at`.
@freezed
abstract class TableDigest with _$TableDigest {
  const factory TableDigest({required int count, required String hash}) =
      _TableDigest;

  factory TableDigest.fromJson(Map<String, dynamic> json) =>
      _$TableDigestFromJson(json);
}
