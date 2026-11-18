import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';
import 'package:flutter/foundation.dart';

/// The phone ↔ desktop link, version 2. See "Mobile ↔ desktop
/// communication" in `_bmad-output/planning-artifacts/architecture.md`.
///
/// Every frame body starts with a kind byte:
/// - [_kindUnknownKey], alone: the desktop couldn't read the hello, so this
///   phone's pairing key is not (or no longer) the desktop's.
/// - [_kindHandshake]: `[12-byte nonce][AES-256-GCM]` under the pairing key,
///   for hello, ack, confirm and reject.
/// - [_kindSession]: `[8-byte counter][AES-256-GCM]` under a key derived for
///   this session and direction; the counter is the nonce and must be the
///   next one, so a frame can't be replayed, reordered or reflected.
const protocolVersion = 2;

const _kindUnknownKey = 0x00;
const _kindHandshake = 0x01;
const _kindSession = 0x02;

final _handshakeAad = Uint8List.fromList(utf8.encode('hw-link-2 handshake'));
final _sessionAad = Uint8List.fromList(utf8.encode('hw-link-2 session'));

enum MessageType {
  hello(0x01),
  ack(0x02),
  ping(0x03),
  pong(0x04),
  data(0x05),
  confirm(0x06),
  reject(0x07),
  ready(0x08),
  kill(0xFF);

  final int code;
  const MessageType(this.code);

  static MessageType fromCode(int code) {
    return MessageType.values.firstWhere(
      (t) => t.code == code,
      orElse: () => throw ArgumentError('Unknown message type: $code'),
    );
  }
}

class TcpMessage {
  final MessageType type;
  final Uint8List payload;

  const TcpMessage({required this.type, required this.payload});

  TcpMessage.fromString({required this.type, required String data})
    : payload = Uint8List.fromList(utf8.encode(data));

  String get payloadString => utf8.decode(payload);
}

/// Why a link ended before or instead of becoming ready.
enum LinkFailure {
  /// The desktop doesn't know this phone's key (a new QR code was made).
  unknownKey,

  /// The other side runs an incompatible app version.
  version,

  /// The desktop user declined this phone.
  declined,

  /// The answer came from another desktop than the paired one.
  wrongDesktop,

  /// The peer's proof didn't match: it doesn't hold the pairing key.
  badProof,

  /// No answer in time, or the connection closed during the handshake.
  noAnswer,
}

class LinkException implements Exception {
  const LinkException(this.failure, [this.detail]);

  final LinkFailure failure;
  final String? detail;

  @override
  String toString() =>
      'LinkException(${failure.name}${detail == null ? '' : ': $detail'})';
}

/// Thrown by a send when no verified link is up, so callers can keep the
/// data for later instead of believing it went out.
class LinkNotConnectedException implements Exception {
  const LinkNotConnectedException();

  @override
  String toString() => 'LinkNotConnectedException';
}

/// The verified device at the other end.
class PeerInfo {
  const PeerInfo({required this.deviceId, required this.name});

  final String deviceId;
  final String name;
}

/// Decodes a pairing key: 32 bytes, base64url with or without padding.
/// Throws [FormatException] for anything else.
Uint8List decodePairingKey(String key) {
  final trimmed = key.trim();
  final padded = trimmed.padRight(
    trimmed.length + (4 - trimmed.length % 4) % 4,
    '=',
  );
  final Uint8List bytes;
  try {
    bytes = base64Url.decode(padded);
  } on FormatException {
    throw const FormatException('pairing key is not base64url');
  }
  if (bytes.length != 32) {
    throw FormatException('pairing key has ${bytes.length} bytes, not 32');
  }
  return bytes;
}

bool isValidPairingKey(String key) {
  try {
    decodePairingKey(key);
    return true;
  } on FormatException {
    return false;
  }
}

/// A short value derived from the pairing key that the desktop advertises
/// over MPC and Bonjour, so the phone finds its own desktop among others
/// without anyone learning the key.
String discoveryToken(String pairingKey, String desktopId) {
  final mac = crypto.Hmac(
    crypto.sha256,
    decodePairingKey(pairingKey),
  ).convert(utf8.encode('hw-link-2 discovery|$desktopId'));
  return base64Url.encode(mac.bytes.sublist(0, 12)).replaceAll('=', '');
}

final _random = Random.secure();

Uint8List _randomBytes(int length) =>
    Uint8List.fromList(List.generate(length, (_) => _random.nextInt(256)));

// pointycastle's GCM runs at about 1.5 MB/s; this one is about ten times
// faster, which matters for sync batches of a few megabytes.
final _aesGcm = DartAesGcm.with256bits();

/// AES-256-GCM: `[ciphertext][16-byte tag]`. Decryption throws when the tag
/// doesn't match.
Uint8List _gcm(
  bool encrypt,
  Uint8List key,
  Uint8List nonce,
  Uint8List aad,
  Uint8List input,
) {
  final secretKey = SecretKeyData(key);
  if (encrypt) {
    final box = _aesGcm.encryptSync(
      input,
      secretKeyData: secretKey,
      nonce: nonce,
      aad: aad,
    );
    return Uint8List.fromList([...box.cipherText, ...box.mac.bytes]);
  }
  if (input.length < 16) throw const FormatException('ciphertext too short');
  final split = input.length - 16;
  final clear = _aesGcm.decryptSync(
    SecretBox(
      Uint8List.sublistView(input, 0, split),
      nonce: nonce,
      mac: Mac(Uint8List.sublistView(input, split)),
    ),
    secretKeyData: secretKey,
    aad: aad,
  );
  return clear is Uint8List ? clear : Uint8List.fromList(clear);
}

Uint8List _hmac(Uint8List key, List<int> message) => Uint8List.fromList(
  crypto.Hmac(crypto.sha256, key).convert(message).bytes,
);

/// HKDF-SHA256 (RFC 5869) for one 32-byte key.
Uint8List _hkdf(Uint8List ikm, Uint8List salt, String info) {
  final prk = _hmac(salt, ikm);
  return _hmac(prk, [...utf8.encode(info), 1]);
}

@visibleForTesting
Uint8List sealHandshake(
  Uint8List key,
  MessageType type,
  Map<String, dynamic> json,
) {
  final nonce = _randomBytes(12);
  final plain = Uint8List.fromList([
    type.code,
    ...utf8.encode(jsonEncode(json)),
  ]);
  return Uint8List.fromList([
    _kindHandshake,
    ...nonce,
    ..._gcm(true, key, nonce, _handshakeAad, plain),
  ]);
}

/// The type and JSON of a handshake body, or null when [key] can't open it.
@visibleForTesting
(MessageType, Map<String, dynamic>)? openHandshake(
  Uint8List key,
  Uint8List body,
) {
  if (body.length < 1 + 12 + 16 || body[0] != _kindHandshake) return null;
  try {
    final plain = _gcm(
      false,
      key,
      body.sublist(1, 13),
      _handshakeAad,
      body.sublist(13),
    );
    final json = jsonDecode(utf8.decode(plain.sublist(1)));
    if (json is! Map<String, dynamic>) return null;
    return (MessageType.fromCode(plain[0]), json);
  } catch (_) {
    // Wrong key, tampered bytes or not a handshake message.
    return null;
  }
}

/// Encrypts and checks the frames of one session in one direction each.
class SessionCipher {
  SessionCipher(this._sendKey, this._receiveKey);

  final Uint8List _sendKey;
  final Uint8List _receiveKey;
  int _sent = 0;
  int _received = 0;

  static Uint8List _nonce(int counter) {
    final nonce = Uint8List(12);
    ByteData.sublistView(nonce).setUint64(4, counter);
    return nonce;
  }

  Uint8List seal(MessageType type, Uint8List payload) {
    final counter = _sent++;
    final header = Uint8List(9)..[0] = _kindSession;
    ByteData.sublistView(header).setUint64(1, counter);
    final plain = Uint8List(1 + payload.length)
      ..[0] = type.code
      ..setAll(1, payload);
    return Uint8List.fromList([
      ...header,
      ..._gcm(true, _sendKey, _nonce(counter), _sessionAad, plain),
    ]);
  }

  /// Throws when the frame doesn't decrypt or isn't the next one.
  TcpMessage open(Uint8List body) {
    if (body.length < 9 + 16 || body[0] != _kindSession) {
      throw const FormatException('not a session frame');
    }
    final counter = ByteData.sublistView(body, 1, 9).getUint64(0);
    if (counter != _received) {
      throw FormatException('frame $counter, expected $_received');
    }
    final plain = _gcm(
      false,
      _receiveKey,
      _nonce(counter),
      _sessionAad,
      body.sublist(9),
    );
    _received++;
    return TcpMessage(
      type: MessageType.fromCode(plain[0]),
      payload: plain.sublist(1),
    );
  }
}

/// Splits a byte stream into length-prefixed frames (TCP). Bytes are kept as
/// received and copied once per frame.
class FrameReader {
  FrameReader({
    required this.maxFrame,
    required this.onFrame,
    required this.onTooLarge,
  });

  int Function() maxFrame;
  final void Function(Uint8List body) onFrame;
  final void Function(int length) onTooLarge;

  final _chunks = <Uint8List>[];
  int _buffered = 0;
  int? _expected;
  bool _stopped = false;

  static Uint8List frame(Uint8List body) {
    final out = Uint8List(4 + body.length);
    ByteData.sublistView(out, 0, 4).setUint32(0, body.length);
    out.setAll(4, body);
    return out;
  }

  void add(List<int> data) {
    if (_stopped || data.isEmpty) return;
    _chunks.add(data is Uint8List ? data : Uint8List.fromList(data));
    _buffered += data.length;
    while (!_stopped) {
      if (_expected == null) {
        if (_buffered < 4) return;
        final length = ByteData.sublistView(_take(4)).getUint32(0);
        if (length > maxFrame()) {
          _stopped = true;
          onTooLarge(length);
          return;
        }
        _expected = length;
      }
      if (_buffered < _expected!) return;
      final body = _take(_expected!);
      _expected = null;
      onFrame(body);
    }
  }

  void stop() {
    _stopped = true;
    _chunks.clear();
    _buffered = 0;
  }

  Uint8List _take(int count) {
    final out = Uint8List(count);
    var filled = 0;
    while (filled < count) {
      final chunk = _chunks.first;
      final needed = count - filled;
      if (chunk.length <= needed) {
        out.setAll(filled, chunk);
        filled += chunk.length;
        _chunks.removeAt(0);
      } else {
        out.setAll(filled, Uint8List.sublistView(chunk, 0, needed));
        _chunks[0] = Uint8List.sublistView(chunk, needed);
        filled += needed;
      }
    }
    _buffered -= count;
    return out;
  }
}

/// MPC carries whole messages but large ones fail, so a frame body travels
/// in pieces of at most [pieceSize]: `[1 = last, 0 = more][bytes]`.
class MpcFramer {
  MpcFramer({
    required this.maxFrame,
    required this.onFrame,
    required this.onTooLarge,
  });

  static const pieceSize = 60 * 1024;

  int Function() maxFrame;
  final void Function(Uint8List body) onFrame;
  final void Function(int length) onTooLarge;

  final _pending = BytesBuilder(copy: false);
  bool _stopped = false;

  static List<Uint8List> split(Uint8List body) {
    final pieces = <Uint8List>[];
    var offset = 0;
    do {
      final end = min(offset + pieceSize, body.length);
      pieces.add(
        Uint8List(1 + end - offset)
          ..[0] = end == body.length ? 1 : 0
          ..setAll(1, Uint8List.sublistView(body, offset, end)),
      );
      offset = end;
    } while (offset < body.length);
    return pieces;
  }

  void add(Uint8List piece) {
    if (_stopped || piece.isEmpty) return;
    _pending.add(Uint8List.sublistView(piece, 1));
    if (_pending.length > maxFrame()) {
      _stopped = true;
      onTooLarge(_pending.length);
      _pending.clear();
      return;
    }
    if (piece[0] == 1) onFrame(_pending.takeBytes());
  }

  void stop() {
    _stopped = true;
    _pending.clear();
  }
}

/// How the link layer below a channel sends a body and closes.
abstract class LinkEndpoint {
  Future<void> sendBody(Uint8List body);
  void close();
}

enum ChannelState { handshaking, awaitingApproval, ready, closed }

/// Timings of a channel; shortened in tests.
class LinkTimings {
  const LinkTimings({
    this.handshake = const Duration(seconds: 15),
    this.approval = const Duration(minutes: 2),
    this.pingInterval = const Duration(seconds: 10),
    this.clientIdle = const Duration(seconds: 25),
    this.serverIdle = const Duration(seconds: 35),
  });

  final Duration handshake;
  final Duration approval;
  final Duration pingInterval;

  /// With nothing received for this long, the phone treats the link as dead;
  /// any frame counts, so a long transfer never trips it.
  final Duration clientIdle;

  /// The desktop drops a phone it hasn't heard from (pings included) for
  /// this long, so a half-open socket never holds the slot.
  final Duration serverIdle;
}

/// Largest frame before the handshake completes; a hello is a few hundred
/// bytes.
const maxHandshakeFrameBytes = 64 * 1024;

/// Largest frame on a verified link: sync batches and file chunks stay far
/// below it.
const maxSessionFrameBytes = 16 * 1024 * 1024;

/// One phone ↔ desktop session over one TCP socket or MPC session: the
/// handshake, encryption, keep-alive and the frames' types.
class SecureChannel {
  SecureChannel.client({
    required this._endpoint,
    required String pairingKey,
    required this.localId,
    required this.localName,
    required String this._expectedPeerId,
    this.timings = const LinkTimings(),
  }) : _isServer = false,
       _keys = [decodePairingKey(pairingKey)],
       _isPairedPeer = null;

  SecureChannel.server({
    required this._endpoint,
    required List<String> pairingKeys,
    required this.localId,
    required this.localName,
    required bool Function(String peerId) this._isPairedPeer,
    this.timings = const LinkTimings(),
  }) : _isServer = true,
       _keys = [for (final k in pairingKeys) decodePairingKey(k)],
       _expectedPeerId = null;

  final LinkEndpoint _endpoint;
  final bool _isServer;
  final List<Uint8List> _keys;
  final String? _expectedPeerId;
  final bool Function(String peerId)? _isPairedPeer;
  final String localId;
  final String localName;
  final LinkTimings timings;

  final _messages = StreamController<TcpMessage>.broadcast(sync: true);
  final _states = StreamController<ChannelState>.broadcast(sync: true);
  final _ready = Completer<void>();

  ChannelState _state = ChannelState.handshaking;
  LinkFailure? _failure;
  PeerInfo? _peer;
  Uint8List? _key;
  Uint8List? _clientNonce;
  Uint8List? _serverNonce;
  SessionCipher? _cipher;
  Timer? _handshakeTimer;
  Timer? _approvalTimer;
  Timer? _pingTimer;
  Timer? _idleTimer;
  Future<void> _sending = Future.value();

  /// Which of the server's keys the phone used: 0 the current one, 1 the
  /// key it is being moved to.
  int? keyIndex;

  /// Why the peer ended the session, when it said so (`user`, `shutdown`).
  String? peerCloseReason;

  ChannelState get state => _state;
  LinkFailure? get failure => _failure;
  PeerInfo? get peer => _peer;
  bool get isReady => _state == ChannelState.ready;
  Stream<TcpMessage> get messages => _messages.stream;
  Stream<ChannelState> get states => _states.stream;

  /// Completes when the link is ready; fails with [LinkException] when it
  /// ends first. On the phone it also completes while the desktop asks its
  /// user to accept this phone.
  Future<void> get established => _ready.future;

  int get maxFrame =>
      _state == ChannelState.ready || _state == ChannelState.awaitingApproval
      ? maxSessionFrameBytes
      : maxHandshakeFrameBytes;

  void start() {
    // Server channels are never awaited; a failure is still delivered to
    // whoever awaits [established].
    _ready.future.ignore();
    _handshakeTimer = Timer(
      timings.handshake,
      () => _fail(LinkFailure.noAnswer, 'handshake timed out'),
    );
    _touch();
    if (!_isServer) {
      _clientNonce = _randomBytes(16);
      _key = _keys.first;
      _sendRaw(
        sealHandshake(_key!, MessageType.hello, {
          'v': protocolVersion,
          'id': localId,
          'name': localName,
          'cn': base64Url.encode(_clientNonce!),
        }),
      );
    }
  }

  /// A frame body from the link below.
  void receive(Uint8List body) {
    if (_state == ChannelState.closed) return;
    _touch();
    if (body.isEmpty) return;
    switch (body[0]) {
      case _kindUnknownKey when !_isServer && _cipher == null:
        _fail(LinkFailure.unknownKey);
      case _kindHandshake:
        _onHandshake(body);
      case _kindSession:
        _onSession(body);
      default:
        if (_isServer && _cipher == null) {
          // An older app version, or not this app at all.
          _fail(LinkFailure.version, 'unreadable first frame');
        } else {
          _drop('unknown frame kind ${body[0]}');
        }
    }
  }

  void _onHandshake(Uint8List body) {
    if (_isServer) {
      if (_clientNonce != null) {
        // Only the hello and the confirm come this way.
        final opened = openHandshake(_key!, body);
        if (opened == null ||
            opened.$1 != MessageType.confirm ||
            _cipher != null) {
          _fail(LinkFailure.badProof, 'unexpected handshake frame');
          return;
        }
        _onConfirm(opened.$2);
        return;
      }
      for (var i = 0; i < _keys.length; i++) {
        final opened = openHandshake(_keys[i], body);
        if (opened == null) continue;
        keyIndex = i;
        _key = _keys[i];
        _onHello(opened.$1, opened.$2);
        return;
      }
      _sendRaw(Uint8List.fromList([_kindUnknownKey]));
      _fail(LinkFailure.unknownKey);
      return;
    }

    final opened = openHandshake(_key!, body);
    if (opened == null) {
      _fail(LinkFailure.badProof, 'unreadable handshake answer');
      return;
    }
    final (type, json) = opened;
    switch (type) {
      case MessageType.ack when _cipher == null:
        _onAck(json);
      case MessageType.reject:
        _fail(_rejection(json['reason']));
      default:
        _fail(LinkFailure.badProof, 'unexpected ${type.name}');
    }
  }

  static LinkFailure _rejection(Object? reason) => switch (reason) {
    'version' => LinkFailure.version,
    'declined' => LinkFailure.declined,
    _ => LinkFailure.noAnswer,
  };

  void _onHello(MessageType type, Map<String, dynamic> json) {
    if (type != MessageType.hello) {
      _fail(LinkFailure.badProof, 'first frame is ${type.name}');
      return;
    }
    if (json['v'] != protocolVersion) {
      _sendRaw(sealHandshake(_key!, MessageType.reject, {'reason': 'version'}));
      _fail(LinkFailure.version, 'hello v${json['v']}');
      return;
    }
    final id = json['id'];
    final cn = _nonceFrom(json['cn']);
    if (id is! String || id.isEmpty || cn == null) {
      _fail(LinkFailure.badProof, 'incomplete hello');
      return;
    }
    final name = json['name'];
    _peer = PeerInfo(deviceId: id, name: name is String ? name : '');
    _clientNonce = cn;
    _serverNonce = _randomBytes(16);
    _sendRaw(
      sealHandshake(_key!, MessageType.ack, {
        'v': protocolVersion,
        'id': localId,
        'name': localName,
        'sn': base64Url.encode(_serverNonce!),
        'proof': base64Url.encode(
          _proof('server', serverId: localId, clientId: id),
        ),
      }),
    );
  }

  void _onAck(Map<String, dynamic> json) {
    if (json['v'] != protocolVersion) {
      _fail(LinkFailure.version, 'ack v${json['v']}');
      return;
    }
    final id = json['id'];
    final sn = _nonceFrom(json['sn']);
    final proof = _nonceFrom(json['proof'], length: 32);
    if (id is! String || sn == null || proof == null) {
      _fail(LinkFailure.badProof, 'incomplete ack');
      return;
    }
    if (id != _expectedPeerId) {
      _fail(LinkFailure.wrongDesktop, 'answered by $id');
      return;
    }
    _serverNonce = sn;
    if (!_equal(proof, _proof('server', serverId: id, clientId: localId))) {
      _fail(LinkFailure.badProof, 'server proof');
      return;
    }
    final name = json['name'];
    _peer = PeerInfo(deviceId: id, name: name is String ? name : '');
    _sendRaw(
      sealHandshake(_key!, MessageType.confirm, {
        'proof': base64Url.encode(
          _proof('client', serverId: id, clientId: localId),
        ),
      }),
    );
    _deriveSession();
    // The desktop now says ready, or that its user has to accept this phone
    // first; the handshake timer keeps running until one of them arrives.
    _startPinging();
  }

  void _onConfirm(Map<String, dynamic> json) {
    final proof = _nonceFrom(json['proof'], length: 32);
    final peer = _peer!;
    if (proof == null ||
        !_equal(
          proof,
          _proof('client', serverId: localId, clientId: peer.deviceId),
        )) {
      _fail(LinkFailure.badProof, 'client proof');
      return;
    }
    _deriveSession();
    _handshakeTimer?.cancel();
    if (_isPairedPeer!(peer.deviceId)) {
      _becomeReady();
    } else {
      _approvalTimer = Timer(timings.approval, decline);
      // Tells the phone to wait for the desktop's user.
      _sendSession(MessageType.ack, Uint8List(0));
      _setState(ChannelState.awaitingApproval);
    }
  }

  /// Desktop: the user accepted the phone that is waiting.
  void approve() {
    if (!_isServer || _state != ChannelState.awaitingApproval) return;
    _approvalTimer?.cancel();
    _becomeReady();
  }

  /// Desktop: the user declined it, or nobody answered.
  void decline() {
    if (!_isServer || _state != ChannelState.awaitingApproval) return;
    _sendRaw(sealHandshake(_key!, MessageType.reject, {'reason': 'declined'}));
    _fail(LinkFailure.declined);
  }

  void _becomeReady() {
    if (_isServer) _sendSession(MessageType.ready, Uint8List(0));
    _handshakeTimer?.cancel();
    _setState(ChannelState.ready);
    if (!_ready.isCompleted) _ready.complete();
  }

  void _onSession(Uint8List body) {
    final cipher = _cipher;
    if (cipher == null) {
      _fail(LinkFailure.badProof, 'session frame before the handshake');
      return;
    }
    final TcpMessage message;
    try {
      message = cipher.open(body);
    } catch (e) {
      // A tampered, replayed or reordered frame: the stream can't be trusted
      // past it.
      _fail(LinkFailure.badProof, 'session frame rejected: $e');
      return;
    }
    switch (message.type) {
      case MessageType.ping:
        _sendSession(MessageType.pong, Uint8List(0));
      case MessageType.pong:
        break;
      case MessageType.ready when !_isServer:
        _becomeReady();
      case MessageType.ack
          when !_isServer && _state == ChannelState.handshaking:
        _handshakeTimer?.cancel();
        _setState(ChannelState.awaitingApproval);
      case MessageType.kill:
        try {
          final json = jsonDecode(utf8.decode(message.payload));
          if (json is Map && json['reason'] is String) {
            peerCloseReason = json['reason'] as String;
          }
        } catch (_) {
          // An empty kill: no reason given.
        }
        close(sendKill: false);
      case MessageType.data when _state == ChannelState.ready:
        _messages.add(message);
      default:
        _drop('${message.type.name} in ${_state.name}');
    }
  }

  void _deriveSession() {
    final salt = Uint8List.fromList([..._clientNonce!, ..._serverNonce!]);
    final c2s = _hkdf(_key!, salt, 'hw-link-2 c2s');
    final s2c = _hkdf(_key!, salt, 'hw-link-2 s2c');
    _cipher = _isServer ? SessionCipher(s2c, c2s) : SessionCipher(c2s, s2c);
  }

  Uint8List _proof(
    String role, {
    required String serverId,
    required String clientId,
  }) => _hmac(_key!, [
    ...utf8.encode('hw-link-2 $role|$serverId|$clientId|'),
    ..._clientNonce!,
    ..._serverNonce!,
  ]);

  static Uint8List? _nonceFrom(Object? value, {int length = 16}) {
    if (value is! String) return null;
    try {
      final bytes = base64Url.decode(value);
      return bytes.length == length ? bytes : null;
    } on FormatException {
      return null;
    }
  }

  static bool _equal(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }

  /// Sends an application message. Throws [LinkNotConnectedException] when
  /// the link isn't ready, and completes once the bytes were handed to the
  /// socket.
  Future<void> send(MessageType type, Uint8List payload) {
    if (_state != ChannelState.ready) {
      return Future.error(const LinkNotConnectedException());
    }
    return _sendSession(type, payload);
  }

  Future<void> _sendSession(MessageType type, Uint8List payload) =>
      _sendRaw(_cipher!.seal(type, payload));

  /// Bodies go out one after the other, in call order; what was queued
  /// before the channel closed still goes out before the endpoint closes.
  Future<void> _sendRaw(Uint8List body) {
    if (_state == ChannelState.closed) {
      return Future.error(const LinkNotConnectedException());
    }
    final next = _sending.then((_) => _endpoint.sendBody(body));
    _sending = next.catchError((Object e) {
      debugPrint('[Link] send failed: $e');
    });
    return next;
  }

  void _startPinging() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(timings.pingInterval, (_) {
      _sendSession(MessageType.ping, Uint8List(0)).catchError((Object e) {
        debugPrint('[Link] ping failed: $e');
      });
    });
  }

  void _touch() {
    _idleTimer?.cancel();
    _idleTimer = Timer(
      _isServer ? timings.serverIdle : timings.clientIdle,
      () => _fail(LinkFailure.noAnswer, 'nothing received'),
    );
  }

  void _drop(String why) => debugPrint('[Link] dropped a frame: $why');

  void _fail(LinkFailure failure, [String? detail]) {
    if (_state == ChannelState.closed) return;
    debugPrint('[Link] ${failure.name}${detail == null ? '' : ': $detail'}');
    _failure = failure;
    _shutDown();
    if (!_ready.isCompleted) {
      _ready.completeError(LinkException(failure, detail));
    }
  }

  /// Ends the session; with [sendKill] the peer is told first, and why.
  Future<void> close({bool sendKill = true, String? reason}) async {
    if (_state == ChannelState.closed) return;
    if (sendKill && _cipher != null) {
      try {
        final payload = reason == null
            ? Uint8List(0)
            : Uint8List.fromList(utf8.encode(jsonEncode({'reason': reason})));
        await _sendSession(
          MessageType.kill,
          payload,
        ).timeout(const Duration(seconds: 2));
      } catch (e) {
        debugPrint('[Link] kill not sent: $e');
      }
    }
    _shutDown();
    if (!_ready.isCompleted) {
      _ready.completeError(const LinkException(LinkFailure.noAnswer, 'closed'));
    }
  }

  /// The link below went away.
  void lowerClosed() {
    if (_state == ChannelState.closed) return;
    _fail(LinkFailure.noAnswer, 'connection closed');
  }

  void _shutDown() {
    _handshakeTimer?.cancel();
    _approvalTimer?.cancel();
    _pingTimer?.cancel();
    _idleTimer?.cancel();
    _setState(ChannelState.closed);
    _sending.whenComplete(_endpoint.close);
    _messages.close();
    _states.close();
  }

  void _setState(ChannelState state) {
    if (_state == state) return;
    _state = state;
    if (!_states.isClosed) _states.add(state);
    if (state == ChannelState.awaitingApproval &&
        !_isServer &&
        !_ready.isCompleted) {
      _ready.complete();
    }
  }
}
