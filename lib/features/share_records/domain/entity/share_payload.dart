import 'package:freezed_annotation/freezed_annotation.dart';

part 'share_payload.freezed.dart';
part 'share_payload.g.dart';

@freezed
class SharePayload with _$SharePayload {
  const SharePayload._();

  const factory SharePayload({
    required String id,
    required DateTime timestamp,
    required String senderDeviceName,
    @Default(300) int expiresInSeconds,
    required SharePayloadBundle bundle,
    @Default(true) bool isViewOnly,
    @Default([]) List<String> activeFilters,
  }) = _SharePayload;

  factory SharePayload.fromJson(Map<String, dynamic> json) =>
      _$SharePayloadFromJson(json);
}

@freezed
class SharePayloadBundle with _$SharePayloadBundle {
  const factory SharePayloadBundle({
    @Default('Bundle') String resourceType,
    @Default('collection') String type,
    required List<Map<String, dynamic>> entry,
    DateTime? lastUpdated,
  }) = _SharePayloadBundle;

  factory SharePayloadBundle.fromJson(Map<String, dynamic> json) =>
      _$SharePayloadBundleFromJson(json);
}
