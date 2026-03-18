import 'package:freezed_annotation/freezed_annotation.dart';

part 'peer_device.freezed.dart';
part 'peer_device.g.dart';

enum PeerConnectionStatus {
  discovered,
  connecting,
  connected,
  handshakeComplete,
  failed,
}

@freezed
class PeerDevice with _$PeerDevice {
  const PeerDevice._();

  const factory PeerDevice({
    required String deviceId,
    String? deviceName,
    String? osType,
    @Default(PeerConnectionStatus.discovered) PeerConnectionStatus status,
    DateTime? discoveredAt,
  }) = _PeerDevice;

  factory PeerDevice.fromJson(Map<String, dynamic> json) =>
      _$PeerDeviceFromJson(json);

  factory PeerDevice.fromPeerDiscovery(Map<String, dynamic> data) {
    return PeerDevice(
      deviceId: data['deviceId'] as String? ?? '',
      deviceName: data['deviceName'] as String?,
      osType: data['osType'] as String?,
      status: _parseStatus(data['connectionStatus'] as String?),
      discoveredAt: DateTime.now(),
    );
  }

  String get displayName => deviceName ?? 'Unknown Device';

  bool get isIOS => osType?.toLowerCase() == 'ios';

  bool get isAndroid => osType?.toLowerCase() == 'android';
}

PeerConnectionStatus _parseStatus(String? status) {
  switch (status?.toLowerCase()) {
    case 'connecting':
      return PeerConnectionStatus.connecting;
    case 'connected':
      return PeerConnectionStatus.connected;
    case 'handshake_complete':
    case 'handshakecomplete':
      return PeerConnectionStatus.handshakeComplete;
    case 'failed':
      return PeerConnectionStatus.failed;
    default:
      return PeerConnectionStatus.discovered;
  }
}
