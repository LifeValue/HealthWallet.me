import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:health_wallet/core/data/local/app_database.dart';
import 'package:health_wallet/features/smart_health_share/domain/shared/services/key_management_service.dart';
import 'package:health_wallet/features/smart_health_share/data/data_source/local/tables/user_keys_table.dart';
import 'package:injectable/injectable.dart';
import 'package:jose/jose.dart';
import 'package:pointycastle/export.dart';

@Injectable(as: KeyManagementService)
class KeyManagementServiceImpl implements KeyManagementService {
  final AppDatabase _appDatabase;
  final FlutterSecureStorage _secureStorage;
  static const String _privateKeyStorageKey = 'smart_health_share_private_key';

  KeyManagementServiceImpl(this._appDatabase, this._secureStorage);

  @override
  Future<JsonWebKey> getOrGenerateKeyPair() async {
    // Check if keys already exist
    final existingKey = await getPublicKey();
    if (existingKey != null) {
      return existingKey;
    }

    // Generate new ES256 key pair (ECDSA P-256) using pointycastle
    final curve = ECCurve_secp256r1();
    final keyParams = ECKeyGeneratorParameters(curve);
    final random = FortunaRandom();
    final seedSource = Random.secure();
    random.seed(KeyParameter(
        Uint8List.fromList(List.generate(32, (_) => seedSource.nextInt(256)))));

    final generator = ECKeyGenerator()
      ..init(ParametersWithRandom(keyParams, random));
    final keyPair = generator.generateKeyPair();

    final privateKey = keyPair.privateKey as ECPrivateKey;
    final publicKey = keyPair.publicKey as ECPublicKey;

    // Convert to JWK format
    final privateKeyJwk = _ecPrivateKeyToJwk(privateKey);
    final publicKeyJwk = _ecPublicKeyToJwk(publicKey);

    // Store private key securely
    await _secureStorage.write(
      key: _privateKeyStorageKey,
      value: jsonEncode(privateKeyJwk),
    );

    // Store public key in database
    await _appDatabase.into(_appDatabase.userKeys).insert(
          UserKeysCompanion.insert(
            publicKey: jsonEncode(publicKeyJwk),
          ),
        );

    return JsonWebKey.fromJson(publicKeyJwk);
  }

  @override
  Future<JsonWebKey?> getPublicKey() async {
    final userKeys = await _appDatabase.select(_appDatabase.userKeys).getSingleOrNull();
    if (userKeys == null) {
      return null;
    }

    try {
      final publicKeyJson = jsonDecode(userKeys.publicKey) as Map<String, dynamic>;
      return JsonWebKey.fromJson(publicKeyJson);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<JsonWebKey?> getPrivateKey() async {
    final privateKeyJsonString = await _secureStorage.read(key: _privateKeyStorageKey);
    if (privateKeyJsonString == null) {
      return null;
    }

    try {
      final privateKeyJson = jsonDecode(privateKeyJsonString) as Map<String, dynamic>;
      return JsonWebKey.fromJson(privateKeyJson);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<String> generateKid(JsonWebKey publicKey) async {
    // Generate SHA-256 thumbprint of the JWK
    // JWK thumbprint is computed on the canonical JSON representation
    final canonicalJson = _canonicalJwkJson(publicKey.toJson());
    final thumbprintBytes = utf8.encode(canonicalJson);
    final hash = sha256.convert(thumbprintBytes);
    return base64Url.encode(hash.bytes).replaceAll('=', '');
  }

  Map<String, dynamic> _ecPrivateKeyToJwk(ECPrivateKey key) {
    final d = _bigIntToBase64Url(key.d!);
    return {
      'kty': 'EC',
      'crv': 'P-256',
      'd': d,
      'use': 'sig',
      'alg': 'ES256',
    };
  }

  Map<String, dynamic> _ecPublicKeyToJwk(ECPublicKey key) {
    final x = _bigIntToBase64Url(_ecPointXToBigInt(key.Q!));
    final y = _bigIntToBase64Url(_ecPointYToBigInt(key.Q!));
    return {
      'kty': 'EC',
      'crv': 'P-256',
      'x': x,
      'y': y,
      'use': 'sig',
      'alg': 'ES256',
    };
  }

  BigInt _ecPointXToBigInt(ECPoint point) {
    return point.x!.toBigInteger()!;
  }

  BigInt _ecPointYToBigInt(ECPoint point) {
    return point.y!.toBigInteger()!;
  }

  String _bigIntToBase64Url(BigInt value) {
    final bytes = _bigIntToBytes(value);
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  Uint8List _bigIntToBytes(BigInt value) {
    if (value == BigInt.zero) {
      return Uint8List(1);
    }

    BigInt absValue = value.abs();

    int byteCount = (absValue.bitLength + 7) ~/ 8;
    final bytes = Uint8List(byteCount);

    int index = byteCount - 1;
    while (absValue > BigInt.zero) {
      bytes[index] = (absValue & BigInt.from(0xff)).toInt();
      absValue = absValue >> 8;
      index--;
    }

    return bytes;
  }

  String _canonicalJwkJson(Map<String, dynamic> jwk) {
    // Sort keys and create canonical JSON
    final sortedKeys = jwk.keys.toList()..sort();
    final canonical = <String, dynamic>{};
    for (final key in sortedKeys) {
      canonical[key] = jwk[key];
    }
    return jsonEncode(canonical);
  }
}

