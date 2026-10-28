import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

/// Crypto primitives for proximity sharing (protocol v1).
///
/// The sender encrypts the payload with a random one-time key and sends it as
/// a [ShareEnvelope] that carries only a commitment (SHA-256) to its public
/// key. Both phones then run P-256 ECDH over session messages, derive a
/// verification code that the users compare, and the sender releases the
/// payload key wrapped with the derived key once the codes match. Committing
/// first stops a man in the middle from choosing keys until the codes agree.
abstract final class ShareCrypto {
  static final _domain = ECDomainParameters('secp256r1');
  static final _wrapAad = Uint8List.fromList(utf8.encode('hwshare-key-v1'));
  static final _kdfInfo = Uint8List.fromList(
    utf8.encode('healthwallet share v1'),
  );

  static const keyLength = 32;
  static const nonceLength = 12;
  static const publicKeyLength = 65;

  static Uint8List randomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
      List.generate(length, (_) => random.nextInt(256)),
    );
  }

  static AsymmetricKeyPair<ECPublicKey, ECPrivateKey> generateKeyPair() {
    final random = FortunaRandom()..seed(KeyParameter(randomBytes(32)));
    final generator = ECKeyGenerator()
      ..init(
        ParametersWithRandom(ECKeyGeneratorParameters(_domain), random),
      );
    final pair = generator.generateKeyPair();
    return AsymmetricKeyPair(
      pair.publicKey as ECPublicKey,
      pair.privateKey as ECPrivateKey,
    );
  }

  /// Uncompressed SEC1 encoding (65 bytes).
  static Uint8List encodePublicKey(ECPublicKey key) => key.Q!.getEncoded(false);

  /// Decodes an uncompressed P-256 point and rejects anything off the curve.
  static ECPublicKey decodePublicKey(Uint8List bytes) {
    if (bytes.length != publicKeyLength || bytes[0] != 0x04) {
      throw const FormatException('Invalid public key encoding');
    }
    final ECPoint? point;
    try {
      point = _domain.curve.decodePoint(bytes);
    } on ArgumentError {
      // Thrown for a coordinate that is not below the field size.
      throw const FormatException('Invalid public key coordinates');
    }
    if (point == null || point.isInfinity) {
      throw const FormatException('Invalid public key');
    }
    // decodePoint neither range-checks the coordinates nor checks the curve
    // equation; re-encoding catches the first, y² = x³ + ax + b the second.
    final x = point.x!;
    final y = point.y!;
    final rhs = x.square() * x + _domain.curve.a! * x + _domain.curve.b!;
    if (!_equal(point.getEncoded(false), bytes) ||
        y.square().toBigInteger() != rhs.toBigInteger()) {
      throw const FormatException('Public key is not on the curve');
    }
    return ECPublicKey(point, _domain);
  }

  static Uint8List commitment(Uint8List publicKey) =>
      SHA256Digest().process(publicKey);

  static bool matchesCommitment(Uint8List publicKey, Uint8List commitment) =>
      _equal(ShareCrypto.commitment(publicKey), commitment);

  /// Derives the key-wrapping key and the six-digit verification code from
  /// the ECDH secret, bound to both public keys.
  static SessionKeys deriveSessionKeys({
    required ECPrivateKey privateKey,
    required ECPublicKey peerPublicKey,
    required Uint8List senderPublicKey,
    required Uint8List receiverPublicKey,
  }) {
    final secret = (ECDHBasicAgreement()..init(privateKey)).calculateAgreement(
      peerPublicKey,
    );
    final salt = Uint8List.fromList([...senderPublicKey, ...receiverPublicKey]);
    final okm = Uint8List(keyLength + 4);
    HKDFKeyDerivator(SHA256Digest())
      ..init(
        HkdfParameters(_bigIntToBytes(secret, 32), okm.length, salt, _kdfInfo),
      )
      ..deriveKey(null, 0, okm, 0);

    final codeValue =
        ByteData.sublistView(okm, keyLength).getUint32(0) % 1000000;
    return SessionKeys(
      wrapKey: Uint8List.sublistView(okm, 0, keyLength),
      verificationCode: codeValue.toString().padLeft(6, '0'),
    );
  }

  /// `[nonce][ciphertext + tag]` of the payload key under [wrapKey].
  static Uint8List wrapPayloadKey(Uint8List wrapKey, Uint8List payloadKey) {
    final nonce = randomBytes(nonceLength);
    return Uint8List.fromList([
      ...nonce,
      ..._gcm(true, wrapKey, nonce, payloadKey, _wrapAad),
    ]);
  }

  static Uint8List unwrapPayloadKey(Uint8List wrapKey, Uint8List wrapped) {
    if (wrapped.length != nonceLength + keyLength + 16) {
      throw const FormatException('Invalid wrapped key');
    }
    return _gcm(
      false,
      wrapKey,
      Uint8List.sublistView(wrapped, 0, nonceLength),
      Uint8List.sublistView(wrapped, nonceLength),
      _wrapAad,
    );
  }

  /// Encrypts on a background isolate; payloads can be several megabytes.
  static Future<Uint8List> encrypt(
    Uint8List key,
    Uint8List nonce,
    Uint8List plaintext,
    Uint8List aad,
  ) => Isolate.run(() => _gcm(true, key, nonce, plaintext, aad));

  /// Throws [InvalidCipherTextException] when the data was tampered with.
  static Future<Uint8List> decrypt(
    Uint8List key,
    Uint8List nonce,
    Uint8List ciphertext,
    Uint8List aad,
  ) => Isolate.run(() => _gcm(false, key, nonce, ciphertext, aad));

  static Uint8List _gcm(
    bool forEncryption,
    Uint8List key,
    Uint8List nonce,
    Uint8List input,
    Uint8List aad,
  ) {
    final cipher = GCMBlockCipher(AESEngine())
      ..init(forEncryption, AEADParameters(KeyParameter(key), 128, nonce, aad));
    final output = Uint8List(cipher.getOutputSize(input.length));
    final len = cipher.processBytes(input, 0, input.length, output, 0);
    final finalLen = cipher.doFinal(output, len);
    return Uint8List.sublistView(output, 0, len + finalLen);
  }

  static Uint8List _bigIntToBytes(BigInt value, int length) {
    final bytes = Uint8List(length);
    var v = value;
    for (var i = length - 1; i >= 0; i--) {
      bytes[i] = (v & BigInt.from(0xff)).toInt();
      v = v >> 8;
    }
    return bytes;
  }

  static bool _equal(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}

class SessionKeys {
  final Uint8List wrapKey;
  final String verificationCode;

  const SessionKeys({required this.wrapKey, required this.verificationCode});
}

/// The file the sender transfers:
/// `"HWSE" | version (1) | commitment (32) | nonce (12) | ciphertext + tag`.
/// The header up to the commitment is authenticated as associated data.
class ShareEnvelope {
  static final _magic = Uint8List.fromList(utf8.encode('HWSE'));
  static const version = 1;
  static const _headerLength = 4 + 1 + 32;

  final Uint8List commitment;
  final Uint8List nonce;
  final Uint8List ciphertext;

  const ShareEnvelope({
    required this.commitment,
    required this.nonce,
    required this.ciphertext,
  });

  /// Whether [bytes] start like an envelope (any version).
  static bool looksLikeEnvelope(Uint8List bytes) =>
      bytes.length >= 4 && ShareCrypto._equal(bytes.sublist(0, 4), _magic);

  static ShareEnvelope decode(Uint8List bytes) {
    if (!looksLikeEnvelope(bytes) ||
        bytes.length < _headerLength + ShareCrypto.nonceLength + 16) {
      throw const FormatException('Not a share envelope');
    }
    if (bytes[4] != version) {
      throw FormatException('Unsupported envelope version ${bytes[4]}');
    }
    const nonceEnd = _headerLength + ShareCrypto.nonceLength;
    return ShareEnvelope(
      commitment: Uint8List.sublistView(bytes, 5, _headerLength),
      nonce: Uint8List.sublistView(bytes, _headerLength, nonceEnd),
      ciphertext: Uint8List.sublistView(bytes, nonceEnd),
    );
  }

  static Uint8List associatedData(Uint8List commitment) =>
      Uint8List.fromList([..._magic, version, ...commitment]);

  Uint8List get aad => associatedData(commitment);

  Uint8List encode() =>
      (BytesBuilder(copy: false)
            ..add(aad)
            ..add(nonce)
            ..add(ciphertext))
          .takeBytes();
}
