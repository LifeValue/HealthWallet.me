import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/features/share_records/data/crypto/share_crypto.dart';
import 'package:health_wallet/features/share_records/data/service/secure_share_session.dart';

/// One end of an in-memory link; [intercept] can rewrite or drop messages.
class _End implements ShareMessageTransport {
  final StreamController<Uint8List> _inbox;
  late _End peer;
  Uint8List? Function(Uint8List message)? intercept;
  final sent = <Uint8List>[];

  _End(this._inbox);

  @override
  Stream<Uint8List> get messages => _inbox.stream;

  @override
  Future<void> send(Uint8List message) async {
    sent.add(message);
    final delivered = intercept == null ? message : intercept!(message);
    if (delivered != null) peer._inbox.add(delivered);
  }
}

(_End, _End) _link() {
  final a = _End(StreamController<Uint8List>.broadcast());
  final b = _End(StreamController<Uint8List>.broadcast());
  a.peer = b;
  b.peer = a;
  addTearDown(() async {
    await a._inbox.close();
    await b._inbox.close();
  });
  return (a, b);
}

final _records = Uint8List.fromList(utf8.encode('{"records":["blood test"]}'));

void main() {
  late _End senderEnd;
  late _End receiverEnd;
  late SecureShareSession sender;
  late SecureShareSession receiver;

  setUp(() {
    (senderEnd, receiverEnd) = _link();
    sender = SecureShareSession(senderEnd);
    // The default waits: the key exchange is real crypto, slow on a busy
    // runner. Tests that expect a wait to run out shorten it.
    receiver = SecureShareSession(receiverEnd);
    addTearDown(sender.dispose);
    addTearDown(receiver.dispose);
  });

  /// [receiver] again, giving up after 300 ms.
  Future<void> impatientReceiver() async {
    await receiver.dispose();
    receiver = SecureShareSession(
      receiverEnd,
      keyTimeout: const Duration(milliseconds: 300),
      confirmationTimeout: const Duration(milliseconds: 300),
    );
    addTearDown(receiver.dispose);
  }

  test('the receiver opens the records after the sender confirms', () async {
    final envelope = await sender.seal(_records);
    final senderCode = sender.awaitReceiver();

    final receiverCode = await receiver.open(envelope);
    expect(await senderCode, receiverCode);

    await sender.confirm();
    expect(await receiver.awaitPayload(), _records);
  });

  test('the envelope holds no plaintext and no sender key', () async {
    final envelope = await sender.seal(_records);

    expect(
      utf8.decode(envelope, allowMalformed: true),
      isNot(contains('blood')),
    );
    expect(senderEnd.sent, isEmpty);
  });

  test('the payload key is not sent before the sender confirms', () async {
    await impatientReceiver();
    final envelope = await sender.seal(_records);
    final senderCode = sender.awaitReceiver();
    await receiver.open(envelope);
    await senderCode;

    // Receiver key in, sender key out; nothing else until confirm().
    expect(senderEnd.sent.map((m) => m.first), [0x02]);
    await expectLater(
      receiver.awaitPayload(),
      throwsA(isA<SecureShareException>()),
    );
  });

  test('a swapped sender key fails the commitment check', () async {
    // A man in the middle answers the receiver with its own key, which it
    // could not have committed to before seeing the receiver's key.
    final envelope = await sender.seal(_records);
    final attacker = ShareCrypto.encodePublicKey(
      ShareCrypto.generateKeyPair().publicKey,
    );
    senderEnd.intercept = (message) => message.first == 0x02
        ? Uint8List.fromList([0x02, ...attacker])
        : message;
    unawaited(sender.awaitReceiver().catchError((_) => ''));

    await expectLater(
      receiver.open(envelope),
      throwsA(isA<SecureShareException>()),
    );
  });

  test('a swapped receiver key changes the sender\'s code', () async {
    // The attacker can relay the envelope but not the receiver's code.
    final envelope = await sender.seal(_records);
    final attacker = ShareCrypto.encodePublicKey(
      ShareCrypto.generateKeyPair().publicKey,
    );
    receiverEnd.intercept = (message) => message.first == 0x01
        ? Uint8List.fromList([0x01, ...attacker])
        : message;
    final senderCode = sender.awaitReceiver();
    final receiverCode = receiver.open(envelope).catchError((_) => 'failed');

    expect(await senderCode, isNot(await receiverCode));
  });

  test('a tampered envelope fails authentication', () async {
    final envelope = await sender.seal(_records);
    envelope[envelope.length - 1] ^= 0x01;
    final senderCode = sender.awaitReceiver();
    await receiver.open(envelope);
    await senderCode;

    await sender.confirm();

    await expectLater(
      receiver.awaitPayload(),
      throwsA(isA<SecureShareException>()),
    );
  });

  test('the receiver times out without a sender key', () async {
    await impatientReceiver();
    final envelope = await sender.seal(_records);
    receiverEnd.intercept = (_) => null;

    await expectLater(
      receiver.open(envelope),
      throwsA(isA<SecureShareException>()),
    );
  });

  test('open rejects data that is not an envelope', () async {
    await expectLater(
      receiver.open(Uint8List.fromList(utf8.encode('{"id":"x"}'))),
      throwsA(isA<SecureShareException>()),
    );
    expect(receiverEnd.sent, isEmpty);
  });

  test('malformed and repeated messages are ignored', () async {
    final envelope = await sender.seal(_records);
    final senderCode = sender.awaitReceiver();
    receiverEnd.peer._inbox
      ..add(Uint8List(0))
      ..add(Uint8List.fromList([0x01, 1, 2, 3]))
      ..add(Uint8List.fromList([0x7f, ...List.filled(65, 0)]));

    final receiverCode = await receiver.open(envelope);
    expect(await senderCode, receiverCode);

    await sender.confirm();
    await sender.confirm();
    expect(senderEnd.sent.where((m) => m.first == 0x03), hasLength(1));
    expect(await receiver.awaitPayload(), _records);
  });

  test('dispose cancels a waiting step', () async {
    final envelope = await sender.seal(_records);
    final senderCode = sender.awaitReceiver();
    await receiver.open(envelope);
    await senderCode;

    final payload = receiver.awaitPayload();
    await receiver.dispose();

    await expectLater(payload, throwsA(isA<SecureShareCancelled>()));
  });

  test('a session disposed after sealing cancels the key exchange instead '
      'of throwing', () async {
    final (sender, _) = _link();
    final session = SecureShareSession(sender);
    await session.seal(utf8.encode('{}'));
    await session.dispose();

    await expectLater(
      session.awaitReceiver(),
      throwsA(isA<SecureShareCancelled>()),
    );
  });

  test('a session disposed while sealing keeps no keys', () async {
    final (sender, _) = _link();
    final session = SecureShareSession(sender);
    final sealing = session.seal(utf8.encode('{}'));
    await session.dispose();

    await expectLater(sealing, throwsA(isA<SecureShareCancelled>()));
    await expectLater(
      session.awaitReceiver(),
      throwsA(isA<SecureShareCancelled>()),
    );
  });

  test('confirm needs a completed exchange', () async {
    await sender.seal(_records);
    expect(sender.confirm, throwsStateError);
  });
}
