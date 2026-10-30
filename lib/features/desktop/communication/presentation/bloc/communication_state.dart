part of 'communication_bloc.dart';

enum ConnectionStatus { disconnected, discovering, awaitingApproval, connected }

enum ConnectionTransport { tcp, multipeerConnectivity, unknown }

/// Why the phone isn't connected, for the message the user sees.
enum LinkIssue {
  /// Nothing answered at any known address.
  notFound,

  /// The desktop has a new pairing; scan its QR code again.
  keyRejected,

  /// The desktop's user declined this phone.
  declined,

  /// The other device runs an older app version.
  desktopOutdated,
}

@freezed
abstract class DesktopSyncState with _$DesktopSyncState {
  const factory DesktopSyncState({
    @Default(ConnectionStatus.disconnected) ConnectionStatus connectionStatus,
    @Default(ConnectionTransport.unknown)
    ConnectionTransport connectionTransport,
    DevicePairing? pairedDevice,
    String? connectedIp,
    int? connectedPort,
    String? connectedDeviceName,
    LinkIssue? issue,
    @Default(false) bool vpnDetected,

    /// Desktop: no usable network address, so no phone can reach it.
    @Default(false) bool networkUnavailable,

    /// Desktop: a phone with an older app version tried to connect.
    @Default(false) bool outdatedPhoneSeen,

    /// Desktop: the phone waiting for the user to accept it.
    String? pendingApprovalName,
  }) = _DesktopSyncState;

  factory DesktopSyncState.initial() => const DesktopSyncState();
}
