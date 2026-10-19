import 'package:freezed_annotation/freezed_annotation.dart';

part 'sync_delta.freezed.dart';
part 'sync_delta.g.dart';

@freezed
class SyncDelta with _$SyncDelta {
  const factory SyncDelta({
    required String tableName,
    required List<Map<String, dynamic>> rows,
    required String deviceId,
    required DateTime timestamp,
  }) = _SyncDelta;

  factory SyncDelta.fromJson(Map<String, dynamic> json) =>
      _$SyncDeltaFromJson(json);
}
