import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pointycastle/asn1.dart';
import 'package:pointycastle/export.dart';

/// Throwaway RSA key and self-signed certificate generated at test time, so no
/// signing material is ever committed. The key is 1024 bits to keep the
/// suite fast; it signs nothing outside the test run.
class SigningTestMaterial {
  SigningTestMaterial._(this.publicKey, this.privateKey);

  factory SigningTestMaterial.generate() {
    final seed = Random.secure();
    final random = FortunaRandom()
      ..seed(
        KeyParameter(
          Uint8List.fromList(List<int>.generate(32, (_) => seed.nextInt(256))),
        ),
      );
    final generator = RSAKeyGenerator()
      ..init(
        ParametersWithRandom(
          RSAKeyGeneratorParameters(BigInt.from(65537), 1024, 64),
          random,
        ),
      );
    final pair = generator.generateKeyPair();
    return SigningTestMaterial._(
      pair.publicKey as RSAPublicKey,
      pair.privateKey as RSAPrivateKey,
    );
  }

  final RSAPublicKey publicKey;
  final RSAPrivateKey privateKey;

  static const _rsaEncryption = '1.2.840.113549.1.1.1';
  static const _sha256WithRsa = '1.2.840.113549.1.1.11';
  static const _uid = '0.9.2342.19200300.100.1.1';
  static const _organizationalUnit = '2.5.4.11';
  static const _commonName = '2.5.4.3';

  /// The private key as an unencrypted PKCS#8 PEM, the format of both the
  /// Apple pass key and Google service-account keys.
  String get pkcs8PrivateKeyPem {
    final p = privateKey.p!;
    final q = privateKey.q!;
    final d = privateKey.privateExponent!;
    final pkcs1 = ASN1Sequence(
      elements: [
        ASN1Integer(BigInt.zero),
        ASN1Integer(privateKey.modulus),
        ASN1Integer(publicKey.publicExponent),
        ASN1Integer(d),
        ASN1Integer(p),
        ASN1Integer(q),
        ASN1Integer(d % (p - BigInt.one)),
        ASN1Integer(d % (q - BigInt.one)),
        ASN1Integer(q.modInverse(p)),
      ],
    );
    final pkcs8 = ASN1Sequence(
      elements: [
        ASN1Integer(BigInt.zero),
        _algorithm(_rsaEncryption),
        ASN1OctetString(octets: pkcs1.encode()),
      ],
    );
    return _pem('PRIVATE KEY', pkcs8.encode());
  }

  /// A self-signed X.509 v1 certificate whose subject carries the Pass Type ID
  /// (UID) and Team ID (OU), the two values passkit checks before signing.
  String certificatePem({required String passTypeId, required String teamId}) {
    final name = ASN1Sequence(
      elements: [
        _rdn(_uid, passTypeId),
        _rdn(_organizationalUnit, teamId),
        _rdn(_commonName, 'HealthWallet test pass certificate'),
      ],
    );
    final now = DateTime.now().toUtc();
    final tbs = ASN1Sequence(
      elements: [
        ASN1Integer(BigInt.from(1)),
        _algorithm(_sha256WithRsa),
        name,
        ASN1Sequence(
          elements: [
            ASN1UtcTime(now.subtract(const Duration(days: 1))),
            ASN1UtcTime(now.add(const Duration(days: 365))),
          ],
        ),
        name,
        ASN1Sequence(
          elements: [
            _algorithm(_rsaEncryption),
            ASN1BitString(
              stringValues: ASN1Sequence(
                elements: [
                  ASN1Integer(publicKey.modulus),
                  ASN1Integer(publicKey.publicExponent),
                ],
              ).encode(),
            ),
          ],
        ),
      ],
    );
    final tbsBytes = tbs.encode();
    final signer = Signer('SHA-256/RSA')
      ..init(true, PrivateKeyParameter<RSAPrivateKey>(privateKey));
    final signature = signer.generateSignature(tbsBytes) as RSASignature;
    final certificate = ASN1Sequence(
      elements: [
        tbs,
        _algorithm(_sha256WithRsa),
        ASN1BitString(stringValues: signature.bytes),
      ],
    );
    return _pem('CERTIFICATE', certificate.encode());
  }

  /// Verifies an RS256 signature over [signingInput] with [publicKey].
  bool verifyRs256(String signingInput, Uint8List signature) {
    final verifier = Signer('SHA-256/RSA')
      ..init(false, PublicKeyParameter<RSAPublicKey>(publicKey));
    return verifier.verifySignature(
      Uint8List.fromList(utf8.encode(signingInput)),
      RSASignature(signature),
    );
  }

  static ASN1Sequence _algorithm(String oid) => ASN1Sequence(
    elements: [ASN1ObjectIdentifier.fromIdentifierString(oid), ASN1Null()],
  );

  static ASN1Set _rdn(String oid, String value) => ASN1Set(
    elements: [
      ASN1Sequence(
        elements: [
          ASN1ObjectIdentifier.fromIdentifierString(oid),
          ASN1UTF8String(utf8StringValue: value),
        ],
      ),
    ],
  );

  static String _pem(String label, Uint8List der) {
    final body = base64.encode(der);
    final lines = <String>[
      for (var i = 0; i < body.length; i += 64)
        body.substring(i, min(i + 64, body.length)),
    ];
    return '-----BEGIN $label-----\n${lines.join('\n')}\n-----END $label-----\n';
  }
}

/// Serves [assets] (key → bytes) through the `flutter/assets` channel that
/// `rootBundle` reads from; any other key behaves like a missing asset.
void serveTestAssets(Map<String, List<int>> assets) {
  rootBundle.clear();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMessageHandler('flutter/assets', (message) async {
        final key = utf8.decode(
          message!.buffer.asUint8List(
            message.offsetInBytes,
            message.lengthInBytes,
          ),
        );
        final bytes = assets[Uri.decodeFull(key)];
        if (bytes == null) return null;
        return ByteData.sublistView(Uint8List.fromList(bytes));
      });
}

void clearTestAssets() {
  rootBundle.clear();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMessageHandler('flutter/assets', null);
}
