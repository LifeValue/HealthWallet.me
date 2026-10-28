import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/features/share_records/data/crypto/share_crypto.dart';
import 'package:pointycastle/export.dart';

Uint8List _publicKey(AsymmetricKeyPair<ECPublicKey, ECPrivateKey> pair) =>
    ShareCrypto.encodePublicKey(pair.publicKey);

void main() {
  group('key agreement', () {
    test('both sides derive the same wrap key and code', () {
      final sender = ShareCrypto.generateKeyPair();
      final receiver = ShareCrypto.generateKeyPair();

      final senderKeys = ShareCrypto.deriveSessionKeys(
        privateKey: sender.privateKey,
        peerPublicKey: receiver.publicKey,
        senderPublicKey: _publicKey(sender),
        receiverPublicKey: _publicKey(receiver),
      );
      final receiverKeys = ShareCrypto.deriveSessionKeys(
        privateKey: receiver.privateKey,
        peerPublicKey: sender.publicKey,
        senderPublicKey: _publicKey(sender),
        receiverPublicKey: _publicKey(receiver),
      );

      expect(senderKeys.verificationCode, receiverKeys.verificationCode);
      expect(senderKeys.verificationCode, matches(RegExp(r'^\d{6}$')));
      expect(senderKeys.wrapKey, receiverKeys.wrapKey);
      expect(senderKeys.wrapKey, hasLength(ShareCrypto.keyLength));
    });

    test('a different peer key gives a different wrap key', () {
      final sender = ShareCrypto.generateKeyPair();
      final receiver = ShareCrypto.generateKeyPair();
      final attacker = ShareCrypto.generateKeyPair();

      SessionKeys keysWith(
        AsymmetricKeyPair<ECPublicKey, ECPrivateKey> peer,
      ) => ShareCrypto.deriveSessionKeys(
        privateKey: sender.privateKey,
        peerPublicKey: peer.publicKey,
        senderPublicKey: _publicKey(sender),
        receiverPublicKey: _publicKey(peer),
      );

      expect(keysWith(receiver).wrapKey, isNot(keysWith(attacker).wrapKey));
    });

    test('public keys round-trip through their encoding', () {
      final pair = ShareCrypto.generateKeyPair();
      final encoded = _publicKey(pair);

      expect(encoded, hasLength(ShareCrypto.publicKeyLength));
      expect(
        ShareCrypto.decodePublicKey(encoded).Q,
        pair.publicKey.Q,
      );
    });

    final invalidKeys = <String, Uint8List Function(Uint8List)>{
      'a point off the curve': (key) => Uint8List.fromList(key)..[64] ^= 0x01,
      'a coordinate above the field size': (key) =>
          Uint8List.fromList(key)..fillRange(1, 33, 0xff),
      'a compressed point': (key) =>
          Uint8List.fromList(key.sublist(0, 33))..[0] = 0x02,
      'the wrong prefix': (key) => Uint8List.fromList(key)..[0] = 0x05,
    };
    for (final MapEntry(key: name, value: corrupt) in invalidKeys.entries) {
      test('decodePublicKey rejects $name', () {
        final key = _publicKey(ShareCrypto.generateKeyPair());
        expect(
          () => ShareCrypto.decodePublicKey(corrupt(key)),
          throwsFormatException,
        );
      });
    }

    test('commitments match only their own key', () {
      final key = _publicKey(ShareCrypto.generateKeyPair());
      final other = _publicKey(ShareCrypto.generateKeyPair());
      final commitment = ShareCrypto.commitment(key);

      expect(ShareCrypto.matchesCommitment(key, commitment), isTrue);
      expect(ShareCrypto.matchesCommitment(other, commitment), isFalse);
    });
  });

  group('payload key wrapping', () {
    test('unwraps with the same key', () {
      final wrapKey = ShareCrypto.randomBytes(32);
      final payloadKey = ShareCrypto.randomBytes(32);

      final wrapped = ShareCrypto.wrapPayloadKey(wrapKey, payloadKey);

      expect(ShareCrypto.unwrapPayloadKey(wrapKey, wrapped), payloadKey);
    });

    test('fails with another key', () {
      final wrapped = ShareCrypto.wrapPayloadKey(
        ShareCrypto.randomBytes(32),
        ShareCrypto.randomBytes(32),
      );

      expect(
        () => ShareCrypto.unwrapPayloadKey(
          ShareCrypto.randomBytes(32),
          wrapped,
        ),
        throwsA(isA<InvalidCipherTextException>()),
      );
    });
  });

  group('payload encryption', () {
    final key = ShareCrypto.randomBytes(32);
    final nonce = ShareCrypto.randomBytes(12);
    final aad = Uint8List.fromList([1, 2, 3]);
    final plaintext = Uint8List.fromList(utf8.encode('{"records":[]}'));

    test('decrypts what it encrypted', () async {
      final ciphertext = await ShareCrypto.encrypt(key, nonce, plaintext, aad);

      expect(ciphertext, isNot(plaintext));
      expect(
        await ShareCrypto.decrypt(key, nonce, ciphertext, aad),
        plaintext,
      );
    });

    test('rejects changed ciphertext or associated data', () async {
      final ciphertext = await ShareCrypto.encrypt(key, nonce, plaintext, aad);
      final tampered = Uint8List.fromList(ciphertext)..[0] ^= 0x01;

      await expectLater(
        ShareCrypto.decrypt(key, nonce, tampered, aad),
        throwsA(isA<InvalidCipherTextException>()),
      );
      await expectLater(
        ShareCrypto.decrypt(key, nonce, ciphertext, Uint8List.fromList([9])),
        throwsA(isA<InvalidCipherTextException>()),
      );
    });
  });

  group('envelope', () {
    ShareEnvelope envelope() => ShareEnvelope(
      commitment: Uint8List(32)..[0] = 7,
      nonce: Uint8List(12)..[0] = 8,
      ciphertext: Uint8List(20)..[0] = 9,
    );

    test('round-trips through its encoding', () {
      final decoded = ShareEnvelope.decode(envelope().encode());

      expect(decoded.commitment, envelope().commitment);
      expect(decoded.nonce, envelope().nonce);
      expect(decoded.ciphertext, envelope().ciphertext);
      expect(decoded.aad, envelope().aad);
    });

    test('is told apart from the old JSON payloads', () {
      expect(ShareEnvelope.looksLikeEnvelope(envelope().encode()), isTrue);
      expect(
        ShareEnvelope.looksLikeEnvelope(
          Uint8List.fromList(utf8.encode('{"id":"x"}')),
        ),
        isFalse,
      );
    });

    test('rejects other versions and truncated data', () {
      final otherVersion = envelope().encode()..[4] = 2;
      expect(() => ShareEnvelope.decode(otherVersion), throwsFormatException);

      final truncated = envelope().encode().sublist(0, 40);
      expect(() => ShareEnvelope.decode(truncated), throwsFormatException);
    });
  });
}
