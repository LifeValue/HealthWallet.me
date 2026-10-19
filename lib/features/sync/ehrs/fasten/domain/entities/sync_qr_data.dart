import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:health_wallet/features/sync/data/services/jwt_service.dart';

part 'sync_qr_data.freezed.dart';
part 'sync_qr_data.g.dart';

@freezed
class SyncQrData with _$SyncQrData {
  const SyncQrData._();

  const factory SyncQrData({
    required String token,
    required SyncTokenMetaData tokenMeta,
    required List<String> serverBaseUrls,
    required String syncEndpoint,
  }) = _SyncQrData;

  factory SyncQrData.fromJson(Map<String, dynamic> json) {
    final decodedToken = JwtService.decodeJWT(json["token"] as String);

    return SyncQrData(
      token: json["token"] as String,
      tokenMeta: SyncTokenMetaData.fromJson(decodedToken ?? {}),
      serverBaseUrls:
          (json["server_base_urls"] as List).whereType<String>().toList(),
      syncEndpoint: json["sync_endpoint"] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        "token": token,
        "server_base_urls": serverBaseUrls,
        "sync_endpoint": syncEndpoint,
      };
}

@freezed
class SyncTokenMetaData with _$SyncTokenMetaData {
  const factory SyncTokenMetaData({
    @JsonKey(name: 'full_name') @Default('') String fullName,
    @JsonKey(name: 'picture') @Default('') String picture,
    @JsonKey(name: 'email') @Default('') String email,
    @JsonKey(name: 'iss') @Default('') String issuer,
    @JsonKey(name: 'role') @Default('') String role,
    @JsonKey(name: 'sub') @Default('') String userName,
    @JsonKey(name: 'exp') @Default(0) int expiresAt,
    @JsonKey(name: 'iat') @Default(0) int issuedAt,
  }) = _SyncTokenMetaData;

  factory SyncTokenMetaData.fromJson(Map<String, dynamic> json) =>
      _$SyncTokenMetaDataFromJson(json);
}

extension SyncTokenExtensions on SyncTokenMetaData {
  DateTime get expirationDateTime =>
      DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000);

  /// Check if the token is expired
  bool get isExpired => DateTime.now().isAfter(expirationDateTime);

  /// Check if the token is about to expire (within 24 hours)
  bool get isExpiringSoon =>
      DateTime.now().add(const Duration(hours: 24)).isAfter(expirationDateTime);

  /// Check if the token is about to expire within specified duration
  bool isExpiringWithin(Duration duration) =>
      DateTime.now().add(duration).isAfter(expirationDateTime);

  /// Get time remaining until expiration
  Duration get timeUntilExpiration =>
      expirationDateTime.difference(DateTime.now());

  /// Get formatted expiration time for display
  String get formattedExpiration {
    final now = DateTime.now();
    final diff = expirationDateTime.difference(now);

    if (diff.isNegative) {
      final expiredDiff = now.difference(expirationDateTime);
      if (expiredDiff.inDays > 0) {
        return 'Expired ${expiredDiff.inDays} day${expiredDiff.inDays != 1 ? 's' : ''} ago';
      } else if (expiredDiff.inHours > 0) {
        return 'Expired ${expiredDiff.inHours} hour${expiredDiff.inHours != 1 ? 's' : ''} ago';
      } else {
        return 'Expired ${expiredDiff.inMinutes} minute${expiredDiff.inMinutes != 1 ? 's' : ''} ago';
      }
    } else {
      if (diff.inDays > 0) {
        return 'Expires in ${diff.inDays} day${diff.inDays != 1 ? 's' : ''}';
      } else if (diff.inHours > 0) {
        return 'Expires in ${diff.inHours} hour${diff.inHours != 1 ? 's' : ''}';
      } else {
        return 'Expires in ${diff.inMinutes} minute${diff.inMinutes != 1 ? 's' : ''}';
      }
    }
  }
}
