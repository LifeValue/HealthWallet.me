import 'dart:convert';
import 'dart:math';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:uuid/uuid.dart';

part 'device_pairing.freezed.dart';
part 'device_pairing.g.dart';

@freezed
class DevicePairing with _$DevicePairing {
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
  }) = _DevicePairing;

  factory DevicePairing.fromJson(Map<String, dynamic> json) =>
      _$DevicePairingFromJson(json);

  static DevicePairing generate({
    required String deviceName,
    required String localIp,
    int port = 49152,
    String? os,
  }) {
    final random = Random.secure();
    final keyBytes = List<int>.generate(32, (_) => random.nextInt(256));

    return DevicePairing(
      deviceId: const Uuid().v4(),
      deviceName: deviceName,
      pairingKey: base64Url.encode(keyBytes),
      lastIp: localIp,
      lastPort: port,
      pairedAt: DateTime.now(),
      os: os,
    );
  }
}
