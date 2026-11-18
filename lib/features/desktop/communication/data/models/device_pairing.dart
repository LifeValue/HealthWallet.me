import 'dart:convert';
import 'dart:math';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:health_wallet/features/desktop/communication/data/services/link_protocol.dart';
import 'package:uuid/uuid.dart';

part 'device_pairing.freezed.dart';
part 'device_pairing.g.dart';

/// The pairing between this device and the other one. On the phone it
/// describes the desktop (from its QR code); on the desktop it is the
/// desktop's own identity, key and the phone it is paired with.
@freezed
abstract class DevicePairing with _$DevicePairing {
  const DevicePairing._();

  const factory DevicePairing({
    required String deviceId,
    required String deviceName,
    required String pairingKey,
    required String lastIp,
    required int lastPort,
    String? lastSsid,
    String? lastPassword,
    required DateTime pairedAt,
    String? os,

    /// Desktop: the phone that may connect without asking, null until the
    /// first one paired.
    String? peerDeviceId,
    String? peerDeviceName,

    /// Desktop: the key handed to the phone and not yet confirmed. Both keys
    /// are accepted until the phone uses the new one.
    String? pendingKey,
  }) = _DevicePairing;

  factory DevicePairing.fromJson(Map<String, dynamic> json) =>
      _$DevicePairingFromJson(json);

  static String newKey() {
    final random = Random.secure();
    return base64Url.encode(List<int>.generate(32, (_) => random.nextInt(256)));
  }

  static DevicePairing generate({
    required String deviceName,
    required String localIp,
    int port = 49152,
    String? os,
  }) {
    return DevicePairing(
      deviceId: const Uuid().v4(),
      deviceName: deviceName,
      pairingKey: newKey(),
      lastIp: localIp,
      lastPort: port,
      pairedAt: DateTime.now(),
      os: os,
    );
  }

  /// The keys a phone may use, current first.
  List<String> get acceptedKeys => [pairingKey, ?pendingKey];

  /// What the desktop's QR code carries.
  String toQrPayload() => jsonEncode({
    'v': protocolVersion,
    'device_id': deviceId,
    'ip': lastIp,
    'port': lastPort,
    'pairing_key': pairingKey,
    'device_name': deviceName,
    'os': os,
  });

  /// Reads a scanned QR code.
  static PairingQr parseQr(String data) {
    final Object? json;
    try {
      json = jsonDecode(data);
    } on FormatException {
      return const PairingQr.notPairing();
    }
    if (json is! Map<String, dynamic> ||
        !json.containsKey('pairing_key') ||
        !json.containsKey('device_id')) {
      return const PairingQr.notPairing();
    }
    if (json['v'] != protocolVersion) return const PairingQr.outdated();

    final deviceId = json['device_id'];
    final key = json['pairing_key'];
    final ip = json['ip'];
    final port = json['port'];
    final name = json['device_name'];
    if (deviceId is! String ||
        deviceId.isEmpty ||
        key is! String ||
        !isValidPairingKey(key) ||
        ip is! String ||
        port is! int ||
        port < 1 ||
        port > 65535) {
      return const PairingQr.invalid();
    }
    return PairingQr.valid(
      DevicePairing(
        deviceId: deviceId,
        deviceName: name is String && name.isNotEmpty ? name : deviceId,
        pairingKey: key,
        lastIp: ip,
        lastPort: port,
        pairedAt: DateTime.now(),
        os: json['os'] as String?,
      ),
    );
  }
}

/// The outcome of reading a QR code that may be a desktop's pairing code.
sealed class PairingQr {
  const PairingQr();

  const factory PairingQr.valid(DevicePairing pairing) = ValidPairingQr;

  /// Not a pairing code at all (e.g. a Fasten code).
  const factory PairingQr.notPairing() = NotPairingQr;

  /// A pairing code from a desktop app that speaks an older protocol.
  const factory PairingQr.outdated() = OutdatedPairingQr;

  /// A pairing code with a missing or malformed field.
  const factory PairingQr.invalid() = InvalidPairingQr;
}

class ValidPairingQr extends PairingQr {
  const ValidPairingQr(this.pairing);

  final DevicePairing pairing;
}

class NotPairingQr extends PairingQr {
  const NotPairingQr();
}

class OutdatedPairingQr extends PairingQr {
  const OutdatedPairingQr();
}

class InvalidPairingQr extends PairingQr {
  const InvalidPairingQr();
}
