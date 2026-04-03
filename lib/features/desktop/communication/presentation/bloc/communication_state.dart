part of 'communication_bloc.dart';

enum ConnectionStatus { disconnected, discovering, connected }

enum ConnectionTransport { tcp, multipeerConnectivity, unknown }

@freezed
class DesktopSyncState with _$DesktopSyncState {
  const factory DesktopSyncState({
    @Default(ConnectionStatus.disconnected) ConnectionStatus connectionStatus,
    @Default(ConnectionTransport.unknown)
    ConnectionTransport connectionTransport,
    DevicePairing? pairedDevice,
    String? connectedIp,
    int? connectedPort,
    String? connectedDeviceName,
    String? error,
    @Default(false) bool vpnDetected,
  }) = _DesktopSyncState;

  factory DesktopSyncState.initial() => const DesktopSyncState();
}
