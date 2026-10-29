import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:health_wallet/features/share_records/data/crypto/share_crypto.dart';
import 'package:pointycastle/export.dart';

/// Carries opaque messages between the two phones of a share session.
abstract class ShareMessageTransport {
  Stream<Uint8List> get messages;

  Future<void> send(Uint8List message);
}

/// The key exchange failed or was tampered with; the session must end.
class SecureShareException implements Exception {
  final String message;

  const SecureShareException(this.message);

  @override
  String toString() => 'SecureShareException: $message';
}

/// The session was disposed while a step was waiting.
class SecureShareCancelled implements Exception {
  const SecureShareCancelled();
}

/// One end of the key exchange for a single transfer (see [ShareCrypto]).
///
/// Sender: [seal] → transfer the envelope → [awaitReceiver] → users compare
/// the code → [confirm]. Receiver: [open] → users compare the code →
/// [awaitPayload].
class SecureShareSession {
  static const _receiverKey = 0x01;
  static const _senderKey = 0x02;
  static const _payloadKey = 0x03;

  final ShareMessageTransport _transport;
  final Duration keyTimeout;
  final Duration confirmationTimeout;

  late final StreamSubscription<Uint8List> _subscription;
  final _inbox = <int, Completer<Uint8List>>{};
  bool _disposed = false;

  AsymmetricKeyPair<ECPublicKey, ECPrivateKey>? _keyPair;
  Uint8List? _payloadKeyBytes;
  SessionKeys? _sessionKeys;
  ShareEnvelope? _envelope;
  bool _confirmed = false;

  SecureShareSession(
    this._transport, {
    this.keyTimeout = const Duration(seconds: 60),
    this.confirmationTimeout = const Duration(minutes: 5),
  }) {
    _subscription = _transport.messages.listen(_onMessage);
  }

  // Sender

  /// Encrypts [plaintext] with a fresh payload key and returns the envelope
  /// to transfer. The payload key stays here until [confirm].
  Future<Uint8List> seal(Uint8List plaintext) async {
    final keyPair = ShareCrypto.generateKeyPair();
    final payloadKey = ShareCrypto.randomBytes(ShareCrypto.keyLength);
    final commitment = ShareCrypto.commitment(
      ShareCrypto.encodePublicKey(keyPair.publicKey),
    );
    final nonce = ShareCrypto.randomBytes(ShareCrypto.nonceLength);
    final ciphertext = await ShareCrypto.encrypt(
      payloadKey,
      nonce,
      plaintext,
      ShareEnvelope.associatedData(commitment),
    );
    _keyPair = keyPair;
    _payloadKeyBytes = payloadKey;
    return ShareEnvelope(
      commitment: commitment,
      nonce: nonce,
      ciphertext: ciphertext,
    ).encode();
  }

  /// Waits for the receiver's key, reveals ours and returns the code to show.
  Future<String> awaitReceiver() async {
    final keyPair = _keyPair;
    if (keyPair == null) throw StateError('seal() must run first');

    final receiverKeyBytes = await _receive(_receiverKey, null);
    final senderKeyBytes = ShareCrypto.encodePublicKey(keyPair.publicKey);
    final keys = ShareCrypto.deriveSessionKeys(
      privateKey: keyPair.privateKey,
      peerPublicKey: _decodeKey(receiverKeyBytes),
      senderPublicKey: senderKeyBytes,
      receiverPublicKey: receiverKeyBytes,
    );
    await _send(_senderKey, senderKeyBytes);
    _sessionKeys = keys;
    return keys.verificationCode;
  }

  /// Releases the payload key once the user has confirmed the codes match.
  Future<void> confirm() async {
    final keys = _sessionKeys;
    final payloadKey = _payloadKeyBytes;
    if (keys == null || payloadKey == null) {
      throw StateError('awaitReceiver() must complete first');
    }
    if (_confirmed) return;
    _confirmed = true;
    await _send(
      _payloadKey,
      ShareCrypto.wrapPayloadKey(keys.wrapKey, payloadKey),
    );
  }

  // Receiver

  /// Starts the exchange for a received envelope and returns the code to show.
  Future<String> open(Uint8List envelopeBytes) async {
    final ShareEnvelope envelope;
    try {
      envelope = ShareEnvelope.decode(envelopeBytes);
    } on FormatException catch (e) {
      throw SecureShareException(e.message);
    }
    final keyPair = ShareCrypto.generateKeyPair();
    final receiverKeyBytes = ShareCrypto.encodePublicKey(keyPair.publicKey);
    await _send(_receiverKey, receiverKeyBytes);

    final senderKeyBytes = await _receive(_senderKey, keyTimeout);
    if (!ShareCrypto.matchesCommitment(senderKeyBytes, envelope.commitment)) {
      throw const SecureShareException(
        'Sender key does not match its commitment',
      );
    }
    final keys = ShareCrypto.deriveSessionKeys(
      privateKey: keyPair.privateKey,
      peerPublicKey: _decodeKey(senderKeyBytes),
      senderPublicKey: senderKeyBytes,
      receiverPublicKey: receiverKeyBytes,
    );
    _envelope = envelope;
    _sessionKeys = keys;
    return keys.verificationCode;
  }

  /// Waits for the sender to confirm, then decrypts the payload.
  Future<Uint8List> awaitPayload() async {
    final keys = _sessionKeys;
    final envelope = _envelope;
    if (keys == null || envelope == null) {
      throw StateError('open() must complete first');
    }
    final wrapped = await _receive(_payloadKey, confirmationTimeout);
    try {
      final payloadKey = ShareCrypto.unwrapPayloadKey(keys.wrapKey, wrapped);
      return await ShareCrypto.decrypt(
        payloadKey,
        envelope.nonce,
        envelope.ciphertext,
        envelope.aad,
      );
    } on InvalidCipherTextException {
      throw const SecureShareException('Payload failed authentication');
    } on FormatException catch (e) {
      throw SecureShareException(e.message);
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _subscription.cancel();
    for (final completer in _inbox.values) {
      if (!completer.isCompleted) {
        completer.completeError(const SecureShareCancelled());
      }
    }
    _payloadKeyBytes?.fillRange(0, _payloadKeyBytes!.length, 0);
    _payloadKeyBytes = null;
    _keyPair = null;
    _sessionKeys = null;
  }

  void _onMessage(Uint8List message) {
    if (message.isEmpty) return;
    final type = message[0];
    final expectedLength = switch (type) {
      _receiverKey || _senderKey => 1 + ShareCrypto.publicKeyLength,
      _payloadKey => 1 + ShareCrypto.nonceLength + ShareCrypto.keyLength + 16,
      _ => null,
    };
    if (expectedLength == null || message.length != expectedLength) {
      debugPrint('[SecureShare] Ignoring malformed message (type $type)');
      return;
    }
    final completer = _completer(type);
    // Each step happens once; a repeat could only be a replay.
    if (!completer.isCompleted) {
      completer.complete(Uint8List.fromList(message.sublist(1)));
    }
  }

  Completer<Uint8List> _completer(int type) =>
      _inbox.putIfAbsent(type, Completer<Uint8List>.new);

  Future<Uint8List> _receive(int type, Duration? timeout) async {
    if (_disposed) throw const SecureShareCancelled();
    final future = _completer(type).future;
    if (timeout == null) return future;
    try {
      return await future.timeout(timeout);
    } on TimeoutException {
      throw const SecureShareException('Timed out waiting for the other phone');
    }
  }

  Future<void> _send(int type, Uint8List body) async {
    if (_disposed) throw const SecureShareCancelled();
    try {
      await _transport.send(Uint8List.fromList([type, ...body]));
    } catch (e) {
      throw SecureShareException('Could not reach the other phone: $e');
    }
  }

  ECPublicKey _decodeKey(Uint8List bytes) {
    try {
      return ShareCrypto.decodePublicKey(bytes);
    } on FormatException catch (e) {
      throw SecureShareException(e.message);
    }
  }
}
