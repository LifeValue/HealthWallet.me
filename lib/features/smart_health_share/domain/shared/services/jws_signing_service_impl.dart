import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:health_wallet/features/smart_health_share/domain/shared/services/jws_signing_service.dart';
import 'package:health_wallet/features/smart_health_share/domain/shared/services/key_management_service.dart';
import 'package:injectable/injectable.dart';
import 'package:jose/jose.dart';
import 'package:pointycastle/api.dart'
    show
        KeyParameter,
        ParametersWithRandom,
        PrivateKeyParameter,
        PublicKeyParameter;
import 'package:pointycastle/digests/sha256.dart';
import 'package:pointycastle/ecc/api.dart'
    show ECDomainParameters, ECPrivateKey, ECPublicKey;
import 'package:pointycastle/export.dart';
import 'package:pointycastle/signers/ecdsa_signer.dart';

@Injectable(as: JWSSigningService)
class JWSSigningServiceImpl implements JWSSigningService {
  final KeyManagementService _keyManagementService;

  JWSSigningServiceImpl(this._keyManagementService);

  /// Internal debug logger for instrumentation (NDJSON to .cursor/debug.log)
  void _log({
    required String location,
    required String message,
    required String hypothesisId,
    Map<String, dynamic>? data,
    String runId = 'run1',
  }) {
    // #region agent log
    final logFile = File(
        '/Users/beniamin/Work/_TECHSTACKAPPS/HEALTH_WALLET/_WORKPLACE/wp_3/HealthWallet.me/.cursor/debug.log');
    final entry = {
      'sessionId': 'debug-session',
      'runId': runId,
      'hypothesisId': hypothesisId,
      'location': location,
      'message': message,
      'data': data ?? {},
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    try {
      logFile.writeAsStringSync('${jsonEncode(entry)}\n',
          mode: FileMode.append, flush: false);
    } catch (_) {
      // Best-effort logging; ignore failures
    }
    // #endregion
  }

  @override
  Future<String> signJwt({
    required Map<String, dynamic> payload,
    required String issuer,
    required int nbf,
    required String kid,
  }) async {
    // Get private key
    final privateKeyJwk = await _keyManagementService.getPrivateKey();
    if (privateKeyJwk == null) {
      throw Exception('Private key not found. Generate key pair first.');
    }

    // Create JWT header with required fields
    final header = {
      'alg': 'ES256',
      'typ': 'JWT',
      'zip': 'DEF',
      'kid': kid,
    };

    // Add issuer and nbf to payload
    final fullPayload = {
      ...payload,
      'iss': issuer,
      'nbf': nbf,
    };

    // Encode header
    final headerJson = jsonEncode(header);
    final encodedHeader =
        base64Url.encode(utf8.encode(headerJson)).replaceAll('=', '');

    // Compress payload using DEFLATE before encoding
    final payloadBytes = utf8.encode(jsonEncode(fullPayload));
    final compressed = Deflate(payloadBytes).getBytes();
    final encodedCompressedPayload =
        base64Url.encode(Uint8List.fromList(compressed)).replaceAll('=', '');

    // Create signing input (header.compressed_payload)
    final signingInput = '$encodedHeader.$encodedCompressedPayload';

    // Sign using ES256
    final signature = await _signEs256(signingInput, privateKeyJwk);
    final encodedSignature = base64Url.encode(signature).replaceAll('=', '');

    // Return compact JWS: header.compressed_payload.signature
    return '$encodedHeader.$encodedCompressedPayload.$encodedSignature';
  }

  @override
  Future<bool> verifyJwt({
    required String compactJws,
    required JsonWebKey publicKey,
  }) async {
    try {
      final parts = compactJws.split('.');
      if (parts.length != 3) {
        return false;
      }

      final signingInput = '${parts[0]}.${parts[1]}';
      final signature = base64Url.decode(_addPadding(parts[2]));

      return await _verifyEs256(signingInput, signature, publicKey);
    } catch (e) {
      return false;
    }
  }

  @override
  Map<String, dynamic> parseJwtPayload(String compactJws) {
    try {
      final parts = compactJws.split('.');
      if (parts.length != 3) {
        throw Exception('Invalid JWT format');
      }

      // Decompress payload if compressed
      final payloadBase64 = parts[1];
      final padded = _addPadding(payloadBase64);
      final payloadBytes = base64Url.decode(padded);

      // Try to decompress (DEFLATE)
      try {
        final decompressed = Inflate(payloadBytes.toList()).getBytes();
        final payloadJson = utf8.decode(decompressed);
        return jsonDecode(payloadJson) as Map<String, dynamic>;
      } catch (e) {
        // If decompression fails, try direct decode
        final payloadJson = utf8.decode(payloadBytes);
        return jsonDecode(payloadJson) as Map<String, dynamic>;
      }
    } catch (e) {
      throw Exception('Failed to parse JWT payload: $e');
    }
  }

  Future<Uint8List> _signEs256(String data, JsonWebKey privateKeyJwk) async {
    final jwk = privateKeyJwk.toJson();
    final d = base64Url.decode(_addPadding(jwk['d'] as String));

    // Create EC private key using P-256 domain parameters
    final domainParams = ECDomainParameters('prime256v1');
    final dBigInt = _bytesToBigInt(d);
    final privateKey = ECPrivateKey(dBigInt, domainParams);

    // Initialize SecureRandom for ECDSA signer
    final random = FortunaRandom();
    final seedSource = Random.secure();
    random.seed(KeyParameter(
        Uint8List.fromList(List.generate(32, (_) => seedSource.nextInt(256)))));

    // Sign using ECDSA with SecureRandom
    final signer = ECDSASigner(SHA256Digest());
    signer.init(
      true,
      ParametersWithRandom(PrivateKeyParameter(privateKey), random),
    );

    final dataBytes = utf8.encode(data);
    final hash = sha256.convert(dataBytes).bytes;
    final signature =
        signer.generateSignature(Uint8List.fromList(hash)) as ECSignature;

    // Encode signature as r||s (64 bytes)
    final rBytes = _bigIntToBytes32(signature.r);
    final sBytes = _bigIntToBytes32(signature.s);
    return Uint8List.fromList([...rBytes, ...sBytes]);
  }

  Future<bool> _verifyEs256(
    String data,
    Uint8List signature,
    JsonWebKey publicKeyJwk,
  ) async {
    try {
      final jwk = publicKeyJwk.toJson();
      final x = base64Url.decode(_addPadding(jwk['x'] as String));
      final y = base64Url.decode(_addPadding(jwk['y'] as String));

      // Create EC public key
      final domainParams = ECDomainParameters('prime256v1');
      final xBigInt = _bytesToBigInt(x);
      final yBigInt = _bytesToBigInt(y);
      final publicKeyPoint =
          domainParams.curve.createPoint(xBigInt, yBigInt, false);
      final publicKey = ECPublicKey(publicKeyPoint, domainParams);

      // Verify signature
      final verifier = ECDSASigner(SHA256Digest());
      verifier.init(false, PublicKeyParameter(publicKey));

      final dataBytes = utf8.encode(data);
      final hash = sha256.convert(dataBytes).bytes;

      // Split signature into r and s (32 bytes each)
      final r = _bytesToBigInt(signature.sublist(0, 32));
      final s = _bytesToBigInt(signature.sublist(32, 64));
      final sig = ECSignature(r, s);

      return verifier.verifySignature(Uint8List.fromList(hash), sig);
    } catch (e) {
      return false;
    }
  }

  String _addPadding(String base64) {
    final remainder = base64.length % 4;
    if (remainder == 0) {
      return base64;
    }
    return base64 + '=' * (4 - remainder);
  }

  BigInt _bytesToBigInt(Uint8List bytes) {
    BigInt result = BigInt.zero;
    for (int i = 0; i < bytes.length; i++) {
      result = result << 8;
      result = result | BigInt.from(bytes[i]);
    }
    return result;
  }

  Uint8List _bigIntToBytes32(BigInt value) {
    final bytes = _bigIntToBytes(value);
    if (bytes.length >= 32) {
      return bytes.sublist(bytes.length - 32);
    }
    final result = Uint8List(32);
    result.setRange(32 - bytes.length, 32, bytes);
    return result;
  }

  Uint8List _bigIntToBytes(BigInt value) {
    if (value == BigInt.zero) {
      return Uint8List(1);
    }

    var absValue = value.abs();

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
}


