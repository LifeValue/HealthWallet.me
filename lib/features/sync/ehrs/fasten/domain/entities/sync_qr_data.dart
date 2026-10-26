import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:health_wallet/features/sync/data/services/jwt_service.dart';

part 'sync_qr_data.freezed.dart';
part 'sync_qr_data.g.dart';

@freezed
abstract class SyncQrData with _$SyncQrData {
  const SyncQrData._();

  const factory SyncQrData({
    required String token,
    required SyncTokenMetaData tokenMeta,
    required List<String> serverBaseUrls,
    required String syncEndpoint,
  }) = _SyncQrData;

  factory SyncQrData.fromJson(Map<String, dynamic> json) {
    final decodedToken = JwtService.decodeJWT(json['token'] as String);

    return SyncQrData(
      token: json['token'] as String,
      tokenMeta: SyncTokenMetaData.fromJson(decodedToken ?? {}),
      serverBaseUrls: (json['server_base_urls'] as List)
          .whereType<String>()
          .toList(),
      syncEndpoint: json['sync_endpoint'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'token': token,
    'server_base_urls': serverBaseUrls,
    'sync_endpoint': syncEndpoint,
  };
}

@freezed
abstract class SyncTokenMetaData with _$SyncTokenMetaData {
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
}
